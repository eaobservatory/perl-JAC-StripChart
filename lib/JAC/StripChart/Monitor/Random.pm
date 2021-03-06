package JAC::StripChart::Monitor::Random;

=head1 NAME

JAC::StripChart::Monitor::Random - Random number generator for stripchart

=head1 SYNOPSIS

 use JAC::StripChart::Monitor::Random;


 $mon = new JAC::StripChart::Monitor::Random( randmin => 5,
                                              randmax => 20);


=head1 DESCRIPTION

A source of data for stripchart testing that uses a random number generator
to return a single data point for each poll, for the current time.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use DateTime;
use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = 1.0;


=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

 $cfg = new JAC::StripChart::Monitor::Random( randmin => -2 );

Takes a hash argument with keys:

 randmin => Lowest data value to return
 randmax => Highest data value to return

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
                   MonID => '',
		   DataMin => 0,
		   DataMax => 1,
                  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| monid randmin randmax |) {
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

=item B<randmin>

Smallest random value to return.

=cut

sub randmin {
  my $self = shift;
  if (@_) {
    $self->{DataMin} = shift;
  }
  return $self->{DataMin};
}

=item B<randmax>

Largest random value to return.

=cut

sub randmax {
  my $self = shift;
  if (@_) {
    $self->{DataMax} = shift;
  }
  return $self->{DataMax};
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

  my $randmax = $self->randmax;
  my $randmin = $self->randmin;

  # get the value
  my $r = rand();
  my $val = ($randmax - $randmin) * $r + $randmin;

  # get the current MJD
  my $mjd = DateTime->now->mjd;

  return [ $mjd, $val];
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

L<JAC::StripChart>, L<JAC::StripChart::Monitor::ORACIndex>.

=cut

1;
