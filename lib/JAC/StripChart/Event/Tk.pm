package JAC::StripChart::Event::Tk;

=head1 NAME

JAC::StripChart::Event::Tk - Code for Tk event loop

=head1 SYNOPSIS

  use JAC::StripChart::Event::Tk;

  $e = new JAC::StripChart::Event::Tk( $w );

  $e->configure_event( $st );
  $e->update()
  $e->MainLoop();

=head1 DESCRIPTION

Handle device-specific callbacks and event loops.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use Tk ();

# make sure we have access to the poll rate
use JAC::StripChart;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new event object.

  $sub = new JAC::StripChart::Event::Tk( context => $w );

The context must be supplied as a Tk::Frame object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my %args = @_;

  my $e = bless {
		 CONTEXT => undef,
		 HAS_BEEN_CONFIGURED => 0,
		}, $class;


  # store the parameters
  $e->context( $args{context} ) if exists $args{context};

  return $e;
}

=back

=head2 Accessor Methods

=over 4

=item B<context>

Tk::Frame object associated with the GUI.

 $w = $e->context();

=cut

sub context {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    throw JAC::StripChart::Error::BadClass("Supplied argument not of class Tk::Frame")
          unless UNIVERSAL::isa( $arg, "Tk::Frame");
    $self->{CONTEXT} = $arg;
  }
  return $self->{CONTEXT};
}

=item B<configured>

Indicates that the configure_event() method has been invoked.

  $configured = $e->configured();

=cut

sub configured {
  my $self = shift;
  if (@_) {
    $self->{HAS_BEEN_CONFIGURED} = shift;
  }
  return $self->{HAS_BEEN_CONFIGURED};
}

=back

=head2 General Methods

=over 4

=item B<configure_event>

Configures the event loop so that any callbacks are registered.
This routine registers the stripchart update method with the Tk
event loop using a 1 second refresh.

 $e->configure_event( $st );

It takes the top level stripchart object, and it can only be called
once.

=cut

sub configure_event {
  my $self = shift;
  my $st = shift;
  my $w = $self->context;
  &tkupdate_chart( $w, $st );
  $self->configured( 1 );
}

=item B<update>

Run the Tk event loop once. You must run configure_event() method first
if it has not already been configured. This ensures that stripchart
events are processed as well as GUI events.

  $e->update();

=cut

sub update {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("Please run configure_event() method before calling update()")
    unless $self->configured;
  Tk::DoOneEvent(0);
}

=item B<MainLoop>

Run the Tk mainloop. configure_event() must have been run first.

=cut

sub MainLoop {
  my $self = shift;
  throw JAC::StripChart::Error::FatalError("Please run configure_event() method before calling MainLoop()")
    unless $self->configured;
  Tk::MainLoop;
}

=back

=begin __PRIVATE_FUNCTIONS__

=head2 Private Functions

=over 4

=item B<tkupdate_chart>

Register a repeating callback (every second) with the Tk system that
will run the update() method.

=cut

sub tkupdate_chart {
  my $context = shift;
  my $st = shift;
  $context->after( JAC::StripChart::POLL_INTERVAL,
		   sub { $st->update();
			 print "Updating...\n";
			 $context->after(JAC::StripChart::POLL_INTERVAL,
					 [\&tkupdate_chart,
					  $context, $st]);
		       }
		 );
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research Council.
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
