#!/usr/bin/env perl
# Copyright [2009-2018] EMBL-European Bioinformatics Institute
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
use  Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}, "division:s", "eg", "release:i"];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);
$opts->{dbname} ||= 'ensembl_metadata';

my ($args) = @{ $cli_helper->get_dba_args_for_opts( $opts, 1 ) };
my $metadatadba=Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args);
my $gdba = $metadatadba->get_GenomeInfoAdaptor();
my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
my $release;

if ( defined $opts->{eg} || defined $opts->{division} ) {
  if (defined $opts->{release})
  {
    $release = $rdba->fetch_by_ensembl_genomes_release($opts->{release});
    $gdba->data_release($release);
  }
  else{
    $gdba->set_ensembl_genomes_release();
  }
}
else{
  if (defined $opts->{release}){
    $release = $rdba->fetch_by_ensembl_release($opts->{release});
    $gdba->data_release($release);
  }
  else{
    $gdba->set_ensembl_release();
  }
}

my $report = {
	      eg_version=> $gdba->data_release()->ensembl_genomes_version(),
	      ensembl_version=> $gdba->data_release()->ensembl_version()
};

$logger->info("Getting genomes from release ".$opts->{release}) if defined $opts->{release} || $logger->info("Getting genomes from current release");
my $genomes = get_genomes($gdba, $opts->{division});
$logger->info("Found ".scalar(keys %$genomes)." genomes from from release ".$opts->{release}) if defined $opts->{release} || $logger->info("Found ".scalar(keys %$genomes)." genomes from current release");
# decrement releases
if ( defined $opts->{eg} || defined $opts->{division} ) {
  my $prev_eg = $gdba->data_release()->ensembl_genomes_version()-1;
  $logger->info("Switching release to EG $prev_eg");
  $gdba->set_ensembl_genomes_release($gdba->data_release()->ensembl_genomes_version()-1);
} else {
  my $prev_ens = $gdba->data_release()->ensembl_genomes_version()-1;
  $logger->info("Switching release to Ensembl $prev_ens");
  $gdba->set_ensembl_release($prev_ens);
}
$logger->info("Getting genomes from previous release");
my $prev_genomes = get_genomes($gdba, $opts->{division});
$logger->info("Found ".scalar(keys %$prev_genomes)." genomes from previous release");

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
my $dbs = {};
my $species = {};
$logger->info("Comparing releases");
while (my ($set_chain, $genome) = each %{$genomes}) {  
  $species->{$genome->{species_taxonomy_id}}++;
  $dbs->{$genome->{database}}++;
  $report->{protein_coding} += $genome->{protein_coding};
  $report->{genomes}++;
  my $prev_genome = $prev_genomes->{$set_chain};
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
$report->{databases} = scalar keys %$dbs;
$report->{species} = scalar keys %$species;
$report->{new_genomes}     = scalar @$new_genomes;
$report->{new_assemblies}  = scalar @$new_assemblies;
$report->{new_annotations} = scalar @$new_annotations;
$report->{renamed_genomes} = scalar @$renamed_genomes;
$report->{removed_genomes} = scalar @$removed_genomes; 


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


my $summary_file = "summary.txt";
$logger->info("Writing summary to $summary_file");
my $news;
my $division = $opts->{division};
$division =~ s/^Ensembl/Ensembl /;
my $division2 = lc($division);
$division2 =~ s/Ensembl //;
my $url = "ftp://ftp.ensemblgenomes.org/pub/current/$division2/";

if($opts->{division} eq 'EnsemblBacteria') {

  # get counts of bacteria and archaea
  my $taxon_sql = q/select count(*) from ncbi_taxonomy.ncbi_taxa_name n join ncbi_taxonomy.ncbi_taxa_node p on (n.taxon_id=p.taxon_id) join ncbi_taxonomy.ncbi_taxa_node c on (c.left_index between p.left_index and p.right_index) join organism o on (o.taxonomy_id=c.taxon_id) join genome using (organism_id) where n.name=? and n.name_class='scientific name' and data_release_id=?/;
  $report->{bacteria} = $gdba->dbc()->sql_helper()->execute_single_result(-SQL=>$taxon_sql, -PARAMS=>['Bacteria',$gdba->data_release()->dbID()]);
  $report->{archaea} = $gdba->dbc()->sql_helper()->execute_single_result(-SQL=>$taxon_sql, -PARAMS=>['Archaea',$gdba->data_release()->dbID()]);
  $news = <<"END_B";
Release $report->{eg_version} of $opts->{division} has been loaded from EMBL-Bank release XXX into $report->{databases} multispecies Ensembl v$report->{ensembl_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{bacteria} bacteria and $report->{archaea} archaea) from $report->{species} species containing $report->{protein_coding} protein coding genes. This release includes <a href="${url}new_genomes.txt">$report->{new_genomes}</a> new genomes, <a href="${url}updated_assemblies.txt">$report->{new_assemblies} genomes with updated assemblies, <a href="${url}updated_annotations.txt">$report->{new_annotations}</a> genomes with updated annotation, <a href="${url}renamed_genomes.txt">$report->{renamed_genomes}</a> genomes where the assigned name has changed, and <a href="${url}removed_genomes.txt">$report->{removed_genomes}</a> genomes removed since the last release.

Ensembl Bacteria has been updated to include the latest versions of $report->{genomes} genomes ($report->{eubacteria} bacteria and $report->{archaea} archaea) from the INSDC archives.
END_B

} else {

    $news = <<"END";
Release $report->{eg_version} of $division has been loaded into $report->{databases} Ensembl v$report->{ensembl_version} databases.  The current dataset contains $report->{genomes} genomes from $report->{species} species containing $report->{protein_coding} protein coding genes. This release includes <a href="${url}new_genomes.txt">$report->{new_genomes}</a> new genomes, <a href="${url}updated_assemblies.txt">$report->{new_assemblies}</a> genomes with updated assemblies, <a href="${url}updated_annotations.txt">$report->{new_annotations}</a> genomes with updated annotation, <a href="${url}renamed_genomes.txt">$report->{renamed_genomes}</a> genomes where the assigned name has changed, and <a href="${url}removed_genomes.txt">$report->{removed_genomes}</a> genomes removed since the last release.
END

}

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

sub get_genomes {
  my ($gdba, $division) = @_;
  my $genome_details = {};
  my $genomes = {};
  if(defined $division) { 
    $genomes = $gdba->fetch_all_by_division($division);
  } else {
    $genomes = $gdba->fetch_all();
  }
  my $dbs = {};
  for my $genome (@{$genomes}) {
    # name
    my $gd = {
	      name=>$genome->name(),
	      assembly=>$genome->assembly_name(),
	      genebuild=>$genome->genebuild(),
	      database=>$genome->dbname(),
	      species_id=>$genome->species_id(),
	      species_taxonomy_id=>($genome->organism()->species_taxonomy_id() || $genome->organism()->taxonomy_id()),
	      protein_coding=>$genome->annotations()->{nProteinCoding}
	     };
    my $key;
    if($genome->dbname() =~ m/collection_core/) {
      ($key) = split(/\./, $genome->assembly_accession());
    } else {
      $key = $gd->{name};
    }
    $genome_details->{$key} = $gd;    
  }
  return $genome_details;
}
