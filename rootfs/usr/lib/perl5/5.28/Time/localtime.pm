package Time::localtime;
use strict;
use 5.006_001;

use Time::tm;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
our (  
      $tm_sec, $tm_min, $tm_hour, $tm_mday,
      $tm_mon, $tm_year, $tm_wday, $tm_yday,
      $tm_isdst
);
 
BEGIN {
    use Exporter   ();
    @ISA         = qw(Exporter Time::tm);
    @EXPORT      = qw(localtime ctime);
    @EXPORT_OK   = qw(  
			$tm_sec $tm_min $tm_hour $tm_mday 
			$tm_mon $tm_year $tm_wday $tm_yday 
			$tm_isdst
		    );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
    $VERSION     = 1.03;
}

sub populate (@) {
    return unless @_;
    my $tmob = Time::tm->new();
    @$tmob = (
		$tm_sec, $tm_min, $tm_hour, $tm_mday, 
		$tm_mon, $tm_year, $tm_wday, $tm_yday, 
		$tm_isdst )
	    = @_;
    return $tmob;
} 

sub localtime (;$) { populate CORE::localtime(@_ ? shift : time)}
sub ctime (;$)     { scalar   CORE::localtime(@_ ? shift : time) } 

1;

__END__

