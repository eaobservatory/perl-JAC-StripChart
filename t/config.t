#!perl

use strict;
use warnings;
use Test::More tests => 3;

require_ok( 'JAC::StripChart::Config' );

my $cfg = new JAC::StripChart::Config();
isa_ok( $cfg, "JAC::StripChart::Config" );

# Read config from data handle and write a file
my $cfgfile = "testcfg.ini";
my @lines = <DATA>;
open my $fh, "> $cfgfile" or die "Error writing config file '$cfgfile': $!";
print $fh @lines;
close($fh);

$cfg->filename($cfgfile);
is( $cfg->filename, $cfgfile, "Is filename set?");

END { unlink $cfgfile }

__DATA__
[globals]
nx=2
ny=

[chart1]
yautoscale=1
yscale=[min,max]
yunits=Jy
xscale=window|auto
xwindow=56 [minutes]
xminstart=-24
data=fcf850,fcf450

[chart4]
yautoscale=1
yscale=[min,max]
yunits=Jy
xscale=window|auto
xwindow=56 [minutes]
xminstart=-24
data=fcf850,fcf450

[fcf450]
monitor_class=ORACIndex
indexfile=index.gains
column=GAIN
filter_UNITS=ARCSEC
filter_FILTER=450W

[fcf850]
monitor_class=ORACIndex
indexfile=index.gains
column=GAIN
filter_UNITS=ARCSEC
filter_FILTER=850W
