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
$VERSION = 1.0;

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
		  BOUNDS => [], # Cache of data bounds
		  WBOUNDS => [], # Cache of windowed data
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
  return unless @_;

  # It is importance that we remove duplicates by overwriting the old
  # values with the new. The easiest way to do this is
  # to use a hash (although not the most memory or speed efficient for a
  # large time series).

  # In order to prevent unnecessary hash creation and resorting we
  # first sort the input data and if the oldest new point is newer
  # than the newest old point we simply push the new data onto the old
  # without resorting to a hash. We then do a further optimization of
  # adjusting the bounds cache simply by looking at the new data.

  # If it was important, we could do a similar optimization for the
  # case where all the data are older than the earliest data point.
  # This is left as an exercise for the user that wants to run time
  # backwards....

  my @newdata = sort { $a->[0] <=> $b->[0] } @_;

  # also just push if we do not have any data yet
  my $newer;
  if ( !@{$self->{DATA}} || $newdata[0]->[0] > $self->{DATA}->[-1]->[0] ) {

    # indicate that we only have new data
    $newer = 1;

    # filter out undef values [since we may want the cleaned data
    # for bounds checking]
    @newdata = grep { defined $_->[1] } @newdata;

    # and store the new data
    push( @{ $self->{DATA} }, @newdata );

    # since the data are all newer we can calculate the new bounds
    # simply by looking at the new data and the cached bounds.
    # only do this if we have a precalculated cache, since otherwise
    # we are not actually saving anything
    my @cache = $self->bounds_cache();
    if (@cache) {
      $cache[1] = $newdata[-1]->[0];
      my $nmin = min( map { $_->[1] } @newdata );
      my $nmax = max( map { $_->[1] } @newdata );
      $cache[2] = $nmin if $nmin < $cache[2];
      $cache[3] = $nmax if $nmax > $cache[3];
      $self->bounds_cache( \@cache );
    }
  } elsif ($newdata[0]->[0] == $self->{DATA}->[-1]->[0] ) {
    # The new data overwrite the last data in the list. In this
    # case we can not easily recaulate the bounds unless we know that
    # the new Y bounds are greater than and less than the last number
    # in the old data set and the bounds of the previous data set. For
    # now we push on the new data and clear the cache

    # remove the last point in the old data
    pop(@{$self->{DATA}});

    # filter out undef values in the new data
    @newdata = grep { defined $_->[1] } @newdata;

    # and store the new data
    push( @{ $self->{DATA} }, @newdata );

  } else {
    # the new points were within the old
    # If this happens a lot we can further optimise by restricting
    # our merge to the subset of old data that lies within the range
    # of the new data. For now, do a full resort

    # hash the existing data with the new data
    # Note that 3.50 is different from 3.5 so we force numify
    my %data = map { (0+ $_->[0]) => $_ } @{ $self->{DATA} }, @newdata;

    # Sort the keys into time order
    my @sortkeys = sort { $data{$a}->[0] <=> $data{$b}->[0]
			} keys %data;

    # and recreate the sorted list whilst removing undefs
    @{ $self->{DATA} } = grep { defined $_->[1] }
                              map { $data{$_} } @sortkeys;

  }

  # clear the bounds cache (unless we've recalculated)
  $self->bounds_cache( undef ) unless $newer;
  $self->wbounds_cache( undef );

  # no return value
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
 $ref  = $ts->data;

By default, returns only those points within the window and data are
returned as a list of references to arrays of (t,y) pairs. Returns a
reference to an array in list context.

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
  # Get all of the data - note alldata will return an empty array
  # reference if there no data exist, so only proceed if the array
  # contains data
  my $alldata = $self->alldata;
  return unless @$alldata;

  # Requested interval
  my ($min,$max) = $self->window;

  # Find the index
  my $first = $self->_find_index( 'min', $alldata, $min );
  my $last  = $self->_find_index( 'max', $alldata, $max, $first );

  # deal with "outside"
  if ($opts{outside}) {
    $first-- if ($first > 0 && (defined $min &&
				$alldata->[$first]->[0] != $min));
    $last++  if ($last < $#$alldata && (defined $max &&
					$alldata->[$last]->[0] != $max));
  }

  # get the slice
  my @data = @$alldata[$first..$last];

  if ($opts{xyarr}) {
    # If separate arrays wanted, split data into 2 arrays
    my (@tdata, @ydata);
    foreach my $i (0..$#data) {
      push (@tdata, $data[$i]->[0]);
      push (@ydata, $data[$i]->[1]);
    }
    return (\@tdata, \@ydata);
  }

  return (wantarray ? @data : \@data);
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

    # clear the cache
    $self->wbounds_cache( undef );

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

=back

=begin __PRIVATE_ACCESSORS

=head2 Private Accessor Methods

These methods are for internal use.

=over 4

=item B<bounds_cache>

This is the cache for the previously calculated bounds
as calculated from the full data range. It is populated
on demand and cleared when ever new data are added to the
time series.

  @bounds = $ts->bounds_cache();
  $ts->bounds_cache( \@bounds );

The cache is cleared with an undef

  $ts->bounds_cache( undef );

=cut

sub bounds_cache {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    if (defined $arg) {
      @{ $self->{BOUNDS} } = @$arg;
    } else {
      @{ $self->{BOUNDS} } = ();
    }
  }
  return @{ $self->{BOUNDS} };
}

=item B<wbounds_cache>

The bounds for the current window. Same behaviour as the
C<bounds_cache> method except that the cache is cleared
when window() is updated.

=cut

sub wbounds_cache {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    if (defined $arg) {
      @{ $self->{WBOUNDS} } = @$arg;
    } else {
      @{ $self->{WBOUNDS} } = ();
    }
  }
  return @{ $self->{WBOUNDS} };
}

=back

=end __PRIVATE_ACCESSORS

=head2 General Methods

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

  # see if we have a valid cache and return it
  my @bounds;
  if ($full) {
    @bounds = $self->bounds_cache();
  } else {
    @bounds = $self->wbounds_cache();
  }
  return @bounds if @bounds;

  # clear the window and retain the current values
  # we also have to retain the windowed cache

  # get either all the data or a subset
  my $data;
  if ($full) {
    $data = $self->alldata();
  } else {
    $data = $self->data();
  }

  # sorted order so the tmin and tmax are easy
  my $tmin = $data->[0]->[0];
  my $tmax = $data->[-1]->[0];

  # we must calculate the Y range, and we therefore need
  # the Y data in a single array (even if that costs us a lot of memory)
  my @ydata = map { $_->[1] } @$data;
  my $ymin = min( @ydata );
  my $ymax = max( @ydata );

  # cache the result
  if ($full) {
    $self->bounds_cache( [$tmin, $tmax, $ymin, $ymax] );
  } else {
    $self->wbounds_cache( [$tmin, $tmax, $ymin, $ymax] );
  }

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
    $data = $self->data( %opts );
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

# Complains about `unmatched =back' on make...
#=back

=begin _PRIVATE_METHODS_

=head2 Private Methods

=over 4

=item B<_find_index>

=cut

sub _find_index {
  my $self = shift;
  my $type = shift;
  my $data = shift;
  my $ref = shift;
  my $start = shift || 0;

  # return immediately if no reference -Inf or +Inf
  if (!defined $ref) {
    return 0 if $type eq 'min';
    return $#$data if $type eq 'max';
  }

  # determine reference values
  my $low = $data->[0]->[0];
  my $high = $data->[-1]->[0];

  # and simple values
  return 0 if ( $type eq 'min' && $low >= $ref );
  return $#$data if ( $type eq 'max' && $high <= $ref );

  # iterate to the correct value
  my $left = $start;
  my $right = $#$data;

  while (abs($left - $right) > 1) {
    my $middle = int(($right+$left)/2);
    my $midval = $data->[$middle]->[0];
    my $leftval = $data->[$left]->[0];
    my $rightval = $data->[$right]->[0];

#    print "Ref: $ref  Left: $leftval  Right: $rightval Middle: $midval\n";

    return $left if $leftval == $ref;
    return $right if $rightval == $ref;
    return $middle if $midval == $ref;

    # binary chop
    if ( $leftval <= $ref && $midval >= $ref) {
      # the correct answer is in this half
#      print "LEFT SIDE:  $left - $right\n";
      $right = $middle;
    } else {
      # it is in the right hand half
      $left = $middle;
#      print "RIGHT SIDE:  $left - $right\n";
    }
  }

  # now we choose the left or right value depending on whether
  # we are wanting the min or max limit
  return $right if $type eq 'min';
  return $left if $type eq 'max';

}

=back

=end _PRIVATE_METHODS_

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
