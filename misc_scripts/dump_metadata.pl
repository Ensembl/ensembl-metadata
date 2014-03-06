#!/usr/bin/env perl

=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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
perl dump_metadata.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TT2MetaDataDumper

To dump the metadata for a new Ensembl Genomes release as txt:
perl dump_metadata.pl -host mysql-eg-staging-2.ebi.ac.uk -port 4275 -user ensro \
	-mhost mysql-eg-pan-1.ebi.ac.uk -mport 4276 -muser ensro -mdbname ensembl_production \
	-dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TextMetaDataDumper
	
=head1 USAGE

  --user=user                      username for the genome_info database server

  --pass=pass                      password for genome_info database server

  --host=host                      genome_info database server 

  --port=port                      port for genome_info database server 

  --dbname=dbname                     port for genome_info database server 
  
  --dumper=dumper				     dumper to use (must extend Bio::EnsEMBL::Utils::MetaData::MetaDataDumper)

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
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::DBSQL::DBConnection;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}];
push(@{$optsd}, "dumper:s@");
push(@{$optsd}, "division:s");
push(@{$optsd}, "verbose");

my $opts = $cli_helper->process_args($optsd, \&pod2usage);

if (defined $opts->{verbose}) {
  Log::Log4perl->easy_init($DEBUG);
}
else {
  Log::Log4perl->easy_init($INFO);
}
my $logger = get_logger();

my ($dba) = @{$cli_helper->get_dbas_for_opts($opts,1)};
my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(
												   -DBC => $dba->dbc());
# get all metadata
my $metadata = [];
if (defined $opts->{division}) {
  $logger->info("Fetching metadata for " . $opts->{division});
  $metadata = $gdba->fetch_by_division($opts->{division});
}
else {
  $logger->info("Fetching all metadata");
  $metadata = $gdba->fetch_all();
}

$metadata = [grep { $_->division() ne 'Ensembl' } @$metadata];

# create dumper
$opts->{dumper} ||=
  ['Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::JsonMetaDataDumper'];
for my $dumper_module (@{$opts->{dumper}}) {
  load $dumper_module;
  my $dumper = $dumper_module->new();
  if (!defined $opts->{division}) {
	$logger->info("Dumping metadata using $dumper");
	$dumper->dump_metadata($metadata, $dumper->{file});
  }
  $logger->info("Dumping per-division metadata using $dumper");
  $dumper->dump_metadata($metadata, $dumper->{file}, 1);
}
$logger->info("Completed dumping");
