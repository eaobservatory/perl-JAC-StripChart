package JAC::StripChart::Sink::AST::Tk;

=head1 NAME

JAC::StripChart::Sink::AST::Tk - Tk specific AST class

=head1 SYNOPSIS

  use JAC::StripChart::Sink::AST::Tk;

  $tk->select_plot

=head1 DESCRIPTION

This is an AST subclass that exists purely to select the correct AST
graphics engine for Tk and any other device specific methods.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use List::Util qw/ min max /;
use Starlink::AST::Tk;

use base qw| JAC::StripChart::Sink::AST |;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = 1.0;

=head1 METHODS

Methods are inherited from C<JAC::StripChart::Sink::AST>.

=head2 General Methods

=over 4

=item B<_default_dev_class>

The default plotting device.

=cut

sub _default_dev_class {
  return "Tk";
}

=item B<_grfselect>

Select the PGPLOT graphics subsystem for AST. Requires an AST plot
object as argument.

  $ast->_grfselect( $plot );

=cut

sub _grfselect {
  my $self = shift;
  my $plt = shift;
  my $dev = $self->device();
  throw JAC::StripChart::Error::FatalError("Attempt to select Tk canvas but no canvas has been registered")
    unless defined $dev;
  $dev->select;
  $plt->tk( $dev->canvas );
  my $w = $dev->canvas->cget( '-width' );
  my $h = $dev->canvas->cget( '-height' );
#  print "HW = ($w, $h)\n";
  return;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research Council.
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
