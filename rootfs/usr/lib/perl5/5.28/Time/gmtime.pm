package Time::gmtime;
use strict;
use 5.006_001;

use Time::tm;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
our (   $tm_sec, $tm_min, $tm_hour, $tm_mday,
        $tm_mon, $tm_year, $tm_wday, $tm_yday, 
		$tm_isdst,
);
 
BEGIN { 
    use Exporter   ();
    @ISA         = qw(Exporter Time::tm);
    @EXPORT      = qw(gmtime gmctime);
    @EXPORT_OK   = qw(  
			$tm_sec $tm_min $tm_hour $tm_mday 
			$tm_mon $tm_year $tm_wday $tm_yday 
			$tm_isdst
		    );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
    $VERSION     = 1.04;
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

sub gmtime (;$)    { populate CORE::gmtime(@_ ? shift : time)}
sub gmctime (;$)   { scalar   CORE::gmtime(@_ ? shift : time)} 

1;
__END__

