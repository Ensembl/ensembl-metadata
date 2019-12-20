#!/usr/bin/env perl
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to populate the metadata database with given databases

=head1 SYNOPSIS

perl metadata_updater.pl  -metadata_uri $(mysql-ens-general-dev-2 details uri)ensembl_metadata \
   -database_uri $(mysql-ens-general-dev-2 details url)homo_sapiens_core_100_38 \
   -e_release 100 -eg_release 47 -release_date 2019-03-15 -current_release 1 \
   -email joe.bloggs@ebi.ac.uk -comment 'Loading human for 100' -source 'Manual'

=head1 OPTIONS

=over 8

=item B<-M[etadata_uri]> <metadata_uri>

Mandatory. URI of the metadata database. e.g(mysql://ensro@mysql-ens-general-dev-2:4586/ensembl_metadata)

=item B<-D[atabase_uri]> <database_uri>

Mandatory. URI of the database to load into metadata. e.g(mysql://ensro@mysql-ens-general-dev-2:4586/homo_sapiens_core_100_38)

=item B<-E[_release]> <e_release>

Mandatory. Vertebrates release number

=item B<-EG[_release]> <eg_release>

Mandatory. Non-vertebrates release number

=item B<-R[elease_date]> <release_date>

Date of the release

=item B<-C[urrent_release]> <current_release> [0|1]

Flag to specify if this is the current release

=item B<-Em[ail]> <email>

Email of the person submitting the database

=item B<-C[omment]> <comment>

Description of what the database is

=item B<-S[ource]> <source>

Source of the handover, manual or handover

=item B<-m[man]>

Print full usage information.

=back

=head1 AUTHOR

tmaurel

=head1 MAINTANER

tmaurel

=head1 VERSION

$Revision$
=cut

use warnings;
use strict;
use Getopt::Long;
use Carp;
use Data::Dumper;
use Bio::EnsEMBL::MetaData::MetadataUpdater
  qw/process_database/;
use Log::Log4perl qw/:easy/;

my $opts = {};
GetOptions( $opts, 'metadata_uri=s','database_uri=s','release_date=s','e_release=s','eg_release=s','current_release=s','email=s','comment=s','source=s','verbose' );

if ( $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger;
if ( !defined $opts->{metadata_uri} || !defined $opts->{database_uri}) {
  croak "Usage: metadata_updater.pl -metadata_uri <mysql://user:password\@host:port/metadata_db_name> -database_uri <mysql://user:password\@host:port/homo_sapiens_core_92_38> -e_release 92 -eg_release 39 -release_date 2018-04-04 -current_release 1 -email john.doe\@ebi.ac.uk -comment 'loading database for 91' -source 'Handover' [-verbose]";
}

#Process the given database
process_database($opts->{metadata_uri}, $opts->{database_uri},$opts->{release_date},$opts->{e_release}, $opts->{eg_release}, $opts->{current_release},$opts->{email},$opts->{comment},$opts->{source},$opts->{verbose});
