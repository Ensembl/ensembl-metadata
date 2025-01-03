#!/usr/bin/env perl

=head1 LICENSE

Copyright [2009-2025] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to generate a summary of key metadata for ENA bacteria in JSON and XML.

=head1 EXAMPLE

To dump the metadata for a new Ensembl Genomes release as tt2:
perl dump_metadata.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::MetaData::MetaDataDumper::TT2MetaDataDumper

To dump the metadata for a new Ensembl Genomes release as txt:
perl dump_metadata.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::MetaData::MetaDataDumper::TextMetaDataDumper
	
=head1 USAGE

  --user=user                      username for the genome_info database server

  --pass=pass                      password for genome_info database server

  --host=host                      genome_info database server 

  --port=port                      port for genome_info database server 

  --dbname=dbname                     port for genome_info database server 
  
  --dumper=dumper				     dumper to use (must extend Bio::EnsEMBL::MetaData::MetaDataDumper)

  --release=release            release version for the dump, if not defined current release will be used

=head1 AUTHOR

Dan Staines

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::CliHelper;
use Carp;
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Module::Load;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release);

use Data::Dumper;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [ @{ $cli_helper->get_dba_opts() } ];
push( @{$optsd}, "dumper:s@" );
push( @{$optsd}, "division:s@" );
push( @{$optsd}, "verbose" );
push ( @{$optsd}, "release:i" );
push ( @{$optsd}, "dump_path:s" );

my $opts = $cli_helper->process_args( $optsd, \&pod2usage );

if ( defined $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

$opts->{dbname} ||= 'ensembl_metadata';

$opts->{dump_path} ||= './';

my ($args) = @{ $cli_helper->get_dba_args_for_opts( $opts, 1 ) };
my $metadatadba=Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args);
my $gdba = $metadatadba->get_GenomeInfoAdaptor();
my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();

#Get the release for the given division
my ($release,$release_info);
($rdba,$gdba,$release,$release_info) = fetch_and_set_release($opts->{release},$rdba,$gdba);
$logger->info("Getting genomes from release ".$opts->{release}) if defined $opts->{release} || $logger->info("Getting genomes from current release");

# get all metadata
my $dump_all = 0;
if ( !defined $opts->{division} || scalar( @{ $opts->{division} } ) == 0 ) {
  $opts->{division} = $gdba->list_divisions();
  $dump_all = 1;
}
elsif(scalar( @{ $opts->{division} } ) > 1){
  $dump_all = 1;
}

my @metadata = ();
my $division_list = [];
for my $div ( @{ $opts->{division} } ) {
  #Get both division short and full name from a division short or full name
  my ($division,$division_name)=process_division_names($div);
  $logger->info("Fetching metadata for $division");
  push $division_list, $division_name;
  @metadata = ( @{ $gdba->fetch_all_by_division($division_name, 1) }, @metadata );
}
$logger->info( "Retrieved metadata for " . scalar(@metadata) . " genomes" );
@metadata =
  sort { $b->division() cmp $a->division() or $b->name() cmp $a->name() }
  @metadata;

# create dumper
$opts->{dumper} ||=
  ['Bio::EnsEMBL::MetaData::MetaDataDumper::JsonMetaDataDumper'];

my @dumpers = map { print "Loading $_"; load $_; $_->new() } @{ $opts->{dumper} };

# start dumpers
$logger->info("Starting dumpers");
for my $dumper (@dumpers) {
  $dumper->start( $division_list, $opts->{dump_path}, $dumper->{file}, $dump_all );
}
# process metadata
$logger->info("Writing metadata");
while ( my $md = pop(@metadata) ) {
  for my $dumper (@dumpers) {
    $logger->debug(
                 "Dumping metadata " . $md->name() . " using " . ref($dumper) );
    if ( $dump_all == 1 ) {
      $logger->debug(
        "Dumping metadata " . $md->name() . " to ' all
  ' file using " . ref($dumper) );

      $dumper->write_metadata( $md, $dumper->{all} );
    }
    $logger->debug(
              "Dumping metadata " . $md->name() . " to divisional file using " .
                ref($dumper) );

    $dumper->write_metadata( $md, $md->{division} );
  }
  # unload to reduce memory consumption
  $md->_unload();
}

$logger->info("Closing dumpers");
# finish dumpers
for my $dumper (@dumpers) {
  $dumper->end();
}

$logger->info("Completed dumping");
