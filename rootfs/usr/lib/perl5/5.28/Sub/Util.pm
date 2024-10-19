
package Sub::Util;

use strict;
use warnings;

require Exporter;

our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
  prototype set_prototype
  subname set_subname
);

our $VERSION    = "1.50";
$VERSION   = eval $VERSION;

require List::Util; # as it has the XS
List::Util->VERSION( $VERSION ); # Ensure we got the right XS version (RT#100863)




sub prototype
{
  my ( $code ) = @_;
  return CORE::prototype( $code );
}





1;
