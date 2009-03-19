package JAC::StripChart::Device::Subplot;

=head1 NAME

JAC::StripChart::Device::Subplot - A generic subplot

=head1 SYNOPSIS

  $s = new JAC::StripChart::Device::Subplot( $dev, $panel );
  $s->select;

=head1 DESCRIPTION

Provides control of sub plot selection.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = 1.0;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new subplot.

  $sub = new JAC::StripChart::Device::Subplot( $dev, 4 );

The first argument must be a JAC::StripChart::Device object.
The second argument must be a panel number on the display.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($device, $panel) = @_;

  my $sub = bless {
		   DEVICE => undef,
		   PANEL => 0,
		  }, $class;


  # store the parameters
  $sub->device( $device );
  $sub->panel( $panel );

  return $sub;
}

=back

=head2 Accessor Methods

=over 4

=item B<device>

The associated plot device object.

=cut

sub device {
  my $self = shift;
  if (@_) { $self->{DEVICE} = shift; }
  return $self->{DEVICE};
}

=item B<panel>

The panel number within the plot device.

=cut

sub panel {
  my $self = shift;
  if (@_) { $self->{PANEL} = shift; }
  return $self->{PANEL};
}

=item B<event_class>

Name of the relevant Event handling class that should be used with
this device. Returns undef in the base class.

=cut

sub event_class {
  return;
}

=back

=head2 General Methods

=over 4

=item B<select>

Select the specified panel. Does not erase it. The base class simply
selects the base device.

 $sub->select();

=cut

sub select {
  my $self = shift;
  # select the device itself
  $self->device->select();
  return;
}

=item B<clear>

Clear this device, ready for plotting. Base class simply clears the
base device.

=cut

sub clear {
  my $self = shift;
  $self->select;
  $self->device->clear();
  return;
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<panel_coords>

Return the panel coordinates corresponding to the panel number.
Top left panel is panel 1, corresponding to coordinate (1,1).

 ($i, $j) = $sub->panel_coords();

=cut

sub panel_coords {
  my $self = shift;

  # Convert the panel number to an X, Y coordinate
  #   1  2  3  4
  #   5  6  7  8 etc
  my @nxy = $self->device->nxy;
  my $panel = $self->panel;

  # Calculate the X position by seeing what the residual
  # is when dividing by the width
  my $x = $panel % $nxy[0];
  my $y = int($panel / $nxy[0] ) + ($x == 0 ? 0 : 1);
  $x = $nxy[0] if $x == 0;

  return ($x, $y);
}

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

L<JAC::StripChart>, L<JAC::StripChart::Device>

=cut

1;
