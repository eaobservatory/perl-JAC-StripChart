#!perl

use strict;
use warnings;
use Module::Build;

# Copyright (C) 2012 Science and Technology Facilities Council.
# All Rights Reserved.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place,Suite 330, Boston, MA 02111-1307,
# USA

# Set it up.
my $build = Module::Build->new
  (
   module_name => 'JAC::StripChart',
   license  => 'gpl',
   dist_abstract => 'Infrastructure for a stripchart',
   dist_author => [
                   'Tim Jenness <t.jenness@jach.hawaii.edu>',
                   'Brad Cavanagh <b.cavanagh@jach.hawaii.edu>',
                   'Andy Gibb <agg@phas.ubc.ca>',
                  ],
   dist_version => '0.02',
   script_files => [ qw/
                         stripchart xstripchart
                       / ],
   recommends => {
                  'PGPLOT' => 0,
                  'Graphics::PLplot' => 0,
                  'Tk' => '804.0',
                  'JCMT::Tau' => 0,
                 },
   requires => {
                'Starlink::AST' => 1.02,
                'Number::Interval' => 0,
                'List::Util' => 0,
                'Scalar::Util' => 0,
                'Color::Rgb' => 0,
                'DateTime::Format::ISO8601' => 0,
                'DateTime' => 0,
                'DateTime::TimeZone' => 0,
                'Astro::PAL' => 0,
                'Time::Piece' => 0,
                'Date::Format' => 0,
                'JAC::Setup' => 0,
                'Error' => 0,
                'Config::IniFiles' => 0,
               },
   build_requires => {
                      'Test::More' => 0,
                     },
   configure_requires => {
                          "Module::Build" => 0.30,
                         },
  );

$build->create_build_script;
