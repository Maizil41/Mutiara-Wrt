use strict;
package Tie::Memoize;
use Tie::Hash;
our @ISA = 'Tie::ExtraHash';
our $VERSION = '1.1';

our $exists_token = \undef;

sub croak {require Carp; goto &Carp::croak}


sub FETCH {
  my ($h,$key) = ($_[0][0], $_[1]);
  my $res = $h->{$key};
  return $res if defined $res;	# Shortcut if accessible
  return $res if exists $h->{$key}; # Accessible, but undef
  my $cache = $_[0][1]{$key};
  return if defined $cache and not $cache; # Known to not exist
  my @res = $_[0][2]->($key, $_[0][4]);	# Autoload
  $_[0][1]{$key} = 0, return unless @res; # Cache non-existence
  delete $_[0][1]{$key};	# Clear existence cache, not needed any more
  $_[0][0]{$key} = $res[0];	# Store data and return
}

sub EXISTS   {
  my ($a,$key) = (shift, shift);
  return 1 if exists $a->[0]{$key}; # Have data
  my $cache = $a->[1]{$key};
  return $cache if defined $cache; # Existence cache
  my @res = $a->[3]($key,$a->[4]);
  $a->[1]{$key} = 0, return unless @res; # Cache non-existence
  # Now we know it exists
  return ($a->[1]{$key} = 1) if $a->[5]; # Only existence reported
  # Now know the value
  $a->[0]{$key} = $res[0];    # Store data
  return 1
}

sub TIEHASH  {
  croak 'syntax: tie %hash, \'Tie::AutoLoad\', \&fetch_subr' if @_ < 2;
  croak 'syntax: tie %hash, \'Tie::AutoLoad\', \&fetch_subr, $data, \&exists_subr, \%data_cache, \%existence_cache' if @_ > 6;
  push @_, undef if @_ < 3;	# Data
  push @_, $_[1] if @_ < 4;	# exists
  push @_, {} while @_ < 6;	# initial value and caches
  bless [ @_[4,5,1,3,2], $_[1] ne $_[3]], $_[0]
}

1;


