#!/usr/bin/env perl

=head1 LICENSE

  Copyright (c) 1999-2014 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 DESCRIPTION

This script is used to generate a summary of key metadata for ENA bacteria in JSON and XML.

=head1 EXAMPLE

To dump the metadata for a new Ensembl Genomes release as tt2:
perl load_metadata_db.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TT2MetaDataDumper

To dump the metadata for a new Ensembl Genomes release as txt:
perl load_metadata_db.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TextMetaDataDumper
	
=head1 USAGE

  --user=user                      username for the release database server

  --pass=pass                      password for release database server

  --host=host                      release database server 

  --port=port                      port for release database server 
  
  --mdriver=dbname                  driver to use for production database

  --muser=user                      username for the production database

  --mpass=pass                      password for production database

  --mhost=host                      server where the production database is stored

  --mport=port                      port for production database
  
  --mdbname=dbname                  name/SID of production database to process

  --mdriver=dbname                  driver to use for production database

  --mdriver=dbname                  driver to use for production database

  --guser=user                      username for the metadata database

  --gpass=pass                      password for metadata database

  --ghost=host                      server where the metadata database is stored

  --gport=port                      port for metadata database
  
  --gdbname=dbname                  name/SID of metadata database to process

  --gdriver=dbname                  driver to use for metadata database
  
  --url=url							ENA genomes registry URL (use with Bio::EnsEMBL::Utils::MetaData::DBAFinder::EnaDBAFinder)

  --finder=finder				     finder to use (must extend Bio::EnsEMBL::Utils::MetaData::DBAFinder)

  --processor=processor				     processor to use (must extend Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor)

  --force_update				     If information already exists for a species/database, replace


=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::CliHelper;
use Carp;
use Log::Log4perl qw(:easy);
use Pod::Usage;
use Data::Dumper;
use Module::Load;
use Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::DBSQL::DBConnection;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [ @{ $cli_helper->get_dba_opts() },
			  @{ $cli_helper->get_dba_opts('m') },
			  @{ $cli_helper->get_dba_opts('g') } ];
push( @{$optsd}, "nocache" );
push( @{$optsd}, "url:s" );
push( @{$optsd}, "finder:s" );
push( @{$optsd}, "processor:s" );
push( @{$optsd}, "contigs" );
push( @{$optsd}, "annotation" );
push( @{$optsd}, "registry:s" );
push( @{$optsd}, "species:s" );
push( @{$optsd}, "division:s" );
push( @{$optsd}, "verbose" );
push( @{$optsd}, "force_update" );

my $opts = $cli_helper->process_args( $optsd, \&pod2usage );

if ( defined $opts->{verbose} ) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

my $gdba =
  Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(
							   -DBC =>
								 Bio::EnsEMBL::DBSQL::DBConnection->new(
														-USER =>,
														$opts->{guser},
														-PASS =>,
														$opts->{gpass},
														-HOST =>,
														$opts->{ghost},
														-PORT =>,
														$opts->{gport},
														-DBNAME =>,
														$opts->{gdbname}
								 ) );

my %processor_opts =
  map { my $key = '-' . uc($_); $key => $opts->{$_} } keys %$opts;

# create DBAFinder
$opts->{finder} ||=
  'Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder';
$logger->info("Retrieving DBAs using $opts->{finder}");
load $opts->{finder};
my $finder = $opts->{finder}->new(%processor_opts);
my $dbas   = $finder->get_dbas();
$logger->info( "Retrieved " . scalar(@$dbas) . " DBAs" );

# create processor
$opts->{processor} ||=
  'Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor';
load $opts->{processor};
$logger->info("Processing DBAs using $opts->{processor}");
if ( $opts->{annotation} ) {
  $processor_opts{-ANNOTATION_ANALYZER} =
	Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer->new();
}
$processor_opts{-INFO_ADAPTOR} = $gdba;
my $processor = $opts->{processor}->new(%processor_opts);
my $details   = $processor->process_metadata($dbas);
$logger->info("Completed processing");
for my $md ( @{$details} ) {
	# if the species has been stored and we want to force an update, update it
	# otherwise only store if its not been seen already
  if ( defined $md->dbID() && defined $opts->{force_update} ) {
	$logger->info( "Updating " . $md->species() );
	$gdba->update($md);
  }
  elsif ( !defined $md->dbID() ) {
	$logger->info( "Storing " . $md->species() );
	$gdba->store($md);
  }
  # if we're not just updating a single species, update compara too
  if ( !defined $opts->{species} && defined $md->compara() ) {
	for my $compara ( @{ $md->compara() } ) {
	  if ( defined $compara->dbID() && defined $opts->{force_update} ) {
		$logger->info( "Updating compara " . $compara->to_string() );
		$gdba->update_compara($compara);
	  }
	  elsif ( !defined $compara->dbID() ) {
		$logger->info( "Storing " . $compara->to_string() );
		$gdba->store_compara($compara);
	  }
	}
  }
}

$logger->info("Metadata load complete");
