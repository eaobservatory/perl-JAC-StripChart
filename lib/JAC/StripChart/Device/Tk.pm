package JAC::StripChart::Device::Tk;

=head1 NAME

JAC::StripChart::Device::Tk - Tk plotting device

=head1 SYNOPSIS

  use JAC::StripChart::Device::Tk;

  $dev = new JAC::StripChart::Device::Tk( context => MainWindow->new() );

  $s = $dev->define_subplot( 2 );
  $s->select;

=head1 DESCRIPTION

Tk-based stripchart output device.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use base qw/ JAC::StripChart::Device /;

use Tk;
use Tk::Canvas;

use JAC::StripChart::Device::Tk::Subplot;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new Tk canvas. Multiple subplots require multiple canvases
to be created (see the devid() method).

    $dev = new JAC::StripChart::Device::PGPLOT( nxy => [3,4],
                                                context => $frame );

Supported options are:

  context => Parent Tk frame in which to embed the canvas(es)
  nxy =>   Ref to array indicating the number of x and y subplots

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $dev = $class->SUPER::new( @_ );

  # obtain the context
  my $context = $dev->context;

  # see if we have a valid context
  if (!defined $context || !UNIVERSAL::isa($context, "Tk::Frame") ) {

    # Create one
    $context = MainWindow->new;
    $dev->context( $context );
  }

  # we now need to create the individual canvas objects
  # To support multiple objects in X and Y we create a frame and then
  # fill it in using the grid packer

  # First create a frame
  my $parent = $context->Frame();

  # some where to store the canvas objects
  my @canv;

  # loop over nx ny
  my ($nx, $ny ) = $dev->nxy;
  for my $i ( 1 .. $nx ) {
    for my $j ( 1 .. $ny ) {
      my $index = $dev->_ij_to_index( $i, $j );
      print "********************* INDEX: $index with $i, $j\n";
      $canv[ $index ] = $parent->Canvas( -background => 'white',
				       )->grid( -column => ($i-1),
						-row => ($j-1) );
    }
  }

  # pack it into the "context"
  $parent->pack();

  # store the canvas objects
  $dev->devid( \@canv );

  return $dev;
}

=back

=head2 Accessor Methods

=over 4

=item B<devid>

Reference to an array of canvas objects representing the subplots.

=back

=head2 General Methods

=over 4

=item B<define_subplot>

Return an object suitable for registering with a Sink object, that can
be used for controlling device switching and subplot selection.

  $s = $dev->define_subplot( 2 );

A subsection number is required. Returns objects of class
C<JAC::StripChart::Device::Tk::Subplot>.

=cut

sub define_subplot {
  my $self = shift;
  my $panl = shift;
  $panl = 0 unless defined $panl;
  my $s = new JAC::StripChart::Device::Tk::Subplot( $self, $panl );
  return $s;
}

=item B<select>

Select this particular Tk canvas, instead of any other canvas.

  $dev->select;

A no-op for Tk canvases since each canvas is already specific.

=cut

sub select {
  my $self = shift;
  return;
}

=item B<clear>

Clear this device, ready for plotting.

=cut

sub clear {
  my $self = shift;
  my $canvases = $self->devid;
  for my $c (@$canvases) {
    $c->delete( 'all' );
  }

}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_ij_to_index>

Convert an x and y position in subplot coordinates to an array index
within the "devid" array.

  $k = $dev->_ij_to_index( $i, $j );

=cut

sub _ij_to_index {
  my $self = shift;
  my ($i, $j) = @_;
  my ($nx, $ny) = $self->nxy;
  return ( $nx * ($j - 1) + $i - 1 );
}

=back

=end __PRIVATE_METHODS__

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004-2005 Particle Physics and Astronomy Research Council.
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

L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
