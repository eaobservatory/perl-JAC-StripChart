package JAC::StripChart::Monitor::Simple;

=head1 NAME

JAC::StripChart::Monitor::Simple - Configure a stripchart ORAC-DR monitor

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::Simple;

  $cfg = new JAC::StripChart::Monitor::Simple( indexfile => $file );

=head1 DESCRIPTION



=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::Monitor::SimpleFile;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

 $cfg = new JAC::StripChart::Monitor::Simple( indexfile => $file );

Takes a hash argument with keys:

  indexfile => name of the ORAC-DR indexfile.
               If no path, assumes $ORAC_DATA_OUT

  tcol => column number for time values

  ycol => column number for y-axis values

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
		   MonID => '',
		   IndexObject => undef,
		   TCol => undef,
		   YCol => undef,
		   Tframe => undef,
		  }, $class;

  if (@_) {
    my %args = @_;
    # loop over known important methods
    for my $k (qw| monid indexfile tcol ycol|) {
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
    $self->index( new JAC::StripChart::Monitor::SimpleFile( $file ) )
  }
  return (defined $self->index ? $self->index->indexfile : undef);
}

=item B<index>

The underlying Monitor::Simple object associated with this
object.

=cut

sub index {
  my $self = shift;
  if (@_) {
    # Check class
    my $obj = shift;
# TO BE ADDED LATER... ASSUME IT'S VALID FOR NOW
    throw JAC::StripChart::Error::BadArgs("Supplied object to method 'index' must be of class 'JAC::StripChart::Monitor::SimpleFile' but was class '".ref($obj)."'")
      unless UNIVERSAL::isa($obj, "JAC::StripChart::Monitor::SimpleFile");
    $self->{IndexObject} = $obj;

  }
  return $self->{IndexObject};
}

=item B<tcol> and B<ycol>

The columns containing the data to be plotted (time must be one of them)

=cut

sub tcol {
  my $self = shift;
  if (@_) {
    $self->{Tcol} = shift;
  }
  return $self->{Tcol};
}

sub ycol {
  my $self = shift;
  if (@_) {
    $self->{Ycol} = shift;
  }
  return $self->{Ycol};
}

=item B<tframe>

Set the Time frame units

=cut

sub tframe {
  my $self = shift;
  if (@_) {
    $self->{Tframe} = shift;
  }
  return $self->{Tframe};
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
  return $self->index->getData( $id, $self->tcol, $self->ycol,  $self->tframe );
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

L<JAC::StripChart>

=cut

1;

