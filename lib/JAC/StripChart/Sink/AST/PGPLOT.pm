package JAC::StripChart::Sink::AST::PGPLOT;

=head1 NAME

JAC::StripChart::Sink::AST::PGPLOT - PGPLOT specific AST class

=head1 SYNOPSIS

  use JAC::StripChart::Sink::AST::PGPLOT;

  $pgplot->select_plot

=head1 DESCRIPTION

This is an AST subclass that exists purely to select the correct AST
graphics engine for PGPLOT.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use List::Util qw/ min max /;
use Starlink::AST::PGPLOT;

use base qw| JAC::StripChart::Sink::AST |;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

Methods are inherited from C<JAC::StripChart::Sink::AST>.

=head2 General Methods

=over 4

=item B<_default_dev_class>

The default plotting device.

=cut

sub _default_dev_class {
  return "PGPLOT";
}

=item B<_grfselect>

Select the PGPLOT graphics subsystem for AST. Requires an AST plot
object as argument.

  $ast->_grfselect( $plot );

=cut

sub _grfselect {
  my $self = shift;
  my $plt = shift;
  $plt->pgplot;
  return;
}

=item B<_colour_to_index>

Translate given colour to PGPLOT colour index

  $self->_colour_to_index( $colour );

=cut

sub _colour_to_index {
  my $self = shift;
  my $colour = shift;
  my $cindex = -1;

  # Note the order of @knowncolours is set to match the PGPLOT index number
  my @knowncolours = qw( white red green blue cyan magenta yellow orange chartreuse springgreen skyblue purple pink darkgrey grey);

  # Colour index given
  if ($colour =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Colour index does not exist - must lie between 1 and 15") if ($colour > 15 || $colour < 1);
    $cindex = $colour;
  } elsif ($colour =~ /[a-z]/) {
    # Convert to lower case
    my $lcolour = lc($colour);
    # Now examine other colours and convert known values to indices
    $lcolour = "grey" if ($lcolour eq "gray"); # For those who can't spell...
    $lcolour = "grey" if ($lcolour eq "lightgrey"); 
    for my $j (0..scalar(@knowncolours-1)) {
      if ($knowncolours[$j] eq $lcolour) {
	$cindex = $j + 1;
	last;
      } 
    }
  } else {
    throw JAC::StripChart::Error::BadConfig("Invalid string for colour");
  }
  # Warn if $cindex not set, and set to default colour
  # FUTURE: use this to establish new colour table
  if ($cindex == -1) {
    warnings::warnif(" Unknown colour, '$colour': setting to default value (yellow)");
    $cindex = 7;
  }
  return $cindex;
}

=item B<_style_to_index>

Translate given line style to PGPLOT line style index

  $self->_style_to_index( $style );

PGPLOT supports only 5 linestyles

=cut

sub _style_to_index {
  my $self = shift;
  my $style = shift;
  my $stindex = 1;

  if ($style eq "solid") {
    $stindex = 1;
  } elsif ($style eq "dot" || $style eq "dotted") {
    $stindex = 4;
  } elsif ($style eq "dash-dot" || $style eq "ddash" || $style eq "dot-dash" ) {
    $stindex = 3;
  } elsif ($style eq "longdash" || $style eq "ldash" || $style eq "dash" || $style eq "dashed" )  {
    $stindex = 2;
  } elsif ($style eq "dash-dot-dot" || $style eq "dddash") {
    $stindex = 5;
  } else {
    print " Unknown LineStyle - setting style to solid \n";
    $stindex = 1;
  }
  
  return $stindex;
}

=item B<_sym_to_index>

Translate given plot symbol to PGPLOT symbol index

  $self->_sym_to_index( $style );

For now, only support basic symbols (circle, square etc). If symbol
index is given directly, then check for valid value and set it to the
given or default value.

=cut

sub _sym_to_index {
  my $self = shift;
  my $sym = shift;
  my $symindex = -10;

  # Prefix with `f' to get filled versions
  my %knownsymbols = ( square => 0,
		       dot => 1,
		       plus => 2,
		       asterisk => 3,
		       circle => 4,
		       cross => 5,
		       times => 5,
		       x => 5,
		       triangle => 7,
		       diamond => 11,
		       star => 12,
		       fcircle => 17,
		       fsquare => 16,
		       ftriangle => 13,
		       fstar => 18,
		       fdiamond => -4);

  if ($sym =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Symbol index not defined - must lie between -4 and 31") 
      if ($sym > 31 || $sym < -4);
    $symindex = $sym;
  } elsif ($sym =~ /[a-z]/) {
    foreach my $symkey (keys %knownsymbols) {
      $symindex = $knownsymbols{$symkey} if ($symkey eq $sym);
    }
  }
  if ($symindex == -10) {
    warnings::warnif(" Unknown symbol, '$sym': setting to default (+)");
    $symindex = 7;
  }

  return $symindex;
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
