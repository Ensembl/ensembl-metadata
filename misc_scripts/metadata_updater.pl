#!/usr/bin/env perl
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::MetaData::MetadataUpdater
  qw/process_database/;
use Log::Log4perl qw/:easy/;

my $opts = {};
GetOptions( $opts, 'metadata_uri=s','database_uri=s','species=s','db_type=s','release_date=s','e_release=s','eg_release=s','current_release=s','verbose' );

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger;
if(!defined $opts->{species} and $opts->{db_type} eq "compara"){
  croak "Usage: metadata_updater.pl -metadata_uri <mysql://user:password\@host:port/metadata_db_name> -database_uri <mysql://user:password\@host:port/ensembl_compara_92> -db_type compara -species multi -e_release 92 [-eg_release 39] -release_date 2018-04-04 -current_release 1 [-verbose]";
}
elsif (!defined $opts->{species} and $opts->{db_type} ne "compara") {
  croak "Usage: metadata_updater.pl -metadata_uri <mysql://user:password\@host:port/metadata_db_name> -database_uri <mysql://user:password\@host:port/homo_sapiens_core_92_38> -db_type core -species homo_sapiens -e_release 92 [-eg_release 39] -release_date 2018-04-04 -current_release 1 [-verbose]";
}
if ( !defined $opts->{metadata_uri} || !defined $opts->{database_uri} || !defined $opts->{e_release}) {
  croak "Usage: metadata_updater.pl -metadata_uri <mysql://user:password\@host:port/metadata_db_name> -database_uri <mysql://user:password\@host:port/homo_sapiens_core_92_38> -db_type core -species homo_sapiens -e_release 92 [-eg_release 39] -release_date 2018-04-04 -current_release 1 [-verbose]";
}

#Process the given database
process_database($opts->{metadata_uri}, $opts->{database_uri},$opts->{species},$opts->{db_type},$opts->{release_date},$opts->{e_release}, $opts->{eg_release}, $opts->{current_release},  $opts->{verbose});
