package JAC::StripChart::Chart;

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

   $cfg = new JAC::StripChart::Chart( monitors => \@mon );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create object
  my $chart = bless {
		   Monitors => [],
		   ID => undef,
		  }, $class;

  if (@_) {
    my %args = @_;

    # loop over known important methods
    for my $k (qw| monitors chartid |) {
      $chart->$k($args{$k}) if exists $args{$k};
    }
  }

  return $chart;
}

=back

=head2 Accessor Methods

=over 4

=item B<column>

Chart ID associated with this strip chart. Should be a unique
string.

=cut

sub chartid {
  my $self = shift;
  if (@_) {
    $self->{ID} = shift;
  }
  return $self->{ID};
}

=item B<monitors>

Data monitors associated with this strip chart.

  @monitors = $chart->monitors;
  $chart->monitors(@monitors);

=cut

sub monitors {
  my $self = shift;
  if (@_) {
    # see if we have a hash ref as first arg
    my @monitors = (ref($_[0]) ? @{$_[0]} : @_);

    # Should add a test for class here
    # (or at least make sure the getData method is there)
    @{ $self->{Monitors} } = @monitors;
  }
  return @{ $self->{Monitors} };
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
