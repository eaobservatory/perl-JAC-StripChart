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

use Number::Interval;
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
		  WINDOW => undef, # Number::Interval object
		 }, $class;

  return $ts;
}

=head2 Accessor Methods

=over 4

=item B<id>

Return ID string identifying this data set.

=cut

sub id {
  my $self = shift;
  return $self->{ID};
}

=item B<add_data>

Add more data into the time series. Data should be supplied
as a list of references to arrays of (t,y) doublets.

  $ts->add_data( @newdata );
  $ts->add_data( [ $t1, $y1 ], [ $t2, $y2 ] );

If the data point already exists for that time slice, the newest value
will be retained (new data is assumed to supercede older data). If the
Y value is undefined, it is assumed that the point for that period should
be removed (this can be used to remove points).

Time is assumed to increase; the time series data will always be sorted
into time order when retrieved.

A single time should refer to a single value.

=cut

sub add_data {
  my $self = shift;

  # We want to remove duplicates. The easiest way to do this is
  # to use a hash (although not the most memory efficient for a
  # large time series).

  # hash the existing data with the new data
  my %data = map { $_->[0] => $_ } @{ $self->{DATA} }, @_;

  # Sort the keys into time order
  my @sortkeys = sort { $data{$a}->[0] <=> $data{$b}->[0] } keys %data;

  # and recreate the sorted list whilst removing undefs
  @{ $self->{DATA} } = grep { defined $_->[1] }
                          map { $data{$_} } @sortkeys;
  return;
}

=item B<alldata>

Retrieves all the data regardless of window. Data are returned
as a list of x/y pairs.

 @data = $self->alldata();

=cut

sub alldata {
  my $self = shift;
  # undocumented access to internal array ref
  return (wantarray ? @{ $self->{DATA} } : $self->{DATA} );
}

=item B<data>

Retrieves the data that lies within the currently specified
window. Assumes the data are already sorted into time order.

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

If the window is not defined (both ranges undefined), the full data
set are retrieved.

=cut

sub data {
  my $self = shift;
  my %opts = (
	      xyarr => 0,
	      outside => 0,
	      @_);

  # Somewhere to store the output data
  my @data;

  # Get all of the data
  my @alldata = $self->alldata;

  # Requested interval
  my $int = $self->window;
  $int = new Number::Interval( Min => undef, Max => undef)
    unless defined $int;

  # Loop through data to find limits
  my $first;
  my $last;
  foreach my $i (0..$#alldata) {

    ### This needs to be made more efficient such that it stops
    # the first time we go out of range since we know the data are sorted

    # Add data within window
    if ($int->contains( $alldata[$i]->[0] )) {
      push ( @data, $alldata[$i] );

      # store the indices of the first and last hit
      $first = $i unless defined $first;
      $last = $i;
    }
  }

  # Store the outside values if required (this is useful for plotting lines)
  # but not if the lower/upper level of the window is exactly matched
  # by the first/last data point
  if ($opts{outside} && defined $first) {

    # get the current extrema
    my $dtmin = $data[0]->[0];
    my $dtmax = $data[-1]->[0];

    # First see if the min point equals the window
    if ($first > 0) {
      my $wmin = $int->min;
      # note that wmin must be defined, else $first would be 0
      push( @data, $alldata[$first-1]) if $wmin < $dtmin;
    }

    # then see if the max point equals the window
    if ($last < $#alldata) {
      my $wmax = $int->max;
      # note that wmax must be defined, else $last would be $#alldata
      push( @data, $alldata[$last+1]) if $wmax > $dtmax;
    }
  }

  # HACK: shouldn't be needed.
  @data = sort {$a->[0] <=> $b->[0]} @data;

  if ($opts{xyarr}) {
    # If separate arrays wanted, split data into 2 arrays
    my (@tdata, @ydata);
    foreach my $i (0..$#data) {
      push (@tdata, $data[$i]->[0]);
      push (@ydata, $data[$i]->[1]);
    }
    return (\@tdata, \@ydata);
  }

  return @data;
}

=item B<window>

Sets the current plotting window as a C<Number::Interval> object.

  $ts->window( $interval );

Returns the interval object in scalar context.

  $interval = $ts->window();

In a list context, returns the limits (undef for no lower bound
or no upper bound respectively)

  ($wmin, $wmax) = $ts->window();

If 2 arguments are given to this method, they will be converted into
a C<Number::Interval> object.

=cut

sub window {
  my $self = shift;
  if (@_) {
    if (scalar(@_) == 1) {
      my $int = shift;
      croak "Window must be supplied as a Number::Interval object"
         if (defined $int && !UNIVERSAL::isa( $int, "Number::Interval"));
      $self->{WINDOW} = $int;
    } elsif (scalar(@_) == 2) {
      my ($min, $max) = @_;
      $self->{WINDOW} = new Number::Interval( Min => $min, Max => $max,
					      IncMax => 1, IncMin => 1
					    );
    } else {
      croak "Bizarre number of arguments to window() method";
    }
  }

  if (wantarray) {
    if (defined $self->{WINDOW}) {
      return ($self->{WINDOW}->minmax);
    } else {
      return (undef,undef);
    }
  } else {
    return $self->{WINDOW};
  }
}

=item B<bounds>

Retrieve the upper and lower t- and y-bounds within the current window

  ($tmin, $tmax, $ymin, $ymax) = $ts->bounds;

If the argument is true, the windowing will be disabled and the full
bounds will be returned.

  ($tmin, $tmax, $ymin, $ymax) = $ts->bounds( 1 );

=cut

sub bounds {
  my $self = shift;
  my $full = shift;

  # clear the window and retain the current values
  my $oldwin;
  if ($full) {
    $oldwin = $self->window;
    $self->window( undef, undef );
  }

  # get the data within the window
  my ($tdataref, $ydataref) = $self->data(xyarr => 1);

  # reset the windowing
  $self->window( $oldwin ) if defined $oldwin;

  my @tdata = @{ $tdataref };
  my @ydata = @{ $ydataref };

  my $tmin = min( @tdata );
  my $tmax = max( @tdata );
  my $ymin = min( @ydata );
  my $ymax = max( @ydata );

  return ( $tmin, $tmax, $ymin, $ymax );
}

=item B<npts>

Return the number of data points which lie within the bounds of the
current window.

  $npts = $ts->npts;

Can optionally include the "outside" parameter so as to return values
consistent with the C<data()> method.

  $npts = $ts->npts( outside => 1 );

Finally, if the full number of points is required regardless of window,
use the 'full' parameter

  $npts = $ts->npts( full => 1 );

=cut

sub npts {
  my $self = shift;
  my %inopts = @_;

  # we only support the following args to data()
  my @data_args = qw/ outside /;
  my %opts;
  for my $a (@data_args) {
    $opts{$a} = $inopts{$a} if exists $inopts{$a};
  }

  my $data;
  if ($inopts{full}) {
    $data = $self->alldata();
  } else {
    ($data, my $ydata) = $self->data(xyarr => 1, %opts);
  }

  my $npts = ( defined $data ? scalar( @{ $data } ) : 0 );
  return $npts;
}

=item B<prevdata>

Given a time, return the data pair immediately prior. Ignores
the current window setting.

  $xypair = $ts->prevdata( $tval );
  ($t, $y) = $ts->prevdata( $tval );

Can return empty list or undef if no data point exists before this
value (this will happen if no argument is provided).

Obviously, $tval must be in the same units as the timeseries.

=cut

sub prevdata {
  my $self = shift;

  my $prev;
  if (@_ && defined $_[0]) {
    my $tval = shift;
    # Use the low level accessor to bypass any window checks
    foreach my $d (reverse $self->alldata ) {
      # jump out the first time we get a value less than the reference
      if ( $d->[0] < $tval) {
	$prev = $d;
	last;
      }
    }
  }

  if (wantarray) {
    return (defined $prev ? @$prev : () );
  } else {
    return $prev;
  }
}

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Andy Gibb E<lt>agg@astro.ubc.caE<gt>


=head1 COPYRIGHT

Copyright (C) 2004, 2005 Particle Physics and Astronomy Research Council and
the University of British Columbia. All Rights Reserved.

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
