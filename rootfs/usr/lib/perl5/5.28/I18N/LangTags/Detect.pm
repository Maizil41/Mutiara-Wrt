

require 5;
package I18N::LangTags::Detect;
use strict;

our ( $MATCH_SUPERS, $USING_LANGUAGE_TAGS,
             $USE_LITERALS, $MATCH_SUPERS_TIGHTLY);

BEGIN { unless(defined &DEBUG) { *DEBUG = sub () {0} } }
 # define the constant 'DEBUG' at compile-time

our $VERSION = "1.07";
our @ISA = ();
use I18N::LangTags qw(alternate_language_tags locale2language_tag);

sub _uniq { my %seen; return grep(!($seen{$_}++), @_); }
sub _normalize {
  my(@languages) =
    map lc($_),
    grep $_,
    map {; $_, alternate_language_tags($_) } @_;
  return _uniq(@languages) if wantarray;
  return $languages[0];
}


sub detect () { return __PACKAGE__->ambient_langprefs; }


sub ambient_langprefs { # always returns things untainted
  my $base_class = $_[0];
  
  return $base_class->http_accept_langs
   if length( $ENV{'REQUEST_METHOD'} || '' ); # I'm a CGI
       # it's off in its own routine because it's complicated

  # Not running as a CGI: try to puzzle out from the environment
  my @languages;

  foreach my $envname (qw( LANGUAGE LC_ALL LC_MESSAGES LANG )) {
    next unless $ENV{$envname};
    DEBUG and print "Noting \$$envname: $ENV{$envname}\n";
    push @languages,
      map locale2language_tag($_),
        # if it's a lg tag, fine, pass thru (untainted)
        # if it's a locale ID, try converting to a lg tag (untainted),
        # otherwise nix it.

      split m/[,:]/,
      $ENV{$envname}
    ;
    last; # first one wins
  }
  
  if($ENV{'IGNORE_WIN32_LOCALE'}) {
    # no-op
  } elsif(&_try_use('Win32::Locale')) {
    # If we have that module installed...
    push @languages, Win32::Locale::get_language() || ''
     if defined &Win32::Locale::get_language;
  }
  return _normalize @languages;
}


sub http_accept_langs {
  # Deal with HTTP "Accept-Language:" stuff.  Hassle.
  # This code is more lenient than RFC 3282, which you must read.
  # Hm.  Should I just move this into I18N::LangTags at some point?
  no integer;

  my $in = (@_ > 1) ? $_[1] : $ENV{'HTTP_ACCEPT_LANGUAGE'};
  # (always ends up untainting)

  return() unless defined $in and length $in;

  $in =~ s/\([^\)]*\)//g; # nix just about any comment
  
  if( $in =~ m/^\s*([a-zA-Z][-a-zA-Z]+)\s*$/s ) {
    # Very common case: just one language tag
    return _normalize $1;
  } elsif( $in =~ m/^\s*[a-zA-Z][-a-zA-Z]+(?:\s*,\s*[a-zA-Z][-a-zA-Z]+)*\s*$/s ) {
    # Common case these days: just "foo, bar, baz"
    return _normalize( $in =~ m/([a-zA-Z][-a-zA-Z]+)/g );
  }

  # Else it's complicated...

  $in =~ s/\s+//g;  # Yes, we can just do without the WS!
  my @in = $in =~ m/([^,]+)/g;
  my %pref;
  
  my $q;
  foreach my $tag (@in) {
    next unless $tag =~
     m/^([a-zA-Z][-a-zA-Z]+)
        (?:
         ;q=
         (
          \d*   # a bit too broad of a RE, but so what.
          (?:
            \.\d+
          )?
         )
        )?
       $
      /sx
    ;
    $q = (defined $2 and length $2) ? $2 : 1;
    #print "$1 with q=$q\n";
    push @{ $pref{$q} }, lc $1;
  }

  return _normalize(
    # Read off %pref, in descending key order...
    map @{$pref{$_}},
    sort {$b <=> $a}
    keys %pref
  );
}


my %tried = ();
  # memoization of whether we've used this module, or found it unusable.

sub _try_use {   # Basically a wrapper around "require Modulename"
  # "Many men have tried..."  "They tried and failed?"  "They tried and died."
  return $tried{$_[0]} if exists $tried{$_[0]};  # memoization

  my $module = $_[0];   # ASSUME sane module name!
  { no strict 'refs';
    no warnings 'once';
    return($tried{$module} = 1)
     if %{$module . "::Lexicon"} or @{$module . "::ISA"};
    # weird case: we never use'd it, but there it is!
  }

  print " About to use $module ...\n" if DEBUG;
  {
    local $SIG{'__DIE__'};
    local @INC = @INC;
    pop @INC if $INC[-1] eq '.';
    eval "require $module"; # used to be "use $module", but no point in that.
  }
  if($@) {
    print "Error using $module \: $@\n" if DEBUG > 1;
    return $tried{$module} = 0;
  } else {
    print " OK, $module is used\n" if DEBUG;
    return $tried{$module} = 1;
  }
}

1;
__END__



