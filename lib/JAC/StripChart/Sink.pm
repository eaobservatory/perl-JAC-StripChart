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

This class handles the display of strip charts using a specified plot
device.  This base class will not actually plot anything since it does
not know how to draw lines. New data will be sent to STDOUT. The base
class simply controls the parts of the class that are device
independent, such as the plot attributes.

=cut


use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use Scalar::Util qw/ looks_like_number /;
use JAC::StripChart::Error;
use JAC::StripChart::TimeMap;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

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
       Ylabel => 'Flux',
		   Window => 0,
		   PlotTitle => ' ',
		   Attr => ' ',
		   Tunits => 'unit',
       OutputTimeScale => "UTC",
		   TimeMap => new JAC::StripChart::TimeMap,
		   Updated => 0,
		  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| device growt window autoscale yscale yunits ylabel
                   timescale plottitle tunits |) {
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

=item B<updated>

True if the plot attributes (e.g. growt(), autoscale()) have been
modified. The attribute is set to true automatically when a relevant
plot attribute is modified. It can be used by a Sink to decide whether
a full refresh of a plot is required (but remember to set it to false
after the plot has been refreshed).

=cut

sub updated {
  my $self = shift;
  if (@_) {
    $self->{Updated} = shift;
  }
  return $self->{Updated};
}

=item B<growt>

A boolean inndicating whether the extent of the strip chart should
grow as more data are plotted, or it should be a fixed moving
window. If false, the C<window> method controls the size of the moving
window.

Sets the updated() flag on update.

=cut

sub growt {
  my $self = shift;
  if (@_) {
    $self->_set_and_check_update_flag( "GrowT", shift );
  }
  return $self->{GrowT};
}

=item B<window>

Size of the moving window for the strip chart, in hours. If C<growt>
is false, this value is used as the default (minimum) width for the plot.
Must be greater than 0.

Sets the updated() flag on update.

=cut

sub window {
  my $self = shift;
  if (@_) {
    my $val = shift;
    if ($val && looks_like_number($val) && $val > 0) {
      $self->_set_and_check_update_flag( "Window", $val );
    }
  }
  return $self->{Window};
}

=item B<autoscale>

A boolean indicating whether the Y axis should autoscale (true) or
whether it should be a fixed size.

Sets the updated() flag on update.

=cut

sub autoscale {
  my $self = shift;
  if (@_) { 
    $self->_set_and_check_update_flag( "Autoscale", shift );
  }
  return $self->{Autoscale};
}

=item B<yscale>

The min and max limits for the Y axis. Only used if C<autoscale>
is false. Only accepts numbers.

  ($min, $max ) = $snk->yscale;
  $snk->yscale( $min, $max );

Sets the updated() flag on update.

=cut

sub yscale {
  my $self = shift;
  if (@_) {
    my @yl = (ref($_[0]) ? @{ $_[0] } : @_ );

    # need to see if we are updating
    for my $i ( 0 .. $#yl ) {
      $yl[$i] = 0 if !defined $yl[$i];
      $yl[$i] = $self->{Yscale}->[$i]
	unless looks_like_number($yl[$i]);
      if ($self->{Yscale}->[$i] != $yl[$i]) {
	$self->updated( 1 );
	last;
      }
    }

    @{ $self->{Yscale} } = @yl;
  }
  return @{ $self->{Yscale} };
}

=item B<plottitle>

Plot title for the strip chart.

=cut

sub plottitle {
  my $self = shift;
  if (@_) { $self->{PlotTitle} = shift; }
  return $self->{PlotTitle};
}

=item B<tunits>

Set the output time axis units for the chart.

=cut

sub tunits {
  my $self = shift;
  if (@_) {
    $self->{Tunits} = shift;
  }
  return $self->{Tunits};
}

=item B<timescale>

Set the timescale for the display of the output time axis. Defaults
to UTC. Not supported by all sinks. Only used for display. Does
not affect the MJD values themselves which are assumed to be UTC
on input.

Allowed values are those expected by AST.

=cut

sub timescale {
  my $self = shift;
  if (@_) {
    $self->{OutputTimeScale} = shift;
  }
  return $self->{OutputTimeScale};
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

=item B<ylabel>

The label for the Y axis.

  $ylab = $snk->label;
  $snk->ylabel( $ylab );

=cut

sub ylabel {
  my $self = shift;
  if (@_) {
    my $ylabel = shift;
    $self->{Ylabel} = $ylabel;
  }
  return $self->{Ylabel};
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

If the updated() method is true, this method can be called by the
update() loop even if no data are provided. This method should clear
the updated() flag.

=cut

sub putData {
  my $self = shift;
  my ($chartid, $monid, $attrs, @data ) = @_;

  # clear the updated flag
  $self->updated( 0 );

  # return without action if we have no data
  return unless @data;

  print "# Data trigger for Chart $chartid Monitor $monid\n";
  @data = $self->timemap->do_map( @data );
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

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_set_and_check_update_flag>

Store the value using the supplied internal object key and if the
value is different, set the updated() attribute to true.

  $snk->_set_and_check_update_flag( $key, $newvalue );

If the new value is undef, it will be ignored.

=cut

sub _set_and_check_update_flag {
  my $self = shift;
  my $key = shift;
  my $newval = shift;
  return unless defined $newval;

  my $oldval = $self->{$key};

  my $doupdate;
  if (defined $oldval) {
    $doupdate = 1 if $oldval != $newval;
  } else {
    $doupdate = 1;
  }

  if ($doupdate) {
    $self->{$key} = $newval;
    $self->updated( 1 );
  }

  return;
}

=back

=item B<_update_line_colours>

Checks the line colours that have been set and sorts out any
duplicates to avoid coinfusing plots. Must take a hash of attribute
objects indexed by monitor ID.

  $snk->_update_line_colours( %attrs );

Will leave colours unchanged if called with no argument.

=cut

sub _update_line_colours {
  my $self = shift;
  my %attrs;

  if (@_) {
    %attrs = @_;
  } else {
   warnings::warnif("No attributes supplied - will not check and update colours "); 
   return;
  }

  use Data::Dumper;

  # Loop over the monitors to check for identical line colours
  my %colourcount;
  my %moncols; 
  foreach my $monid (keys %attrs) {
    $moncols{$monid} = $self->_colour_to_index($attrs{$monid}->linecol);
  }
  # Now determine how many of each colour there are
  foreach my $col (values %moncols) {
    my $i = ( (defined $colourcount{$col}) ? $colourcount{$col} : 1);
    $i++ if ($colourcount{$col});
    $colourcount{$col} = $i;
  }
  # Now find unused colours
  my @uncols;
  # KLUDGE: hard-wired number of colour indices
  my $colour = 0;
  foreach my $cindex (1..15) {
    foreach my $monid (keys %moncols) {
      # Check if colour index exists in hash else add it to list of unused colours
      $colour = 1 if (exists $colourcount{$cindex});
    }
    push (@uncols, $cindex) unless ($colour);
    $colour = 0;
  }

  # Now check for those that occur more than once and
  # set line colour attributes to new values
  foreach my $monid (keys %attrs) {
    if ($colourcount{$moncols{$monid}} > 1) {
      $attrs{$monid}->linecol($uncols[0]); # Set linecol attribute
      shift @uncols; # this colour is now used so remove it from @uncols
      $colourcount{$moncols{$monid}}--; # reduce count for that colour
    }
  }

  return;

}

=back

=end __PRIVATE_METHODS__

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



