package JAC::StripChart::Monitor::WVM;

=head1 NAME

JAC::StripChart::Monitor::WVM - Water Vapor Monitor

=head1 SYNOPSIS

 use JAC::StripChart::Monitor::WVM;


 $mon = new JAC::StripChart::Monitor::WVM();

=head1 DESCRIPTION

Real time WVM data.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JCMT::Tau::WVM;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::TimeZone;
use JAC::StripChart::Error;

use vars qw/ $VERSION $USE_SIMPLE /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

$USE_SIMPLE = 0;

# Cache UTC timezone until JCMT::Tau::WVM module can be taught
# to retain the DateTime object
my $UTC;
BEGIN {
  $UTC = new DateTime::TimeZone( name => 'UTC' );
}

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

 $cfg = new JAC::StripChart::Monitor::WVM();

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
                   MonID => '',
		   LastRead => {},
                  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| monid |) {
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

=item B<last_read>

Date WVM file was last read for a given chart id. C<undef> indicates
that we should start from the UT start.

  $last = $mon->last_read( $chartid );
  $mon->last_read( $chartid, $dt );

Stored as a DateTime object for convenience.

=cut

sub last_read {
  my $self = shift;
  my $chartid = shift;
  croak "Must define chartID to obtain last read status\n"
    unless defined $chartid;

  if (@_) {
    $self->{LastRead}->{$chartid} = shift;
  }
  return $self->{LastRead}->{$chartid};
}

=back

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the index file since the
last time we were asked for data.

  @newdata = $mon->getData( $id );

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2". This id allows the monitor
to cache values for different charts without re-reading the input
stream.

@newdata contains a sorted list where each entry is a reference to a 2
element array. First element is the time in MJD.

=cut

sub getData {
  my $self = shift;
  my $id = shift;

  # Simple read current value only
  if ($USE_SIMPLE) {
    # simple technique first. Just read the value from the single
    # line file that has the most recent data point. We will miss points
    # but for testing it doesn't matter. Correct solution is to read
    # into a JCMT::Tau::WVM object
    my $file = "/jcmtdata/raw/wvm/wvm.dat";

    # no data available if no file
    open my $fh, "<$file" or return ();

    my $line = <$fh>;
    return () unless $line;
    my ($ut, $tau) = split(/\s+/,$line);
    return () unless defined $tau;
    return () unless $ut;

    my $dt = eval { DateTime::Format::ISO8601->parse_datetime( $ut ); };
    return () unless defined $dt;

    return [ $dt->mjd, $tau];

  } else {
    # Proper system

    # get time last read (for this chart)
    my $last = $self->last_read($id);

    # if undefined, start at the day boundary
    my $now = DateTime->now( time_zone => $UTC );
    if (!defined $last) {
      $last = DateTime->new( year => $now->year,
			     month => $now->month,
			     day => $now->day,
			     time_zone => $UTC,
			   );
    }

    # Read the WVM
    my $wvm = new JCMT::Tau::WVM( Start_Time => $last,
				  End_Time => $now,
				);

    $self->last_read( $id, $now );

    return () unless defined $wvm;

    my $data = $wvm->data;
    my @data;
    for my $w (sort keys %$data) {
      my $mjd = DateTime->from_epoch( epoch => $w, time_zone => $UTC )->mjd;
      push(@data, [ $mjd, $data->{$w}]);
    }

    return @data;
  }

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
