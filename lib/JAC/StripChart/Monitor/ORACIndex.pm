package JAC::StripChart::Monitor::ORACIndex;

=head1 NAME

JAC::StripChart::Monitor::ORACIndex - Configure a stripchart ORAC-DR monitor

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::ORACIndex;

  $cfg = new JAC::StripChart::Monitor::ORACIndex( indexfile => $file );

=head1 DESCRIPTION

This class is used for monitoring ORAC-DR index files.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::Monitor::ORACIndexFile;

use JCMT::Tau;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

 $cfg = new JAC::StripChart::Monitor::ORACIndex( indexfile => $file );

Takes a hash argument with keys:

  indexfile => name of the ORAC-DR indexfile.
               If no path, assumes $ORAC_DATA_OUT

  column    => Column name of interest for this data monitor

  filter    => Filter parameters for valid data.
               Reference to a hash containing valid column names
               as keys.
  cvtsub    => name of a subroutine to call to process data

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
		   MonID => '',
		   IndexObject => undef,
		   Column => undef,
		   Filter => {},
		  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| monid indexfile column filter cvtsub|) {
      $mon->$k($args{$k}) if exists $args{$k};
    }
  }

  return $mon;
}

=back

=head2 Accessor Methods

=over 4

=item B<monid>

String that can be used to describe the monitor (eg as a plot legend).

=cut

sub monid {
  my $self = shift;
  if (@_) {
    $self->{MonID} = shift;
  }
  return $self->{MonID};
}

=item B<indexfile>

Name of the ORAC-DR index file used as the data source for this
monitor.

Returns undef if no index file has yet been stored.

=cut

sub indexfile {
  my $self = shift;
  if (@_) {
    my $file = shift;
    $self->index( new JAC::StripChart::Monitor::ORACIndexFile( $file ) )
  }
  return (defined $self->index ? $self->index->indexfile : undef);
}

=item B<index>

The underlying Monitor::IndexFile object associated with this
object.

=cut

sub index {
  my $self = shift;
  if (@_) {
    # Check class
    my $obj = shift;
    throw JAC::StripChart::Error::BadArgs("Supplied object to method 'index' must be of class 'JAC::StripChart::Monitor::ORACIndexFile' but was class '".ref($obj)."'")
      unless UNIVERSAL::isa($obj, "JAC::StripChart::Monitor::ORACIndexFile");
    $self->{IndexObject} = $obj;

  }
  return $self->{IndexObject};
}

=item B<column>

Column name of interest for this monitor.

=cut

sub column {
  my $self = shift;
  if (@_) {
    $self->{Column} = shift;
  }
  return $self->{Column};
}

=item B<filter>

Column names (and values) that should be to filter the
content in the data source.

  %filter = $mon->filter;

  $mon->filter( %filter );
  $mon->filter( \%filter );

=cut

sub filter {
  my $self = shift;
  if (@_) {
    # see if we have a hash ref as first arg
    my %filter;
    if (ref($_[0])) {
      %filter = %{$_[0]};
    } else {
      %filter = @_;
    }
    %{ $self->{Filter} } = %filter;
  }
  return %{ $self->{Filter} };
}

=item B<cvtsub>

Name of the subroutine to be called to post-process data returned by the
monitor before it is returned to the plot system.

 $cfg->cvtsub( "cvt_to_something" );
 $cfg->cvtsub( \&convert );

Can be a code ref.

Converted to a code ref on return.

=cut

sub cvtsub {
  my $self = shift;
  if (@_) {
    my $sub = shift;
    my $cvtref;
    if (ref($sub) eq 'CODE') {
      $cvtref = $sub;
    } else {
      my $pkg = 'JAC::StripChart::Monitor::ORACIndex::CVTSUB';
      my $cvtsub = $pkg . "::$sub";
      $cvtref = eval '\&'.$cvtsub;

      # test it
      eval '$cvtref->(0.5)';
      if ($@) {
	warnings::warnif("Undefined convert subroutine $sub. Ignoring it");
	$cvtref = undef;
      }
    }
    # store it
    $self->{CVTSUB} = $cvtref;
  }
  return $self->{CVTSUB};
}

=back

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the index file since the
last time we were asked for data.

  @newdata = $mon->getData( $id );

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2".

@newdata contains a sorted list where each entry is a reference to a 2
element array. First element is the time in MJD.

=cut

sub getData {
  my $self = shift;
  my $id = shift;
  my @data = $self->index->getData( $id, $self->column, $self->filter );

  # return if no data
  return () unless @data;

  # conversion
  my $cvtsub = $self->cvtsub;
  return @data unless $cvtsub;

  # process the data
  for my $d (@data) {
    my $val = $cvtsub->( $d->[1] );
    $d->[1] = $val if defined $val;
  }

  return @data;
}

=back

=head2 Conversion Subroutines

The following subroutines can be specified in the configuration
file to force the data returned by the monitor to be processed before
it is plotted.

Currently, the conversion is not taken into account when determining
the unique monitor name so if two monitors are configured identically
except that one is converting and the other isn't they will steal each
others data. This will be fixed if it becomes a problem.

=cut

# Private package namespace
package JAC::StripChart::Monitor::ORACIndex::CVTSUB;

=over 4

=item B<skydip850_to_225>

Used to convert 850 skydip tau to 225 GHz tau.

=cut

sub skydip850_to_225 {
  my $input = shift;
  return unless defined $input;
  my ($tau, $status) = JCMT::Tau::get_tau( 'CSO', '850W', $input);
  return ($status == 0 ? $tau : undef );
}


=item B<skydip450_to_225>

Used to convert 450 skydip tau to 225 GHz tau.

=cut

sub skydip450_to_225 {
  my $input = shift;
  return unless defined $input;
  my ($tau, $status) = JCMT::Tau::get_tau( 'CSO', '450W', $input);
  return ($status == 0 ? $tau : undef );
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

L<JAC::StripChart>, L<JAC::StripChart::Monitor::ORACIndexFile>.

=cut

1;

