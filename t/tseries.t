#!perl

use strict;
use warnings;
use Test::More tests => 46;

require_ok( 'JAC::StripChart::TimeSeries' );

# Some test data
my @tdata = qw/ 1 2 3 4  5  6  7  8  9 10 /;
my @ydata = qw/ 2 4 6 8 10 12 14 16 18 20 /;

my @data = map { [$tdata[$_], $ydata[$_] ] } ( 0 .. $#tdata );

my $ts = new JAC::StripChart::TimeSeries( "test" );
isa_ok( $ts, "JAC::StripChart::TimeSeries" );


$ts->add_data( [1.25, 3.5]);

# get the bounds
my @bounds = $ts->bounds();
is( $bounds[0], 1.25, "min t");
is( $bounds[1], 1.25, "max t");
is( $bounds[2], 3.5, "min y");
is( $bounds[3], 3.5, "max y");

is( $ts->npts, 1, "count number of points");

# Now add all the remaining points
$ts->add_data( @data );

@bounds = $ts->bounds();
is( $bounds[0], 1, "min t");
is( $bounds[1], 10, "max t");
is( $bounds[2], 2, "min y");
is( $bounds[3], 20, "max y");
is( $ts->npts, 11, "count number of points");

# now set a window
$ts->window( undef, 5.5 );

@bounds = $ts->bounds();
is( $bounds[0], 1, "min t");
is( $bounds[1], 5, "max t");
is( $bounds[2], 2, "min y");
is( $bounds[3], 10, "max y");
is( $ts->npts, 6, "count number of points");


# new window
$ts->window( undef, 5 );

@bounds = $ts->bounds();
is( $bounds[0], 1, "min t");
is( $bounds[1], 5, "max t");
is( $bounds[2], 2, "min y");
is( $bounds[3], 10, "max y");
is( $ts->npts, 6, "count number of points");

# new window
$ts->window( 1.2, 5 );

@bounds = $ts->bounds();
is( $bounds[0], 1.25, "min t");
is( $bounds[1], 5, "max t");
is( $bounds[2], 3.5, "min y");
is( $bounds[3], 10, "max y");
is( $ts->npts, 5, "count number of points");

is( $ts->npts( outside => 1 ), 6, "count number of points inc outside");

# new window
$ts->window( 6.3, undef );

@bounds = $ts->bounds();
is( $bounds[0], 7, "min t");
is( $bounds[1], 10, "max t");
is( $bounds[2], 14, "min y");
is( $bounds[3], 20, "max y");
is( $ts->npts, 4, "count number of points");

is( $ts->npts( outside => 1 ), 5, "count number of points inc outside");

# new window
$ts->window( 6, 9 );

@bounds = $ts->bounds();
is( $bounds[0], 6, "min t");
is( $bounds[1], 9, "max t");
is( $bounds[2], 12, "min y");
is( $bounds[3], 18, "max y");
is( $ts->npts, 4, "count number of points");

is( $ts->npts( outside => 1 ), 4, "count number of points inc outside");

# new window
$ts->window( 5.9, 9.1 );

@bounds = $ts->bounds();
is( $bounds[0], 6, "min t");
is( $bounds[1], 9, "max t");
is( $bounds[2], 12, "min y");
is( $bounds[3], 18, "max y");
is( $ts->npts, 4, "count number of points");

is( $ts->npts( outside => 1 ), 6, "count number of points inc outside");


