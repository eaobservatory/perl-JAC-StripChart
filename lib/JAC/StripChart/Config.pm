package JAC::StripChart::Config;

=head1 NAME

JAC::StripChart::Config - Configure a stripchart

=head1 SYNOPSIS

  use JAC::StripChart::Config;

  $cfg = new JAC::StripChart::Config( $file );

  @charts = $cfg->charts();


=head1 DESCRIPTION



=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::Chart;

use Config::IniFiles;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

my $CHART_PREFIX = "chart";

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

   $cfg = new JAC::StripChart::Config( $file );
   $cfg2 = $cfg->new( $file );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $cfg = bless {
		   FileName => undef,
		   NXY => [],
		   Charts => [],
		  }, $class;

  if (@_) {
    $cfg->filename( $_[0] );
  }

  return $cfg;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of the config file used to configure the stripchart.

=cut

sub filename {
  my $self = shift;
  if (@_) {
    $self->{FileName} = shift;
    $self->read_config();
  }
  return $self->{FileName};
}

=item B<charts>

Configured StripChart objects generated from the config file.

  @charts = $cfg->charts();
  $cfg->charts(@charts);

=cut

sub charts {
  my $self = shift;
  if (@_) {
    # see if we have a hash ref as first arg
    my @charts = (ref($_[0]) eq 'ARRAY'  ? @{$_[0]} : @_);

    # Should add a test for class here
    @{ $self->{Charts} } = @charts;
  }
  return @{ $self->{Charts} };
}

=item B<nxy>

Number of charts in the X- and Y-directions on the main plot
window.

  @nxy = $cfg->nxy;
  $cfg->nxy($nx, $ny);

=cut

sub nxy {
  my $self = shift;
  if (@_) {
    @{ $self->{NXY} } = @_;
  }
  return @{ $self->{NXY} };
}

=back

=head2 General Methods

=over 4

=item B<read_config>

Read and parse the config file specified in the C<filename> attribute.

  $cfg->read_config;

=cut

sub read_config {
  my $self = shift;

  # Get the filename
  my $fname = $self->filename;

  JAC::StripChart::Error::FileNotFound->throw("Config file not defined")
    unless defined $fname;

  JAC::StripChart::Error::FileNotFound->throw("Config file '$fname' does not exist") 
    unless -e $fname;

  # Read the file
  my %data;
  tie %data, 'Config::IniFiles', (-file => $fname);

  # Find the largest chart index
  my @index = map { substr($_,5) } grep /^$CHART_PREFIX(\d+)$/, keys %data;

  # sort the indices
  @index = sort @index;

  use Data::Dumper;
  print Dumper(\@index);

  # get the max index
  my $maxind = $index[-1];

  throw JAC::StripChart::Error::BadConfig("No chart definition located")
    unless defined $maxind;

  throw JAC::StripChart::Error::BadConfig("Possible error in config file. Attempt to plot more than 64 charts (requested $maxind)")
    if $maxind > 64;


  print Dumper($data{globals});

  # Do we have a specified number of plots for display?
  # And do we care if some charts won't be plotted?
  # In the following test we only test for truth or nx and ny
  # value since (1) INI only returns empty strings and not undef
  # and (2) a value of 0 may as well be the same meaning as undef
  # No need for an exists test first in the ini tie
  my ($nx, $ny);
  if (exists $data{globals} &&
    ($data{globals}->{nx} || $data{globals}->{ny}) ) {
    # read both values (even if one may be undefined)
    $nx = $data{globals}->{nx};
    $ny = $data{globals}->{ny};

    # do nothing more if both are true
    unless ($nx && $ny) {
      # at this point we know that either NX or NY is true
      # but not both
      if (!$nx) {
	# no X so derive from Y
	$nx = $maxind / $ny;
	$nx = int($nx) + 1 if  int($nx) != $nx;
      } elsif (!$ny) {
	# no Y so derive from X
	$ny = $maxind / $nx;
	$ny = int($ny) + 1 if  int($ny) != $ny;
      } else {
	croak "This should not happen if previous test worked. Neither nx nor ny are false.";
      }
    }

  } else {
    # we are working this out ourselves
    # KLUGE for now
    $nx = $maxind;
    $ny = 1;
  }

  # Store the number in X and Y
  $self->nxy( $nx, $ny );

  print "NX = $nx   NY = $ny \n";
  print Dumper($self);

  # Get the name of the Sink class to be used. This is in global
  # but defaults to ::Sink.
  my @sinks;
  my $snk_root = "JAC::StripChart::Sink";
  if (exists $data{globals} && $data{globals}->{output_class}) {
    my @classes = $self->_to_array($data{globals}->{output_class});
    @sinks = map { $snk_root . "::" . $_ } @classes;
  } else {
    push(@sinks, $snk_root );
  }

  # preload all the requested Sink classes
  for my $class (@sinks) {
    eval "use $class;";
    JAC::StripChart::Error::BadConfig->throw("Attempt to use data sink of class $class except that class could not be loaded: $@") if $@;
  }


  # Read all the chart information
  my @charts; # Chart objects
  my %cmon;  # Chart monitor id lookup
  my %mkeys; # Stores the number of times a particular monitor is used, keys are the monitor IDs
  for my $i (@index) {

    # Get the chart ID. We assume that the config identifier
    # is the same as the chart class id
    my $chartid = "$CHART_PREFIX$i";

    # Store monitor details for later creation
    # And also store the relevant monitor names for this chart
    my @thischart;

    # Check for data sources
    throw JAC::StripChart::Error::BadConfig("No data source specified in config file")
      unless exists $data{$chartid}->{data};

    for my $m ($self->_to_array($data{$chartid}->{data})) {
      push(@thischart,$m);
      $mkeys{$m}++;
    }

    # Now need to create Chart objects
    # Do it here rather than after monitor object creation
    # in order to save a loop
    push(@charts, new JAC::StripChart::Chart( chartid => $chartid));
    $cmon{$chartid} = \@thischart;

    # Read the sink options from the chart
    my %plotdefn;
    for my $par ( qw| autoscale yscale growt window plottitle | ) {
      next unless exists $data{$chartid}->{$par};
      $plotdefn{$par} = $self->_to_array($data{$chartid}->{$par});
    }

    # and associate the sinks with the chart
    my @snkobj = map { $_->new( %plotdefn ) } @sinks;
    print Dumper(@snkobj);
    $charts[-1]->sinks( @snkobj );

#    print Dumper(@charts);
  }

  # Store charts
  $self->charts( @charts );

  # Create  monitor objects
  my %monitors;
  for my $m (keys %mkeys) {
    throw JAC::StripChart::Error::BadConfig("Request for data stream '$m' but that stream is not specified in config file")
      unless exists $data{$m};

    # Get the class name
    my $class_suffix = $data{$m}->{monitor_class};

    # Form constructor args for monitor object
    my %args;
    for my $k (keys %{$data{$m}}) {
      next if $k eq 'monitor_class';
      my $value = $data{$m}->{$k};
      $value =~ s/\s+$//; # clean
      if ($k =~ /_/) {
	# This is a special filter option
	# use split in case option has multiple underscores
	my ($type, $variant) = split(/_/, $k,2);
	$args{$type}->{$variant} = $value;
      } else {
	$args{$k} = $value;
      }
    }

    # some descriptive id
    $args{monid} = $m;

#    print Dumper(\%args);

    my $class = "JAC::StripChart::Monitor::$class_suffix";
    eval "use $class;";
    JAC::StripChart::Error::BadConfig->throw("Attempt to use monitor of class $class except that class could not be loaded: $@") if $@;
    $monitors{$m} = $class->new( %args );

  }

  # Attach monitors to charts and determine monitor attributes
  # Loop over all charts, and then over all monitors for that chart
  my %attrdefn;
  my %attrargs;
  for my $cht (@charts) {
    my $c = $cht->chartid;

    # Now iterate over each monitor string, attaching it.  Note %cmon
    # has already stored the monitor ids above (key = chartid, values
    # = array of monids).
    my @mon = map { $monitors{$_} } @{ $cmon{$c} };

    # Attach to the chart object
    $cht->monitors( \@mon );

    # Now for the attributes
    for my $par ( qw| symbol linestyle linecol symcol | ) {
      next unless exists $data{$c}->{$par};
      $attrdefn{$par} = $self->_to_array($data{$c}->{$par});

      # Deal with multiple monitors per chart
      if (ref($attrdefn{$par}) eq 'ARRAY') {
	my $nmons = scalar(@{$cmon{$c}});
	# Loop over no of elements in attributes
	for my $mons (1..$nmons) {
	  my @newpair = ($par, @{$attrdefn{$par}}[$mons-1]) ;
	  push( @{ $attrargs{ $self->_genkey($c, $cmon{$c}->[$mons-1])  } }, @newpair);
	}
      } else {
	my @newpair = ($par, $attrdefn{$par}) ;
	push( @{ $attrargs{ $self->_genkey($c, $cmon{$c}->[0]) } }, @newpair);
      }
    }
  }

  # Redefine the anon arrays as anon hashes to set up the attributes
  # args. Using %tmphash makes it a little clearer what's going on
  for my $attrkey (keys %attrargs) {
    my %tmphash = ( ref($attrargs{$attrkey}) eq 'ARRAY' ? @{ $attrargs{$attrkey} } : $attrargs{$attrkey});
    $attrargs{$attrkey} = \%tmphash;

    # Generate attributes object
    my $attrs = new JAC::StripChart::Chart::Attrs(%{ $attrargs{$attrkey} } );
    # Retrieve monitor ID from $attrkey = second (& final) element in array
    my ($chartid, $monidkey) = split(/_/,$attrkey,2);

    # Attach to relevant monitor
    for my $chart (@charts) {
      $chart->monattrs( $monidkey => $attrs ) if ($chartid eq $chart->chartid) ;
      # test by retrieving Attr object
#      my $testobj = $chart->monattrs($monidkey);
#      print Dumper($testobj);
    }

  } # end foreach

}


=item B<_genkey>

Generate a unique private key from the supplied chart configuration.

  $key = $i->_genkey( $chartid, $monid );

=cut

sub _genkey {
  my $self = shift;
  return join("_",@_);
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_to_array>

Convert a line in a config array to a list.

  @contents = $cfg->_to_array( $string );

In scalar context returns the single scalar value if no other
values are determined, else a reference to an array.

=cut

sub _to_array {
  my $self = shift;
  my $str = shift;
  return () unless defined $str;

  my @vals;
  if (ref($str)) {
    @vals = @$str;
  } else {
    @vals = split(/,/, $str);
  }

  if (wantarray) {
    return @vals;
  } else {
    if (@vals == 1) {
      return $vals[0];
    } else {
      return \@vals;
    }
  }
}


=back

=end __PRIVATE_METHODS__

=head1 FORMAT

The file format for StripChart configuration is based on the INI
file format.

Global parameters for all plots can be set in the "globals" section.
Currently, it is assumed that all plots should appear on all specified
plot devices. This is a simplification that is not present in the 
strip chart system itself.

  [globals]
  nx=10
  ny=2
  output_class=AST::PGPLOT,PLplot

Each chart is configured and data sources specified.

  [chart1]
  yautoscale=1
  yunits=Jy
  growt=1
  window=3600
  data=fcf850,fcf850db,fcf450

  [chart2]
  yautoscale=1
  yscale=0,1.5
  yunits=Jy
  growt=1
  window=4800
  data=fcf850,fcf850db,fcf450

Data sources are specified in their own sections. The labels
are used by charts.

  [fcf450]
  monitor_class=ORACIndex
  indexfile=index.fcf

  [fcf850]
  monitor_class=ORACIndex
  indexfile=index.fcf
  column=GAIN
  filter_UNITS=ARCSEC
  filter_FILTER=850W

  [fcf850db]
  monitor_class=ORACDB
  table=scuba_fcf
  column=GAIN
  filter_UNITS=ARCSEC
  filter_FILTER=850W

  [wvm]
  monitor_class=EPICSCA
  location=.WVM

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

L<JAC::StripChart>

=cut

1;

