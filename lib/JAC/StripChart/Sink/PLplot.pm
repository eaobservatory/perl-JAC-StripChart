package JAC::StripChart::Sink::PLplot;

=head1 NAME

JAC::StripChart::Sink::PLplot - PLplot standard stripchart

=head1 SYNOPSIS

  use JAC::StripChart::Sink::PLplot;

  my $snk = new JAC::StripChart::Sink::PLplot( device => $dev );

=head1 DESCRIPTION

This class handles the display of strip charts using PLplot.  It does
not need to know about sources of data or how to create a display
device. It only needs to know how to plot the data being sent to it on
the device that is registered with it.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use Graphics::PLplot;

use base qw| JAC::StripChart::Sink |;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);


=head1 METHODS

Methods are inherited from C<JAC::StripChart::Sink>.

=head2 Local Accessors

=over 4

=item B<stripid>

PLplot stripchart ID associated with this stripchart.

=cut

sub stripid {
  my $self = shift;
  if (@_) { $self->{PLPLOT_STRIPID} = shift; }
  return $self->{PLPLOT_STRIPID};
}

=item B<penid>

Returns the pen number corresponding to a particular monitor.

 %pens = $snk->penid;
  $pen = $snk->penid( $monid );
  $snk->penid( %pens );

=cut

sub penid {
  my $self = shift;
  if (@_) {
    if (scalar(@_) == 1) {
      my $monid = shift;
      return $self->{PENID}->{$monid};
    } else {
      %{ $self->{PENID} } = @_;
    }
  } else {
    return %{ $self->{PENID} };
  }
}

=back

=head2 General Methods

=over 4

=item B<init>

Initialise the PLplot stripchart subsystem.

  $snk->init( %attrs  );

Expects to receive the chart attributes for all the monitors
serviced by this sink, as a hash with keys corresponding to
the monitor label.

=cut

sub init {
  my $self = shift;
  my %attrs = @_;

  # Select the correct PLplot device
  $self->device->select();

  # create a stripchart

  # Number of pens
  my $npen = scalar(keys %attrs);

  # Maximum of 4 pens
  if ($npen > 4) {
    warnings::warnif("Can only support 4 pens, not $npen");
    $npen = 4;
  }

  # We need to specify color for each pen [should use Attrs]
  my $colbox = 1;
  my $collab = 3;

  my @colline = (2..($npen+1));  # color of lines
  my @styline = @colline;   # linestyle
  my @legline = keys %attrs;

  # Create a hash indexed by monitor id so that we can associated
  # particular pen with a particular monitor
  my $i = 0;
  my %pen = map { $_ =>  ++$i } keys %attrs;
  $self->penid( %pen );

  # pad
  for my $i (($#colline+1)..3) {
    $colline[$i] = 5;
    $styline[$i] = $colline[$i];
    $legline[$i] = '';
  }

  # legend position
  my $xlab = 0.7;
  my $ylab = 0.9;

  my $tmin = 0;
  my $tmax = 1;
  my $ymin = 0;
  my $ymax = 10;
  my $tjump = 0.1;

  my $autoy = 1;  # autoscale y
  my $acc = 1;    # don't scrip, accumulate

  # now initialise the strip chart
  my $id = plstripc( "bcnst", "bcnstv", $tmin, $tmax,
                     $tjump, $ymin, $ymax,
                     $xlab, $ylab,
                     $autoy, $acc,
                     $colbox, $collab,
                     \@colline, \@styline, \@legline,
                     "t", "", "Strip chart title goes here");

  $self->stripid( $id );

}

=item B<putData>

Plot the data on the registered device using AST as the plotting engine.

  $snk->putData( $chartid, $monid, $attr, @data );

=cut

sub putData {
  my $self = shift;
  my ($chartid, $monid, $attr, @data ) = @_;

  # We should cache the data in case we are asked to reset the display

  # Select the correct device
  $self->device->select;

  my $pen = $self->penid( $monid );
  my $id  = $self->stripid();
  return unless $pen;

  for my $xy (@data) {
    $id->plstripa( $pen, $xy->[0], $xy->[1]);
  }

}

=back

=head2 Private Methods

=over 4

=item B<_default_dev_class>

The default plotting device.

=cut

sub _default_dev_class {
  return "PLplot";
}

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

L<JAC::StripChart::Sink>, L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
