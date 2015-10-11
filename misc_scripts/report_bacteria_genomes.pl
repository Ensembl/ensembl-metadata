#!/usr/bin/env perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
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
my $optsd = [@{$cli_helper->get_dba_opts("prev")}, @{$cli_helper->get_dba_opts()}, "division:s"];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);

my $dbc      = Bio::EnsEMBL::DBSQL::DBConnection->new(-USER => $opts->{user},     -PASS => $opts->{pass},     -HOST => $opts->{host},     -PORT => $opts->{port}, -DBNAME=> $opts->{dbname});
my $prev_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(-USER => $opts->{prevuser}, -PASS => $opts->{prevpass}, -HOST => $opts->{prevhost}, -PORT => $opts->{prevport},-DBNAME=> $opts->{prevdbname});
my $genomes  = genome_details($dbc,$opts->{division});
my $prev_genomes = genome_details($prev_dbc,$opts->{division});

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
	} elsif ($genome->{genebuild} ne $prev_genome->{genebuild}) {
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
  [qw/name assembly new_genebuild old_genebuild database species_id/],
  sub {
      return [$_[0]->{new}->{name}, $_[0]->{new}->{assembly}, $_[0]->{new}->{genebuild}, $_[0]->{old}->{genebuild}, $_[0]->{new}->{database}, $_[0]->{new}->{species_id}];
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
my $news;
if($opts->{division} eq 'EnsemblBacteria') {
    my $news = <<END;
Release $report->{eg_version} of Ensembl Bacteria has been loaded from EMBL-Bank release XXX into $report->{databases} multispecies Ensembl v$report->{ens_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{eubacteria} bacteria and $report->{archaea} archaea) containing $report->{protein_coding} protein coding genes loaded from $report->{seq_regions} INSDC entries. This release includes $report->{new_genomes} new genomes, $report->{new_assemblies} genomes with updated assemblies, $report->{new_annotations} genomes with updated annotation, $report->{renamed_genomes} genomes where the assigned name has changed, and $report->{removed_genomes} genomes removed since the last release.

Ensembl Bacteria has been updated to include the latest versions of $report->{genomes} genomes ($report->{eubacteria} bacteria and $report->{archaea} archaea) from the INSDC archives.
END
} else {
    $division =~ s/Ensembl/Ensembl /;
    my $news = <<END;
Release $report->{eg_version} of Ensembl Bacteria has been loaded from EMBL-Bank release XXX into $report->{databases} multispecies Ensembl v$report->{ens_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{eubacteria} bacteria and $report->{archaea} archaea) containing $report->{protein_coding} protein coding genes loaded from $report->{seq_regions} INSDC entries. This release includes $report->{new_genomes} new genomes, $report->{new_assemblies} genomes with updated assemblies, $report->{new_annotations} genomes with updated annotation, $report->{renamed_genomes} genomes where the assigned name has changed, and $report->{removed_genomes} genomes removed since the last release.

Ensembl Bacteria has been updated to include the latest versions of $report->{genomes} genomes.
}
open my $summary, ">", "$summary_file" || croak "Could not open $summary_file for writing";
print $summary $news;
close $summary;
}

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
  my ($dbc,$division)   = @_;
  my $genomes = {};
  my $report  = {};
  my $dbs = {};
  $dbc->sql_helper()->execute_no_return(
      -SQL => qq/
	 select dbname,
   species_id,
   ifnull(assembly_id,assembly_name),
   species,
   name,
   genebuild
from genome where division=?/,
      -CALLBACK => sub {
          my ($database, $species_id, $assembly, $name, $full_name, $genebuild,$cnt) = @{$_[0]};
          $report->{genomes}++;
          $genebuild =~ s/-EnsemblBacteria/-ENA/;
          my ($set_chain, $version) = split ('\\.', $assembly);
          $genomes->{$set_chain} = {
              set_chain         => $set_chain,
              version           => $version,
              assembly          => $assembly,
              name              => $name,
              full_name         => $full_name,
              genebuild         => $genebuild,
              database          => $database,
              species_id        => $species_id};
          if (!defined $report->{eg_version}) {
              $database =~ m/.*_core_([0-9]+)_([0-9]+)_[0-9]+/;
              $report->{eg_version}  = $1;
              $report->{ens_version} = $2;
          }
          $dbs->{$database}+=1;
          return;            
      },
      -PARAMS => [$division]);
  
  if($division eq 'EnsemblBacteria') {
      for my $db_name (keys %$dbs) {
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
      }
  }
  
  $report->{databases} = scalar(keys %$dbs);
  return {genomes => $genomes, report => $report};
} ## end sub genome_details
