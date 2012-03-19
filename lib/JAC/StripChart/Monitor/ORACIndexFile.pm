package JAC::StripChart::Monitor::ORACIndexFile;

=head1 NAME

JAC::StripChart::Monitor::ORACIndexFile - low level index file access

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::ORACIndexFile;

  $cfg = new JAC::StripChart::Monitor::ORACIndexFile( indexfile => $file );

=head1 DESCRIPTION



=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;

use JAC::StripChart::Error;
use File::Spec;

# Need MJD conversion
use Astro::PAL;

# Need to be able to read index files
use lib File::Spec->catdir($ENV{ORAC_DIR},"lib","perl5");
use ORAC::Index::Extern;


use vars qw/ $VERSION /;
$VERSION = 1.0;

# Global hash look up table to keep track of which objects
# have been associated with which index file. This is attempting
# to cache repeat requests to access an index file.
use vars qw/ %CACHE /;


=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Takes single constructor argument of the index file itself.
Assumes ORAC_DATA_OUT if the path to the file is not absolute.

 $cfg = new JAC::StripChart::Monitor::ORACIndexFile( $file );

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Obtain the file name
  my $ifile = shift;

  # Now convert it to an absolute path
  $ifile = $class->_abs_path( $ifile );

  # look up in cache and return cached value if it exists
  return $CACHE{$ifile} if exists $CACHE{$ifile};

  # Create object
  my $mon = bless {
		   IndexFile => undef,
		   Index => undef,
		   MonPos => {},
		  }, $class;

  # Store filename (triggering read)
  $mon->indexfile( $ifile );

  # Store in cache
  $CACHE{$ifile} = $mon;

  return $mon;
}

=back

=head2 Accessor Methods

=over 4

=item B<indexfile>

Name of the ORAC-DR index file used as the data source for this
monitor.

=cut

sub indexfile {
  my $self = shift;
  if (@_) {
    $self->{IndexFile} = shift;

    # Trigger read of index file itself
    $self->index( new ORAC::Index::Extern($self->{IndexFile}, 
					  ORAC::Index::NO_RULES));
  }
  return $self->{IndexFile};
}

=item B<index>

The underlying ORAC::Index object associated with this
object.

=cut

sub index {
  my $self = shift;
  if (@_) {
    # Check class
    my $obj = shift;
    throw JAC::StripChart::Error::BadArgs("Supplied object to method 'index' must be of class 'ORAC::Index' but was class '".ref($obj)."'")
      unless UNIVERSAL::isa($obj, "ORAC::Index");
    $self->{Index} = $obj;

  }
  return $self->{Index};
}

=item B<_monitor_posn>

This (private) hash contains information on the data most recently
obtained from the index file for each stripchart that is monitoring
this index file.

Valid keys are derived using the C<_genkey> method.

  $i->_monitor_posn( $key, $newval );
  $curval = $i->_monitor_posn( $key );
  %allvals = $i->_monitor_posn();

In the second example, 0 is returned rather than undef if no
key is present.

=cut

sub _monitor_posn {
  my $self = shift;
  if (@_) {
    my $key = shift;
    if (@_) {
      $self->{MonPos}->{$key} = shift;
    } else {
      my $curval = $self->{MonPos}->{$key};
      return (defined $curval ? $curval : 0);
    }
  } else {
    return %{ $self->{MonPos} };
  }
}


=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the index file since the
last time we were asked for data.

  @newdata = $mon->getData( $id, $column, %filter );

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2".

@newdata contains a sorted list where each entry is a reference to a 2
element array.

=cut

sub getData {
  my $self = shift;
  my $id = shift;
  my $column = shift;
  my %filter = @_;

  # Generate the unique key
  my $key = $self->_genkey( $id, $column, %filter);

  # Get the reference time for this chart
  my $reftime = $self->_monitor_posn( $key );

  # Obtain the lines that match the filter
  my @match = $self->index->scanindex(%filter);

  # Make sure that column exists.
  if (@match && !exists $match[0]->{$column}) {
    warnings::warnif("Column name '$column' not recognized by index file");
    return ();
  }

  # Now we have to filter on the basis of time. In this
  # case ORACTIME (ie YYYYMMDD.frac) format.
  @match = sort { $a->{ORACTIME} <=> $b->{ORACTIME} } 
              grep { $_->{ORACTIME} > $reftime } @match;

  # set reference time
  $self->_monitor_posn( $key, $match[-1]->{ORACTIME})
    if @match;

  # return the answer (time should be in MJD UT)
  return map { [ $self->_oractime_to_mjd($_->{ORACTIME}),
		 $_->{$column}
	       ] } @match;
}

=item B<_genkey>

Generate a unique private key from the supplied chart configuration.

  $key = $i->_genkey( $chartid, $column, %filter );

The filter hash can be empty.

=cut

sub _genkey {
  my $self = shift;
  return join("_",@_);
}

=back

=head2 Class Method


=over 4

=item B<_abs_path>

Internal method to attach path to a specified index file location.

=cut

sub _abs_path {
  my $class = shift;
  my $file = shift;

  # currently only uses cwd if ORAC_DATA_OUT is not defined.
  # It is feasible that we should actually check whether
  # the file is in ORAC_DATA_OUT and cwd and make a more informed
  # decision!
  return File::Spec->rel2abs( $file, $ENV{ORAC_DATA_OUT});

}

=item B<_oractime_to_mjd>

Convert ORACTIME (YYYYMMDD.frac)

=cut

sub _oractime_to_mjd {
  my $class = shift;
  my $oractime = shift;

  Astro::PAL::palCldj( substr($oractime,0,4),
		       substr($oractime,4,2),
		       substr($oractime,6,2),
		       my $mjd, my $j
		     );

  warnings::warnif("Bad status in oractime_to_mjd from slaCldj: $j")
    unless $j == 0;

  # Add on the fraction of day
  my $frac = $oractime - int($oractime);
  $mjd += $frac;

  return $mjd;
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

L<JAC::StripChart::Monitor::ORACIndex>

=cut

1;

