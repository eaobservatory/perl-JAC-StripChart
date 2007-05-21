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

use base qw| JAC::StripChart::Sink |;
use JAC::StripChart::Error;
use JAC::StripChart::TimeSeries;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

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

  # Update colours to check for duplicates
  $self->_update_line_colours( $self->attr );

  # Configure the timemap (we may want to make this choice
  # configurable so I'm writing this as if it is)
#  my $output = 'hours';  # days or radians or hours or unit
  my $tunits = $self->tunits;

  my $fr;
  my $shared = "title=StripChart,label(1)=Time,label(2)=Flux,unit(2)=Jy";
  # KLUDGE: assumes that data being plotted are arriving TODAY and
  # data files contain no older data! Really need to use oldest point
  # to be plotted for each chart
  use Time::Piece;
  my $today = gmtime; 
  my $refdate = $today->ymd;
  if ($tunits eq 'days' || $tunits eq 'unit') {
    $self->timemap->output( $tunits );

    # unit string depends on format but we know that refdate
    # will be set
    my $unit;
    if ($tunits eq 'days' ) {
      $unit = 'frac UT day since midnight '. $refdate;
    } else {
      $unit = 'MJD';
    }

    # Create the plotting frame
    $fr = new Starlink::AST::Frame( 2, "$shared,unit(1)=$unit" );

  } elsif ($tunits eq 'hours' ) {

    $self->timemap->output( $tunits );

    # Create the plotting frame
    $fr = new Starlink::AST::Frame( 2, "$shared,unit(1)=UT Hours since midnight $refdate" );

  } elsif ($tunits eq 'radians' ) {

    $self->timemap->output( $tunits );

    # Now we get tricky since we want a slice of a SkyFrame
    # to render the hours minutes and seconds as if it was 
    # a RA cut

    # create a sky frame and extract axis 1 (RA) into a new 1D frame
    my $sky = new Starlink::AST::SkyFrame( "" );
    my $ra = $sky->PickAxes( [1] );

    # create a 1D frame for the Y axis
    my $yaxis = new Starlink::AST::Frame(1, "" );

    # combine into a 2D compound frame
    $fr = new Starlink::AST::CmpFrame( $ra, $yaxis, "$shared,unit(1)=UT Hours since midnight $refdate" );

  } else {
    throw JAC::StripChart::Error::FatalError("Unknown output format for map: $tunits");
  }

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

  # return immediately if no data and not updated
  return if (!scalar(@data) && !$self->updated);

  # Retrieve or create new timeseries object
  my $ts = $self->astCache( $monid );

  # Sort data by time (useful later)
  @data = sort { $a->[0] <=> $b->[0] } @data;

  # Use the first date as reference date for the mapping
  if (!$self->timemap->refdate && scalar(@data) ) {
    $self->timemap->refdate( int($data[0]->[0]) );
  }

  # Store new data in it
  $ts->add_data( @data );

  # return if no data in time series yet
  return unless $ts->npts( full => 1 );

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
  if (!$window || (defined $window && $window <= 0)) {
    # Check if ts x-limits are equal...
    if ($tsxmin == $tsxmax) {
      my $dayfrac = 0.1 / 24; # 1 hour
      if ($tsxmin == 0) { # Catch value = 0 case
	$plxmin = 0;
	$plxmax = $dayfrac;
      } else {
	# units are in MJD so we only want to adjust the default
	# bounds by a fraction of a day not a fraction of the MJD
	# if we have min == max
	$plxmax = $tsxmax + $dayfrac;
#	$plxmin = max( int($tsxmin), ($tsxmin - $dayfrac) );
	$plxmin = $tsxmin;
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

  # Note that if the plot attributes have been modified we are forced
  # to redraw the plot regardless of whether the data fit inside the current
  # bounds
  if ($self->updated) {
    $self->device->clear();
    undef $plt;
    $self->updated( 0 );
  }

  # do we have a plot already?
  if (defined $plt) {
    $isold = 1;

    # We have a plot but we are not sure whether the bounds are okay
    # Get the current plot bounds from the plot frame
    my @plotbounds = $plt->PBox;

    # convert the t bounds back to MJD
    ($plotbounds[0]) = $self->timemap->do_inverse( $plotbounds[0] );
    ($plotbounds[1]) = $self->timemap->do_inverse( $plotbounds[1] );

    # see if the data bounds are inside these bounds
    if ( $wxmin < $plotbounds[0] ||
	 $wxmax > $plotbounds[1] ||
	 $wymin < $plotbounds[2] ||
	 $wymax > $plotbounds[3] ) {

      # If not and we are autoscaling then check and reset plot
      # bounds if necessary to keep the largest values
      if ($self->autoscale) {
	$plymin = $plotbounds[2] if ($plymin > $plotbounds[2]);
	$plymax = $plotbounds[3] if ($plymax < $plotbounds[3]);
      }
      # Only allow $plxmin/max to be used if $plxmax exceeds current
      # x limit, else the original window is retained.
      if ($plxmax < $plotbounds[1]) {
	$plxmax = $plotbounds[1];
	$plxmin = $plotbounds[0];
      }

      # Clear the plot
      $isold = 0;
      $self->device->clear();
      undef $plt;

    }
  }

  # Create the new AST plot object if we do not have one
  if (!defined $plt) {
    # convert t bounds to processed format
    my ($mapped_plxmin) = $self->timemap->do_map( $plxmin );
    my ($mapped_plxmax) = $self->timemap->do_map( $plxmax );

    # create plot
    my $border = 0.14;
    $plt = new Starlink::AST::Plot( $self->astFrame(), 
				    [$border,$border,1-$border,1-$border],
				    [$mapped_plxmin,$plymin,
				     $mapped_plxmax,$plymax], 
				    "size(title)=1.5,size(textlab)=1.3,size(numlab)=1.3,".
				    "colour(title)=3,colour(textlab)=3,labelling=exterior,".
				    "colour(border)=2,colour(numlab)=2,colour(ticks)=2");
    $self->astPlot( $plt );
  }

  # Register the correct plotting engine callbacks
  $self->_grfselect( $plt );

  # Only want to plot new data, unless the plot is to be redrawn
  my ($plxref, $plyref);
  # Find most recent time
  my $lastdata = $data[0]->[0]; 
  my $lasttime = $ts->prevdata($lastdata); # Return ref to earliest point

  # If a plot exists, and we have plotted data previously then
  # determine the most recent data to plot.
  my $npts = $ts->npts( outside => 1 );
  if ( $isold && $lasttime->[0] ) {
    # Set window if the new points lie within the current window
    $ts->window($lasttime->[0], undef) if ($lasttime->[0] > $plxmin);
    # Retrieve data
    ($plxref,$plyref) = $ts->data(xyarr => 1);
    # Re-calculate number of points to plot
    $npts = $ts->npts; 
  } else {
    # If no plot, then use the whole range of values
    $plxref = $xref;
    $plyref = $yref;
  }


  # Draw the plot axes if we have changed the plot bounds
  # Reset window to full range
  $ts->window($winlo, $winhi); 
  unless ($isold) {

    # Set plotting attributes:
    $plt->Set("Labelling","exterior"); # Doesn't seem to do anything...
    my $title = $self->plottitle;
    $plt->Set("Title",$title);
    $plt->Set("TitleGap","0.01");

    $plt->Grid();

    # Retrieve all other data from cache - note use monitors from
    # Cache as these are the data that havbe already been stored, as
    # opposed to all the monitors that will be (and may not yet be)
    # plotted.
    my %cache = $self->astCache;
    foreach my $mon ( keys %cache ) {

      unless ($mon eq $monid) {
        # Retrieve cached data
        my $tscache = $self->astCache( $mon );
	$tscache->window( $winlo, $winhi );
	my $ncachepts = $tscache->npts( outside => 1 );

	# Retrieve plotting attributes
	my $tsattr = $self->attr($mon);

	# Replot data
	if ($ncachepts > 0) {
	  my $tsscol = $self->_colour_to_index($tsattr->symcol);
	  my $tssym = $self->_sym_to_index($tsattr->symbol);
	  my ($xcache, $ycache) = $tscache->data(xyarr => 1, outside => 1);
	  $plt->Set("colour(markers)", $tsscol);
	  my @mapped = $self->timemap->do_map( @$xcache );
	  $plt->Mark($tssym, \@mapped, $ycache);
	  if ($ncachepts > 1) {
	    my $tslcol = $self->_colour_to_index($tsattr->linecol);
	    my $tslstyle = $self->_style_to_index($tsattr->linestyle);
	    $plt->Set("colour(curves)", $tslcol);
	    $plt->Set("style(curves)", $tslstyle);
	    $plt->PolyCurve(\@mapped, $ycache);
	  }
	}
      } # end unless $monid
    } # end foreach $mon
  } # end unless $isold 


  # Position offsets for plot legends
  my ($delta,$j) = (0.05,0);
#  my $x0 = 0.8; # Original value
#  my $y0 = 0.95; # Original value
  my $x0 = 0.8; # Hack to deal with Tk vs PGPLOT concepts of 0->1
  my $y0 = 0.88;
  my @keys = $self->monitor_ids;
  my ($plline, $plsym);
  foreach my $mon (@keys) {
    my $plotattr = $self->attr($mon);
    # Plot legend...
    $plt->Set("Current=1");
    # Retrieve plot attributes
    my $symcol = $self->_colour_to_index($plotattr->symcol);
    my $symbol = $self->_sym_to_index($plotattr->symbol);
    my $linecol = $self->_colour_to_index($plotattr->linecol);
    my $linestyle = $self->_style_to_index($plotattr->linestyle);
    # Plot text label
    # Initial position of plot legend
    my ($xpos, $ypos);
    $xpos = $x0;
    $ypos = $y0 - $delta*$j;
    $j++;

    $plt->Set("Size(Strings)=1.5");
    $plt->Set("Colour(Strings)",$linecol);
    $plt->Text($mon,[$xpos,$ypos],[0.0,1.0],"CC");
    # Determine position of plot legend
    my ($lbox, $ubox) = $plt->BoundingBox;
    my $xpt1 = 0.95 * $lbox->[0];
    my $ypt1 = $lbox->[1];
    my $xleg = [ $xpt1, ($xpt1 - 0.075) ];
    my $ymid = 0.5 * ( $lbox->[1] + $ubox->[1] );
    my $yleg = [ $ymid, $ymid ];
    # Determine whether to plot symbols or lines
    $plline = ( ($plotattr->linestyle eq '0' || lc($plotattr->linestyle) =~ "no") ? 0 : 1 );
    $plsym = ( ($plotattr->symbol eq '0' || lc($plotattr->symbol) =~ "no") ? 0 : 1 );
    throw  JAC::StripChart::Error::BadConfig("Must specify either a symbol or a linestyle for monitor $mon on chart $chartid") 
      unless ($plline || $plsym);

    # Plot legend
    if ($plline) {
      $plt->Set("colour(curves)", $linecol);
      $plt->Set("style(curves)", $linestyle);
      $plt->PolyCurve($xleg, $yleg);
    }
    if ($plsym) {
      $plt->Set("colour(markers)", $symcol);
      $plt->Mark($symbol, $xleg, $yleg);
    }
    $plt->Set("Current=2");
  }

  # Plot the data using the requested attributes (if applicable)
  $plline = ( ($attr->linestyle eq '0' || lc($attr->linestyle) =~ "no") ? 0 : 1 );
  $plsym = ( ($attr->symbol eq '0' || lc($attr->symbol) =~ "no") ? 0 : 1 );

  throw  JAC::StripChart::Error::BadConfig("Must specify either a symbol or a linestyle for monitor $monid on chart $chartid") 
    unless ($plline || $plsym);

  if ($npts > 0) {
    my @mapped = $self->timemap->do_map( @$plxref );
    if ($plsym) {
      my $symcol = $self->_colour_to_index($attr->symcol);
      my $symbol = $self->_sym_to_index($attr->symbol);
      $plt->Set("colour(markers)",$symcol);
      $plt->Mark($symbol, \@mapped, $plyref);
    }

    if ($npts > 1 && $plline) {
      my $linecol = $self->_colour_to_index($attr->linecol);
      my $linestyle = $self->_style_to_index($attr->linestyle);
      $plt->Set("colour(curves)", $linecol);
      $plt->Set("style(curves)", $linestyle);
      $plt->PolyCurve(\@mapped, $plyref);
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

=item B<_colour_to_index>

Translate given colour to AST colour index

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

Translate given line style to AST line style index

  $self->_style_to_index( $style );

PGPLOT supports only 5 linestyles

=cut

sub _style_to_index {
  my $self = shift;
  my $style = shift;
  my $stindex = 1;

  if ($style =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Line style index does not exist - must lie between 1 and 5") 
      if ($style > 5 || $style < 0);
    $stindex = $style;
  } elsif ($style =~ /[a-z]/) {
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
    } elsif ($style =~ "no") {
      $stindex = 0;
    }
  } else {
    print " Unknown LineStyle - setting style to solid \n";
    $stindex = 1;
  }

  return $stindex;
}

=item B<_sym_to_index>

Translate given plot symbol to AST symbol index

  $self->_sym_to_index( $style );

For now, only support basic symbols (circle, square etc). If symbol
index is given directly, then check for valid value and set it to the
given or default value.

=cut

sub _sym_to_index {
  my $self = shift;
  my $sym = shift;
  my $symindex = -10;

  # Prefix with `f' to get filled versions
  my %knownsymbols = ( square => 0,
		       dot => 1,
		       plus => 2,
		       asterisk => 3,
		       circle => 4,
		       cross => 5,
		       times => 5,
		       x => 5,
		       triangle => 7,
		       diamond => 11,
		       star => 12,
		       fcircle => 17,
		       fsquare => 16,
		       ftriangle => 13,
		       fstar => 18,
		       fdiamond => -4);

  if ($sym =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Symbol index not defined - must lie between -4 and 31") 
      if ($sym > 31 || $sym < -4);
    $symindex = $sym;
  } elsif ($sym =~ /[a-z]/) {
    if ($sym =~ "no") {
      $symindex = 0;
    } else {
      foreach my $symkey (keys %knownsymbols) {
	$symindex = $knownsymbols{$symkey} if ($symkey eq $sym);
      }
    }
  }
  if ($symindex == -10) {
    warnings::warnif(" Unknown symbol, '$sym': setting to default (+)");
      $symindex = 2;
  }
  return $symindex;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Andy Gibb E<lt>agg@astro.ubc.caE<gt>


=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council and
the University of British Columbia. Copyright (C) 2007 Science and Technology
Facilities Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA  02111-1307, USA

=head1 SEE ALSO

L<JAC::StripChart::Sink>, L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
