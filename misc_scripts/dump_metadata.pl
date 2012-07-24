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

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = $cli_helper->get_dba_opts();
push( @{$optsd}, "nocache" );
push( @{$optsd}, "url" );
push( @{$optsd}, "finder:s" );
push( @{$optsd}, "dumper:s" );
push( @{$optsd}, "processor:s" );
push( @{$optsd}, "contigs" );

my $opts = $cli_helper->process_args( $optsd, \&pod2usage );

$opts->{finder} ||= 'Bio::EnsEMBL::Utils::MetaData::DBAFinder::DbHostDBAFinder';
load $opts->{finder};
$opts->{dumper} ||= 'Bio::EnsEMBL::Utils::MetaData::MetaDataDumper::JsonMetaDataDumper';
load $opts->{dumper};
$opts->{processor} ||= 'Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor';
load $opts->{processor};

my %ens_opts = map {my $key = '-'.uc($_); $key=>$opts->{$_}} keys %$opts;

# create DBAFinder
my $finder = $opts->{finder}->new(%ens_opts);
# create processor
my $processor = $opts->{processor}->new(%ens_opts);
# create dumper
my $dumper = $opts->{dumper}->new(%ens_opts);
my $dbas =  $finder->get_dbas();
my $details = $processor->process_metadata($dbas);
$dumper->dump_metadata($details);