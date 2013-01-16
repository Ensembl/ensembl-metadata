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

This script is used to generate a text summary of all the genomes loaded into ENA Bacteria.

=head1 AUTHOR

dstaines

=head1 MAINTANER

$Author$

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Pod::Usage;
use Bio::EnsEMBL::LookUp;
use Bio::EnsEMBL::Utils::CliHelper;
use Log::Log4perl qw(:easy);

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = $cli_helper->get_dba_opts();
push( @{$optsd}, "nocache" );
push( @{$optsd}, "url:s" );

my $opts = $cli_helper->process_args( $optsd, \&pod2usage );

my $helper;
if ( defined $opts->{url} ) {
    $helper = Bio::EnsEMBL::LookUp->new(
                      -URL => $opts->{url},-NO_CACHE => 1);
} else {
    Bio::EnsEMBL::LookUp->register_all_dbs(
                           $opts->{host}, $opts->{port}, $opts->{user},
                           $opts->{pass}, $opts->{pattern} );
    $helper = Bio::EnsEMBL::LookUp->new(
                                                -NO_CACHE => $opts->{nocache} );
}
my $report;
for my $dbc ( @{ $helper->get_all_DBConnections() } ) {

    print "Processing " . $dbc->dbname() . "\n";

    $report->{databases}++;

    if ( !defined $report->{ena_version} ) {
        $dbc->dbname() =~
          m/ena_[0-9]+_collection_core_([0-9]+)_([0-9]+)_[0-9]+/;
        $report->{ena_version} = $1;
        $report->{ens_version} = $2;
    }

    # count genomes count(distinct(species_id))
    $report->{genomes} +=
      $dbc->sql_helper()
      ->execute_single_result(
"select count(distinct(species_id)) from meta where species_id is not null" );
    # count eubacteria species.classification Bacteria
    $report->{eubacteria} +=
      $dbc->sql_helper()
      ->execute_single_result(
"select count(*) from meta where meta_key='species.classification' and meta_value='Bacteria'"
      );
    # count archaea species.classification Archaea
    $report->{archaea} +=
      $dbc->sql_helper()
      ->execute_single_result(
"select count(*) from meta where meta_key='species.classification' and meta_value='Archaea'"
      );
    # count genes by biotype
    my $genes =
      $dbc->sql_helper()
      ->execute_into_hash("select biotype,count(*) from gene group by biotype");
    for my $biotype ( keys %$genes ) {
        $report->{$biotype} += $genes->{$biotype};
    }
    # count seq_regions for ENA
    $report->{seq_regions} +=
      $dbc->sql_helper()
      ->execute_single_result(
"select count(*) from seq_region join seq_region_attrib using (seq_region_id) where value='ENA'"
      );

} ## end for my $dbc ( @{ $helper...})

my $news = <<END;
The current release of Ensembl Bacteria has been loaded from EMBL-Bank release $report->{ena_version} into $report->{databases} multispecies Ensembl v$report->{ens_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{eubacteria} eubacteria and $report->{archaea} archaea) containing $report->{protein_coding} protein coding genes loaded from $report->{seq_regions} INSDC entries.
END

print $news;
