package JAC::StripChart::Sink::AST::PLplot;

=head1 NAME

JAC::StripChart::Sink::AST::PLplot - PLplot specific AST class

=head1 SYNOPSIS

  use JAC::StripChart::Sink::AST::PLplot;

  $pgplot->select_plot

=head1 DESCRIPTION

This is an AST subclass that exists purely to select the correct AST
graphics engine for PLplot.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use List::Util qw/ min max /;

use Graphics::PLplot;
use Starlink::AST::PLplot;


use base qw| JAC::StripChart::Sink::AST |;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

Methods are inherited from C<JAC::StripChart::Sink::AST>.

=head2 General Methods

=over 4

=item B<init>

Initialise the plot area for AST.

=cut

sub init {
  plvpor(0.15,0.85,0.15,0.85);
  plwind(0,1,0,1);

}


=item B<_default_dev_class>

The default plotting device.

=cut

sub _default_dev_class {
  return "PLplot";
}

=item B<_grfselect>

Select the PLplot graphics subsystem for AST. Requires an AST plot
object as argument.

  $ast->_grfselect( $plot );

=cut

sub _grfselect {
  my $self = shift;
  my $plt = shift;
  $plt->plplot;
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

L<JAC::StripChart::Sink>, L<JAC::StripChart::Sink::AST>

=cut

1;
