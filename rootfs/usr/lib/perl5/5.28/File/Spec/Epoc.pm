package File::Spec::Epoc;

use strict;

our $VERSION = '3.74';
$VERSION =~ tr/_//d;

require File::Spec::Unix;
our @ISA = qw(File::Spec::Unix);


sub case_tolerant {
    return 1;
}


sub canonpath {
    my ($self,$path) = @_;
    return unless defined $path;

    $path =~ s|/+|/|g;                             # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g;                        # xx/././xx -> xx/xx
    $path =~ s|^(\./)+||s unless $path eq "./";    # ./xx      -> xx
    $path =~ s|^/(\.\./)+|/|s;                     # /../../xx -> xx
    $path =~  s|/\Z(?!\n)|| unless $path eq "/";          # xx/       -> xx
    return $path;
}


1;
