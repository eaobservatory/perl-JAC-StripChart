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
  my $fr = new Starlink::AST::Frame( 2, "title=Title,label(1)=time,unit(2)=MJD,label(2)=flux,unit(2)=Jy" );

  $self->astFrame( $fr );

  # We can not set plot attributes here since we are in principal creating
  # a new plot each time the scale changes

}

=item B<putData>

Plot the data on the registered device using AST as the plotting engine.

  $snk->putData( $chartid, $monid, $attr, @data );

=cut

my %cache;
sub putData {
  my $self = shift;
  my ($chartid, $monid, $attr, @data ) = @_;

  # First need to store the new data in the cache indexed by monid
  for my $elem (@data) {
    $cache{$monid}{$elem->[0]} = $elem->[1];
  }

  # then need to calculate statistics from the data for autoscaling
  my @x = map { $_->[0] } @data;
  my @y = map { $_->[1] } @data;

  my $xmax = max( @x );
  my $xmin = min( @x );
  my $ymax = max( @y );
  my $ymin = min( @y );

  # Now we need to window this range to make sure things are as specified
  # We should do all calculations on the cache rather than on the
  # current data

  # Select the correct subsection
  $self->device()->select;

  # Now need to find out whether the data range for plotting
  # has changed. If it has we need to clear and recreate the
  # plot.
  my $isold = 0;
  my $plt = $self->astPlot;

  if (defined $plt) {
    $isold = 1;
    # We have a plot but we are not sure whether the bounds are okay
    # Get the current plot bounds from the plot frame
    my @bounds = $plt->PBox;

    # see if the data bounds are inside these bounds
    if ( $xmin < $bounds[0] ||
	 $xmax > $bounds[1] ||
	 $ymin < $bounds[2] ||
	 $ymax > $bounds[3] ) {
      # Clear the plot
      $isold = 0;
      $self->device->clear();
      undef $plt;

      # But make sure that we retrieve all the cache for replotting
      # from the specified x-range
      # Currently extract all
      @x = ();
      @y = ();
      # Really need to replot all cached data for this plot
      for my $x ( sort { $a <=> $b } keys %{ $cache{$monid} } ) {
	push(@x, $x);
	push(@y, $cache{$monid}->{$x});
      }
    }
  }

  # Create the new AST plot object if we do not have one
  if (!defined $plt) {
    $plt = new Starlink::AST::Plot( $self->astFrame(), [0,0,1,1],
				    [$xmin,$ymin,$xmax,$ymax], "" );
    $self->astPlot( $plt );
  }


  # Register the correct plotting engine callbacks
  $self->_grfselect( $plt );

  # draw the plot axes if we have changed the plot bounds
  $plt->Grid() unless $isold;

#  my $chan = new Starlink::AST::Channel( sink => sub { print "$_[0]\n"; } );
#  $chan->Write( $plt );

  # plot the data using the requested attributes
  $plt->PolyCurve(\@x, \@y);

  # return and wait for more data

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
