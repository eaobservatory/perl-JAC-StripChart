package JAC::StripChart::Monitor::SimpleFile;

=head1 NAME

JAC::StripChart::Monitor::SimpleFile - low level simple data file access

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::SimpleFile;

  $cfg = new JAC::StripChart::Monitor::SimpleFile( indexfile => $file );

=head1 DESCRIPTION


Whereas an ORAC index file must contain the column header info (and a
unique name for each line), a simple file is assumed to contain
nothing more than space-separated columns of date, one of which must
be a time axis. If the time contains no day/month/year info, the
current values are assumed. The format for the time must be specified
in the config.ini file. Allowed values are: MJD, ORACTIME, UT, Local,
where UT and Local are given as hh:mm:ss.sssss.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;
use Data::Dumper;

use JAC::StripChart::Error;
use File::Spec;
use IO::File;

# Need MJD conversion
use Astro::SLA;
use Time::Piece;

# Need to be able to read index files
use lib File::Spec->catdir($ENV{ORAC_DIR},"lib","perl5");
#use JAC::StripChart::Simple::Access;

use List::Util qw/ min /;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# Global hash look up table to keep track of which objects
# have been associated with which index file. This is attempting
# to cache repeat requests to access an index file.
use vars qw/ %CACHE /;

# Variable storing the oldest monitor position
use vars qw/ $oldest /;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Takes single constructor argument of the index file itself.
Assumes ORAC_DATA_OUT if the path to the file is not absolute.

 $cfg = new JAC::StripChart::Monitor::SimpleFile( $file );

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
		   SimpleFile => undef,
		   Index => undef,
		   MonPos => {},
		   LastRead => undef,
		   Ncols => undef,
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

Name of the simple ascii file used as the data source for this
monitor.

=cut

sub indexfile {
  my $self = shift;
  if (@_) {
    $self->{SimpleFile} = shift;

    # Read file to get number of columns
    $self->get_columns;    
#    $self->index( $self->{SimpleFile}) ;
  }
  return $self->{SimpleFile};
}

=item B<index>

The underlying JAC::Stripchart::Simple object associated with this
object.

=cut

sub index {
  my $self = shift;
  if (@_) {
    # Check class
    my $obj = shift;
    throw JAC::StripChart::Error::BadArgs("Supplied object to method 'index' must be of class 'JAC::StripChart::Monitor' but was class '".ref($obj)."'")
      unless UNIVERSAL::isa($obj, "JAC::StripChart::Monitor");
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


=item B<get_columns>

Reads the input file, and returns the number of columns.

  $index->get_columns; 

Croaks if file does not exist.

=cut

sub get_columns {

  my $self = shift;

  # Update read time
  $self->last_read(time());

  # Look for index file
  my $file = $self->indexfile;
  throw JAC::StripChart::Error::FileNotFound("Simple data file $file does not exist")
    unless (-e $file);

  my $handle = new IO::File "< $file";
  my $ncols = undef;

  if (defined $handle) {
    foreach my $line (<$handle>) {
      next if $line =~ /^\s*#/; # Ignore lines beginning with # or *
      $line =~ s/^\s+//g;	# zap leading blanks
      my @data = split(/\s+/,$line); # Split on spaces
      $ncols = $#data + 1 if (!$ncols);  # Set the number of columns
      last if $ncols; # Don't need to read any more once $ncols is set
    }
  } else {
    croak("Couldn't open index file $file : $!");
  }

  $self->{Ncols} = $ncols;
  return $self->{Ncols};

}

=item B<last_read>

Time the data file was last read. This is used to determine whether
the data file should be re-read.

Relies on the object being based on a hash.

=cut

sub last_read {
  my $self = shift;
  if (@_) { $self->{LastRead} = shift; }
  return $self->{LastRead};
}

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the index file since the
last time we were asked for data.

  @newdata = $mon->getData( $id, $tcol, $ycol, $tframe);

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2".

@newdata contains a sorted list where each entry is a reference to a 2
element array.

=cut

sub getData {
  my $self = shift;

# Fail if less than 4 parameters are present
  my $nparams = 4;
  my $nfound = $#_ + 1;
  throw JAC::StripChart::Error::BadArgs("Incorrect number of parameters supplied in call to getData (need $nparams, found $nfound)")
    if ($nfound <=> $nparams);
  my ($id, $tcol, $ycol, $tframe) = @_;

  # Check that $tcol and $ycol exist
  warnings::warnif("Unable to plot data for $id because requested T column is not present in file")
    if ($self->{Ncols} < $tcol);
  warnings::warnif("Unable to plot data for $id because requested Y column is not present in file")
    if ($self->{Ncols} < $ycol );

  # Check for different columns!
  if ($tcol == $ycol) {
    warnings::warnif("Unable to plot data for $id because t_col = y_col: both set to column $tcol");
      return;
    }

  # Generate a unique key
  my $key = $self->_genkey( $id, $tcol, $ycol);

  # Read (get) the stored reference time for this chart
  my $reftime = $self->_monitor_posn( $key );
  if (!$oldest) {
    $oldest = $reftime ;
  } else {
    $oldest = $self->oldest_monpos;
  }

  # Read new data and store in the @cache
  my @cache = $self->readsimple($id, $tcol, $ycol, $tframe, $oldest);

  # Set the reference time to a new value
  $self->_monitor_posn( $key, $cache[-1]->[0])
    if @cache;

#  print Dumper(\@cache);

  # return the answer (time should be in MJD UT)
  return map { [ $self->_oractime_to_mjd($_->[0]),
		 $_->[1]
	       ] } @cache;
#return @cache;
}

=item B<readsimple>

A method for returning the two columns of data of interest. 

  @data = $self->readsimple( $tcol, $ycol, $id, $tframe, $oldest);

=cut

sub readsimple {
  my $self = shift;

# Fail if less than 5 parameters are present
  my $nparams = 5;
  my $nfound = $#_ + 1;
  throw JAC::StripChart::Error::BadArgs("Incorrect number of parameters supplied in call to readsimple (need $nparams, found $nfound)")
    if ($nfound <=> $nparams);
  my ($id, $tcol, $ycol, $tframe, $oldest) = @_;

  my $file = $self->indexfile;
  return unless (-e $file);
  my $handle = new IO::File "< $file";
  my @plotdata;

  # Read successive lines from file
  while (my $line = <$handle>) {
    next if $line =~ /^\#/; # Skip lines beginning with a #
    $line =~ s/^\s+//g;     # Delete leading blanks
    my @data = split(/\s+/,$line);
    next if $data[$tcol-1] < $oldest;
#    # Convert time data to ORACTIME
#    my $tdata = convert_to_oractime($data[$tcol-1], $tframe);
#    push (@plotdata, [ $tdata, $data[$ycol-1] ]);
    push (@plotdata, [ $data[$tcol-1], $data[$ycol-1] ]);
  }

  return @plotdata;
}

=item B<oldest_monpos>

Determine the oldest value for monpos for caching plot data.

=cut

sub oldest_monpos {

  my $self = shift;
  my %monpos = $self->_monitor_posn();
  my $oldest = min(values %monpos);

  return $oldest;
}

=item B<_genkey>

Generate a unique private key from the supplied chart configuration.

  $key = $i->_genkey( $chartid, $tcol, $ycol);

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

  Astro::SLA::slaCldj( substr($oractime,0,4),
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

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Andy Gibb E<lt>agg@astro.ubc.caE<gt>

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

=cut

1;

