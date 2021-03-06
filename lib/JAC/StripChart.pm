package JAC::StripChart;

=head1 NAME

JAC::StripChart - Create a stripchart

=head1 SYNOPSIS

  $st = new JAC::StripChart( $cfgfile );

  @charts = $st->charts;

  $st->init();
  $st->update();
  $st->MainLoop;

=head1 DESCRIPTION

This class provides high level control over the stripchart system.

=cut


use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use JAC::StripChart::Config;


use vars qw/ $VERSION /;
$VERSION = 1.0;

# stripchart poll rate in milliseconds
use constant POLL_INTERVAL => 750;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Create a new stripchart environment.

   $st = new JAC::StripChart( $cfgfile );

Additional arguments will be forwarded to the config object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  throw JAC::StripChart::Error::BadConfig("A config file name must be supplied") unless @_;

  # Create object
  my $st = bless {
		   Config => undef,
		   Charts => [],
		   Devices => [],
		   CallBack => undef,
		  }, $class;


  my $cfgfile = shift;
  my $cfg = new JAC::StripChart::Config( $cfgfile, @_ );

  $st->charts( $cfg->charts );
  $st->config( $cfg );

  return $st;
}

=back

=head2 Accessor Methods

=over 4

=item B<charts>

Configured StripChart objects.

  @charts = $st->charts();
  $st->charts(@charts);

=cut

sub charts {
  my $self = shift;
  if (@_) {
    # see if we have a hash ref as first arg
    my @charts = (ref($_[0]) eq 'ARRAY'  ? @{$_[0]} : @_);

    # Should add a test for class here
    @{ $self->{Charts} } = @charts;
  }
  return @{ $self->{Charts} };
}

=item B<config>

This is the underlying Config object. It can be used for
querying any global state that was stored in the config
system. Note that it is possible to cerate a strip chart
without registering a config object.

=cut

sub config {
  my $self = shift;
  if (@_) { $self->{Config} = shift; }
  return $self->{Config};
}

=item B<devices>

Returns all the devices required to render the charts.
Can return an empty list if the C<init> method has not been instantiated.

 @devs = $st->devices;

=cut

sub devices {
  my $self = shift;
  if (@_) {
    @{$self->{Devices}} = @_;
  }
  return @{ $self->{Devices} };
}

=item B<callback>

A routine that will be called from within the update() method to allow
additional attribute handling to be performed periodically. 

  $st->callback( \&mycb );
  $st->callback( [ \&mycb, $arg1, $arg2 ] );

If a reference to an array is passed in, it is assumed to 
include additional arguments that should be sent to the callback.

Array callbacks don't currently work. There seems to be a bizarre
reference counting problem.

=cut

sub callback {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    if (not ref( $arg ) ) {
      throw JAC::StripChart::Error::BadArgs("Argument to callback() method is not a reference");
    } elsif (ref($arg) eq 'ARRAY' && not ref($arg->[0]) ) {
      throw JAC::StripChart::Error::BadArgs("first element in array given to callback() method is not a reference");
    }

    $self->{CallBack} = $arg;
  }
  return ($self->{CallBack});
}

=back

=head2 General Methods

=over 4

=item B<init>

Ask each chart for its requested device driver, collate the responses
and then initialise each Device class and register the resulting
objects with the individual Chart objects.

  $st->init;

Any remaining arguments (as hash key/value pairs) are passed directly
to the low-level device constructor. Unrecognized keys will be
ignored.

 $st->init( nxy => [2,1], context => $w );

=cut

sub init {
  my $self = shift;
  my %args = @_;

  # First found out who wants what
  my %devlist;
  for my $c ($self->charts) {
    # Get the sinks
    for my $s ($c->sinks) {
      my $class = $s->device_class;
      $devlist{$class}++ if $class;
    }
  }

  # Find out how many subplots are needed
  my $cfg = $self->config();
  my @nxy = ($cfg ? $cfg->nxy : [1,1] );

  # put this in Args, unless nxy is already present
  $args{nxy} = \@nxy unless exists $args{nxy};

  # Find out about tabs.
  $args{tabs} = $cfg->tabs;

  # load all the classes and instantiate the main control class for each device
  my %dev;
  for my $d (keys %devlist) {
    my $class = __PACKAGE__ . "::Device::$d";
    eval "use $class";
    JAC::StripChart::Error::BadConfig->throw("Attempt to use a device of class $class except that class could not be loaded: $@") if $@;

    # this is the top level control
    $dev{$d} = $class->new( %args );
  }

  # store the devices
  $self->devices( values %dev );

  # Now associate each chart with a device class configured
  # to its needs
  for my $c ($self->charts) {

    # get the stripchart position
    my $posn = $c->posn;

    # Get the plotting attributes (forcing them to exist)
    my %attr = map { $_, $c->monattrs( $_ ) } 
      map { $_->monid } $c->monitors;

    # now loop over all sinks
    for my $s ($c->sinks) {
      my $class = $s->device_class;
      next unless $class;
      my $dev = $dev{$class};

      # Now need to request a subset
      my $sdev = $dev->define_subplot( $posn );

      # and register with the sink
      $s->device( $sdev );

      # and initialise
      $s->init( %attr );
    }
  }

}

=item B<update>

Ask each strip chart to update its contents.

  $st->update;

=cut

sub update {
  my $self = shift;

  # first run the callback if it is present
  if ($self->callback) {
    my $cb = $self->callback();
    if (ref($cb) eq "CODE") {
      $cb->();
    } elsif (ref($cb) eq 'ARRAY') {
      my $cb2 = shift(@$cb);
      throw JAC::StripChart::Error::FatalError("unrecognized callback type. Not Code ref") unless ref($cb2) eq 'CODE';
      $cb2->( @$cb );
    } else {
      throw JAC::StripChart::Error::FatalError("unrecognized callback type");
    }
  }

  # now process the charts
  for my $c ($self->charts) {
    $c->update();
  }
  return;
}

=item B<MainLoop>

This loop continuously requests each chart to update itself.
If the devices require their own event loops, the method will
do the correct thing and forward on the event loop intialisation.

  $st->MainLoop();

Arguments indicate event loops that should be serviced regardless
of the devices required for the stripchart.

  $st->MainLoop( $event );

The arguments must be JAC::StripChart::Event objects.

NOTE: There needs to be a way to exit this loop for the non-GUI
non-event loop case.

=cut

sub MainLoop {
  my $self = shift;

  # initial event classes
  my @e = @_;

  # assume that we only need one event class of each type
  my %types = map { ref($_),undef } @e;

  # Then decide whether we require any non-standard event loop
  # from the charts themselves
  my @dev = $self->devices;

  for my $d (@dev) {
    my $eclass = $d->event_class();
    next unless $eclass;

    # skip if we have had this already
    next if exists $types{$eclass};
    $types{$eclass}++;

    # load the required class
    eval "require $eclass";
    throw JAC::StripChart::Error::FatalError("Error loading support event handling class '$eclass': $@") if $@;

    # create a new one and store it
    push(@e, $eclass->new( context => $d->context ));
  }

  # 3 cases: No event classes, 1 event class or many
  if (!@e) {
    while (1) {
      $self->update;
      select(undef,undef,undef, POLL_INTERVAL / 1000 );
    }
  } elsif (scalar(@e) == 1) {
    $e[0]->configure_event( $self );
    $e[0]->MainLoop();
  } else {
    $_->configure_event( $self ) for @e;;
    while (1) {
      $_->update() for @e;
      select(undef,undef,undef, POLL_INTERVAL / 1000 );
    }
  }
  return;
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

L<JAC::StripChart::Chart>, L<JAC::StripChart::Config>

=cut

1;
