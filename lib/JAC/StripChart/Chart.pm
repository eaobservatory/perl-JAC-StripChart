package JAC::StripChart::Chart;

=head1 NAME

JAC::StripChart::Chart - A single stripchart

=head1 SYNOPSIS

  use JAC::StripChart::Chart;

  $chart = new JAC::StripChart::Chart( chartid => 2 );

  @monitors = $chart->monitors;
  @sinks    = $chart->sinks;

=head1 DESCRIPTION

This object represents a single stripchart. These objects are usually
created from a configuration file (see C<JAC::StripChart::Config>).


=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::Chart::Attrs;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

   $cfg = new JAC::StripChart::Chart( monitors => \@mon );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $chart = bless {
		     Monitors => [],
		     MonAttrs => {},
		     Sinks => [],
		     ID => undef,
		    }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| monitors chartid |) {
      $chart->$k($args{$k}) if exists $args{$k};
    }
  }

  return $chart;
}

=back

=head2 Accessor Methods

=over 4

=item B<column>

Chart ID associated with this strip chart. Should be a unique
string. Generally includes an integer suffix.

=cut

sub chartid {
  my $self = shift;
  if (@_) {
    $self->{ID} = shift;
  }
  return $self->{ID};
}

=item B<monitors>

Data monitors associated with this strip chart.

  @monitors = $chart->monitors;
  $chart->monitors(@monitors);

=cut

sub monitors {
  my $self = shift;
  if (@_) {
    # see if we have an array ref as first arg
    my @monitors = (ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_);

    # Should add a test for class here
    # (or at least make sure the getData method is there)
    @{ $self->{Monitors} } = @monitors;
  }
  return @{ $self->{Monitors} };
}

=item B<monattrs>

Plot attributes associated with each monitor. This controls
whether symbols and/or lines should be plotted and the color of the
lines/symbols. Not all plot devices support all attributes.

  $monattr = $chart->monattrs( $monid );
  $chart->monattrs( $monid => $monattr, $monid2 => $monattr2 );

  %monattr = $chart->monattrs();

A hash indexed by monitor ID, returning a C<JAC::StripChart::Chart::Attrs>
object.

If the specified monitor does not have a corresponding attribute
object, a new one is created automatically.

=cut

sub monattrs {
  my $self = shift;
  if (@_) {
    my $monid = shift;

    if (@_) {
      # store
      my $attr = shift;
      throw JAC::StripChart::Error::BadClass("Supplied attribute not of class JAC::StripChart::Chart::Attrs")
	unless UNIVERSAL::isa( $attr, "JAC::StripChart::Chart::Attrs");
      $self->{MonAttrs}->{$monid} = $attr;
    } else {
      # retrieval
      if (exists $self->{MonAttrs}->{$monid}) {
	return $self->{MonAttrs}->{$monid};
      } else {
	$self->{MonAttrs}->{$monid} = new JAC::StripChart::Chart::Attrs();
	return $self->{MonAttrs}->{$monid};
      }
    }
    return;
  } else {
    return %{ $self->{MonAttrs} };
 }
}


=item B<sinks>

These are the data sinks which will receive data from the data monitors.

  @sinks = $chart->sinks;
  $chart->sinks( @sinks );

If there is more than one sink, the same contents will appear on
multiple charts.

=cut

sub sinks {
  my $self = shift;
  if (@_) {
    # see if we have a hash ref as first arg
    my @sinks = (ref($_[0]) eq 'ARRAY' ? @{$_[0]} : @_);

    # Should add a test for class here
    # (or at least make sure the putData method is there)
    @{ $self->{Sinks} } = @sinks;
  }
  return @{ $self->{Sinks} };
}

=back

=head2 General Methods

=over 4

=item B<posn>

In some cases a chart should be placed in a specific position
in the output device rather than filling the output device (although
that is not always supported).

This method returns a position index to be interpreted by the device
driver.

Returns 0 if no specific position is available.

=cut

sub posn {
  my $self = shift;
  my $id = $self->chartid;
  if ($id =~ /(\d+)$/) {
    return $1;
  } else {
    return 0;
  }
}

=item B<update>

Queries the monitor to see if new data have arrived, and if it has,
forwards that data to the data sinks for plotting.

=cut

sub update {
  my $self = shift;

  # loop over all the monitors looking for data
  for my $m ($self->monitors) {

    my @newdata = $m->getData( $self->chartid );
    next unless @newdata;

    # and plot that data on each sink
    for my $s ($self->sinks) {
      $s->putData( $self->chartid, $m->monid,
		   $self->monattrs( $m->monid ),
		   @newdata );
    }
  }
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

L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
