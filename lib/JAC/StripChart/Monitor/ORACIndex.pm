package JAC::StripChart::Monitor::ORACIndex;

=head1 NAME

JAC::StripChart::Monitor::ORACIndex - Configure a stripchart ORAC-DR monitor

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::ORACIndex;

  $cfg = new JAC::StripChart::Monitor::ORACIndex( indexfile => $file );

=head1 DESCRIPTION



=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;

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

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $mon = bless {
		   IndexFile => undef,
		   Column => undef,
		   Filter => {},
		  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| indexfile column filter|) {
      $mon->$k($args{$k}) if exists $args{$k};
    }
  }

  return $mon;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of the ORAC-DR index file used as the data source for this
monitor.

=cut

sub indexfile {
  my $self = shift;
  if (@_) {
    $self->{IndexFile} = shift;
  }
  return $self->{IndexFile};
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

=back

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the index file since the
last time we were asked for data.

  @newdata = $mon->getData( $id );

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2".

=cut

sub getData {

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

