package Time::tm;
use strict;

our $VERSION = '1.00';

use Class::Struct qw(struct);
struct('Time::tm' => [
     map { $_ => '$' } qw{ sec min hour mday mon year wday yday isdst }
]);

1;
__END__

