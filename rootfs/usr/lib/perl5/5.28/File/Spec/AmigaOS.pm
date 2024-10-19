package File::Spec::AmigaOS;

use strict;
require File::Spec::Unix;

our $VERSION = '3.74';
$VERSION =~ tr/_//d;

our @ISA = qw(File::Spec::Unix);


my $tmpdir;
sub tmpdir {
  return $tmpdir if defined $tmpdir;
  $tmpdir = $_[0]->_tmpdir( $ENV{TMPDIR}, "/t" );
}


sub file_name_is_absolute {
  my ($self, $file) = @_;

  # Not 100% robust as a "/" must not preceded a ":"
  # but this cannot happen in a well formed path.
  return $file =~ m{^/|:}s;
}


1;
