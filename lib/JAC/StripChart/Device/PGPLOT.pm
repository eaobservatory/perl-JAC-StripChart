package JAC::StripChart::Device::PGPLOT;

=head1 NAME

JAC::StripChart::Device::PGPLOT - PGPLOT plotting device

=head1 SYNOPSIS

  use JAC::StripChart::Device::PGPLOT;

  $dev = new JAC::StripChart::Device::PGPLOT();

  $s = $dev->define_subplot( 2 );
  $s->select;

=head1 DESCRIPTION

PGPLOT-based stripchart output device.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use base qw/ JAC::StripChart::Device /;

use PGPLOT;

use JAC::StripChart::Device::Subplot::PGPLOT;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = 1.0;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new PGPLOT device. This will create a PGPLOT window.

    $dev = new JAC::StripChart::Device::PGPLOT( nxy => [3,4] );

Supported options are:

  nxy =>   Ref to array indicating the number of x and y subplots
  dev =>   PGPLOT device name (eg /xserve)

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $dev = $class->SUPER::new( @_ );

  my @nxy = $dev->nxy;
  my @dims = $dev->dims();
  $ENV{PGPLOT_XW_WIDTH} = $dims[0] if $dims[0] > 0;

  my $devdriver = $dev->device_driver;
  my $devid = pgopen( $devdriver ? $devdriver : '/xw' );
  throw JAC::StripChart::Error::BadPlotDevice("Error opening PGPLOT window")
    if $devid <= 0;

  # subdivide the page
  pgsubp( @nxy );

  # store the device id
  $dev->devid( $devid );

  return $dev;
}

=back

=head2 Accessor Methods

=over 4

=item B<devid>

The low level PGPLOT device ID returned by the call to PGOPEN.

=back

=head2 General Methods

=over 4

=item B<define_subplot>

Return an object suitable for registering with a Sink object, that can
be used for controlling device switching and subplot selection.

  $s = $dev->define_subplot( 2 );

A subsection number is required. Returns objects of class
C<JAC::StripChart::Device::Subplot::PGPLOT>.

=cut

sub define_subplot {
  my $self = shift;
  my $panl = shift;
  $panl = 0 unless defined $panl;
  my $s = new JAC::StripChart::Device::Subplot::PGPLOT( $self, $panl );
  return $s;
}

=item B<select>

Select this particular PGPLOT device, instead of any other PGPLOT
device.

  $dev->select;

=cut

sub select {
  my $self = shift;
  pgslct( $self->devid );
}

=item B<clear>

Clear this device, ready for plotting.

=cut

sub clear {
  my $self = shift;
  $self->select;
  pgeras;
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

L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
