package JAC::StripChart::Monitor::SimpleFile;

=head1 NAME

JAC::StripChart::Monitor::SimpleFile - low level simple data file access

=head1 SYNOPSIS

  use JAC::StripChart::Monitor::SimpleFile;

  $sf = new JAC::StripChart::Monitor::SimpleFile( $file );

=head1 DESCRIPTION

Whereas an ORAC index file must contain the column header info (and a
unique name for each line), a simple file is assumed to contain
nothing more than space-separated columns of date, one of which must
be a time axis. If the time contains only HMS info, the current UT
date is assumed. The format for the time must be specified in the
config.ini file. Allowed values are: MJD, ORACTIME, MDY, DMY, YMD and
HMS. MJD & ORACTIME have no separators; the others may employ any
non-numeric, non-space character.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
use Carp;
use Data::Dumper;

use JAC::StripChart::Error;
use File::Spec;
use File::stat;

# Need MJD conversion
use Astro::SLA;
use Time::Piece;

use List::Util qw/ min /;

use vars qw/ $VERSION /;
$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# Global hash look up table to keep track of which objects
# have been associated with which files. This is attempting
# to cache repeat requests to access the contents of a file.
use vars qw/ %CACHE /;

# Variable storing the oldest monitor position
use vars qw/ $oldest /;

=head1 METHODS

=head2 Constructors

=over 4

=item B<new>

Takes single constructor argument of the simple ASCII file itself.
Assumes a full path is specified, or relative to current directory.

 $sf = new JAC::StripChart::Monitor::SimpleFile( $file );

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
		   MonPos => {},
		   LastRead => 0,
		   Ncols => undef,
		  }, $class;

  # Store filename (triggering read)
  $mon->filename( $ifile );

  # Store in cache
  $CACHE{$ifile} = $mon;

  return $mon;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of the simple ascii file used as the data source for this
monitor.

  $file = $sf->filename;

=cut

sub filename {
  my $self = shift;
  if (@_) {
    $self->{SimpleFile} = shift;

    # Read file to get number of columns
    $self->find_ncolumns;
  }
  return $self->{SimpleFile};
}

=item B<ncols>

Number of columns associated with this data file.

 $ncols = $sf->ncols;

=cut

sub ncols {
  my $self = shift;
  if (@_) {
    $self->{Ncols} = shift;
  }
  return $self->{Ncols};
}

=item B<_monitor_posn>

This (private) hash contains information on the data most recently
obtained from the data file for each stripchart that is monitoring
this data file.

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


=item B<find_ncolumns>

Reads the input file, and returns the number of columns.

  $ncol = $sfile->find_columns;

Returns without action if the file does not exist. Assumes that
it will appear later.

It does throw an exception if the file was there but could not be read.

The object state is updated (see the C<ncols> method).

=cut

sub find_ncolumns {
  my $self = shift;
  my $file = $self->filename;

  throw JAC::StripChart::Error::FatalError( "Unable to retrieve column count if file name is not defined")
    unless defined $file;

  # return without action if no file
  return unless -e $file;

  # Try to open the file. 
  open my $handle, "< $file" or
    throw JAC::StripChart::Error::FatalError( "Unable to open file $file despite its existence: $!");

  # If successful, then set LastRead attribute
#  $self->last_read( time() );
  # Read file, looking for columns
  my $ncols;
  while (my $line = <$handle>) {
    next if $line =~ /^\s*#/;      # Ignore lines beginning with # or *
    $line =~ s/^\s+//g;	           # Zap leading blanks
    my @data = split(/\s+/,$line); # Split on spaces
    if (@data) {
      $ncols = @data;              # Set the number of columns to the split result
      last;                        # we are only looking for the number of columns
    }
  }

  close($handle);
  # Need to be careful about re-checking this if the file suddenly appears
  return $self->ncols($ncols);

}

=item B<last_read>

Time the data file was last read (using the epoch seconds). This is
used to determine whether the data file should be re-read.

  $last_read = $sf->last_read;

=cut

sub last_read {
  my $self = shift;
  if (@_) { $self->{LastRead} = shift; }
  return $self->{LastRead};
}

=head1 General Methods

=over 4

=item B<getData>

Retrieve the data that has arrived in the data file since the
last time we were asked for data.

  @newdata = $mon->getData( $id, $tcol, $ycol, $tformat);

where ID is a unique identifier associated with a specific
strip chart. e.g. "chart1", "chart2".

@newdata contains a sorted list where each entry is a reference to a 2
element array.

=cut

sub getData {
  my $self = shift;

  # Fail if less than 4 parameters are present
  $self->_checkparams( 4, \@_);
  my ($id, $tcol, $ycol, $tformat) = @_;

  # make sure we have a column count
  my $ncol = $self->ncols;
  if (!$ncol) {
    $ncol = $self->find_ncolumns;
    # no file so return
    return () unless defined $ncol;
  }

  # Check that $tcol and $ycol exist
  warnings::warnif("Unable to plot data for $id because requested T column is not present in file")
    if ($ncol < $tcol);
  warnings::warnif("Unable to plot data for $id because requested Y column is not present in file")
    if ($ncol < $ycol );

  # Check for different columns!
  if ($tcol == $ycol) {
    warnings::warnif("Unable to plot data for $id because t_col = y_col: both set to column $tcol");
      return;
    }

  # Generate a unique key
  my $key = $self->_genkey( $id, $tcol, $ycol);

  # Read (get) the stored reference time for this chart
  my $reftime = $self->_monitor_posn( $key );
#  print $reftime;

#  return if ($self->last_read > $self->last_write($self->filename));
  return if ($reftime > $self->last_write($self->filename));

  if (!$oldest) {
    $oldest = $reftime ;
  } else {
    $oldest = $self->oldest_monpos;
  }
#  print $id, $oldest ."\n";

  # Read new data and store in @newdata
  my @newdata = $self->readsimple($id, $tcol, $ycol, $tformat, $oldest, $key);

  # Set the reference time to a new value - note time is in MJD!
#  $self->_monitor_posn( $key, $newdata[-1]->[0])
#    if @newdata;

  # return the answer (time is in MJD)
  return map { [ $_->[0], $_->[1] ] } @newdata;
}

=item B<readsimple>

A method for returning the two columns of data of interest.

  @data = $self->readsimple( $tcol, $ycol, $id, $tformat, $oldest);

where $tcol is the index of the column representing time, $ycol
is the index of the column, etc

=cut

sub readsimple {
  my $self = shift;

  # Fail if less than 6 parameters are present
  $self->_checkparams( 6, \@_ );
  my ($id, $tcol, $ycol, $tformat, $oldest, $key) = @_;

  # Get the filename and see if it is present
  my $file = $self->filename;
  return () unless (-e $file);

  # open the file
  open my $handle, "< $file"
    or throw JAC::StripChart::Error::FileNotFound("Error opening file $file: $!");

  my @plotdata;

  # Read successive lines from file
  while (my $line = <$handle>) {
    next if $line =~ /^\#/; # Skip lines beginning with a #
    $line =~ s/^\s+//g;     # Delete leading blanks
    my @data = split(/\s+/,$line);

    # Convert time data to MJD
    my $tdata = $self->_convert_to_mjd($data[$tcol-1], $tformat);
    # String comparison of time in case time format includes non digits.
    next if $tdata lt $oldest;
    push (@plotdata, [ $tdata, $data[$ycol-1] ]);
#    push (@plotdata, [ $data[$tcol-1], $data[$ycol-1] ]);
    $self->_monitor_posn( $key, $data[$tcol-1]);
  }

  close($handle);
  # update the last_read time
  $self->last_read( time() );

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

=item B<_checkparams>

Private routine to check parameter counts.

  $sf->_checkparams( 4, \@_ );

Will make sure that @_ contains exactly 4 arguments.

=cut

sub _checkparams {
  my $self = shift;
  my ($nparams, $args) = @_;

  # Find the caller subroutine
  my @call = caller(1);
  my $sub = $call[3];

  # Calculate number of arguments present
  my $nfound = scalar(@$args);

  throw JAC::StripChart::Error::BadArgs("Incorrect number of parameters supplied in call to $sub (need $nparams, found $nfound)")
    if ($nfound != $nparams);
}

=item B<_convert_to_mjd>

Routine to convert time format to MJD

  my $mjdtime = _convert_to_mjd($timedata, $tformat);

$timedate is a string containing the data/time information which is
split along specific types of separator (:, / and - allowed).

=cut

sub _convert_to_mjd {
  my $self = shift;
  my ($datetime, $tformat) = @_;
  my ($day, $month, $year, $hour, $minute, $seconds, 
      $separator, $frac, $mjd);

  # Find separator
  ($separator = $datetime) =~ s/[\d+\.]//g;

  # ORACTIME should not have a separator...
  if ($tformat =~ /ora/i && $separator ne "") {
    warnings::warnif("Time format does not look like ORACTIME");
      return;
  }

  # Trim separator string to just 1st character
  if ($separator eq "") {
    $separator = " ";
  } else {
    $separator = substr($separator,0,1);
  }
#  print $tformat ." ". $datetime ." ". $separator." ...\n";

  # Check separator is a legal one, if present (ORACTIME and MJD have no separators)
  warnings::warnif("Unknown separator - unable to parse time string") unless ($separator =~ /[:\/-]|[\s]/);

  if ($tformat =~ /mjd/i) {
    return $datetime;
  } else {
    if ($tformat =~ /ora/i) {
#      print $datetime ."\n";
      $day = substr($datetime,6,2);
      $month = substr($datetime,4,2);
      $year = substr($datetime,0,4);
      $frac = $datetime - int($datetime);
    } else {
      my @datetime = split(/$separator/,$datetime);
      if (scalar(@datetime) != 6 && scalar(@datetime) != 3) {
	warnings::warnif("Date/Time does not appear to be a known format - unable to continue");
	  return;
      }
      if ($tformat =~ /dmy/i) {
	($day, $month, $year, $hour, $minute, $seconds) = @datetime;
      } elsif ($tformat =~ /mdy/i) {
	($month, $day, $year, $hour, $minute, $seconds) = @datetime;
      } elsif ($tformat =~ /ymd/i) {
	($year, $month, $day, $hour, $minute, $seconds) = @datetime;
      } elsif ($tformat =~ /hms/i) {
	my $curdate = gmtime;
	my @datestring = split(/-/,$curdate->ymd); # By default, $curdate has `-' for a separator
	($year, $month, $day) = @datestring;
	($hour, $minute, $seconds) = @datetime;
      } else {
	warnings::warnif("Unknown time format - something has gone wrong here.");
      }
    }
    # Convert date to MJD number
    Astro::SLA::slaCldj( $year, $month, $day, $mjd, my $j );
    warnings::warnif("Bad status in convert_to_mjd from slaCldj: $j")
      unless $j == 0;
    # Calculate day fraction unless already calculated above
    Astro::SLA::slaDtf2d( $hour, $minute, $seconds, $frac, $j)
      unless defined $frac;
    warnings::warnif("Bad status in convert_to_mjd from slaDtf2d: $j")
      unless $j == 0;

    $mjd += $frac;
  }

  return $mjd;
}


=back

=head2 Class Method

=over 4

=item B<_abs_path>

Internal method to attach path to a specified file location.

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

=item B<last_write>

Internal method to determine the time a file was last written to. Uses the 
File::stat module. 

  my $last_write_time = $self->last_write($self->filename);

=cut

sub last_write {
  my $self = shift;
  my $file = shift;
  my $inode = stat($file);
  return $inode->mtime;
}

=back

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
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

=cut

1;
