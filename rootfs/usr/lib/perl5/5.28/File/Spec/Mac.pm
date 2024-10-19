package File::Spec::Mac;

use strict;
use Cwd ();
require File::Spec::Unix;

our $VERSION = '3.74';
$VERSION =~ tr/_//d;

our @ISA = qw(File::Spec::Unix);

sub case_tolerant { 1 }



sub canonpath {
    my ($self,$path) = @_;
    return $path;
}


sub catdir {
	my $self = shift;
	return '' unless @_;
	my @args = @_;
	my $first_arg;
	my $relative;

	# take care of the first argument

	if ($args[0] eq '')  { # absolute path, rootdir
		shift @args;
		$relative = 0;
		$first_arg = $self->rootdir;

	} elsif ($args[0] =~ /^[^:]+:/) { # absolute path, volume name
		$relative = 0;
		$first_arg = shift @args;
		# add a trailing ':' if need be (may be it's a path like HD:dir)
		$first_arg = "$first_arg:" unless ($first_arg =~ /:\Z(?!\n)/);

	} else { # relative path
		$relative = 1;
		if ( $args[0] =~ /^::+\Z(?!\n)/ ) {
			# updir colon path ('::', ':::' etc.), don't shift
			$first_arg = ':';
		} elsif ($args[0] eq ':') {
			$first_arg = shift @args;
		} else {
			# add a trailing ':' if need be
			$first_arg = shift @args;
			$first_arg = "$first_arg:" unless ($first_arg =~ /:\Z(?!\n)/);
		}
	}

	# For all other arguments,
	# (a) ignore arguments that equal ':' or '',
	# (b) handle updir paths specially:
	#     '::' 			-> concatenate '::'
	#     '::' . '::' 	-> concatenate ':::' etc.
	# (c) add a trailing ':' if need be

	my $result = $first_arg;
	while (@args) {
		my $arg = shift @args;
		unless (($arg eq '') || ($arg eq ':')) {
			if ($arg =~ /^::+\Z(?!\n)/ ) { # updir colon path like ':::'
				my $updir_count = length($arg) - 1;
				while ((@args) && ($args[0] =~ /^::+\Z(?!\n)/) ) { # while updir colon path
					$arg = shift @args;
					$updir_count += (length($arg) - 1);
				}
				$arg = (':' x $updir_count);
			} else {
				$arg =~ s/^://s; # remove a leading ':' if any
				$arg = "$arg:" unless ($arg =~ /:\Z(?!\n)/); # ensure trailing ':'
			}
			$result .= $arg;
		}#unless
	}

	if ( ($relative) && ($result !~ /^:/) ) {
		# add a leading colon if need be
		$result = ":$result";
	}

	unless ($relative) {
		# remove updirs immediately following the volume name
		$result =~ s/([^:]+:)(:*)(.*)\Z(?!\n)/$1$3/;
	}

	return $result;
}


sub catfile {
    my $self = shift;
    return '' unless @_;
    my $file = pop @_;
    return $file unless @_;
    my $dir = $self->catdir(@_);
    $file =~ s/^://s;
    return $dir.$file;
}


sub curdir {
    return ":";
}


sub devnull {
    return "Dev:Null";
}


sub rootdir { '' }


sub tmpdir {
    my $cached = $_[0]->_cached_tmpdir('TMPDIR');
    return $cached if defined $cached;
    $_[0]->_cache_tmpdir($_[0]->_tmpdir( $ENV{TMPDIR} ), 'TMPDIR');
}


sub updir {
    return "::";
}


sub file_name_is_absolute {
    my ($self,$file) = @_;
    if ($file =~ /:/) {
	return (! ($file =~ m/^:/s) );
    } elsif ( $file eq '' ) {
        return 1 ;
    } else {
	return 0; # i.e. a file like "a"
    }
}


sub path {
    return unless exists $ENV{Commands};
    return split(/,/, $ENV{Commands});
}


sub splitpath {
    my ($self,$path, $nofile) = @_;
    my ($volume,$directory,$file);

    if ( $nofile ) {
        ( $volume, $directory ) = $path =~ m|^((?:[^:]+:)?)(.*)|s;
    }
    else {
        $path =~
            m|^( (?: [^:]+: )? )
               ( (?: .*: )? )
               ( .* )
             |xs;
        $volume    = $1;
        $directory = $2;
        $file      = $3;
    }

    $volume = '' unless defined($volume);
	$directory = ":$directory" if ( $volume && $directory ); # take care of "HD::dir"
    if ($directory) {
        # Make sure non-empty directories begin and end in ':'
        $directory .= ':' unless (substr($directory,-1) eq ':');
        $directory = ":$directory" unless (substr($directory,0,1) eq ':');
    } else {
	$directory = '';
    }
    $file = '' unless defined($file);

    return ($volume,$directory,$file);
}



sub splitdir {
	my ($self, $path) = @_;
	my @result = ();
	my ($head, $sep, $tail, $volume, $directories);

	return @result if ( (!defined($path)) || ($path eq '') );
	return (':') if ($path eq ':');

	( $volume, $sep, $directories ) = $path =~ m|^((?:[^:]+:)?)(:*)(.*)|s;

	# deprecated, but handle it correctly
	if ($volume) {
		push (@result, $volume);
		$sep .= ':';
	}

	while ($sep || $directories) {
		if (length($sep) > 1) {
			my $updir_count = length($sep) - 1;
			for (my $i=0; $i<$updir_count; $i++) {
				# push '::' updir_count times;
				# simulate Unix '..' updirs
				push (@result, '::');
			}
		}
		$sep = '';
		if ($directories) {
			( $head, $sep, $tail ) = $directories =~ m|^((?:[^:]+)?)(:*)(.*)|s;
			push (@result, $head);
			$directories = $tail;
		}
	}
	return @result;
}



sub catpath {
    my ($self,$volume,$directory,$file) = @_;

    if ( (! $volume) && (! $directory) ) {
	$file =~ s/^:// if $file;
	return $file ;
    }

    # We look for a volume in $volume, then in $directory, but not both

    my ($dir_volume, $dir_dirs) = $self->splitpath($directory, 1);

    $volume = $dir_volume unless length $volume;
    my $path = $volume; # may be ''
    $path .= ':' unless (substr($path, -1) eq ':'); # ensure trailing ':'

    if ($directory) {
	$directory = $dir_dirs if $volume;
	$directory =~ s/^://; # remove leading ':' if any
	$path .= $directory;
	$path .= ':' unless (substr($path, -1) eq ':'); # ensure trailing ':'
    }

    if ($file) {
	$file =~ s/^://; # remove leading ':' if any
	$path .= $file;
    }

    return $path;
}


sub _resolve_updirs {
	my $path = shift @_;
	my $proceed;

	# resolve any updirs, e.g. "HD:tmp::file" -> "HD:file"
	do {
		$proceed = ($path =~ s/^(.*):[^:]+::(.*?)\z/$1:$2/);
	} while ($proceed);

	return $path;
}


sub abs2rel {
    my($self,$path,$base) = @_;

    # Clean up $path
    if ( ! $self->file_name_is_absolute( $path ) ) {
        $path = $self->rel2abs( $path ) ;
    }

    # Figure out the effective $base and clean it up.
    if ( !defined( $base ) || $base eq '' ) {
	$base = Cwd::getcwd();
    }
    elsif ( ! $self->file_name_is_absolute( $base ) ) {
        $base = $self->rel2abs( $base ) ;
	$base = _resolve_updirs( $base ); # resolve updirs in $base
    }
    else {
	$base = _resolve_updirs( $base );
    }

    # Split up paths - ignore $base's file
    my ( $path_vol, $path_dirs, $path_file ) =  $self->splitpath( $path );
    my ( $base_vol, $base_dirs )             =  $self->splitpath( $base );

    return $path unless lc( $path_vol ) eq lc( $base_vol );

    # Now, remove all leading components that are the same
    my @pathchunks = $self->splitdir( $path_dirs );
    my @basechunks = $self->splitdir( $base_dirs );
	
    while ( @pathchunks &&
	    @basechunks &&
	    lc( $pathchunks[0] ) eq lc( $basechunks[0] ) ) {
        shift @pathchunks ;
        shift @basechunks ;
    }

    # @pathchunks now has the directories to descend in to.
    # ensure relative path, even if @pathchunks is empty
    $path_dirs = $self->catdir( ':', @pathchunks );

    # @basechunks now contains the number of directories to climb out of.
    $base_dirs = (':' x @basechunks) . ':' ;

    return $self->catpath( '', $self->catdir( $base_dirs, $path_dirs ), $path_file ) ;
}


sub rel2abs {
    my ($self,$path,$base) = @_;

    if ( ! $self->file_name_is_absolute($path) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined( $base ) || $base eq '' ) {
	    $base = Cwd::getcwd();
        }
        elsif ( ! $self->file_name_is_absolute($base) ) {
            $base = $self->rel2abs($base) ;
        }

	# Split up paths

	# ignore $path's volume
        my ( $path_dirs, $path_file ) = ($self->splitpath($path))[1,2] ;

        # ignore $base's file part
	my ( $base_vol, $base_dirs ) = $self->splitpath($base) ;

	# Glom them together
	$path_dirs = ':' if ($path_dirs eq '');
	$base_dirs =~ s/:$//; # remove trailing ':', if any
	$base_dirs = $base_dirs . $path_dirs;

        $path = $self->catpath( $base_vol, $base_dirs, $path_file );
    }
    return $path;
}



1;
