package JAC::StripChart::Monitor::Simple;

=head1 NAME

JAC::StripChart::Monitor::Simple - Configure a stripchart monitor for a simple text file

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::Simple;

  $cfg = new JAC::StripChart::Monitor::Simple( filename => $file );

=head1 DESCRIPTION

Interface to a simple text file with space separated columns where
time is represented by one of the columns and the time-varying data
represented by another.

Useful for testing stripchart functionality.

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

 $cfg = new JAC::StripChart::Monitor::Simple( filename => $file );

Takes a hash argument with keys:

  filename => name of the file containing incoming data

  tcol => column number for time values

  ycol => column number for y-axis values

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
		   MonID => '',
		   FileObject => undef,
		   TCol => undef,
		   YCol => undef,
		   Tformat => undef,
		  }, $class;

  if (@_) {
    my %args = @_;
    # loop over known important methods
    for my $k (qw| monid filename tcol ycol tformat|) {
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

=item B<filename>

Name of the file used as the data source for this monitor.
Returns undef if no file has yet been registered.

=cut

sub filename {
  my $self = shift;
  if (@_) {
    my $file = shift;
    $self->file( new JAC::StripChart::Monitor::SimpleFile( $file ) )
  }
  return (defined $self->file ? $self->file->filename : undef);
}

=item B<file>

The underlying Monitor::SimpleFile object associated with this
object.

=cut

sub file {
  my $self = shift;
  if (@_) {
    # Check class
    my $obj = shift;
# TO BE ADDED LATER... ASSUME IT'S VALID FOR NOW
    throw JAC::StripChart::Error::BadArgs("Supplied object to method 'file' must be of class 'JAC::StripChart::Monitor::SimpleFile' but was class '".ref($obj)."'")
      unless UNIVERSAL::isa($obj, "JAC::StripChart::Monitor::SimpleFile");
    $self->{FileObject} = $obj;

  }
  return $self->{FileObject};
}

=item B<tcol>

The column number representing the time axis.

=cut

sub tcol {
  my $self = shift;
  if (@_) {
    $self->{TCol} = shift;
  }
  return $self->{TCol};
}

=item B<ycol>

The column number representing the Y-axis data.

=cut

sub ycol {
  my $self = shift;
  if (@_) {
    $self->{YCol} = shift;
  }
  return $self->{YCol};
}

=item B<tformat>

Set the Time format. Checks whether $tformat is a known format.


=cut

sub tformat {
  my $self = shift;
  if (@_) {
    my $tformat = substr($_[0],0,3);
# Check that Tformat is one of the allowed possibilities.
# Return without setting tformat if no match.
    if ($tformat !~ /mjd|ora|dmy|mdy|ymd|hms/i) {
      warnings::warnif("Unknown time format for ".$self->monid." - unable to plot data");
	return;
      }
    $self->{Tformat} = shift;
  }
  return $self->{Tformat};
}

=back

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the file since the
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
  return $self->file->getData( $id, $self->tcol, $self->ycol,  $self->tformat );
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>and
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

