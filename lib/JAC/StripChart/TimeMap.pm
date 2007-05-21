package JAC::StripChart::TimeMap;

=head1 NAME

  use JAC::StripChart::TimeMap;

  $tmap = new JAC::StripChart::TimeMap( output => 'radians' );
  $tmap->refdate( $mjd );
  @mapped = $map->do_map( @input );

=head1 DESCRIPTION

Class for converting time date in MJD to the requested output
units. Can optionally be given a reference date that will be
subtracted prior to processing.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

# Conversion of hours to radians (pi/12)
use constant DH2R => 0.26179938779914943653855361527329190701643078328126;

# conversion of days to radians is simply 2PI
use constant D2PI => 6.2831853071795864769252867665590057683943387987502;


=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new time map.

  $tmap = new JAC::StripChart();
  $tmap = new JAC::StripChart( output => 'radians' );

Hash options are forwarded to the corresponding accessor methods.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;

  my $tm = bless {
		  OutputFormat => 'unit',
		  RefMJD => 0,
		 };

  for my $a ( qw/ refdate output / ) {
    $tm->$a( $args{$a} ) if exists $args{$a};
  }

  return $tm;
}

=back

=head2 Accessor Methods

=over 4

=item B<output>

The output format for the map. Supported options are:

  unit     - unit mapping without subtracting reference
  days     - unit mapping, input to output whilst
             subtracting reference date
  radians  - radians since reference date
  hours    - decimal hours since reference date

Note that refdate() is always subtracted. Default is 'unit'.

=cut

sub output {
  my $self = shift;
  if (@_) {
    my $arg = lc(shift);
    croak "Unsupported output option: $arg"
      unless $arg =~ /hours|radians|days|unit/;
    $self->{OutputFormat} = $arg;
  }
  return $self->{OutputFormat};
}

=item B<refdate>

Reference date to be subtracted from each input time. Should be an MJD.

  $tm->refdate( $mjd );
  $mjd = $tm->refdate;

=cut

sub refdate {
  my $self = shift;
  if (@_) {
    $self->{RefMJD} = shift;
  }
  return (defined $self->{RefMJD} ? $self->{RefMJD} : 0.0 );
}

=back

=head2 General Methods

=over 4

=item B<do_map>

Convert the input data to the output.

  @converted = $tm->do_map( @input );

If @input contains references to arrays, the first element of that
array is assumed to represent the MJD time.

=cut

sub do_map {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("Can not be called in scalar context")
    unless wantarray();

  my @input = @_;

  # determine output format
  my $output = $self->output;
  return @input if $output eq 'unit';

  # Get the time column
  my @times;
  if (ref($input[0])) {
    @times = map { $_->[0] } @input;
  } else {
    @times = @input;
  }

  # Subtract the reference date
  my $refdate = $self->refdate;
  @times = map {$_ - $refdate } @times;

  if ($output eq 'hours') {
    @times = map { $_ * 24  } @times;
  } elsif ($output eq 'radians') {
    @times = map { $_ * D2PI  } @times;
  } elsif ($output eq 'days') {
    # no op
  } else {
    croak "Unrecognized output format: $output";
  }

  # Put the times back
  if (ref($input[0])) {
    for my $i ( 0..$#times ) {
      $input[$i]->[0] = $times[$i];
    }
    return @input;
  } else {
    return @times;
  }
}

=item B<do_inverse>

Map from the output units back into MJD.

  @mjd = $tmap->do_inverse( @units );

If @input contains references to arrays, the first element of that
array is assumed to represent the MJD time.

=cut

sub do_inverse {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("Can not be called in scalar context")
    unless wantarray();
  my @input = @_;

  # determine input format
  my $output = $self->output;
  return @input if $output eq 'unit';

  # Get the time column
  my @times;
  if (ref($input[0])) {
    @times = map { $_->[0] } @input;
  } else {
    @times = @input;
  }

  # convert to base unit
  if ($output eq 'hours') {
    @times = map { $_ / 24  } @times;
  } elsif ($output eq 'radians') {
    @times = map { $_ / D2PI  } @times;
  } elsif ($output eq 'days') {
    # no op
  } else {
    croak "Unrecognized input format: $output";
  }

  # Add the reference date
  my $refdate = $self->refdate;
  @times = map {$refdate + $_ } @times;


  # Put the times back
  if (ref($input[0])) {
    for my $i ( 0..$#times ) {
      $input[$i]->[0] = $times[$i];
    }
    return @input;
  } else {
    return @times;
  }

}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research Council.
All Rights Resrved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA  02111-1307, USA

=head1 SEE ALSO

L<JAC::StripChart::Sink>, L<JAC::StripChart>

=cut

1;
