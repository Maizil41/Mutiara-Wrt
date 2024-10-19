package Tie::RefHash;

use vars qw/$VERSION/;

$VERSION = "1.39";

use 5.005;


use Tie::Hash;
use vars '@ISA';
@ISA = qw(Tie::Hash);
use strict;
use Carp qw/croak/;

BEGIN {
  local $@;
  # determine whether we need to take care of threads
  use Config ();
  my $usethreads = $Config::Config{usethreads}; # && exists $INC{"threads.pm"}
  *_HAS_THREADS = $usethreads ? sub () { 1 } : sub () { 0 };
  *_HAS_SCALAR_UTIL = eval { require Scalar::Util; 1 } ? sub () { 1 } : sub () { 0 };
  *_HAS_WEAKEN = defined(&Scalar::Util::weaken) ? sub () { 1 } : sub () { 0 };
}

BEGIN {
  # create a refaddr function

  local $@;

  if ( _HAS_SCALAR_UTIL ) {
    Scalar::Util->import("refaddr");
  } else {
    require overload;

    *refaddr = sub {
      if ( overload::StrVal($_[0]) =~ /\( 0x ([a-zA-Z0-9]+) \)$/x) {
          return $1;
      } else {
        die "couldn't parse StrVal: " . overload::StrVal($_[0]);
      }
    };
  }
}

my (@thread_object_registry, $count); # used by the CLONE method to rehash the keys after their refaddr changed

sub TIEHASH {
  my $c = shift;
  my $s = [];
  bless $s, $c;
  while (@_) {
    $s->STORE(shift, shift);
  }

  if (_HAS_THREADS ) {

    if ( _HAS_WEAKEN ) {
      # remember the object so that we can rekey it on CLONE
      push @thread_object_registry, $s;
      # but make this a weak reference, so that there are no leaks
      Scalar::Util::weaken( $thread_object_registry[-1] );

      if ( ++$count > 1000 ) {
        # this ensures we don't fill up with a huge array dead weakrefs
        @thread_object_registry = grep { defined } @thread_object_registry;
        $count = 0;
      }
    } else {
      $count++; # used in the warning
    }
  }

  return $s;
}

my $storable_format_version = join("/", __PACKAGE__, "0.01");

sub STORABLE_freeze {
  my ( $self, $is_cloning ) = @_;
  my ( $refs, $reg ) = @$self;
  return ( $storable_format_version, [ values %$refs ], $reg || {} );
}

sub STORABLE_thaw {
  my ( $self, $is_cloning, $version, $refs, $reg ) = @_;
  croak "incompatible versions of Tie::RefHash between freeze and thaw"
    unless $version eq $storable_format_version;

  @$self = ( {}, $reg );
  $self->_reindex_keys( $refs );
}

sub CLONE {
  my $pkg = shift;

  if ( $count and not _HAS_WEAKEN ) {
    warn "Tie::RefHash is not threadsafe without Scalar::Util::weaken";
  }

  # when the thread has been cloned all the objects need to be updated.
  # dead weakrefs are undefined, so we filter them out
  @thread_object_registry = grep { defined && do { $_->_reindex_keys; 1 } } @thread_object_registry;
  $count = 0; # we just cleaned up
}

sub _reindex_keys {
  my ( $self, $extra_keys ) = @_;
  # rehash all the ref keys based on their new StrVal
  %{ $self->[0] } = map { refaddr($_->[0]) => $_ } (values(%{ $self->[0] }), @{ $extra_keys || [] });
}

sub FETCH {
  my($s, $k) = @_;
  if (ref $k) {
      my $kstr = refaddr($k);
      if (defined $s->[0]{$kstr}) {
        $s->[0]{$kstr}[1];
      }
      else {
        undef;
      }
  }
  else {
      $s->[1]{$k};
  }
}

sub STORE {
  my($s, $k, $v) = @_;
  if (ref $k) {
    $s->[0]{refaddr($k)} = [$k, $v];
  }
  else {
    $s->[1]{$k} = $v;
  }
  $v;
}

sub DELETE {
  my($s, $k) = @_;
  (ref $k)
    ? (delete($s->[0]{refaddr($k)}) || [])->[1]
    : delete($s->[1]{$k});
}

sub EXISTS {
  my($s, $k) = @_;
  (ref $k) ? exists($s->[0]{refaddr($k)}) : exists($s->[1]{$k});
}

sub FIRSTKEY {
  my $s = shift;
  keys %{$s->[0]};  # reset iterator
  keys %{$s->[1]};  # reset iterator
  $s->[2] = 0;      # flag for iteration, see NEXTKEY
  $s->NEXTKEY;
}

sub NEXTKEY {
  my $s = shift;
  my ($k, $v);
  if (!$s->[2]) {
    if (($k, $v) = each %{$s->[0]}) {
      return $v->[0];
    }
    else {
      $s->[2] = 1;
    }
  }
  return each %{$s->[1]};
}

sub CLEAR {
  my $s = shift;
  $s->[2] = 0;
  %{$s->[0]} = ();
  %{$s->[1]} = ();
}

package Tie::RefHash::Nestable;
use vars '@ISA';
@ISA = 'Tie::RefHash';

sub STORE {
  my($s, $k, $v) = @_;
  if (ref($v) eq 'HASH' and not tied %$v) {
      my @elems = %$v;
      tie %$v, ref($s), @elems;
  }
  $s->SUPER::STORE($k, $v);
}

1;
