package JAC::StripChart::Config;

=head1 NAME

JAC::StripChart::Config - Configure a stripchart

=head1 SYNOPSIS

  use JAC::StripChart::Config;

  $cfg = new JAC::StripChart::Config( $file );

  @plots = $cfg->plots();


=head1 DESCRIPTION



=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use Config::IniFiles;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

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
  my @index = map { substr($_,5) } grep /^chart(\d+)$/, keys %data;

  # sort the indices
  @index = sort @index;

  use Data::Dumper;
  print Dumper(\@index);

  # get the max index
  my $maxind = $index[-1];

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
    $nx = $data{globals}->{nx};
    $ny = $data{globals}->{ny};

    if (!$nx) {
      $nx = $maxind / $ny;
      $nx = int($nx) + 1 if  int($nx) != $nx;
    } elsif (!$ny) {
      $ny = $maxind / $nx;
      $ny = int($ny) + 1 if  int($ny) != $ny;
    } else {
      croak "This should not happen if previous test worked. Neither nx nor ny are true";
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

  # Read all the chart information
  my @charts;
  my %mkeys;
  for my $i (@index) {

    # parse plot information
    print "Found chart $i\n";

    # Now need to create Chart objects

    # Store monitor details for later creation
    for my $m (split(/,/, $data{"chart$i"}->{data})) {
      $mkeys{$m}++;
    }
  }


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
      if ($k =~ /^(\w+)_(\w+)$/) {
	# This is a special filter option
	$args{$1}->{$2} = $data{$m}->{$k};
      } else {
	$args{$k} = $data{$m}->{$k};
      }
    }

    print Dumper(\%args);

    my $class = "JAC::StripChart::Monitor::$class_suffix";
    eval "use $class;";
    JAC::StripChart::Error::BadConfig->throw("Attempt to use monitor of class $class except that class could not be loaded: $@") if $@;

    $monitors{$m} = $class->new( %args );


  }


  # Store charts
#  $self->charts( @charts );

}


=back

=head1 FORMAT

The file format for StripChart configuration is based on the INI
file format.

  [global]
  nx=10
  ny=2

  [plot1]
  yautoscale=1
  yscale=[min,max]
  yunits=Jy
  xscale=window|auto
  xwindow=56 [minutes]
  xminstart=-24
  data=fcf850,fcf850db,fcf450

  [plot2]
  yautoscale=1
  yscale=[min,max]
  yunits=Jy
  xscale=window|auto
  xwindow=56 [minutes]
  xminstart=-24
  data=fcf850,fcf850db,fcf450

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

L<JAC::StripChart>

=cut

1;

