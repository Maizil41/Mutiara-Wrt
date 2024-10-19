package File::Spec::VMS;

use strict;
use Cwd ();
require File::Spec::Unix;

our $VERSION = '3.74';
$VERSION =~ tr/_//d;

our @ISA = qw(File::Spec::Unix);

use File::Basename;
use VMS::Filespec;



my $use_feature;
BEGIN {
    if (eval { local $SIG{__DIE__};
               local @INC = @INC;
               pop @INC if $INC[-1] eq '.';
               require VMS::Feature; }) {
        $use_feature = 1;
    }
}

sub _unix_rpt {
    my $unix_rpt;
    if ($use_feature) {
        $unix_rpt = VMS::Feature::current("filename_unix_report");
    } else {
        my $env_unix_rpt = $ENV{'DECC$FILENAME_UNIX_REPORT'} || '';
        $unix_rpt = $env_unix_rpt =~ /^[ET1]/i; 
    }
    return $unix_rpt;
}



sub canonpath {
    my($self,$path) = @_;

    return undef unless defined $path;

    my $unix_rpt = $self->_unix_rpt;

    if ($path =~ m|/|) {
      my $pathify = $path =~ m|/\Z(?!\n)|;
      $path = $self->SUPER::canonpath($path);

      return $path if $unix_rpt;
      $path = $pathify ? vmspath($path) : vmsify($path);
    }

    $path =~ s/(?<!\^)</[/;			# < and >       ==> [ and ]
    $path =~ s/(?<!\^)>/]/;
    $path =~ s/(?<!\^)\]\[\./\.\]\[/g;		# ][.		==> .][
    $path =~ s/(?<!\^)\[000000\.\]\[/\[/g;	# [000000.][	==> [
    $path =~ s/(?<!\^)\[000000\./\[/g;		# [000000.	==> [
    $path =~ s/(?<!\^)\.\]\[000000\]/\]/g;	# .][000000]	==> ]
    $path =~ s/(?<!\^)\.\]\[/\./g;		# foo.][bar     ==> foo.bar
    1 while ($path =~ s/(?<!\^)([\[\.])(-+)\.(-+)([\.\]])/$1$2$3$4/);
						# That loop does the following
						# with any amount of dashes:
						# .-.-.		==> .--.
						# [-.-.		==> [--.
						# .-.-]		==> .--]
						# [-.-]		==> [--]
    1 while ($path =~ s/(?<!\^)([\[\.])(?:\^.|[^\]\.])+\.-(-+)([\]\.])/$1$2$3/);
						# That loop does the following
						# with any amount (minimum 2)
						# of dashes:
						# .foo.--.	==> .-.
						# .foo.--]	==> .-]
						# [foo.--.	==> [-.
						# [foo.--]	==> [-]
						#
						# And then, the remaining cases
    $path =~ s/(?<!\^)\[\.-/[-/;		# [.-		==> [-
    $path =~ s/(?<!\^)\.(?:\^.|[^\]\.])+\.-\./\./g;	# .foo.-.	==> .
    $path =~ s/(?<!\^)\[(?:\^.|[^\]\.])+\.-\./\[/g;	# [foo.-.	==> [
    $path =~ s/(?<!\^)\.(?:\^.|[^\]\.])+\.-\]/\]/g;	# .foo.-]	==> ]
						# [foo.-]       ==> [000000]
    $path =~ s/(?<!\^)\[(?:\^.|[^\]\.])+\.-\]/\[000000\]/g;
						# []		==>
    $path =~ s/(?<!\^)\[\]// unless $path eq '[]';
    return $unix_rpt ? unixify($path) : $path;
}


sub catdir {
    my $self = shift;
    my $dir = pop;

    my $unix_rpt = $self->_unix_rpt;

    my @dirs = grep {defined() && length()} @_;

    my $rslt;
    if (@dirs) {
	my $path = (@dirs == 1 ? $dirs[0] : $self->catdir(@dirs));
	my ($spath,$sdir) = ($path,$dir);
	$spath =~ s/\.dir\Z(?!\n)//i; $sdir =~ s/\.dir\Z(?!\n)//i; 

	if ($unix_rpt) {
	    $spath = unixify($spath) unless $spath =~ m#/#;
	    $sdir= unixify($sdir) unless $sdir =~ m#/#;
            return $self->SUPER::catdir($spath, $sdir)
	}

	$rslt = vmspath( unixify($spath) . '/' . unixify($sdir));

	# Special case for VMS absolute directory specs: these will have
	# had device prepended during trip through Unix syntax in
	# eliminate_macros(), since Unix syntax has no way to express
	# "absolute from the top of this device's directory tree".
	if ($spath =~ /^[\[<][^.\-]/s) { $rslt =~ s/^[^\[<]+//s; }

    } else {
	# Single directory. Return an empty string on null input; otherwise
	# just return a canonical path.

	if    (not defined $dir or not length $dir) {
	    $rslt = '';
	} else {
	    $rslt = $unix_rpt ? $dir : vmspath($dir);
	}
    }
    return $self->canonpath($rslt);
}


sub catfile {
    my $self = shift;
    my $tfile = pop();
    my $file = $self->canonpath($tfile);
    my @files = grep {defined() && length()} @_;

    my $unix_rpt = $self->_unix_rpt;

    my $rslt;
    if (@files) {
	my $path = (@files == 1 ? $files[0] : $self->catdir(@files));
	my $spath = $path;

        # Something building a VMS path in pieces may try to pass a
        # directory name in filename format, so normalize it.
	$spath =~ s/\.dir\Z(?!\n)//i;

        # If the spath ends with a directory delimiter and the file is bare,
        # then just concatenate them.
	if ($spath =~ /^(?<!\^)[^\)\]\/:>]+\)\Z(?!\n)/s && basename($file) eq $file) {
	    $rslt = "$spath$file";
	} else {
           $rslt = unixify($spath);
           $rslt .= (defined($rslt) && length($rslt) ? '/' : '') . unixify($file);
           $rslt = vmsify($rslt) unless $unix_rpt;
	}
    }
    else {
        # Only passed a single file?
        my $xfile = (defined($file) && length($file)) ? $file : '';

        $rslt = $unix_rpt ? $xfile : vmsify($xfile);
    }
    return $self->canonpath($rslt) unless $unix_rpt;

    # In Unix report mode, do not strip off redundant path information.
    return $rslt;
}



sub curdir {
    my $self = shift @_;
    return '.' if ($self->_unix_rpt);
    return '[]';
}


sub devnull {
    my $self = shift @_;
    return '/dev/null' if ($self->_unix_rpt);
    return "_NLA0:";
}


sub rootdir {
    my $self = shift @_;
    if ($self->_unix_rpt) {
       # Root may exist, try it first.
       my $try = '/';
       my ($dev1, $ino1) = stat('/');
       my ($dev2, $ino2) = stat('.');

       # Perl falls back to '.' if it can not determine '/'
       if (($dev1 != $dev2) || ($ino1 != $ino2)) {
           return $try;
       }
       # Fall back to UNIX format sys$disk.
       return '/sys$disk/';
    }
    return 'SYS$DISK:[000000]';
}


sub tmpdir {
    my $self = shift @_;
    my $tmpdir = $self->_cached_tmpdir('TMPDIR');
    return $tmpdir if defined $tmpdir;
    if ($self->_unix_rpt) {
        $tmpdir = $self->_tmpdir('/tmp', '/sys$scratch', $ENV{TMPDIR});
    }
    else {
        $tmpdir = $self->_tmpdir( 'sys$scratch:', $ENV{TMPDIR} );
    }
    $self->_cache_tmpdir($tmpdir, 'TMPDIR');
}


sub updir {
    my $self = shift @_;
    return '..' if ($self->_unix_rpt);
    return '[-]';
}


sub case_tolerant {
    return 1;
}


sub path {
    my (@dirs,$dir,$i);
    while ($dir = $ENV{'DCL$PATH;' . $i++}) { push(@dirs,$dir); }
    return @dirs;
}


sub file_name_is_absolute {
    my ($self,$file) = @_;
    # If it's a logical name, expand it.
    $file = $ENV{$file} while $file =~ /^[\w\$\-]+\Z(?!\n)/s && $ENV{$file};
    return scalar($file =~ m!^/!s             ||
		  $file =~ m![<\[][^.\-\]>]!  ||
		  $file =~ /^[A-Za-z0-9_\$\-\~]+(?<!\^):/);
}


sub splitpath {
    my($self,$path, $nofile) = @_;
    my($dev,$dir,$file)      = ('','','');
    my $vmsify_path = vmsify($path);

    if ( $nofile ) {
        #vmsify('d1/d2/d3') returns '[.d1.d2]d3'
        #vmsify('/d1/d2/d3') returns 'd1:[d2]d3'
        if( $vmsify_path =~ /(.*)\](.+)/ ){
            $vmsify_path = $1.'.'.$2.']';
        }
        $vmsify_path =~ /(.+:)?(.*)/s;
        $dir = defined $2 ? $2 : ''; # dir can be '0'
        return ($1 || '',$dir,$file);
    }
    else {
        $vmsify_path =~ /(.+:)?([\[<].*[\]>])?(.*)/s;
        return ($1 || '',$2 || '',$3);
    }
}


sub splitdir {
    my($self,$dirspec) = @_;
    my @dirs = ();
    return @dirs if ( (!defined $dirspec) || ('' eq $dirspec) );

    $dirspec =~ s/(?<!\^)</[/;                  # < and >	==> [ and ]
    $dirspec =~ s/(?<!\^)>/]/;
    $dirspec =~ s/(?<!\^)\]\[\./\.\]\[/g;	# ][.		==> .][
    $dirspec =~ s/(?<!\^)\[000000\.\]\[/\[/g;	# [000000.][	==> [
    $dirspec =~ s/(?<!\^)\[000000\./\[/g;	# [000000.	==> [
    $dirspec =~ s/(?<!\^)\.\]\[000000\]/\]/g;	# .][000000]	==> ]
    $dirspec =~ s/(?<!\^)\.\]\[/\./g;		# foo.][bar	==> foo.bar
    while ($dirspec =~ s/(^|[\[\<\.])\-(\-+)($|[\]\>\.])/$1-.$2$3/g) {}
						# That loop does the following
						# with any amount of dashes:
						# .--.		==> .-.-.
						# [--.		==> [-.-.
						# .--]		==> .-.-]
						# [--]		==> [-.-]
    $dirspec = "[$dirspec]" unless $dirspec =~ /(?<!\^)[\[<]/; # make legal
    $dirspec =~ s/^(\[|<)\./$1/;
    @dirs = split /(?<!\^)\./, vmspath($dirspec);
    $dirs[0] =~ s/^[\[<]//s;  $dirs[-1] =~ s/[\]>]\Z(?!\n)//s;
    @dirs;
}



sub catpath {
    my($self,$dev,$dir,$file) = @_;
    
    # We look for a volume in $dev, then in $dir, but not both
    my ($dir_volume, $dir_dir, $dir_file) = $self->splitpath($dir);
    $dev = $dir_volume unless length $dev;
    $dir = length $dir_file ? $self->catfile($dir_dir, $dir_file) : $dir_dir;
    
    if ($dev =~ m|^(?<!\^)/+([^/]+)|) { $dev = "$1:"; }
    else { $dev .= ':' unless $dev eq '' or $dev =~ /:\Z(?!\n)/; }
    if (length($dev) or length($dir)) {
        $dir = "[$dir]" unless $dir =~ /(?<!\^)[\[<\/]/;
        $dir = vmspath($dir);
    }
    $dir = '' if length($dev) && ($dir eq '[]' || $dir eq '<>');
    "$dev$dir$file";
}


sub abs2rel {
    my $self = shift;
    my($path,$base) = @_;

    $base = Cwd::getcwd() unless defined $base and length $base;

    # If there is no device or directory syntax on $base, make sure it
    # is treated as a directory.
    $base = vmspath($base) unless $base =~ m{(?<!\^)[\[<:]};

    for ($path, $base) { $_ = $self->rel2abs($_) }

    # Are we even starting $path on the same (node::)device as $base?  Note that
    # logical paths or nodename differences may be on the "same device" 
    # but the comparison that ignores device differences so as to concatenate 
    # [---] up directory specs is not even a good idea in cases where there is 
    # a logical path difference between $path and $base nodename and/or device.
    # Hence we fall back to returning the absolute $path spec
    # if there is a case blind device (or node) difference of any sort
    # and we do not even try to call $parse() or consult %ENV for $trnlnm()
    # (this module needs to run on non VMS platforms after all).
    
    my ($path_volume, $path_directories, $path_file) = $self->splitpath($path);
    my ($base_volume, $base_directories, $base_file) = $self->splitpath($base);
    return $self->canonpath( $path ) unless lc($path_volume) eq lc($base_volume);

    # Now, remove all leading components that are the same
    my @pathchunks = $self->splitdir( $path_directories );
    my $pathchunks = @pathchunks;
    unshift(@pathchunks,'000000') unless $pathchunks[0] eq '000000';
    my @basechunks = $self->splitdir( $base_directories );
    my $basechunks = @basechunks;
    unshift(@basechunks,'000000') unless $basechunks[0] eq '000000';

    while ( @pathchunks && 
            @basechunks && 
            lc( $pathchunks[0] ) eq lc( $basechunks[0] ) 
          ) {
        shift @pathchunks ;
        shift @basechunks ;
    }

    # @basechunks now contains the directories to climb out of,
    # @pathchunks now has the directories to descend in to.
    if ((@basechunks > 0) || ($basechunks != $pathchunks)) {
      $path_directories = join '.', ('-' x @basechunks, @pathchunks) ;
    }
    else {
      $path_directories = join '.', @pathchunks;
    }
    $path_directories = '['.$path_directories.']';
    return $self->canonpath( $self->catpath( '', $path_directories, $path_file ) ) ;
}



sub rel2abs {
    my $self = shift ;
    my ($path,$base ) = @_;
    return undef unless defined $path;
    if ($path =~ m/\//) {
       $path = ( -d $path || $path =~ m/\/\z/  # educated guessing about
                  ? vmspath($path)             # whether it's a directory
                  : vmsify($path) );
    }
    $base = vmspath($base) if defined $base && $base =~ m/\//;

    # Clean up and split up $path
    if ( ! $self->file_name_is_absolute( $path ) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined( $base ) || $base eq '' ) {
            $base = Cwd::getcwd();
        }
        elsif ( ! $self->file_name_is_absolute( $base ) ) {
            $base = $self->rel2abs( $base ) ;
        }
        else {
            $base = $self->canonpath( $base ) ;
        }

        # Split up paths
        my ( $path_directories, $path_file ) =
            ($self->splitpath( $path ))[1,2] ;

        my ( $base_volume, $base_directories ) =
            $self->splitpath( $base ) ;

        $path_directories = '' if $path_directories eq '[]' ||
                                  $path_directories eq '<>';
        my $sep = '' ;
        $sep = '.'
            if ( $base_directories =~ m{[^.\]>]\Z(?!\n)} &&
                 $path_directories =~ m{^[^.\[<]}s
            ) ;
        $base_directories = "$base_directories$sep$path_directories";
        $base_directories =~ s{\.?[\]>][\[<]\.?}{.};

        $path = $self->catpath( $base_volume, $base_directories, $path_file );
   }

    return $self->canonpath( $path ) ;
}



1;
