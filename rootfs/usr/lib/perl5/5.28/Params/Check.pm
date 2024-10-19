package Params::Check;

use strict;

use Carp                        qw[carp croak];
use Locale::Maketext::Simple    Style => 'gettext';

BEGIN {
    use Exporter    ();
    use vars        qw[ @ISA $VERSION @EXPORT_OK $VERBOSE $ALLOW_UNKNOWN
                        $STRICT_TYPE $STRIP_LEADING_DASHES $NO_DUPLICATES
                        $PRESERVE_CASE $ONLY_ALLOW_DEFINED $WARNINGS_FATAL
                        $SANITY_CHECK_TEMPLATE $CALLER_DEPTH $_ERROR_STRING
                    ];

    @ISA        =   qw[ Exporter ];
    @EXPORT_OK  =   qw[check allow last_error];

    $VERSION                = '0.38';
    $VERBOSE                = $^W ? 1 : 0;
    $NO_DUPLICATES          = 0;
    $STRIP_LEADING_DASHES   = 0;
    $STRICT_TYPE            = 0;
    $ALLOW_UNKNOWN          = 0;
    $PRESERVE_CASE          = 0;
    $ONLY_ALLOW_DEFINED     = 0;
    $SANITY_CHECK_TEMPLATE  = 1;
    $WARNINGS_FATAL         = 0;
    $CALLER_DEPTH           = 0;
}

my %known_keys = map { $_ => 1 }
                    qw| required allow default strict_type no_override
                        store defined |;


sub check {
    my ($utmpl, $href, $verbose) = @_;

    ### clear the current error string ###
    _clear_error();

    ### did we get the arguments we need? ###
    if ( !$utmpl or !$href ) {
      _store_error(loc('check() expects two arguments'));
      return unless $WARNINGS_FATAL;
      croak(__PACKAGE__->last_error);
    }

    ### sensible defaults ###
    $verbose ||= $VERBOSE || 0;

    ### XXX what type of template is it? ###
    ### { key => { } } ?
    #if (ref $args eq 'HASH') {
    #    1;
    #}

    ### clean up the template ###
    my $args;

    ### don't even bother to loop, if there's nothing to clean up ###
    if( $PRESERVE_CASE and !$STRIP_LEADING_DASHES ) {
        $args = $href;
    } else {
        ### keys are not aliased ###
        for my $key (keys %$href) {
            my $org = $key;
            $key = lc $key unless $PRESERVE_CASE;
            $key =~ s/^-// if $STRIP_LEADING_DASHES;
            $args->{$key} = $href->{$org};
        }
    }

    my %defs;

    ### which template entries have a 'store' member
    my @want_store;

    ### sanity check + defaults + required keys set? ###
    my $fail;
    for my $key (keys %$utmpl) {
        my $tmpl = $utmpl->{$key};

        ### check if required keys are provided
        ### keys are now lower cased, unless preserve case was enabled
        ### at which point, the utmpl keys must match, but that's the users
        ### problem.
        if( $tmpl->{'required'} and not exists $args->{$key} ) {
            _store_error(
                loc(q|Required option '%1' is not provided for %2 by %3|,
                    $key, _who_was_it(), _who_was_it(1)), $verbose );

            ### mark the error ###
            $fail++;
            next;
        }

        ### next, set the default, make sure the key exists in %defs ###
        $defs{$key} = $tmpl->{'default'}
                        if exists $tmpl->{'default'};

        if( $SANITY_CHECK_TEMPLATE ) {
            ### last, check if they provided any weird template keys
            ### -- do this last so we don't always execute this code.
            ### just a small optimization.
            map {   _store_error(
                        loc(q|Template type '%1' not supported [at key '%2']|,
                        $_, $key), 1, 0 );
            } grep {
                not $known_keys{$_}
            } keys %$tmpl;

            ### make sure you passed a ref, otherwise, complain about it!
            if ( exists $tmpl->{'store'} ) {
                _store_error( loc(
                    q|Store variable for '%1' is not a reference!|, $key
                ), 1, 0 ) unless ref $tmpl->{'store'};
            }
        }

        push @want_store, $key if $tmpl->{'store'};
    }

    ### errors found ###
    return if $fail;

    ### flag to see if anything went wrong ###
    my $wrong;

    ### flag to see if we warned for anything, needed for warnings_fatal
    my $warned;

    for my $key (keys %$args) {
        my $arg = $args->{$key};

        ### you gave us this key, but it's not in the template ###
        unless( $utmpl->{$key} ) {

            ### but we'll allow it anyway ###
            if( $ALLOW_UNKNOWN ) {
                $defs{$key} = $arg;

            ### warn about the error ###
            } else {
                _store_error(
                    loc("Key '%1' is not a valid key for %2 provided by %3",
                        $key, _who_was_it(), _who_was_it(1)), $verbose);
                $warned ||= 1;
            }
            next;
        }

        ### copy of this keys template instructions, to save derefs ###
        my %tmpl = %{$utmpl->{$key}};

        ### check if you're even allowed to override this key ###
        if( $tmpl{'no_override'} ) {
            _store_error(
                loc(q[You are not allowed to override key '%1'].
                    q[for %2 from %3], $key, _who_was_it(), _who_was_it(1)),
                $verbose
            );
            $warned ||= 1;
            next;
        }

        ### check if you were supposed to provide defined() values ###
        if( ($tmpl{'defined'} || $ONLY_ALLOW_DEFINED) and not defined $arg ) {
            _store_error(loc(q|Key '%1' must be defined when passed|, $key),
                $verbose );
            $wrong ||= 1;
            next;
        }

        ### check if they should be of a strict type, and if it is ###
        if( ($tmpl{'strict_type'} || $STRICT_TYPE) and
            (ref $arg ne ref $tmpl{'default'})
        ) {
            _store_error(loc(q|Key '%1' needs to be of type '%2'|,
                        $key, ref $tmpl{'default'} || 'SCALAR'), $verbose );
            $wrong ||= 1;
            next;
        }

        ### check if we have an allow handler, to validate against ###
        ### allow() will report its own errors ###
        if( exists $tmpl{'allow'} and not do {
                local $_ERROR_STRING;
                allow( $arg, $tmpl{'allow'} )
            }
        ) {
            ### stringify the value in the error report -- we don't want dumps
            ### of objects, but we do want to see *roughly* what we passed
            _store_error(loc(q|Key '%1' (%2) is of invalid type for '%3' |.
                             q|provided by %4|,
                            $key, "$arg", _who_was_it(),
                            _who_was_it(1)), $verbose);
            $wrong ||= 1;
            next;
        }

        ### we got here, then all must be OK ###
        $defs{$key} = $arg;

    }

    ### croak with the collected errors if there were errors and
    ### we have the fatal flag toggled.
    croak(__PACKAGE__->last_error) if ($wrong || $warned) && $WARNINGS_FATAL;

    ### done with our loop... if $wrong is set, something went wrong
    ### and the user is already informed, just return...
    return if $wrong;

    ### check if we need to store any of the keys ###
    ### can't do it before, because something may go wrong later,
    ### leaving the user with a few set variables
    for my $key (@want_store) {
        next unless exists $defs{$key};
        my $ref = $utmpl->{$key}{'store'};
        $$ref = $NO_DUPLICATES ? delete $defs{$key} : $defs{$key};
    }

    return \%defs;
}


sub allow {
    ### use $_[0] and $_[1] since this is hot code... ###
    #my ($val, $ref) = @_;

    ### it's a regexp ###
    if( ref $_[1] eq 'Regexp' ) {
        local $^W;  # silence warnings if $val is undef #
        return if $_[0] !~ /$_[1]/;

    ### it's a sub ###
    } elsif ( ref $_[1] eq 'CODE' ) {
        return unless $_[1]->( $_[0] );

    ### it's an array ###
    } elsif ( ref $_[1] eq 'ARRAY' ) {

        ### loop over the elements, see if one of them says the
        ### value is OK
        ### also, short-circuit when possible
        for ( @{$_[1]} ) {
            return 1 if allow( $_[0], $_ );
        }

        return;

    ### fall back to a simple, but safe 'eq' ###
    } else {
        return unless _safe_eq( $_[0], $_[1] );
    }

    ### we got here, no failures ###
    return 1;
}


sub _safe_eq {
    ### only do a straight 'eq' if they're both defined ###
    return defined($_[0]) && defined($_[1])
                ? $_[0] eq $_[1]
                : defined($_[0]) eq defined($_[1]);
}

sub _who_was_it {
    my $level = $_[0] || 0;

    return (caller(2 + $CALLER_DEPTH + $level))[3] || 'ANON'
}


{   $_ERROR_STRING = '';

    sub _store_error {
        my($err, $verbose, $offset) = @_[0..2];
        $verbose ||= 0;
        $offset  ||= 0;
        my $level   = 1 + $offset;

        local $Carp::CarpLevel = $level;

        carp $err if $verbose;

        $_ERROR_STRING .= $err . "\n";
    }

    sub _clear_error {
        $_ERROR_STRING = '';
    }

    sub last_error { $_ERROR_STRING }
}

1;


