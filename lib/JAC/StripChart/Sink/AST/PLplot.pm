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
  my $self = shift;
  plvpor(0.15,0.85,0.15,0.85);
  plwind(0,1,0,1);
  plsetopt("db",""); # Use double-buffer option to redraw plot
  plsetopt("np",""); # No-pause

  $self->SUPER::init(@_);

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

=item B<_colour_to_index>

Translate given colour to PLplot colour index

  $self->_colour_to_index( $colour );

=cut

sub _colour_to_index {
  my $self = shift;
  my $colour = shift;
  my $cindex = -1;
  $colour = lc($colour);

  # Note the order of @knowncolours is set to match the PLplot index number
  my @knowncolours = qw( red yellow green aquamarine pink wheat grey brown blue blueviolet
cyan turquoise magenta salmon white );

  # Colour index given
  if ($colour =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Colour index does not exist - must lie between
 1 and 15") if ($colour > 15 || $colour < 1);
    $cindex = $colour;
  } elsif ($colour =~ /[a-z]/) {
    # Now examine other colours and convert known values to indices
    $colour = "grey" if ($colour eq "gray"); # For those who can't spell...
    for my $j (0..scalar(@knowncolours-1)) {
      if ($knowncolours[$j] eq $colour) {
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
    $cindex = 2;
  }
  return $cindex;
}

=item B<_style_to_index>

Translate given line style to PLplot colour index

  $self->_style_to_index( $style );

Since only 4 pens are supported in PLplot, only 4 line styles are
available (out of 8).

=cut

sub _style_to_index {
  my $self = shift;
  my $style = shift;
  my $stindex = 4;

  if ($style =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Line style does not exist - must lie between 1 and 4") 
      if ($style > 4 || $style < 1);
    $stindex = $style;
  } elsif ($style =~ /[a-z]/ ) {
    if ($style eq "solid") {
      $stindex = 1;
    } elsif ($style eq "dot" || $style eq "dotted") {
      $stindex = 2;
    } elsif ($style eq "dash" || $style eq "dashed") {
      $stindex = 3;
    } elsif ($style eq "longdash" || $style eq "ldash") {
      $stindex = 4;
    } else {
      print " Unknown LineStyle - setting style to solid \n";
      $stindex = 1;
    }
  } else {
    throw JAC::StripChart::Error::BadConfig("Invalid string for line style");
  }

  return $stindex;
}

=item B<_sym_to_index>

Translate given plot symbol to PLplot symbol index

  $self->_sym_to_index( $style );

For now, only support basic symbols (circle, square etc). If symbol
index is given directly, then check for valid value and set it to the
given or default value.

PLplot supports specifying any Hershey symbol number by default.

=cut

sub _sym_to_index {
  my $self = shift;
  my $sym = shift;
  my $symindex = 1;

  return;

  # Prefix with `f' to get filled versions
  my %knownsymbols = ( square => '841',
                       dot => '729',
                       plus => '845',
                       asterisk => '847',
                       circle => '840',
                       cross => '846',
                       times => '846',
                       x => '846',
                       triangle => '842',
                       diamond => '843',
                       star => '844',
                       fcircle => '850',
                       fsquare => '851',
                       ftriangle => '852',
                       fstar => '856' );

  if ($sym =~ /\d/) {
    throw JAC::StripChart::Error::BadConfig("Symbol index not defined ")
      if ($sym > 2932 && $sym < 255);
    $symindex = $sym;
  } elsif ($sym =~ /[a-z]/) {
    foreach my $symkey (keys %knownsymbols) {
      $symindex = $knownsymbols{$symkey} if ($symkey eq $sym);
    }
  }

  if ($symindex == 1) {
    warnings::warnif(" Unknown symbol, '$sym': setting to default (+)");
    $symindex = 845;
  }

  return $symindex;
}


=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Andy Gibb E<lt>agg@astro.ubc.caE<gt>


=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research Council and
the University of British Columbia. All Rights Reserved.

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
