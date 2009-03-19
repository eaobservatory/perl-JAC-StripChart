package JAC::StripChart::Device::Subplot::Tk;

=head1 NAME

JAC::StripChart::Device::Subplot::Tk - A subplot in a Tk window

=head1 SYNOPSIS

  $s = new JAC::StripChart::Device::Subplot::Tk( $dev, $panel );
  $s->select;

=head1 DESCRIPTION

Provides control of sub plot selection.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use Tk;
use JAC::StripChart::Error;

use base qw/ JAC::StripChart::Device::Subplot /;

use vars qw/ $VERSION /;
$VERSION = 1.0;

=head1 METHODS

=head2 Accessor Methods

=item B<canvas>

Plot canvas object that should be used for this subplot.

=cut

sub canvas {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    throw JAC::StripChart::Error::BadClass( "Argument must be a Tk::Canvas object") unless ( UNIVERSAL::isa( $arg, "Tk::Canvas") || UNIVERSAL::isa( $arg, "Tk::Zinc" ) );
    $self->{CANVAS} = $arg;
  }
  return $self->{CANVAS};
}

=item B<event_class>

Event handling class for this device.

=cut

sub event_class {
  return "JAC::StripChart::Event::Tk";
}

=head2 General Methods

=over 4

=item B<select>

Select the specified panel. Does not erase it.

=cut

sub select {
  my $self = shift;

  # select the Tk device itself
  $self->device->select;

  # We now need to extract the correct canvas object
  my $panel = $self->panel;

  my $canvases = $self->device->devid;
  $self->canvas( $canvases->[ $panel - 1 ] );

  return;
}

=item B<clear>

Clear this device, ready for plotting.

=cut

sub clear {
  my $self = shift;
  $self->select;
  my $canv = $self->canvas;
  if( $canv->isa( "Tk::Canvas" ) ) {
    $canv->delete( 'all' );
  } elsif( $canv->isa( "Tk::Zinc" ) ) {
    $canv->remove( 'all' );
  }
}


=back

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

L<JAC::StripChart>, L<JAC::StripChart::Device::Tk>, L<JAC::StripChart::Device::Subplot>

=cut

1;
