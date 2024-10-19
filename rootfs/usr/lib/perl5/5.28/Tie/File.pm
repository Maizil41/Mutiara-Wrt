
package Tie::File;
require 5.005;
use Carp ':DEFAULT', 'confess';
use POSIX 'SEEK_SET';
use Fcntl 'O_CREAT', 'O_RDWR', 'LOCK_EX', 'LOCK_SH', 'O_WRONLY', 'O_RDONLY';
sub O_ACCMODE () { O_RDONLY | O_RDWR | O_WRONLY }


$VERSION = "1.02";
my $DEFAULT_MEMORY_SIZE = 1<<21;    # 2 megabytes
my $DEFAULT_AUTODEFER_THRESHHOLD = 3; # 3 records
my $DEFAULT_AUTODEFER_FILELEN_THRESHHOLD = 65536; # 16 disk blocksful

my %good_opt = map {$_ => 1, "-$_" => 1}
                 qw(memory dw_size mode recsep discipline 
                    autodefer autochomp autodefer_threshhold concurrent);

sub TIEARRAY {
  if (@_ % 2 != 0) {
    croak "usage: tie \@array, $_[0], filename, [option => value]...";
  }
  my ($pack, $file, %opts) = @_;

  # transform '-foo' keys into 'foo' keys
  for my $key (keys %opts) {
    unless ($good_opt{$key}) {
      croak("$pack: Unrecognized option '$key'\n");
    }
    my $okey = $key;
    if ($key =~ s/^-+//) {
      $opts{$key} = delete $opts{$okey};
    }
  }

  if ($opts{concurrent}) {
    croak("$pack: concurrent access not supported yet\n");
  }

  unless (defined $opts{memory}) {
    # default is the larger of the default cache size and the 
    # deferred-write buffer size (if specified)
    $opts{memory} = $DEFAULT_MEMORY_SIZE;
    $opts{memory} = $opts{dw_size}
      if defined $opts{dw_size} && $opts{dw_size} > $DEFAULT_MEMORY_SIZE;
    # Dora Winifred Read
  }
  $opts{dw_size} = $opts{memory} unless defined $opts{dw_size};
  if ($opts{dw_size} > $opts{memory}) {
      croak("$pack: dw_size may not be larger than total memory allocation\n");
  }
  # are we in deferred-write mode?
  $opts{defer} = 0 unless defined $opts{defer};
  $opts{deferred} = {};         # no records are presently deferred
  $opts{deferred_s} = 0;        # count of total bytes in ->{deferred}
  $opts{deferred_max} = -1;     # empty

  # What's a good way to arrange that this class can be overridden?
  $opts{cache} = Tie::File::Cache->new($opts{memory});

  # autodeferment is enabled by default
  $opts{autodefer} = 1 unless defined $opts{autodefer};
  $opts{autodeferring} = 0;     # but is not initially active
  $opts{ad_history} = [];
  $opts{autodefer_threshhold} = $DEFAULT_AUTODEFER_THRESHHOLD
    unless defined $opts{autodefer_threshhold};
  $opts{autodefer_filelen_threshhold} = $DEFAULT_AUTODEFER_FILELEN_THRESHHOLD
    unless defined $opts{autodefer_filelen_threshhold};

  $opts{offsets} = [0];
  $opts{filename} = $file;
  unless (defined $opts{recsep}) { 
    $opts{recsep} = _default_recsep();
  }
  $opts{recseplen} = length($opts{recsep});
  if ($opts{recseplen} == 0) {
    croak "Empty record separator not supported by $pack";
  }

  $opts{autochomp} = 1 unless defined $opts{autochomp};

  $opts{mode} = O_CREAT|O_RDWR unless defined $opts{mode};
  $opts{rdonly} = (($opts{mode} & O_ACCMODE) == O_RDONLY);
  $opts{sawlastrec} = undef;

  my $fh;

  if (UNIVERSAL::isa($file, 'GLOB')) {
    # We use 1 here on the theory that some systems 
    # may not indicate failure if we use 0.
    # MSWin32 does not indicate failure with 0, but I don't know if
    # it will indicate failure with 1 or not.
    unless (seek $file, 1, SEEK_SET) {
      croak "$pack: your filehandle does not appear to be seekable";
    }
    seek $file, 0, SEEK_SET;    # put it back
    $fh = $file;                # setting binmode is the user's problem
  } elsif (ref $file) {
    croak "usage: tie \@array, $pack, filename, [option => value]...";
  } else {
    # $fh = \do { local *FH };  # XXX this is buggy
    if ($] < 5.006) {
	# perl 5.005 and earlier don't autovivify filehandles
	require Symbol;
	$fh = Symbol::gensym();
    }
    sysopen $fh, $file, $opts{mode}, 0666 or return;
    binmode $fh;
    ++$opts{ourfh};
  }
  { my $ofh = select $fh; $| = 1; select $ofh } # autoflush on write
  if (defined $opts{discipline} && $] >= 5.006) {
    # This avoids a compile-time warning under 5.005
    eval 'binmode($fh, $opts{discipline})';
    croak $@ if $@ =~ /unknown discipline/i;
    die if $@;
  }
  $opts{fh} = $fh;

  bless \%opts => $pack;
}

sub FETCH {
  my ($self, $n) = @_;
  my $rec;

  # check the defer buffer
  $rec = $self->{deferred}{$n} if exists $self->{deferred}{$n};
  $rec = $self->_fetch($n) unless defined $rec;

  # inlined _chomp1
  substr($rec, - $self->{recseplen}) = ""
    if defined $rec && $self->{autochomp};
  $rec;
}

sub _chomp {
  my $self = shift;
  return unless $self->{autochomp};
  if ($self->{autochomp}) {
    for (@_) {
      next unless defined;
      substr($_, - $self->{recseplen}) = "";
    }
  }
}

sub _chomp1 {
  my ($self, $rec) = @_;
  return $rec unless $self->{autochomp};
  return unless defined $rec;
  substr($rec, - $self->{recseplen}) = "";
  $rec;
}

sub _fetch {
  my ($self, $n) = @_;

  # check the record cache
  { my $cached = $self->{cache}->lookup($n);
    return $cached if defined $cached;
  }

  if ($#{$self->{offsets}} < $n) {
    return if $self->{eof};  # request for record beyond end of file
    my $o = $self->_fill_offsets_to($n);
    # If it's still undefined, there is no such record, so return 'undef'
    return unless defined $o;
  }

  my $fh = $self->{FH};
  $self->_seek($n);             # we can do this now that offsets is populated
  my $rec = $self->_read_record;


  $self->{cache}->insert($n, $rec) if defined $rec && not $self->{flushing};
  $rec;
}

sub STORE {
  my ($self, $n, $rec) = @_;
  die "STORE called from _check_integrity!" if $DIAGNOSTIC;

  $self->_fixrecs($rec);

  if ($self->{autodefer}) {
    $self->_annotate_ad_history($n);
  }

  return $self->_store_deferred($n, $rec) if $self->_is_deferring;


  # We need this to decide whether the new record will fit
  # It incidentally populates the offsets table 
  # Note we have to do this before we alter the cache
  # 20020324 Wait, but this DOES alter the cache.  TODO BUG?
  my $oldrec = $self->_fetch($n);

  if (not defined $oldrec) {
    # We're storing a record beyond the end of the file
    $self->_extend_file_to($n+1);
    $oldrec = $self->{recsep};
  }
  my $len_diff = length($rec) - length($oldrec);

  # length($oldrec) here is not consistent with text mode  TODO XXX BUG
  $self->_mtwrite($rec, $self->{offsets}[$n], length($oldrec));
  $self->_oadjust([$n, 1, $rec]);
  $self->{cache}->update($n, $rec);
}

sub _store_deferred {
  my ($self, $n, $rec) = @_;
  $self->{cache}->remove($n);
  my $old_deferred = $self->{deferred}{$n};

  if (defined $self->{deferred_max} && $n > $self->{deferred_max}) {
    $self->{deferred_max} = $n;
  }
  $self->{deferred}{$n} = $rec;

  my $len_diff = length($rec);
  $len_diff -= length($old_deferred) if defined $old_deferred;
  $self->{deferred_s} += $len_diff;
  $self->{cache}->adj_limit(-$len_diff);
  if ($self->{deferred_s} > $self->{dw_size}) {
    $self->_flush;
  } elsif ($self->_cache_too_full) {
    $self->_cache_flush;
  }
}

sub _delete_deferred {
  my ($self, $n) = @_;
  my $rec = delete $self->{deferred}{$n};
  return unless defined $rec;

  if (defined $self->{deferred_max} 
      && $n == $self->{deferred_max}) {
    undef $self->{deferred_max};
  }

  $self->{deferred_s} -= length $rec;
  $self->{cache}->adj_limit(length $rec);
}

sub FETCHSIZE {
  my $self = shift;
  my $n = $self->{eof} ? $#{$self->{offsets}} : $self->_fill_offsets;

  my $top_deferred = $self->_defer_max;
  $n = $top_deferred+1 if defined $top_deferred && $n < $top_deferred+1;
  $n;
}

sub STORESIZE {
  my ($self, $len) = @_;

  if ($self->{autodefer}) {
    $self->_annotate_ad_history('STORESIZE');
  }

  my $olen = $self->FETCHSIZE;
  return if $len == $olen;      # Woo-hoo!

  # file gets longer
  if ($len > $olen) {
    if ($self->_is_deferring) {
      for ($olen .. $len-1) {
        $self->_store_deferred($_, $self->{recsep});
      }
    } else {
      $self->_extend_file_to($len);
    }
    return;
  }

  # file gets shorter
  if ($self->_is_deferring) {
    # TODO maybe replace this with map-plus-assignment?
    for (grep $_ >= $len, keys %{$self->{deferred}}) {
      $self->_delete_deferred($_);
    }
    $self->{deferred_max} = $len-1;
  }

  $self->_seek($len);
  $self->_chop_file;
  $#{$self->{offsets}} = $len;

  $self->{cache}->remove(grep $_ >= $len, $self->{cache}->ckeys);
}

sub PUSH {
  my $self = shift;
  $self->SPLICE($self->FETCHSIZE, scalar(@_), @_);

  # No need to return:
  #  $self->FETCHSIZE;  # because av.c takes care of this for me
}

sub POP {
  my $self = shift;
  my $size = $self->FETCHSIZE;
  return if $size == 0;
  scalar $self->SPLICE($size-1, 1);
}

sub SHIFT {
  my $self = shift;
  scalar $self->SPLICE(0, 1);
}

sub UNSHIFT {
  my $self = shift;
  $self->SPLICE(0, 0, @_);
  # $self->FETCHSIZE; # av.c takes care of this for me
}

sub CLEAR {
  my $self = shift;

  if ($self->{autodefer}) {
    $self->_annotate_ad_history('CLEAR');
  }

  $self->_seekb(0);
  $self->_chop_file;
    $self->{cache}->set_limit($self->{memory});
    $self->{cache}->empty;
  @{$self->{offsets}} = (0);
  %{$self->{deferred}}= ();
    $self->{deferred_s} = 0;
    $self->{deferred_max} = -1;
}

sub EXTEND {
  my ($self, $n) = @_;

  # No need to pre-extend anything in this case
  return if $self->_is_deferring;

  $self->_fill_offsets_to($n);
  $self->_extend_file_to($n);
}

sub DELETE {
  my ($self, $n) = @_;

  if ($self->{autodefer}) {
    $self->_annotate_ad_history('DELETE');
  }

  my $lastrec = $self->FETCHSIZE-1;
  my $rec = $self->FETCH($n);
  $self->_delete_deferred($n) if $self->_is_deferring;
  if ($n == $lastrec) {
    $self->_seek($n);
    $self->_chop_file;
    $#{$self->{offsets}}--;
    $self->{cache}->remove($n);
    # perhaps in this case I should also remove trailing null records?
    # 20020316
    # Note that delete @a[-3..-1] deletes the records in the wrong order,
    # so we only chop the very last one out of the file.  We could repair this
    # by tracking deleted records inside the object.
  } elsif ($n < $lastrec) {
    $self->STORE($n, "");
  }
  $rec;
}

sub EXISTS {
  my ($self, $n) = @_;
  return 1 if exists $self->{deferred}{$n};
  $n < $self->FETCHSIZE;
}

sub SPLICE {
  my $self = shift;

  if ($self->{autodefer}) {
    $self->_annotate_ad_history('SPLICE');
  }

  $self->_flush if $self->_is_deferring; # move this up?
  if (wantarray) {
    $self->_chomp(my @a = $self->_splice(@_));
    @a;
  } else {
    $self->_chomp1(scalar $self->_splice(@_));
  }
}

sub DESTROY {
  my $self = shift;
  $self->flush if $self->_is_deferring;
  $self->{cache}->delink if defined $self->{cache}; # break circular link
  if ($self->{fh} and $self->{ourfh}) {
      delete $self->{ourfh};
      close delete $self->{fh};
  }
}

sub _splice {
  my ($self, $pos, $nrecs, @data) = @_;
  my @result;

  $pos = 0 unless defined $pos;

  # Deal with negative and other out-of-range positions
  # Also set default for $nrecs 
  {
    my $oldsize = $self->FETCHSIZE;
    $nrecs = $oldsize unless defined $nrecs;
    my $oldpos = $pos;

    if ($pos < 0) {
      $pos += $oldsize;
      if ($pos < 0) {
        croak "Modification of non-creatable array value attempted, " .
              "subscript $oldpos";
      }
    }

    if ($pos > $oldsize) {
      return unless @data;
      $pos = $oldsize;          # This is what perl does for normal arrays
    }

    # The manual is very unclear here
    if ($nrecs < 0) {
      $nrecs = $oldsize - $pos + $nrecs;
      $nrecs = 0 if $nrecs < 0;
    }

    # nrecs is too big---it really means "until the end"
    # 20030507
    if ($nrecs + $pos > $oldsize) {
      $nrecs = $oldsize - $pos;
    }
  }

  $self->_fixrecs(@data);
  my $data = join '', @data;
  my $datalen = length $data;
  my $oldlen = 0;

  # compute length of data being removed
  for ($pos .. $pos+$nrecs-1) {
    last unless defined $self->_fill_offsets_to($_);
    my $rec = $self->_fetch($_);
    last unless defined $rec;
    push @result, $rec;

    # Why don't we just use length($rec) here?
    # Because that record might have come from the cache.  _splice
    # might have been called to flush out the deferred-write records,
    # and in this case length($rec) is the length of the record to be
    # *written*, not the length of the actual record in the file.  But
    # the offsets are still true. 20020322
    $oldlen += $self->{offsets}[$_+1] - $self->{offsets}[$_]
      if defined $self->{offsets}[$_+1];
  }
  $self->_fill_offsets_to($pos+$nrecs);

  # Modify the file
  $self->_mtwrite($data, $self->{offsets}[$pos], $oldlen);
  # Adjust the offsets table
  $self->_oadjust([$pos, $nrecs, @data]);

  { # Take this read cache stuff out into a separate function
    # You made a half-attempt to put it into _oadjust.  
    # Finish something like that up eventually.
    # STORE also needs to do something similarish

    # update the read cache, part 1
    # modified records
    for ($pos .. $pos+$nrecs-1) {
      my $new = $data[$_-$pos];
      if (defined $new) {
        $self->{cache}->update($_, $new);
      } else {
        $self->{cache}->remove($_);
      }
    }
    
    # update the read cache, part 2
    # moved records - records past the site of the change
    # need to be renumbered
    # Maybe merge this with the previous block?
    {
      my @oldkeys = grep $_ >= $pos + $nrecs, $self->{cache}->ckeys;
      my @newkeys = map $_-$nrecs+@data, @oldkeys;
      $self->{cache}->rekey(\@oldkeys, \@newkeys);
    }

    # Now there might be too much data in the cache, if we spliced out
    # some short records and spliced in some long ones.  If so, flush
    # the cache.
    $self->_cache_flush;
  }

  # Yes, the return value of 'splice' *is* actually this complicated
  wantarray ? @result : @result ? $result[-1] : undef;
}


sub _twrite {
  my ($self, $data, $pos, $len) = @_;

  unless (defined $pos) {
    die "\$pos was undefined in _twrite";
  }

  my $len_diff = length($data) - $len;

  if ($len_diff == 0) {          # Woo-hoo!
    my $fh = $self->{fh};
    $self->_seekb($pos);
    $self->_write_record($data);
    return;                     # well, that was easy.
  }

  # the two records are of different lengths
  # our strategy here: rewrite the tail of the file,
  # reading ahead one buffer at a time
  # $bufsize is required to be at least as large as the data we're overwriting
  my $bufsize = _bufsize($len_diff);
  my ($writepos, $readpos) = ($pos, $pos+$len);
  my $next_block;
  my $more_data;

  # Seems like there ought to be a way to avoid the repeated code
  # and the special case here.  The read(1) is also a little weird.
  # Think about this.
  do {
    $self->_seekb($readpos);
    my $br = read $self->{fh}, $next_block, $bufsize;
    $more_data = read $self->{fh}, my($dummy), 1;
    $self->_seekb($writepos);
    $self->_write_record($data);
    $readpos += $br;
    $writepos += length $data;
    $data = $next_block;
  } while $more_data;
  $self->_seekb($writepos);
  $self->_write_record($next_block);

  # There might be leftover data at the end of the file
  $self->_chop_file if $len_diff < 0;
}

sub _iwrite {
  my $self = shift;
  my ($D, $s, $e) = @_;
  my $d = length $D;
  my $c = $e-$s-$d;
  local *FH = $self->{fh};
  confess "Not enough space to insert $d bytes between $s and $e"
    if $c < 0;
  confess "[$s,$e) is an invalid insertion range" if $e < $s;

  $self->_seekb($s);
  read FH, my $buf, $e-$s;

  $D .= substr($buf, 0, $c, "");

  $self->_seekb($s);
  $self->_write_record($D);

  return $buf;
}

sub _mtwrite {
  my $self = shift;
  my $unwritten = "";
  my $delta = 0;

  @_ % 3 == 0 
    or die "Arguments to _mtwrite did not come in groups of three";

  while (@_) {
    my ($data, $pos, $len) = splice @_, 0, 3;
    my $end = $pos + $len;  # The OLD end of the segment to be replaced
    $data = $unwritten . $data;
    $delta -= length($unwritten);
    $unwritten  = "";
    $pos += $delta;             # This is where the data goes now
    my $dlen = length $data;
    $self->_seekb($pos);
    if ($len >= $dlen) {        # the data will fit
      $self->_write_record($data);
      $delta += ($dlen - $len); # everything following moves down by this much
      $data = ""; # All the data in the buffer has been written
    } else {                    # won't fit
      my $writable = substr($data, 0, $len - $delta, "");
      $self->_write_record($writable);
      $delta += ($dlen - $len); # everything following moves down by this much
    } 

    # At this point we've written some but maybe not all of the data.
    # There might be a gap to close up, or $data might still contain a
    # bunch of unwritten data that didn't fit.
    my $ndlen = length $data;
    if ($delta == 0) {
      $self->_write_record($data);
    } elsif ($delta < 0) {
      # upcopy (close up gap)
      if (@_) {
        $self->_upcopy($end, $end + $delta, $_[1] - $end);  
      } else {
        $self->_upcopy($end, $end + $delta);  
      }
    } else {
      # downcopy (insert data that didn't fit; replace this data in memory
      # with _later_ data that doesn't fit)
      if (@_) {
        $unwritten = $self->_downcopy($data, $end, $_[1] - $end);
      } else {
        # Make the file longer to accommodate the last segment that doesn't
        $unwritten = $self->_downcopy($data, $end);
      }
    }
  }
}

sub _upcopy {
  my $blocksize = 8192;
  my ($self, $spos, $dpos, $len) = @_;
  if ($dpos > $spos) {
    die "source ($spos) was upstream of destination ($dpos) in _upcopy";
  } elsif ($dpos == $spos) {
    return;
  }

  while (! defined ($len) || $len > 0) {
    my $readsize = ! defined($len) ? $blocksize
               : $len > $blocksize ? $blocksize
               : $len;
      
    my $fh = $self->{fh};
    $self->_seekb($spos);
    my $bytes_read = read $fh, my($data), $readsize;
    $self->_seekb($dpos);
    if ($data eq "") { 
      $self->_chop_file;
      last;
    }
    $self->_write_record($data);
    $spos += $bytes_read;
    $dpos += $bytes_read;
    $len -= $bytes_read if defined $len;
  }
}

sub _downcopy {
  my $blocksize = 8192;
  my ($self, $data, $pos, $len) = @_;
  my $fh = $self->{fh};

  while (! defined $len || $len > 0) {
    my $readsize = ! defined($len) ? $blocksize 
      : $len > $blocksize? $blocksize : $len;
    $self->_seekb($pos);
    read $fh, my($old), $readsize;
    my $last_read_was_short = length($old) < $readsize;
    $data .= $old;
    my $writable;
    if ($last_read_was_short) {
      # If last read was short, then $data now contains the entire rest
      # of the file, so there's no need to write only one block of it
      $writable = $data;
      $data = "";
    } else {
      $writable = substr($data, 0, $readsize, "");
    }
    last if $writable eq "";
    $self->_seekb($pos);
    $self->_write_record($writable);
    last if $last_read_was_short && $data eq "";
    $len -= $readsize if defined $len;
    $pos += $readsize;
  }
  return $data;
}

sub _oadjust {
  my $self = shift;
  my $delta = 0;
  my $delta_recs = 0;
  my $prev_end = -1;
  my %newkeys;

  for (@_) {
    my ($pos, $nrecs, @data) = @$_;
    $pos += $delta_recs;

    # Adjust the offsets of the records after the previous batch up
    # to the first new one of this batch
    for my $i ($prev_end+2 .. $pos - 1) {
      $self->{offsets}[$i] += $delta;
      $newkey{$i} = $i + $delta_recs;
    }

    $prev_end = $pos + @data - 1; # last record moved on this pass 

    # Remove the offsets for the removed records;
    # replace with the offsets for the inserted records
    my @newoff = ($self->{offsets}[$pos] + $delta);
    for my $i (0 .. $#data) {
      my $newlen = length $data[$i];
      push @newoff, $newoff[$i] + $newlen;
      $delta += $newlen;
    }

    for my $i ($pos .. $pos+$nrecs-1) {
      last if $i+1 > $#{$self->{offsets}};
      my $oldlen = $self->{offsets}[$i+1] - $self->{offsets}[$i];
      $delta -= $oldlen;
    }


    # replace old offsets with new
    splice @{$self->{offsets}}, $pos, $nrecs+1, @newoff;
    # What if we just spliced out the end of the offsets table?
    # shouldn't we clear $self->{eof}?   Test for this XXX BUG TODO

    $delta_recs += @data - $nrecs; # net change in total number of records
  }

  # The trailing records at the very end of the file
  if ($delta) {
    for my $i ($prev_end+2 .. $#{$self->{offsets}}) {
      $self->{offsets}[$i] += $delta;
    }
  }

  # If we scrubbed out all known offsets, regenerate the trivial table
  # that knows that the file does indeed start at 0.
  $self->{offsets}[0] = 0 unless @{$self->{offsets}};
  # If the file got longer, the offsets table is no longer complete
  # $self->{eof} = 0 if $delta_recs > 0;

  # Now there might be too much data in the cache, if we spliced out
  # some short records and spliced in some long ones.  If so, flush
  # the cache.
  $self->_cache_flush;
}

sub _fixrecs {
  my $self = shift;
  for (@_) {
    $_ = "" unless defined $_;
    $_ .= $self->{recsep}
      unless substr($_, - $self->{recseplen}) eq $self->{recsep};
  }
}



sub _seek {
  my ($self, $n) = @_;
  my $o = $self->{offsets}[$n];
  defined($o)
    or confess("logic error: undefined offset for record $n");
  seek $self->{fh}, $o, SEEK_SET
    or confess "Couldn't seek filehandle: $!";  # "Should never happen."
}

sub _seekb {
  my ($self, $b) = @_;
  seek $self->{fh}, $b, SEEK_SET
    or die "Couldn't seek filehandle: $!";  # "Should never happen."
}

sub _fill_offsets_to {
  my ($self, $n) = @_;

  return $self->{offsets}[$n] if $self->{eof};

  my $fh = $self->{fh};
  local *OFF = $self->{offsets};
  my $rec;

  until ($#OFF >= $n) {
    $self->_seek(-1);           # tricky -- see comment at _seek
    $rec = $self->_read_record;
    if (defined $rec) {
      push @OFF, int(tell $fh);  # Tels says that int() saves memory here
    } else {
      $self->{eof} = 1;
      return;                   # It turns out there is no such record
    }
  }

  # we have now read all the records up to record n-1,
  # so we can return the offset of record n
  $OFF[$n];
}

sub _fill_offsets {
  my ($self) = @_;

  my $fh = $self->{fh};
  local *OFF = $self->{offsets};

  $self->_seek(-1);           # tricky -- see comment at _seek

  # Tels says that inlining read_record() would make this loop
  # five times faster. 20030508
  while ( defined $self->_read_record()) {
    # int() saves us memory here
    push @OFF, int(tell $fh);
  }

  $self->{eof} = 1;
  $#OFF;
}

sub _write_record {
  my ($self, $rec) = @_;
  my $fh = $self->{fh};
  local $\ = "";
  print $fh $rec
    or die "Couldn't write record: $!";  # "Should never happen."
}

sub _read_record {
  my $self = shift;
  my $rec;
  { local $/ = $self->{recsep};
    my $fh = $self->{fh};
    $rec = <$fh>;
  }
  return unless defined $rec;
  if (substr($rec, -$self->{recseplen}) ne $self->{recsep}) {
    # improperly terminated final record --- quietly fix it.
    $self->{sawlastrec} = 1;
    unless ($self->{rdonly}) {
      local $\ = "";
      my $fh = $self->{fh};
      print $fh $self->{recsep};
    }
    $rec .= $self->{recsep};
  }
  $rec;
}

sub _rw_stats {
  my $self = shift;
  @{$self}{'_read', '_written'};
}


sub _cache_flush {
  my ($self) = @_;
  $self->{cache}->reduce_size_to($self->{memory} - $self->{deferred_s});
}

sub _cache_too_full {
  my $self = shift;
  $self->{cache}->bytes + $self->{deferred_s} >= $self->{memory};
}



sub _extend_file_to {
  my ($self, $n) = @_;
  $self->_seek(-1);             # position after the end of the last record
  my $pos = $self->{offsets}[-1];

  # the offsets table has one entry more than the total number of records
  my $extras = $n - $#{$self->{offsets}};

  # Todo : just use $self->{recsep} x $extras here?
  while ($extras-- > 0) {
    $self->_write_record($self->{recsep});
    push @{$self->{offsets}}, int(tell $self->{fh});
  }
}

sub _chop_file {
  my $self = shift;
  truncate $self->{fh}, tell($self->{fh});
}


sub _bufsize {
  my $n = shift;
  return 8192 if $n <= 0;
  my $b = $n & ~8191;
  $b += 8192 if $n & 8191;
  $b;
}


sub flock {
  my ($self, $op) = @_;
  unless (@_ <= 3) {
    my $pack = ref $self;
    croak "Usage: $pack\->flock([OPERATION])";
  }
  my $fh = $self->{fh};
  $op = LOCK_EX unless defined $op;
  my $locked = flock $fh, $op;

  if ($locked && ($op & (LOCK_EX | LOCK_SH))) {
    # If you're locking the file, then presumably it's because
    # there might have been a write access by another process.
    # In that case, the read cache contents and the offsets table
    # might be invalid, so discard them.  20030508
    $self->{offsets} = [0];
    $self->{cache}->empty;
  }

  $locked;
}

sub autochomp {
  my $self = shift;
  if (@_) {
    my $old = $self->{autochomp};
    $self->{autochomp} = shift;
    $old;
  } else {
    $self->{autochomp};
  }
}

sub offset {
  my ($self, $n) = @_;

  if ($#{$self->{offsets}} < $n) {
    return if $self->{eof};     # request for record beyond the end of file
    my $o = $self->_fill_offsets_to($n);
    # If it's still undefined, there is no such record, so return 'undef'
    return unless defined $o;
   }

  $self->{offsets}[$n];
}

sub discard_offsets {
  my $self = shift;
  $self->{offsets} = [0];
}


sub defer {
  my $self = shift;
  $self->_stop_autodeferring;
  @{$self->{ad_history}} = ();
  $self->{defer} = 1;
}

sub flush {
  my $self = shift;

  $self->_flush;
  $self->{defer} = 0;
}

sub _old_flush {
  my $self = shift;
  my @writable = sort {$a<=>$b} (keys %{$self->{deferred}});

  while (@writable) {
    # gather all consecutive records from the front of @writable
    my $first_rec = shift @writable;
    my $last_rec = $first_rec+1;
    ++$last_rec, shift @writable while @writable && $last_rec == $writable[0];
    --$last_rec;
    $self->_fill_offsets_to($last_rec);
    $self->_extend_file_to($last_rec);
    $self->_splice($first_rec, $last_rec-$first_rec+1, 
                   @{$self->{deferred}}{$first_rec .. $last_rec});
  }

  $self->_discard;               # clear out defered-write-cache
}

sub _flush {
  my $self = shift;
  my @writable = sort {$a<=>$b} (keys %{$self->{deferred}});
  my @args;
  my @adjust;

  while (@writable) {
    # gather all consecutive records from the front of @writable
    my $first_rec = shift @writable;
    my $last_rec = $first_rec+1;
    ++$last_rec, shift @writable while @writable && $last_rec == $writable[0];
    --$last_rec;
    my $end = $self->_fill_offsets_to($last_rec+1);
    if (not defined $end) {
      $self->_extend_file_to($last_rec);
      $end = $self->{offsets}[$last_rec];
    }
    my ($start) = $self->{offsets}[$first_rec];
    push @args,
         join("", @{$self->{deferred}}{$first_rec .. $last_rec}), # data
         $start,                                                  # position
         $end-$start;                                             # length
    push @adjust, [$first_rec, # starting at this position...
                   $last_rec-$first_rec+1,  # this many records...
                   # are replaced with these...
                   @{$self->{deferred}}{$first_rec .. $last_rec},
                  ];
  }

  $self->_mtwrite(@args);  # write multiple record groups
  $self->_discard;               # clear out defered-write-cache
  $self->_oadjust(@adjust);
}

sub discard {
  my $self = shift;
  $self->_discard;
  $self->{defer} = 0;
}

sub _discard {
  my $self = shift;
  %{$self->{deferred}} = ();
  $self->{deferred_s}  = 0;
  $self->{deferred_max}  = -1;
  $self->{cache}->set_limit($self->{memory});
}

sub _is_deferring {
  my $self = shift;
  $self->{defer} || $self->{autodeferring};
}

sub _defer_max {
  my $self = shift;
  return $self->{deferred_max} if defined $self->{deferred_max};
  my $max = -1;
  for my $key (keys %{$self->{deferred}}) {
    $max = $key if $key > $max;
  }
  $self->{deferred_max} = $max;
  $max;
}


sub autodefer {
  my $self = shift;
  if (@_) {
    my $old = $self->{autodefer};
    $self->{autodefer} = shift;
    if ($old) {
      $self->_stop_autodeferring;
      @{$self->{ad_history}} = ();
    }
    $old;
  } else {
    $self->{autodefer};
  }
}

sub _annotate_ad_history {
  my ($self, $n) = @_;
  return unless $self->{autodefer}; # feature is disabled
  return if $self->{defer};     # already in explicit defer mode
  return unless $self->{offsets}[-1] >= $self->{autodefer_filelen_threshhold};

  local *H = $self->{ad_history};
  if ($n eq 'CLEAR') {
    @H = (-2, -1);              # prime the history with fake records
    $self->_stop_autodeferring;
  } elsif ($n =~ /^\d+$/) {
    if (@H == 0) {
      @H =  ($n, $n);
    } else {                    # @H == 2
      if ($H[1] == $n-1) {      # another consecutive record
        $H[1]++;
        if ($H[1] - $H[0] + 1 >= $self->{autodefer_threshhold}) {
          $self->{autodeferring} = 1;
        }
      } else {                  # nonconsecutive- erase and start over
        @H = ($n, $n);
        $self->_stop_autodeferring;
      }
    }
  } else {                      # SPLICE or STORESIZE or some such
    @H = ();
    $self->_stop_autodeferring;
  }
}

sub _stop_autodeferring {
  my $self = shift;
  if ($self->{autodeferring}) {
    $self->_flush;
  }
  $self->{autodeferring} = 0;
}



sub _default_recsep {
  my $recsep = $/;
  if ($^O eq 'MSWin32') {       # Dos too?
    # Windows users expect files to be terminated with \r\n
    # But $/ is set to \n instead
    # Note that this also transforms \n\n into \r\n\r\n.
    # That is a feature.
    $recsep =~ s/\n/\r\n/g;
  }
  $recsep;
}

sub _ci_warn {
  my $msg = shift;
  $msg =~ s/\n/\\n/g;
  $msg =~ s/\r/\\r/g;
  print "# $msg\n";
}

sub _check_integrity {
  my ($self, $file, $warn) = @_;
  my $rsl = $self->{recseplen};
  my $rs  = $self->{recsep};
  my $good = 1; 
  local *_;                     # local $_ does not work here
  local $DIAGNOSTIC = 1;

  if (not defined $rs) {
    _ci_warn("recsep is undef!");
    $good = 0;
  } elsif ($rs eq "") {
    _ci_warn("recsep is empty!");
    $good = 0;
  } elsif ($rsl != length $rs) {
    my $ln = length $rs;
    _ci_warn("recsep <$rs> has length $ln, should be $rsl");
    $good = 0;
  }

  if (not defined $self->{offsets}[0]) {
    _ci_warn("offset 0 is missing!");
    $good = 0;

  } elsif ($self->{offsets}[0] != 0) {
    _ci_warn("rec 0: offset <$self->{offsets}[0]> s/b 0!");
    $good = 0;
  }

  my $cached = 0;
  {
    local *F = $self->{fh};
    seek F, 0, SEEK_SET;
    local $. = 0;
    local $/ = $rs;

    while (<F>) {
      my $n = $. - 1;
      my $cached = $self->{cache}->_produce($n);
      my $offset = $self->{offsets}[$.];
      my $ao = tell F;
      if (defined $offset && $offset != $ao) {
        _ci_warn("rec $n: offset <$offset> actual <$ao>");
        $good = 0;
      }
      if (defined $cached && $_ ne $cached && ! $self->{deferred}{$n}) {
        $good = 0;
        _ci_warn("rec $n: cached <$cached> actual <$_>");
      }
      if (defined $cached && substr($cached, -$rsl) ne $rs) {
        $good = 0;
        _ci_warn("rec $n in the cache is missing the record separator");
      }
      if (! defined $offset && $self->{eof}) {
        $good = 0;
        _ci_warn("The offset table was marked complete, but it is missing " .
                 "element $.");
      }
    }
    if (@{$self->{offsets}} > $.+1) {
        $good = 0;
        my $n = @{$self->{offsets}};
        _ci_warn("The offset table has $n items, but the file has only $.");
    }

    my $deferring = $self->_is_deferring;
    for my $n ($self->{cache}->ckeys) {
      my $r = $self->{cache}->_produce($n);
      $cached += length($r);
      next if $n+1 <= $.;         # checked this already
      _ci_warn("spurious caching of record $n");
      $good = 0;
    }
    my $b = $self->{cache}->bytes;
    if ($cached != $b) {
      _ci_warn("cache size is $b, should be $cached");
      $good = 0;
    }
  }

  # That cache has its own set of tests
  $good = 0 unless $self->{cache}->_check_integrity;

  # Now let's check the deferbuffer
  # Unless deferred writing is enabled, it should be empty
  if (! $self->_is_deferring && %{$self->{deferred}}) {
    _ci_warn("deferred writing disabled, but deferbuffer nonempty");
    $good = 0;
  }

  # Any record in the deferbuffer should *not* be present in the readcache
  my $deferred_s = 0;
  while (my ($n, $r) = each %{$self->{deferred}}) {
    $deferred_s += length($r);
    if (defined $self->{cache}->_produce($n)) {
      _ci_warn("record $n is in the deferbuffer *and* the readcache");
      $good = 0;
    }
    if (substr($r, -$rsl) ne $rs) {
      _ci_warn("rec $n in the deferbuffer is missing the record separator");
      $good = 0;
    }
  }

  # Total size of deferbuffer should match internal total
  if ($deferred_s != $self->{deferred_s}) {
    _ci_warn("buffer size is $self->{deferred_s}, should be $deferred_s");
    $good = 0;
  }

  # Total size of deferbuffer should not exceed the specified limit
  if ($deferred_s > $self->{dw_size}) {
    _ci_warn("buffer size is $self->{deferred_s} which exceeds the limit " .
             "of $self->{dw_size}");
    $good = 0;
  }

  # Total size of cached data should not exceed the specified limit
  if ($deferred_s + $cached > $self->{memory}) {
    my $total = $deferred_s + $cached;
    _ci_warn("total stored data size is $total which exceeds the limit " .
             "of $self->{memory}");
    $good = 0;
  }

  # Stuff related to autodeferment
  if (!$self->{autodefer} && @{$self->{ad_history}}) {
    _ci_warn("autodefer is disabled, but ad_history is nonempty");
    $good = 0;
  }
  if ($self->{autodeferring} && $self->{defer}) {
    _ci_warn("both autodeferring and explicit deferring are active");
    $good = 0;
  }
  if (@{$self->{ad_history}} == 0) {
    # That's OK, no additional tests required
  } elsif (@{$self->{ad_history}} == 2) {
    my @non_number = grep !/^-?\d+$/, @{$self->{ad_history}};
    if (@non_number) {
      my $msg;
      { local $" = ')(';
        $msg = "ad_history contains non-numbers (@{$self->{ad_history}})";
      }
      _ci_warn($msg);
      $good = 0;
    } elsif ($self->{ad_history}[1] < $self->{ad_history}[0]) {
      _ci_warn("ad_history has nonsensical values @{$self->{ad_history}}");
      $good = 0;
    }
  } else {
    _ci_warn("ad_history has bad length <@{$self->{ad_history}}>");
    $good = 0;
  }

  $good;
}


package Tie::File::Cache;
$Tie::File::Cache::VERSION = $Tie::File::VERSION;
use Carp ':DEFAULT', 'confess';

sub HEAP () { 0 }
sub HASH () { 1 }
sub MAX  () { 2 }
sub BYTES() { 3 }
use strict 'vars';

sub new {
  my ($pack, $max) = @_;
  local *_;
  croak "missing argument to ->new" unless defined $max;
  my $self = [];
  bless $self => $pack;
  @$self = (Tie::File::Heap->new($self), {}, $max, 0);
  $self;
}

sub adj_limit {
  my ($self, $n) = @_;
  $self->[MAX] += $n;
}

sub set_limit {
  my ($self, $n) = @_;
  $self->[MAX] = $n;
}

sub _heap_move {
  my ($self, $k, $n) = @_;
  if (defined $n) {
    $self->[HASH]{$k} = $n;
  } else {
    delete $self->[HASH]{$k};
  }
}

sub insert {
  my ($self, $key, $val) = @_;
  local *_;
  croak "missing argument to ->insert" unless defined $key;
  unless (defined $self->[MAX]) {
    confess "undefined max" ;
  }
  confess "undefined val" unless defined $val;
  return if length($val) > $self->[MAX];


  my $oldnode = $self->[HASH]{$key};
  if (defined $oldnode) {
    my $oldval = $self->[HEAP]->set_val($oldnode, $val);
    $self->[BYTES] -= length($oldval);
  } else {
    $self->[HEAP]->insert($key, $val);
  }
  $self->[BYTES] += length($val);
  $self->flush if $self->[BYTES] > $self->[MAX];
}

sub expire {
  my $self = shift;
  my $old_data = $self->[HEAP]->popheap;
  return unless defined $old_data;
  $self->[BYTES] -= length $old_data;
  $old_data;
}

sub remove {
  my ($self, @keys) = @_;
  my @result;


  for my $key (@keys) {
    next unless exists $self->[HASH]{$key};
    my $old_data = $self->[HEAP]->remove($self->[HASH]{$key});
    $self->[BYTES] -= length $old_data;
    push @result, $old_data;
  }
  @result;
}

sub lookup {
  my ($self, $key) = @_;
  local *_;
  croak "missing argument to ->lookup" unless defined $key;


  if (exists $self->[HASH]{$key}) {
    $self->[HEAP]->lookup($self->[HASH]{$key});
  } else {
    return;
  }
}

sub _produce {
  my ($self, $key) = @_;
  my $loc = $self->[HASH]{$key};
  return unless defined $loc;
  $self->[HEAP][$loc][2];
}

sub _promote {
  my ($self, $key) = @_;
  $self->[HEAP]->promote($self->[HASH]{$key});
}

sub empty {
  my ($self) = @_;
  %{$self->[HASH]} = ();
    $self->[BYTES] = 0;
    $self->[HEAP]->empty;
}

sub is_empty {
  my ($self) = @_;
  keys %{$self->[HASH]} == 0;
}

sub update {
  my ($self, $key, $val) = @_;
  local *_;
  croak "missing argument to ->update" unless defined $key;
  if (length($val) > $self->[MAX]) {
    my ($oldval) = $self->remove($key);
    $self->[BYTES] -= length($oldval) if defined $oldval;
  } elsif (exists $self->[HASH]{$key}) {
    my $oldval = $self->[HEAP]->set_val($self->[HASH]{$key}, $val);
    $self->[BYTES] += length($val);
    $self->[BYTES] -= length($oldval) if defined $oldval;
  } else {
    $self->[HEAP]->insert($key, $val);
    $self->[BYTES] += length($val);
  }
  $self->flush;
}

sub rekey {
  my ($self, $okeys, $nkeys) = @_;
  local *_;
  my %map;
  @map{@$okeys} = @$nkeys;
  croak "missing argument to ->rekey" unless defined $nkeys;
  croak "length mismatch in ->rekey arguments" unless @$nkeys == @$okeys;
  my %adjusted;                 # map new keys to heap indices
  # You should be able to cut this to one loop TODO XXX
  for (0 .. $#$okeys) {
    $adjusted{$nkeys->[$_]} = delete $self->[HASH]{$okeys->[$_]};
  }
  while (my ($nk, $ix) = each %adjusted) {
    # @{$self->[HASH]}{keys %adjusted} = values %adjusted;
    $self->[HEAP]->rekey($ix, $nk);
    $self->[HASH]{$nk} = $ix;
  }
}

sub ckeys {
  my $self = shift;
  my @a = keys %{$self->[HASH]};
  @a;
}

sub bytes {
  my $self = shift;
  $self->[BYTES];
}

sub reduce_size_to {
  my ($self, $max) = @_;
  until ($self->[BYTES] <= $max) {
    # Note that Tie::File::Cache::expire has been inlined here
    my $old_data = $self->[HEAP]->popheap;
    return unless defined $old_data;
    $self->[BYTES] -= length $old_data;
  }
}

sub flush {
  my $self = shift;
  $self->reduce_size_to($self->[MAX]) if $self->[BYTES] > $self->[MAX];
}

sub _produce_lru {
  my $self = shift;
  $self->[HEAP]->expire_order;
}

BEGIN { *_ci_warn = \&Tie::File::_ci_warn }

sub _check_integrity {          # For CACHE
  my $self = shift;
  my $good = 1;

  # Test HEAP
  $self->[HEAP]->_check_integrity or $good = 0;

  # Test HASH
  my $bytes = 0;
  for my $k (keys %{$self->[HASH]}) {
    if ($k ne '0' && $k !~ /^[1-9][0-9]*$/) {
      $good = 0;
      _ci_warn "Cache hash key <$k> is non-numeric";
    }

    my $h = $self->[HASH]{$k};
    if (! defined $h) {
      $good = 0;
      _ci_warn "Heap index number for key $k is undefined";
    } elsif ($h == 0) {
      $good = 0;
      _ci_warn "Heap index number for key $k is zero";
    } else {
      my $j = $self->[HEAP][$h];
      if (! defined $j) {
        $good = 0;
        _ci_warn "Heap contents key $k (=> $h) are undefined";
      } else {
        $bytes += length($j->[2]);
        if ($k ne $j->[1]) {
          $good = 0;
          _ci_warn "Heap contents key $k (=> $h) is $j->[1], should be $k";
        }
      }
    }
  }

  # Test BYTES
  if ($bytes != $self->[BYTES]) {
    $good = 0;
    _ci_warn "Total data in cache is $bytes, expected $self->[BYTES]";
  }

  # Test MAX
  if ($bytes > $self->[MAX]) {
    $good = 0;
    _ci_warn "Total data in cache is $bytes, exceeds maximum $self->[MAX]";
  }

  return $good;
}

sub delink {
  my $self = shift;
  $self->[HEAP] = undef;        # Bye bye heap
}


package Tie::File::Heap;
use Carp ':DEFAULT', 'confess';
$Tie::File::Heap::VERSION = $Tie::File::Cache::VERSION;
sub SEQ () { 0 };
sub KEY () { 1 };
sub DAT () { 2 };

sub new {
  my ($pack, $cache) = @_;
  die "$pack: Parent cache object $cache does not support _heap_move method"
    unless eval { $cache->can('_heap_move') };
  my $self = [[0,$cache,0]];
  bless $self => $pack;
}

sub _nseq {
  my $self = shift;
  $self->[0][0]++;
}

sub _cache {
  my $self = shift;
  $self->[0][1];
}

sub _nelts {
  my $self = shift;
  $self->[0][2];
}

sub _nelts_inc {
  my $self = shift;
  ++$self->[0][2];
}  

sub _nelts_dec {
  my $self = shift;
  --$self->[0][2];
}  

sub is_empty {
  my $self = shift;
  $self->_nelts == 0;
}

sub empty {
  my $self = shift;
  $#$self = 0;
  $self->[0][2] = 0;
  $self->[0][0] = 0;            # might as well reset the sequence numbers
}

sub _heap_move {
  my $self = shift;
  $self->_cache->_heap_move(@_);
}

sub insert {
  my ($self, $key, $data, $seq) = @_;
  $seq = $self->_nseq unless defined $seq;
  $self->_insert_new([$seq, $key, $data]);
}

sub _insert_new {
  my ($self, $item) = @_;
  my $i = @$self;
  $i = int($i/2) until defined $self->[$i/2];
  $self->[$i] = $item;
  $self->[0][1]->_heap_move($self->[$i][KEY], $i);
  $self->_nelts_inc;
}

sub _insert {
  my ($self, $item, $i) = @_;
  $i = 1 unless defined $i;
  until (! defined $self->[$i]) {
    if ($self->[$i][SEQ] > $item->[SEQ]) { # inserted item is older
      ($self->[$i], $item) = ($item, $self->[$i]);
      $self->[0][1]->_heap_move($self->[$i][KEY], $i);
    }
    # If either is undefined, go that way.  Otherwise, choose at random
    my $dir;
    $dir = 0 if !defined $self->[2*$i];
    $dir = 1 if !defined $self->[2*$i+1];
    $dir = int(rand(2)) unless defined $dir;
    $i = 2*$i + $dir;
  }
  $self->[$i] = $item;
  $self->[0][1]->_heap_move($self->[$i][KEY], $i);
  $self->_nelts_inc;
}

sub remove {
  my ($self, $i) = @_;
  $i = 1 unless defined $i;
  my $top = $self->[$i];
  return unless defined $top;
  while (1) {
    my $ii;
    my ($L, $R) = (2*$i, 2*$i+1);

    # If either is undefined, go the other way.
    # Otherwise, go towards the smallest.
    last unless defined $self->[$L] || defined $self->[$R];
    $ii = $R if not defined $self->[$L];
    $ii = $L if not defined $self->[$R];
    unless (defined $ii) {
      $ii = $self->[$L][SEQ] < $self->[$R][SEQ] ? $L : $R;
    }

    $self->[$i] = $self->[$ii]; # Promote child to fill vacated spot
    $self->[0][1]->_heap_move($self->[$i][KEY], $i);
    $i = $ii; # Fill new vacated spot
  }
  $self->[0][1]->_heap_move($top->[KEY], undef);
  undef $self->[$i];
  $self->_nelts_dec;
  return $top->[DAT];
}

sub popheap {
  my $self = shift;
  $self->remove(1);
}

sub promote {
  my ($self, $n) = @_;
  $self->[$n][SEQ] = $self->_nseq;
  my $i = $n;
  while (1) {
    my ($L, $R) = (2*$i, 2*$i+1);
    my $dir;
    last unless defined $self->[$L] || defined $self->[$R];
    $dir = $R unless defined $self->[$L];
    $dir = $L unless defined $self->[$R];
    unless (defined $dir) {
      $dir = $self->[$L][SEQ] < $self->[$R][SEQ] ? $L : $R;
    }
    @{$self}[$i, $dir] = @{$self}[$dir, $i];
    for ($i, $dir) {
      $self->[0][1]->_heap_move($self->[$_][KEY], $_) if defined $self->[$_];
    }
    $i = $dir;
  }
}

sub lookup {
  my ($self, $n) = @_;
  my $val = $self->[$n];
  $self->promote($n);
  $val->[DAT];
}


sub set_val {
  my ($self, $n, $val) = @_;
  my $oval = $self->[$n][DAT];
  $self->[$n][DAT] = $val;
  $self->promote($n);
  return $oval;
}

sub rekey {
  my ($self, $n, $new_key) = @_;
  $self->[$n][KEY] = $new_key;
}

sub _check_loc {
  my ($self, $n) = @_;
  unless (1 || defined $self->[$n]) {
    confess "_check_loc($n) failed";
  }
}

BEGIN { *_ci_warn = \&Tie::File::_ci_warn }

sub _check_integrity {
  my $self = shift;
  my $good = 1;
  my %seq;

  unless (eval {$self->[0][1]->isa("Tie::File::Cache")}) {
    _ci_warn "Element 0 of heap corrupt";
    $good = 0;
  }
  $good = 0 unless $self->_satisfies_heap_condition(1);
  for my $i (2 .. $#{$self}) {
    my $p = int($i/2);          # index of parent node
    if (defined $self->[$i] && ! defined $self->[$p]) {
      _ci_warn "Element $i of heap defined, but parent $p isn't";
      $good = 0;
    }

    if (defined $self->[$i]) {
      if ($seq{$self->[$i][SEQ]}) {
        my $seq = $self->[$i][SEQ];
        _ci_warn "Nodes $i and $seq{$seq} both have SEQ=$seq";
        $good = 0;
      } else {
        $seq{$self->[$i][SEQ]} = $i;
      }
    }
  }

  return $good;
}

sub _satisfies_heap_condition {
  my $self = shift;
  my $n = shift || 1;
  my $good = 1;
  for (0, 1) {
    my $c = $n*2 + $_;
    next unless defined $self->[$c];
    if ($self->[$n][SEQ] >= $self->[$c]) {
      _ci_warn "Node $n of heap does not predate node $c";
      $good = 0 ;
    }
    $good = 0 unless $self->_satisfies_heap_condition($c);
  }
  return $good;
}

sub expire_order {
  my $self = shift;
  my @nodes = sort {$a->[SEQ] <=> $b->[SEQ]} $self->_nodes;
  map { $_->[KEY] } @nodes;
}

sub _nodes {
  my $self = shift;
  my $i = shift || 1;
  return unless defined $self->[$i];
  ($self->[$i], $self->_nodes($i*2), $self->_nodes($i*2+1));
}

"Cogito, ergo sum.";  # don't forget to return a true value from the file

__END__


