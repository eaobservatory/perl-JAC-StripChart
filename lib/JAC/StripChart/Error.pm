package JAC::StripChart::Error;

=head1 NAME

JAC::StripChart::Error - Exception handling in an object orientated manner.

=head1 SYNOPSIS

    use JAC::StripChart::Error qw /:try/;
    use JAC::StripChart::Constants qw /:status/;

    # throw an error to be caught
    throw JAC::StripChart::Error::AuthenticationFail( $message, OMP__AUTHFAIL );
    throw JAC::StripChart::Error::FatalError( $message, OMP__FATAL );

    # record and then retrieve an error
    do_stuff();
    my $Error = JAC::StripChart::Error->prior;
    JAC::StripChart::Error->flush if defined $Error;

    sub do_stuff {
        record JAC::StripChart::Error::FatalError( $message, OMP__FATAL);
    }

    # try and catch blocks
    try {
       stuff();
    }
    catch JAC::StripChart::Error::FatalError with 
    {
        # its a fatal error
        my $Error = shift;
	orac_exit_normally($Error);
    }
    otherwise 
    {
       # this block catches croaks and other dies
       my $Error = shift;
       orac_exit_normally($Error);

    }; # Dont forget the trailing semi-colon to close the catch block

=head1 DESCRIPTION

C<JAC::StripChart::Error> inherits from the L<Error|Error> class and more
documentation about the (many) features present in the module but
currently unused by the OMP can be found in the documentation for that
module.

As with the C<Error> package, C<JAC::StripChart::Error> provides two
interfaces.  Firstly it provides a procedural interface to exception
handling, and secondly C<JAC::StripChart::Error> is a base class for
exceptions that can either be thrown, for subsequent catch, or can
simply be recorded.

=head1 PROCEDURAL INTERFACE

C<JAC::StripChart::Error> exports subroutines to perform exception
handling. These will be exported if the C<:try> tag is used in the
C<use> line.

=over 4

=item try BLOCK CLAUSES

C<try> is the main subroutine called by the user. All other
subroutines exported are clauses to the try subroutine.

The BLOCK will be evaluated and, if no error is throw, try will return
the result of the block.

C<CLAUSES> are the subroutines below, which describe what to do in the
event of an error being thrown within BLOCK.

=item catch CLASS with BLOCK

This clauses will cause all errors that satisfy
C<$err-E<gt>isa(CLASS)> to be caught and handled by evaluating
C<BLOCK>.

C<BLOCK> will be passed two arguments. The first will be the error
being thrown. The second is a reference to a scalar variable. If this
variable is set by the catch block then, on return from the catch
block, try will continue processing as if the catch block was never
found.

To propagate the error the catch block may call C<$err-E<gt>throw>

If the scalar reference by the second argument is not set, and the
error is not thrown. Then the current try block will return with the
result from the catch block.

=item otherwise BLOCK

Catch I<any> error by executing the code in C<BLOCK>

When evaluated C<BLOCK> will be passed one argument, which will be the
error being processed.

Only one otherwise block may be specified per try block

=back

=head1 CLASS INTERFACE

=head2 CONSTRUCTORS

The C<JAC::StripChart::Error> object is implemented as a HASH. This
HASH is initialized with the arguments that are passed to it's
constructor. The elements that are used by, or are retrievable by the
C<JAC::StripChart::Error> class are listed below, other classes may
add to these.

	-file
	-line
	-text
	-value

If C<-file> or C<-line> are not specified in the constructor arguments
then these will be initialized with the file name and line number
where the constructor was called from.

The C<JAC::StripChart::Error> package remembers the last error
created, and also the last error associated with a package.

=over 4

=item throw ( [ ARGS ] )

Create a new C<JAC::StripChart::Error> object and throw an error,
which will be caught by a surrounding C<try> block, if there is
one. Otherwise it will cause the program to exit.

C<throw> may also be called on an existing error to re-throw it.

=item with ( [ ARGS ] )

Create a new C<JAC::StripChart::Error> object and returns it. This
is defined for syntactic sugar, eg

    die with JAC::StripChart::Error::FatalError ( $message, OMP__FATAL );

=item record ( [ ARGS ] )

Create a new C<JAC::StripChart::Error> object and returns it. This
is defined for syntactic sugar, eg

  record JAC::StripChart::Error::AuthenticationFail ( $message, OMP__ABORT )
	and return;

=back

=head2 METHODS

=over 4

=item prior ( [ PACKAGE ] )

Return the last error created, or the last error associated with
C<PACKAGE>

    my $Error = JAC::StripChart::Error->prior;


=back

=head2 OVERLOAD METHODS

=over 4

=item stringify

A method that converts the object into a string. By default it returns
the C<-text> argument that was passed to the constructor, appending
the line and file where the exception was generated.

=item value

A method that will return a value that can be associated with the
error. By default this method returns the C<-value> argument that was
passed to the constructor.

=back

=head1 PRE-DEFINED ERROR CLASSES

=over 4

=item B<JAC::StripChart::Error::BadArgs>

Method was called with incorrect arguments.

=item B<JAC::StripChart::Error::BadClass>

Method was supplied with an object of the incorrect class.

=item B<JAC::StripChart::Error::BadConfig>

Configuration file was not correct.

=item B<JAC::StripChart::Error::DirectoryNotFound>

The requested directory could not be found.

=item B<JAC::StripChart::Error::FatalError>

Used when we have no choice but to abort but using a non-standard
reason. It's constructor takes two arguments. The first is a text
value, the second is a numeric value, C<OMP__FATAL>. These values are
what will be returned by the overload methods.

=item B<JAC::StripChart::Error::FileNotFound>

The requested file could not be found.

=back


=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>,
Alasdair Allan E<lt>aa@astro.ex.ac.ukE<gt>

=head1 COPYRIGHT

Copyright (C) 2001-2004 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut

use Error;
use warnings;
use strict;

use vars qw/$VERSION/;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

# flush method added to the base class
use base qw/ Error::Simple /;

package JAC::StripChart::Error::BadArgs;
use base qw/ JAC::StripChart::Error /;

package JAC::StripChart::Error::BadClass;
use base qw/ JAC::StripChart::Error /;

package JAC::StripChart::Error::BadConfig;
use base qw/ JAC::StripChart::Error /;

package JAC::StripChart::Error::DirectoryNotFound;
use base qw/ JAC::StripChart::Error /;

package JAC::StripChart::Error::FatalError;
use base qw/ JAC::StripChart::Error /;

package JAC::StripChart::Error::FileNotFound;
use base qw/ JAC::StripChart::Error /;




1;

