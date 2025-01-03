#!/usr/bin/env perl
# Copyright [2016-2025] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use warnings;
use strict;
use Getopt::Long;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::Utils::MetadataJsonLoader
  qw/load_json/;
use Log::Log4perl qw/:easy/;

my $opts = {};
GetOptions( $opts, 'metadata_uri=s','json_location=s','release_date=s','e_release=s','eg_release=s','current_release=s','email=s','comment=s','update_type=s','source=s','verbose' );

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger;
if ( !defined $opts->{metadata_uri} || !defined $opts->{json_location}) {
  croak "Usage: metadata_updater.pl -metadata_uri <mysql://user:password\@host:port/metadata_db_name> -json_location '/nfs/json.json' -e_release 92 [-eg_release 39] -release_date 2018-04-04 -current_release 1 -email john.doe\@ebi.ac.uk -comment 'loading database for 91' -update_type 'Other' -source 'Handover' [-verbose]";
}

#Process the given database
load_json($opts->{metadata_uri}, $opts->{json_location},$opts->{release_date},$opts->{e_release}, $opts->{eg_release}, $opts->{current_release},$opts->{email},$opts->{comment},$opts->{update_type},$opts->{source},$opts->{verbose});
