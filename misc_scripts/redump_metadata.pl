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

This script is used to reggenerate metadata files using an existing JSON file (so databases do not need touching)

=head1 EXAMPLE

To redump the metadata for a new Ensembl Genomes release as tt2:
perl redump_metadata.pl -json species_metadata.json -dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TT2MetaDataDumper

perl redump_metadata.pl -json species_metadata.json -dumper Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::TextMetaDataDumper
	
=head1 USAGE

  --json_file
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
use JSON;

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [ "dumper:s@", "json_file:s", "verbose"];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);

if(defined $opts->{verbose}) {
	Log::Log4perl->easy_init($DEBUG);	
} else {
	Log::Log4perl->easy_init($INFO);
}

my $logger = get_logger();
my $json;
$logger->info("Reading JSON file ".$opts->{json_file});
{
  local $/ = undef;
  open FILE, $opts->{json_file} or die "Couldn't open file: $!";
  binmode FILE;
  $json = <FILE>;
  close FILE;
}
$logger->info("Parsing JSON");
my $metadata = from_json($json);

# create dumper
$opts->{dumper} ||= ['Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::JsonMetaDataDumper'];
for my $dumper_module (@{$opts->{dumper}}) {
  load $dumper_module;
  my $dumper = $dumper_module->new();
  $logger->info("Dumping metadata using $dumper");
  $dumper->dump_metadata($metadata);
}
$logger->info("Completed dumping");
