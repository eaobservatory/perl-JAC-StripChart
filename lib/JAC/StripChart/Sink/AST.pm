package JAC::StripChart::Sink::AST;

=head1 NAME

JAC::StripChart::Sink::AST - An AST-based stripchart

=head1 SYNOPSIS

  use JAC::StripChart::Sink::AST;

  my $snk = new JAC::StripChart::Sink::AST( device => $dev );


=head1 DESCRIPTION

This class handles the display of strip charts using a plot device
supported by AST. It does not need to know about sources of data
or how to create a display device. It only needs to know how to plot
the data being sent to it on the device that is registered with it.

=cut


use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use List::Util qw/ min max /;
use Starlink::AST;
use Starlink::AST::PGPLOT;

use base qw| JAC::StripChart::Sink |;
use JAC::StripChart::Error;
use JAC::StripChart::TimeSeries;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

Methods are inherited from C<JAC::StripChart::Sink>.

=head2 Class Specific Attributes

=over 4

=item B<astFrame>

AST frame object associated with this plot.

  $fr = $snk->astFrame;

=cut

sub astFrame {
  my $self = shift;
  if (@_) { $self->{AST_Frame} = shift; }
  return $self->{AST_Frame};
}

=item B<astPlot>

AST Plot object associated with this sink

  $plt = $snk->astPlot;

=cut

sub astPlot {
  my $self = shift;
  if (@_) { $self->{AST_Plot} = shift; }
  return $self->{AST_Plot};
}


=item B<astCache>

Cache of timeseries objects for each monitor in the sink

  $snk->astCache( $monid, $ts); # Store timeseries object

  $ts = $snk->astCache( $monid ); # Retrieve specified timeseries object

  %cache = $snk->astCache; # Return hash of all stored timeseries objects

Stores array of hashes which contain the timeseries objects indexed by
monitor ID. A new C<JAC::StripChart::TimeSeries> object is created if
one does not exist for the given monitor ID.

=cut

sub astCache {
  my $self = shift;
  if (@_) { 
    my $monid = shift;
    if (@_) {
      # Store
      my $ts = shift;
      $self->{CACHE}->{$monid} = $ts;
      return;
    } else {
      # Retrieve
      if (exists $self->{CACHE}->{$monid}) {
	return $self->{CACHE}->{$monid};
      } else {
	# Create new timeseries object to fill with data
	$self->{CACHE}->{$monid} = new JAC::StripChart::TimeSeries( $monid );
	return $self->{CACHE}->{$monid};
      }
    }
  }
  return %{ $self->{CACHE} }; # De-reference hash on return
}

=back

=head2 General Methods

=over 4

=item B<init>

Initialise the AST plotting system for this particular chart.

  $snk->init( %attrs );

Expects to receive the chart attributes for all the monitors serviced
by this sink, as a hash with keys corresponding to the monitor label
and values as Chart::Attrs objects.

Probably need the chart title supplied here.

=cut

sub init {
  my $self = shift;

  # Create the AST plot and set the plotting attributes
  my $fr = new Starlink::AST::Frame( 2, "title=Plot title,label(1)=Time,unit(1)=MJD,label(2)=Flux,unit(2)=Jy" );

  $self->astFrame( $fr );

  # We can not set plot attributes here since we are in principle creating
  # a new plot each time the scale changes

}

=item B<putData>

Plot the data on the registered device using AST as the plotting engine.

  $snk->putData( $chartid, $monid, $attr, @data );

=cut

sub putData {
  my $self = shift;
  my ($chartid, $monid, $attr, @data ) = @_;

  # Retrieve or create new timeseries object
  my $ts = $self->astCache( $monid );

  # Store new data in it
  $ts->add_data( @data );
  # Calculate new limits of time series
  my ($xmin, $xmax, $ymin, $ymax ) = $ts->bounds;

  my ($tmin, $tmax);
  # Retrieve window size
  my $window = $self->window;
  # Establish plot limits, window defined relative to most recent value
  if ($window) {
    $tmax = $xmax;
    $tmin = $tmax - $window/24.0; # $window is in hours
  } else { # Set to full range
    $tmin = $xmin; # Earliest time
    $tmax = $xmax; # Most recent time
  }

  # Set the desired plotting window
  $ts->window($tmin, $tmax);

  $xmin = $tmin if ($xmin < $tmin);
  $xmax = $tmax;

  # Select the correct subsection
  $self->device()->select;

  # Retrieve data within the plot window
  my ($xref, $yref);
  ($xref, $yref) = $ts->data(xyarr => 1, outside => 1);

  # Now need to find out whether the data range for plotting
  # has changed. If it has we need to clear and recreate the
  # plot.
  my $isold = 0;
  my $plt = $self->astPlot;

  if (defined $plt) {
    $isold = 1;
    # We have a plot but we are not sure whether the bounds are okay
    # Get the current plot bounds from the plot frame
    my @plotbounds = $plt->PBox;

    # see if the data bounds are inside these bounds
    if ( $xmin < $plotbounds[0] ||
	 $xmax > $plotbounds[1] ||
	 $ymin < $plotbounds[2] ||
	 $ymax > $plotbounds[3] ) {
      # Clear the plot
      $isold = 0;
      $self->device->clear();
      undef $plt;

      # But make sure that we retrieve all the cache for replotting
      # from the specified x-range
      ($xref, $yref) = $ts->data(xyarr => 1, outside => 1);
    }
  }

  # Plotting attributes
  my $linecol = $self->_colour_to_index($attr->linecol);
  my $linestyle = $self->_style_to_index($attr->linestyle);
  my $symcol = $self->_colour_to_index($attr->symcol);
  my $symbol = $self->_sym_to_index($attr->symbol);
  
  # Create the new AST plot object if we do not have one
  if (!defined $plt) {
    # Adjust plot limits to look nice
    if ($self->autoscale) {
      my $dy = $ymax - $ymin;
      $ymin = $ymin - 0.1*$dy;
      $ymax = $ymax + 0.1*$dy;
    } else {
      ($ymin,$ymax) = $self->yscale;
    }
    my $dx = $xmax - $xmin;
    $xmax = $xmax + 0.1*$dx;

    # Set plot attributes
    $plt = new Starlink::AST::Plot( $self->astFrame(), [0,0,1,1],
				    [$xmin,$ymin,$xmax,$ymax], 
				    "size(title)=1.5,size(textlab)=1.3,size(numlab)=1.3,".
				    "colour(title)=3,colour(textlab)=3,colour(curves)=$linecol,".
				    "colour(border)=2,colour(numlab)=2,colour(ticks)=2,".
				    "style(curves)=$linestyle" );
    $self->astPlot( $plt );
  }


  # Register the correct plotting engine callbacks
  $self->_grfselect( $plt );

  # draw the plot axes if we have changed the plot bounds
  $plt->Grid() unless $isold;

#  my $chan = new Starlink::AST::Channel( sink => sub { print "$_[0]\n"; } );
#  $chan->Write( $plt );

  # plot the data using the requested attributes
  $plt->PolyCurve($xref, $yref);

  # return and wait for more data
  return;
}

=back

=head2 Private Methods

=over 4

=item B<_default_dev_class>

The default plotting device.

=cut

sub _default_dev_class {
  return "";
}

=item B<_grfselect>

Select the relevant AST graphics subsystem.

=cut

sub _grfselect {
  my $self = shift;
  my $plt = shift;
  $plt->debug;
  return;
}

=item B<_colour_to_index>

Translate given colour to PGPLOT colour index

  $self->_colour_to_index( $colour );

=cut

sub _colour_to_index {
  my $self = shift;
  my $colour = shift;
  my $cindex = -1;

  # Note the order of @knowncolours is set to match the PGPLOT index number
  my @knowncolours = qw( white red green blue cyan magenta yellow orange chartreuse springgreen skyblue purple pink darkgrey grey);

  # Colour index given
  if ($colour =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Colour index does not exist - must lie between 1 and 15") if ($colour > 15 || $colour < 1);
    $cindex = $colour;
  } elsif ($colour =~ /[a-z]/) {
    # Convert to lower case
    my $lcolour = lc($colour);
    # Now examine other colours and convert known values to indices
    $lcolour = "grey" if ($lcolour eq "gray"); # For those who can't spell...
    $lcolour = "grey" if ($lcolour eq "lightgrey"); 
    for my $j (0..scalar(@knowncolours-1)) {
      if ($knowncolours[$j] eq $lcolour) {
	$cindex = $j + 1;
	last;
      } 
    }
  } else {
    throw JAC::StripChart::Error::BadConfig("Invalid string for colour");
  }
  # Warn if $cindex not set, and set to default colour
  # FUTURE: use this to establish new colour table
  if ($cindex == -1) {
    warnings::warnif(" Unknown colour, '$colour': setting to default value (yellow)");
    $cindex = 7;
  }
  return $cindex;
}

=item B<_style_to_index>

Translate given line style to PGPLOT line style index

  $self->_style_to_index( $style );

PGPLOT supports only 5 linestyles

=cut

sub _style_to_index {
  my $self = shift;
  my $style = shift;
  my $stindex = 4;

  if ($style eq "solid") {
    $stindex = 1;
  } elsif ($style eq "dot" || $style eq "dotted") {
    $stindex = 4;
  } elsif ($style eq "dash-dot" || $style eq "ddash" || $style eq "dot-dash" ) {
    $stindex = 3;
  } elsif ($style eq "longdash" || $style eq "ldash" || $style eq "dash" || $style eq "dashed" )  {
    $stindex = 2;
  } elsif ($style eq "dash-dot-dot" || $style eq "dddash") {
    $stindex = 5;
  } else {
    print " Unknown LineStyle - setting style to solid \n";
    $stindex = 1;
  }
  
  return $stindex;
}

=item B<_sym_to_index>

Translate given plot symbol to PGPLOT symbol index

  $self->_sym_to_index( $style );

For now, only support basic symbols (circle, square etc).

=cut

sub _sym_to_index {
  my $self = shift;
  my $sym = shift;
  my $symindex = 4;

  # Prefix with `f' to get filled versions
  my %knownsymbols = ( square => 0,
		       dot => 1,
		       plus => 2,
		       asterisk => 3,
		       circle => 4,
		       cross => 5,
		       triangle => 7,
		       diamond => 11,
		       star => 12,
		       fcircle => 17,
		       fsquare => 16,
		       ftriangle => 13,
		       fstar => 18,
		       fdiamond => -4);

  foreach my $symkey (keys %knownsymbols) {
    $symindex = $knownsymbols{$symkey} if ($symkey eq $sym);
  }
  
  return $symindex;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>and
Andy Gibb E<lt>agg@astro.ubc.caE<gt>


=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council and
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
