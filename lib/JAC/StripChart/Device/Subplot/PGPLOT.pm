package JAC::StripChart::Device::PGPLOT::Subplot;

=head1 NAME

JAC::StripChart::Device::PGPLOT::Subplot - A subplot in a PGPLOT window

=head1 SYNOPSIS

  $s = new JAC::StripChart::Device::PGPLOT::Subplot( $dev, $panel );
  $s->select;

=head1 DESCRIPTION

Provides control of sub plot selection.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use PGPLOT;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new PGPLOT subplot.

  $sub = new JAC::StripChart::Device::PGPLOT::Subplot( $dev, 4 );

The first argument must be a JAC::StripChart::Device::PGPLOT object.
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

=back

=head2 General Methods

=over 4

=item B<select>

Select the specified panel. Does not erase it.

=cut

sub select {
  my $self = shift;

  # select the PGPLOT device itself
  $self->device->select;

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

  # Select the panel
  pgpanl( $x, $y );

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

L<JAC::StripChart>, L<JAC::StripChart::Device::PGPLOT>

=cut

1;
