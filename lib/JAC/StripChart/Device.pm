package JAC::StripChart::Device;

=head1 NAME

JAC::StripChart::Device - base class for plotting devices

=head1 SYNOPSIS

  use JAC::StripChart::Device;

  $dev = new JAC::StripChart::Device();

  $s = $dev->define_subplot( 2 );
  $s->select;

=head1 DESCRIPTION

Base class for stripchart output devices.

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

Create a new device. In subclasses this may create an output window
or file.

    $dev = new JAC::StripChart::Device( nxy => [3,4] );
    $dev = new JAC::StripChart::Device( context => $c );

Supported options are:

  nxy =>   Ref to array indicating the number of x and y subplots
  context => Context in which the plot should be created.

The context will be specific to a particular device so a device should
check that a context is relevant rather than assuming it is
suitable. If a context is not suitable it should be ignored if
possible, else an exception should be thrown.

nxy will default to [1,1]

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;

  my $dev = bless {
		   DEVID => undef,
		   CONTEXT => undef,
		   NXY => [1,1],
		  }, $class;

  # Read the required x,y subplots and other arguments
  @{$dev->{NXY}} = @{ $args{nxy} } if exists $args{nxy};
  $dev->context( $args{context} ) if exists $args{context};

  return $dev;
}

=back

=head2 Accessor Methods

=over 4

=item B<devid>

The low level device identifier (or object, or reference to array of
objects) created when the device was opened for plotting.

=cut

sub devid {
  my $self = shift;
  if (@_) { $self->{DEVID} = shift; }
  return $self->{DEVID};
}

=item B<nxy>

Number of subplots in the control window. Currently readonly since
there is no need to re-divide the display after it has been
created.

  @nxy = $dev->nxy;

=cut

sub nxy {
  my $self = shift;
  return @{ $self->{NXY} };
}

=item B<context>

Any context (object or scalar depending on device) required to
correctly create the output device. Will be ignored if the particular
device subclass does not now how to use this context.

=cut

sub context {
  my $self = shift;
  if (@_) { $self->{CONTEXT} = shift; }
  return $self->{CONTEXT};
}

=back

=head2 General Methods

=over 4

=item B<define_subplot>

Return an object suitable for registering with a Sink object, that can
be used for controlling device switching and subplot selection.

  $s = $dev->define_subplot( 2 );

A subsection number is required. Returns a subplot object.

=cut

sub define_subplot {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("define_subplot() must be subclassed");
}

=item B<select>

Select this particular device.

  $dev->select();

=cut

sub select {
  throw JAC::StripChart::Error::FatalError("select() must be subclassed");
}

=item B<clear>

Clear this device, ready for plotting.

=cut

sub clear {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("clear() must be subclassed");
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2004-2005 Particle Physics and Astronomy Research Council.
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

L<JAC::StripChart>, L<JAC::StripChart::Config>

=cut

1;
