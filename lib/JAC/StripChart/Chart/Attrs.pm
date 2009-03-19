package JAC::StripChart::Chart::Attrs;

=head1 NAME

JAC::StripChart::Chart::Attrs - Chart plotting attributes

=head1 SYNOPSIS

  use JAC::StripChart::Chart::Attrs;

  $attr = new JAC::StripChart::Chart::Attrs( linecol => 'red' );

=head1 DESCRIPTION

This class is a place to store plotting attributes associated with
individual monitors. The plot devices will query an instance of this
class to decide what color should be used for the data and whether symbols
should be plotted.

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

   $cfg = new JAC::StripChart::Chart::Attrs( linecol => 'red' );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $attrs = bless {
		     LineCol => 'yellow',
		     LineStyle => 'solid',
		     SymCol  => 'green',
		     Symbol  => 'circle',
		    }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k ( keys %args ) {
      my $m = lc($k);
      $attrs->$m($args{$k}) if $attrs->can( $m );
    }
  }

  return $attrs;
}

=back

=head2 Accessor Methods

=over 4

=item B<linecol>

Color of the line.

=cut

sub linecol {
  my $self = shift;
  if (@_) { $self->{LineCol} = shift; }
  return $self->{LineCol};
}


=item B<symcol>

Color of the symbol.

=cut

sub symcol {
  my $self = shift;
  if (@_) { $self->{SymCol} = shift; }
  return $self->{SymCol};
}

=item B<linestyle>

Style of the line.

=cut

sub linestyle {
  my $self = shift;
  if (@_) { $self->{LineStyle} = shift; }
  return $self->{LineStyle};
}

=item B<symbol>

Symbol to use.

=cut

sub symbol {
  my $self = shift;
  if (@_) { $self->{Symbol} = shift; }
  return $self->{Symbol};
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

L<JAC::StripChart::Chart>, L<JAC::StripChart::Config>

=cut

1;
