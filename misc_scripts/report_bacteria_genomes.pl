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

This script is used to find which genomes have changed between two releases of Ensembl Bacteria

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
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts("prev")}, @{$cli_helper->get_dba_opts()}];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);

my $dbc      = Bio::EnsEMBL::DBSQL::DBConnection->new(-USER => $opts->{user},     -PASS => $opts->{pass},     -HOST => $opts->{host},     -PORT => $opts->{port});
my $prev_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(-USER => $opts->{prevuser}, -PASS => $opts->{prevpass}, -HOST => $opts->{prevhost}, -PORT => $opts->{prevport});
my $genomes  = genome_details($dbc);
my $prev_genomes = genome_details($prev_dbc);

# new genomes
my $new_genomes = [];
# genomes with new assemblies
my $new_assemblies = [];
# genomes with new genebuilds
my $new_genebuilds = [];
# genomes with updated genebuild version (==annotation)
my $new_annotations = [];
# renamed genomes
my $renamed_genomes = [];
# removed genomes
my $removed_genomes = [];
while (my ($set_chain, $genome) = each %{$genomes->{genomes}}) {
  my $prev_genome = $prev_genomes->{genomes}->{$set_chain};
  if (!defined $prev_genome) {
	push @$new_genomes, $genome;
  } else {
	if ($genome->{name} ne $prev_genome->{name}) {
	  push @$renamed_genomes, {new => $genome, old => $prev_genome};
	}
	if ($genome->{assembly} ne $prev_genome->{assembly}) {
	  push @$new_assemblies, {new => $genome, old => $prev_genome};
	} elsif ($genome->{genebuild_version} ne $prev_genome->{genebuild_version}) {
	  push @$new_annotations, {new => $genome, old => $prev_genome};
	}
  }
}

while (my ($set_chain, $genome) = each %{$prev_genomes->{genomes}}) {
  if (!defined $genomes->{genomes}->{$set_chain}) {
	push @$removed_genomes, $genome;
  }
}

# print to file
# new genomes
# name assembly database species_id
write_to_file(
  $new_genomes,
  "new_genomes.txt",
  [qw/name assembly database species_id/],
  sub {
	return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{database}, $_[0]->{species_id}];
  });

# updated assemblies
# name old_assembly new_assembly database species_id
write_to_file(
  $new_assemblies,
  "updated_assemblies.txt",
  [qw/name assembly old_assembly  database species_id/],
  sub {
	return [$_[0]->{new}->{name}, $_[0]->{new}->{assembly}, $_[0]->{old}->{assembly}, $_[0]->{new}->{database}, $_[0]->{new}->{species_id}];
  });

# updated annotation
# name assembly old_genebuild new_genebuild database species_id
write_to_file(
  $new_annotations,
  "updated_annotations.txt",
  [qw/name assembly old_genebuild new_genebuild database species_id/],
  sub {
	return [$_[0]->{new}->{name}, $_[0]->{new}->{assembly}, $_[0]->{new}->{genebuild_version}, $_[0]->{old}->{genebuild_version}, $_[0]->{new}->{database}, $_[0]->{new}->{species_id}];
  });

# renamed genomes
# name assembly old_name database species_id
write_to_file(
  $renamed_genomes,
  "renamed_genomes.txt",
  [qw/ name assembly old_name database species_id /],
  sub {
	return [$_[0]->{new}->{name}, $_[0]->{new}->{assembly}, $_[0]->{old}->{name}, $_[0]->{new}->{database}, $_[0]->{new}->{species_id}];
  });

# removed genomes
# name assembly database species_id
write_to_file(
  $removed_genomes,
  "removed_genomes.txt",
  [qw/ name assembly database species_id /],
  sub {
	return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{database}, $_[0]->{species_id}];
  });

my $report = $genomes->{report};
$report->{new_genomes}     = scalar @$new_genomes;
$report->{new_assemblies}  = scalar @$new_assemblies;
$report->{new_annotations} = scalar @$new_annotations;
$report->{renamed_genomes} = scalar @$renamed_genomes;
$report->{removed_genomes} = scalar @$removed_genomes;

my $summary_file = "summary.txt";
$logger->info("Writing summary to $summary_file");
my $news = <<END;
Release $report->{eg_version} Ensembl Bacteria has been loaded from EMBL-Bank release XXX into $report->{databases} multispecies Ensembl v$report->{ens_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{eubacteria} eubacteria and $report->{archaea} archaea) containing $report->{protein_coding} protein coding genes loaded from $report->{seq_regions} INSDC entries. This release includes $report->{new_genomes} new genomes, $report->{new_assemblies} genomes with updated assemblies, $report->{new_annotations} genomes with updated annotation, $report->{renamed_genomes} genomes where the assigned name has changed, and $report->{removed_genomes} genomes removed since the last release.
END
open my $summary, ">", "$summary_file" || croak "Could not open $summary_file for writing";
print $summary $news;
close $summary;

sub write_to_file {
  my ($data, $file_name, $header, $callback) = @_;
  $logger->info("Writing to $file_name");
  open my $file, ">", $file_name or croak "Could not open output file $file_name";
  print $file "#".join("\t", @{$header}) . "\n";
  for my $datum (@{$data}) {
	print $file join("\t", @{$callback->($datum)}) . "\n";
  }
  close $file;
}

sub genome_details {
  my ($dbc)   = @_;
  my $genomes = {};
  my $report  = {};
  # get list of all databases
  for my $db_name (grep { m/bacteria_[0-9]+_collection_core_/ } @{$dbc->sql_helper()->execute_simple(-SQL => "show databases")}) {
	$logger->info("Querying $db_name");
	$dbc->sql_helper()->execute_no_return(
	  -SQL => qq/
	 select '$db_name',
   species_id,
   a.meta_value,
   n.meta_value,
   n2.meta_value,
   g.meta_value,
   g2.meta_value from $db_name.meta a 
   join $db_name.meta n using(species_id) 
   join $db_name.meta n2 using(species_id) 
   join $db_name.meta g using(species_id) 
   join $db_name.meta g2 using(species_id) 
   where a.meta_key = 'assembly.accession'
	 and n.meta_key  = 'species.production_name'
	 and n2.meta_key = 'species.display_name'
	 and g.meta_key  = 'genebuild.hash'
	 and g2.meta_key = 'genebuild.version'/,
	  -CALLBACK => sub {
		my ($database, $species_id, $assembly, $name, $full_name, $genebuild, $genebuild_version) = @{$_[0]};
		$report->{genomes}++;
		my ($set_chain, $version) = split ('\\.', $assembly);
		$genomes->{$set_chain} = {set_chain         => $set_chain,
								  version           => $version,
								  assembly          => $assembly,
								  name              => $name,
								  full_name         => $full_name,
								  genebuild         => $genebuild,
								  genebuild_version => $genebuild_version,
								  database          => $database,
								  species_id        => $species_id};
		return;
	  });

	$report->{databases}++;

	if (!defined $report->{eg_version}) {
	  $db_name =~ m/bacteria_[0-9]+_collection_core_([0-9]+)_([0-9]+)_[0-9]+/;
	  $report->{eg_version}  = $1;
	  $report->{ens_version} = $2;
	}

	# count eubacteria species.classification Bacteria
	$report->{eubacteria} += $dbc->sql_helper()->execute_single_result("select count(*) from $db_name.meta where meta_key='species.classification' and meta_value='Bacteria'");
	# count archaea species.classification Archaea
	$report->{archaea} += $dbc->sql_helper()->execute_single_result("select count(*) from $db_name.meta where meta_key='species.classification' and meta_value='Archaea'");
	# count genes by biotype
	my $genes = $dbc->sql_helper()->execute_into_hash("select biotype,count(*) from $db_name.gene group by biotype");
	for my $biotype (keys %$genes) {
	  $report->{$biotype} += $genes->{$biotype};
	}
	# count seq_regions for ENA
	$report->{seq_regions} += $dbc->sql_helper()->execute_single_result("select count(*) from $db_name.seq_region join $db_name.seq_region_attrib using (seq_region_id) where value='ENA'");
  } ## end for my $db_name (grep {...})
  return {genomes => $genomes, report => $report};
} ## end sub genome_details
