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
use Time::Piece;

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

  my @attrs = @_;
  $self->attr(@attrs);

  # Create the AST plot and set the plotting attributes
  my $title = $self->plottitle;
  my $yunits = $self->yunits;
  # Other labels are not defined yet
#  my $xlabel;
#  my $ylabel;
#  my $xunits;
  my $fr = new Starlink::AST::Frame( 2, "title=$title,label(1)=Time,unit(1)=MJD,label(2)=Flux,unit(2)=$yunits" );

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

  use Data::Dumper;

  # Retrieve or create new timeseries object
  my $ts = $self->astCache( $monid );

  # Store new data in it
  $ts->add_data( @data );

  # Relevance of prefix to min/max variables:
  # ts = entire timeseries
  # pl = plot bounds
  # w  = Range of data within plot window

  # Calculate limits of entire timeseries
  my ($tsxmin, $tsxmax, $tsymin, $tsymax) = $ts->bounds(1);
  # Plot limits - must take account of min/max of *all* ts on this plot
  my ($plxmax, $plxmin, $plymax, $plymin);
  # Limits for data within plot window
  my ($wxmax, $wxmin, $wymax, $wymin);
  # Define limits of plotting window
  my ($winlo, $winhi); 

  # Retrieve window size from ini file
  my $window = $self->window;
  my $growt = $self->growt;

  # Establish plot limits using growt and window
  # If no window defined, then set limits to entire range, regardless
  # of growt
  unless ($window) {
    # Check if ts x-limits are equal...
    if ($tsxmin == $tsxmax) {
      if ($tsxmin == 0) { # Catch value = 0 case
	$plxmin = 0;
	$plxmax = 1;
      } else {
	$plxmin = 0.9*$tsxmin;
	$plxmax = 1.1*$tsxmax;
      }
    } else {
      $plxmin = $tsxmin;
      $plxmax = $tsxmax;
    }
  } else {
    # If a window has been set...
    # Convert $window to days from HOURS
    $window = $window / 24.0;
    if ($growt) {
      # If growt is true, then: check whether the window spans the
      # range of data points and set accordingly, scaling either from
      # the min or max.
      my $xupper = $tsxmin + $window;
      if ($xupper < $tsxmax) { # Data span more than window
	$plxmin = $tsxmin;
	$plxmax = $tsxmax;
      } else { # Window greater than data range
	$plxmin = $tsxmin;
	$plxmax = $plxmin + $window;
      }
    } else {
      # Catch the case where the the range of data points is
      # smaller than the requested window so that the limits are
      # scaled relative to the min value rather than the max.
      my $xupper = $tsxmin + $window;
      if ($xupper > $tsxmax) {
	$plxmin = $tsxmin;
	$plxmax = $plxmin + $window;
      } else {
	$plxmax = $tsxmax;
	$plxmin = $plxmax - $window;
      }
    }
  }

  # Store plotting window
  $winlo = $plxmin;
  $winhi = $plxmax;
  $ts->window($winlo, $winhi); 

  # Expand x-axis by 10% to allow chart to grow
  my $dx = $plxmax - $plxmin;
  $plxmax = $plxmax + 0.1*$dx;

  # Retrieve data limits within current window
  ($wxmin, $wxmax, $wymin, $wymax) = $ts->bounds;

  # Set pl y-limits
  # Catch case of zero points...
  unless ( defined $wxmin ) {
    $plxmin = 0;
    $plxmax = 1;
    $plymin = -1;
    $plymax = 1;
  } else {
    # Calculate limits if autoscaling
    if ($self->autoscale) {
      if ($wymax == $wymin) {
	if ($wymin == 0) { # Catch value = 0 case
	  $plymin = -1;
	  $plymax = 1;
	} else {
	  $plymax = 1.1*$wymax;
	  $plymin = 0.9*$wymin;
	}
      } else {
	my $dy = $wymax - $wymin;
	$plymax = $wymax + 0.1*$dy; # Expand by 10% of range
	$plymin = $wymin - 0.1*$dy;
      }
    } else {
      # Set ymin/max from Yscale attribute
      ($plymin,$plymax) = $self->yscale;
    }
  }

  # Select the correct subsection
  $self->device()->select;

  # Retrieve data within the plot window
  my ($xref, $yref);
  ($xref, $yref) = $ts->data(xyarr => 1, outside => 1);
  my $npts = $ts->npts( outside => 1 );
#  print $monid." ".$npts ." ".scalar(@{$xref})."\n";
#  print Dumper($xref);

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
    if ( $plxmin < $plotbounds[0] ||
	 $plxmax > $plotbounds[1] ||
	 $plymin < $plotbounds[2] ||
	 $plymax > $plotbounds[3] ) {
      # Clear the plot
      $isold = 0;
      $self->device->clear();
      undef $plt;

      # Determine which limits need to change - X probably always, but
      # not always Y
      if ($plymin > $plotbounds[2]) {
	$plymin = $plotbounds[2]; # Leave ymin as is
      } elsif ($plymax < $plotbounds[3]) {
	$plymax = $plotbounds[3]; # Leave ymax as is
      }

      # But make sure that we retrieve all the cache for replotting
      # from the specified x-range
#      ($xref, $yref) = $ts->data(xyarr => 1, outside => 1);
    }
  }

  # Create the new AST plot object if we do not have one
  if (!defined $plt) {
    
    $plt = new Starlink::AST::Plot( $self->astFrame(), [0,0,1,1],
				    [$plxmin,$plymin,$plxmax,$plymax], 
				    "size(title)=1.5,size(textlab)=1.3,size(numlab)=1.3,".
				    "colour(title)=3,colour(textlab)=3,labelling=exterior,".
				    "colour(border)=2,colour(numlab)=2,colour(ticks)=2");
    $self->astPlot( $plt );
  }

  # Register the correct plotting engine callbacks
  $self->_grfselect( $plt );

  # Draw the plot axes if we have changed the plot bounds
  unless ($isold) {
    $plt->Set("Labelling","exterior"); # Doesn't seem to do anything...
    $plt->Grid();
    # retrieve all other data from cache
    my %cache = $self->astCache;
    foreach my $mon (keys %cache ) {
      unless ($mon eq $monid) {
        # Retrieve cached data
        my $tscache = $self->astCache( $mon );
	my $ncachepts = $tscache->npts( outside => 1 );

	# Retrieve plotting attributes
	my $tsattr = $self->attr($mon);

	# Replot data
	if ($ncachepts > 0) {
	  my $tsscol = $self->_colour_to_index($tsattr->symcol);
	  my $tssym = $self->_sym_to_index($tsattr->symbol);
	  my ($xcache, $ycache) = $tscache->data(xyarr => 1, outside => 1);
	  $plt->Set("colour(markers)",$tsscol);
	  $plt->Mark($tssym, $xcache, $ycache);
	  if ($ncachepts > 1) {
	    my $tslcol = $self->_colour_to_index($tsattr->linecol);
	    my $tslstyle = $self->_style_to_index($tsattr->linestyle);
	    $plt->Set("colour(curves)",$tslcol);
	    $plt->Set("style(curves)", $tslstyle);
	    $plt->PolyCurve($xcache, $ycache);
	  }
	}
      } # end unless
    } # end foreach
  } # end unless $isold 

#  my $chan = new Starlink::AST::Channel( sink => sub { print "$_[0]\n"; } );
#  $chan->Write( $plt );

  # Plot the data using the requested attributes
  if ($npts > 0) {
    my $symcol = $self->_colour_to_index($attr->symcol);
    my $symbol = $self->_sym_to_index($attr->symbol);
    $plt->Set("colour(markers)",$symcol);
    $plt->Mark($symbol, $xref, $yref);
    if ($npts > 1) {
      my $linecol = $self->_colour_to_index($attr->linecol);
      my $linestyle = $self->_style_to_index($attr->linestyle);
      $plt->Set("colour(curves)", $linecol);
      $plt->Set("style(curves)", $linestyle);
      $plt->PolyCurve($xref, $yref); 
    }
  }

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
