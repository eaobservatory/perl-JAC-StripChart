package JAC::StripChart::Sink;

=head1 NAME

JAC::StripChart::Sink - Base class for all data sinks

=head1 SYNOPSIS

  use JAC::StripChart::Sink;

  my $plot = new JAC::StripChart::Sink( device => $dev
                                        window => 3600,
                                        growt => 1,
                                       );


=head1 DESCRIPTION

This class handles the display of strip charts using a specified plot device.
This base class will not actually plot anything since it does not know how
to draw lines. New data will be sent to STDOUT. The base class simply
controls the parts of the class that are device independent.

=cut


use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::TimeMap;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new plot object.

   $plt = new JAC::StripChart::Sink( device => $dev );

The object can be configured by using keys matching accessor methods.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $snk = bless {
		   Device => undef,
		   DeviceType => undef,
		   GrowT => 1,
		   AutoScale => 1,
		   Yscale => [0,1],
		   Yunits => ' ',
		   Window => 0,
		   PlotTitle => ' ',
		   Attr => ' ',
		   Output => 'unit',
		   TimeMap => new JAC::StripChart::TimeMap,
		  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| device growt window autoscale yscale yunits plottitle output |) {
      $snk->$k($args{$k}) if exists $args{$k};
    }
  }

  return $snk;
}

=back

=head2 Accessor Methods

=over 4

=item B<device>

This attribute provides access to the underlying C<JAC::StripChart::Device>
that is to be used for plotting. In general, the Device class and the Sink
class should match but this is not always necessary if, for example, an
abstraction plot interface such as AST is used for the Sink.

=cut

sub device {
  my $self = shift;
  if (@_) { $self->{Device} = shift; }
  return $self->{Device};
}

=item B<device_class>

This is the device class that has been requested by the sink
to receive the plot data. If the C<device> attribute is defined
it simply returns the class of the actual registered device.

If a device has not been registered it will return the name of the
requested class.  An empty string indicates that no plot device is
required (only the base class).

This method is used by C<JAC::StripChart> in order to configure the
plots correctly.

=cut

sub device_class {
  my $self = shift;
  my $device = $self->device;

  if ($device) {
    return ref($device);
  } elsif (@_) {
    $self->{DeviceClass} = shift;
  } elsif (defined $self->{DeviceClass}) {
    return $self->{DeviceClass};
  } else {
    return $self->_default_dev_class;
  }
}

=item B<timemap>

Map class used to convert the raw MJD times to the correct output format.
Must be a C<JAC::StripChart::TimeMap> object.

=cut

sub timemap {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    throw JAC::StripChart::Error::BadClass("Supplied argument not of class JAC::StripChart::TimeMap")
	  unless UNIVERSAL::isa( $arg, "JAC::StripChart::TimeMap");
    $self->{TimeMap} = $arg;
  }
  return $self->{TimeMap};
}

=item B<growt>

A boolean inndicating whether the extent of the strip chart should
grow as more data are plotted, or it should be a fixed moving
window. If false, the C<window> method controls the size of the moving
window.

=cut

sub growt {
  my $self = shift;
  if (@_) { $self->{GrowT} = shift; }
  return $self->{GrowT};
}

=item B<window>

Size of the moving window for the strip chart, in hours. Only used
if C<growt> is false.

=cut

sub window {
  my $self = shift;
  if (@_) { $self->{Window} = shift; }
  return $self->{Window};
}

=item B<plottitle>

Plot title for the strip chart.

=cut

sub plottitle {
  my $self = shift;
  if (@_) { $self->{PlotTitle} = shift; }
  return $self->{PlotTitle};
}

=item B<output>

Set the output time axis units for the chart.

=cut

sub output {
  my $self = shift;
  if (@_) { $self->{Output} = shift; }
  return $self->{Output};
}


=item B<autoscale>

A boolean indicating whether the Y axis should autoscale (true) or
whether it should be a fixed size.

=cut

sub autoscale {
  my $self = shift;
  if (@_) { $self->{Autoscale} = shift; }
  return $self->{Autoscale};
}

=item B<yscale>

The min and max limits for the Y axis. Only used if C<autoscale>
is false.

  ($min, $max ) = $snk->yscale;
  $snk->yscale( $min, $max );

=cut

sub yscale {
  my $self = shift;
  if (@_) {
    my @yl = (ref($_[0]) ? @{ $_[0] } : @_ );
    @{ $self->{Yscale} } = @yl;
  }
  return @{ $self->{Yscale} };
}


=item B<yunits>

The units for the Y axis. 

  $yunits = $snk->yunits;

  $snk->yunits( $yunits );

=cut

sub yunits {
  my $self = shift;
  if (@_) {
    my $yunits = shift;
    $self->{Yunits} = $yunits;
  }
  return $self->{Yunits};
}

=item B<attr>

Store the monitor attributes indexed by monitor ID

  $snk->attr( %attr ); # Stores the attributes

Retrieve attribute object for given $monid

  $attr = $snk->attr( $monid );

Return all monitor ID/attribute pairs:

  %attr = $snk->attr();

=cut

sub attr {
  my $self = shift;
  # Check if arguments are passed and whether they are a single mon ID
  # or a hash to store
  if (@_) {
    if (scalar(@_) ==  1) {
      my $monid = shift;
      # retrieval
      return $self->{MonAttrs}->{$monid};
    } else {
      my %attrs = @_;
      foreach my $monid (keys %attrs) {
	my $attr = $attrs{$monid};
	throw JAC::StripChart::Error::BadClass("Supplied attribute not of class JAC::StripChart::Chart::Attrs")
	  unless UNIVERSAL::isa( $attr, "JAC::StripChart::Chart::Attrs");
	$self->{MonAttrs}->{$monid} = $attr;
      }
    }
    return;
  } else {
    return %{ $self->{MonAttrs} };
 }

}

=item B<monitor_ids>

Return an array containing the monitor IDs for the current plot

  @monitorids = $self->monitor_ids;

=cut

sub monitor_ids {
  my $self = shift;
  my %attr = $self->attr;
  return (keys %attr);
}

=back

=head2 General Methods

=over 4

=item B<init>

Runs any code required to initialise the sink. Should be given
the attribute objects configured for each monitor serviced by this
sink.

  $snk->init( %attrs );

=cut

sub init {
  my $self = shift;
  return;
}

=item B<putData>

Place data into the sink.  The method in the base class simply
forwards the data to STDOUT.

  $snk->putData( $chartid, $monid, $attrs, @data );

=cut

sub putData {
  my $self = shift;
  my ($chartid, $monid, $attrs, @data ) = @_;

  print "# Data trigger for Chart $chartid Monitor $monid\n";
  print map { join("  \t", $_->[0],$_->[1] ), "\n"; }  @data;
}

=back

=head2 Protected Methods

These are private methods that should be overridden by subclasses.
They are not part of the public API.

=over 4

=item B<_default_dev_class>

This value overrides the behaviour of the C<device_class> method
for subclasses.

=cut

sub _default_dev_class {
  return '';
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



