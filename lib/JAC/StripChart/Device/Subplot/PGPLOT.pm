package JAC::StripChart::Device::Subplot::PGPLOT;

=head1 NAME

JAC::StripChart::Device::Subplot::PGPLOT - A subplot in a PGPLOT window

=head1 SYNOPSIS

  $s = new JAC::StripChart::Device::Subplot::PGPLOT( $dev, $panel );
  $s->select;

=head1 DESCRIPTION

Provides control of sub plot selection for a PGPLOT device.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use PGPLOT;
use JAC::StripChart::Error;

use base qw/ JAC::StripChart::Device::Subplot /;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 General Methods

=over 4

=item B<select>

Select the specified panel. Does not erase it.

=cut

sub select {
  my $self = shift;

  $self->SUPER::select();

  # calculate the coordinates
  my ($x, $y) = $self->panel_coords();

  # Select the panel
  pgpanl( $x, $y );

  return;
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

L<JAC::StripChart>, L<JAC::StripChart::Device::PGPLOT>,
L<JAC::StripChart::Device::Subplot>.

=cut

1;
