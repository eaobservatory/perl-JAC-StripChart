use ExtUtils::MakeMaker;
use strict;

WriteMakefile( 
               'NAME'           => 'JAC::StripChart',
               'VERSION'        => '0.01',
               'PREREQ_PM'      => {
				    'Graphics::PLplot' => '0.01',
                                   },
               'dist'           => { COMPRESS => "gzip -9f"},
               ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
               ( ABSTRACT  => 'JAC ORAC-DR StripChart utility',
                 AUTHOR         => 'Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>') : ()),
             );
