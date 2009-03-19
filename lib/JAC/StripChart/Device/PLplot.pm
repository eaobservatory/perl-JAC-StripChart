package JAC::StripChart::Device::PLplot;

=head1 NAME

JAC::StripChart::Device::PLplot - PLplot plotting device

=head1 SYNOPSIS

  use JAC::StripChart::Device::PLplot;

  $dev = new JAC::StripChart::Device::PLplot();

  $s = $dev->define_subplot( 2 );
  $s->select;

=head1 DESCRIPTION

PLplot-based stripchart output device.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use base qw/ JAC::StripChart::Device /;

use Graphics::PLplot;

use JAC::StripChart::Device::Subplot::PLplot;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = 1.0;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new PLplot device. This will create a PLplot window.

    $dev = new JAC::StripChart::Device::PLplot( nxy => [3,4] );

Supported options are:

  nxy =>   Ref to array indicating the number of x and y subplots
  dev =>   PLplot device name (eg xwin)

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $dev = $class->SUPER::new( @_ );

  # Select the device
  my $devdriver = $dev->device_driver;
  plsdev( $devdriver ? $devdriver : "xwin" );

  # subdivide the page
  plssub( $dev->nxy );

  # initialise
  plinit();
  pladv(0);
  plvsta();

  return $dev;
}

=back

=head2 General Methods

=over 4

=item B<define_subplot>

Return an object suitable for registering with a Sink object, that can
be used for controlling device switching and subplot selection.

  $s = $dev->define_subplot( 2 );

A subsection number is required. Returns objects of class
C<JAC::StripChart::Device::Subplot::PLplot>.

=cut

sub define_subplot {
  my $self = shift;
  my $panl = shift;
  $panl = 0 unless defined $panl;
  my $s = new JAC::StripChart::Device::Subplot::PLplot( $self, $panl );
  return $s;
}

=item B<select>

Select this particular PLplot device, instead of any other PLplot
device.

  $dev->select;

Does nothing with PLplot.

=cut

sub select {
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
