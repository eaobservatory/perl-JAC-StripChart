package JAC::StripChart::TimeSeries;

=head1 NAME

JAC::StripChart::TimeSeries - Generic class for storing time series data

=head1 SYNOPSIS

  use JAC::StripChart::TimeSeries;

  my $ts = new JAC::StripChart::TimeSeries( $name );

  # Add new data into the time series
  $ts->add_data( @newdata );

  # Specify a windowing function
  $ts->window( $tmin, $tmax );

  # Retrieve the bounds of the time series for the current window
  @bounds = $ts->bounds();

  # Retrieve current data within window
  @data = $ts->data( lol => 0 );

=head1 DESCRIPTION

A generic helper class for storing time series data. Methods are
provided for calculating statistics and returning subsets.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use List::Util qw/ min max /;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new time series object:

 $ts = new JAC::StripChart::TimeSeries( $id );

The id string can be used to identify the time series. In the future this
may be used to minimize memory usage by reusing objects that have the same
id. Therefore, users should assume that any windowing applied to this object
may also affect clones of the object that share the same ID string. If this
is a problem, simply make sure that ID strings are unique.

The id can not be changed.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $id = shift;

  # Create object
  my $ts = bless {
		  ID => $id,
		  DATA => [], # use array of arrays for now
		 }, $class;

  return $ts;
}

=head2 Accessor Methods

=over 4

=item B<id>

ID string identifying this data set.

=cut

sub id {
  my $self = shift;
  return $self->{ID};
}

=item B<add_data>

Add more data into the time series. Data should be supplied
as a list of references to arrays of (t,y) doublets.

  $ts->add_data( @newdata );
  $ts->add_data( [ t1, y1 ], [ $t2, $y2 ] );

If the data point already exists for that time slice, the newest value
will be retained (new data is assumed to supercede older data). If the
Y value is undefined, it is assumed that the point for that period should
be removed (this can be used to remove points).

Time is assumed to increase; the time series data will always be sorted
into time order when retrieved.

=cut

sub add_data {
  my $self = shift;

  # Take a copy of the input data and sort them into time order
  my @new = sort { $a->[0] <=> $b->[0] } @_;

  my $j = 0;
  for my $i ( 0.. $#{$self->{DATA}} ) {
    # we need to see if any members of @new fit into
    # the current array position
    while ( $new[$j]
    next if $new[$j] > $self->{DATA}->[$i];
    
  }

}

=item B<data>

Retrieves the data that lies within the currently specified window.

 @data = $ts->data;

By default, returns only those points within the window and data are
returned as a list of references to arrays of (t,y) pairs.

Hash options can be used to control the results:

 @data = $ts->data( outside => 1 );

Make sure that the points either side of the window are retrieved
(if present) such that lines connecting data points will leave plots
in the correct position.

 ($t, $y) = $ts->data( xyarr => 1 );

Retrieve the data as a reference to an array of time coordinates and
a reference to an array of Y coordinates. This is useful for some plotting
libraries.

=cut

sub data {
  my $self = shift;
  my %opts = (
	      xyarr => 0,
	      outside => 0,
	      @_);

  if (%opts{xyarr} ) {

  } else {

  }

}

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=head1 SEE ALSO

L<JAC::StripChart::Sink>, L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;