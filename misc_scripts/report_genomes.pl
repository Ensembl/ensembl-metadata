#!/usr/bin/env perl
# Copyright [2009-2019] EMBL-European Bioinformatics Institute
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

This script is used to find which and how genomes have changed between a given release of ensembl and the previous one
If output_format is not defined or set to txt, the script produces the following files:
 - new_genomes.txt, list of new genomes between the current release and the previous one
 - removed_genomes.txt, list of genomes that have been removed between the current release and the previous one
 - renamed_genomes.txt, list of genomes that have been renamed between the current release and the previous one
 - summary.txt, Summary of the changes between the current release and the previous one in HTML format
 - updated_annotations.txt, list of genomes with annotation update between the current release and the previous one
 - updated_assemblies.txt, list of genomes with assemby update between the current release and the previous one
If division is not defined, the script will dump a set of file for each divisions appended by the division name.
If output_format is set to json, the script will print a pretty json of the update on the screen and store all the updates
in a file called: report_updates.json
=head1 SYNOPSIS

perl report_genomes.pl $(mysql-ens-meta-prod-1 details script) \
   -release 95 -division vertebrates

perl report_genomes.pl $(mysql-ens-meta-prod-1 details script) \
   -release 42 -division metazoa

perl report_genomes.pl $(mysql-ens-meta-prod-1 details script) \
   -release 95

perl report_genomes.pl $(mysql-ens-meta-prod-1 details script) \
   -release 95  -output_format json

=head1 OPTIONS

=over 8

=item B<-h[ost]> <host>

Mandatory. Host name of the metadata server

=item B<-n[ame]> <ensembl_metadata>

Mandatory. metadata database name, default "ensembl_metadata"

=item B<-p[ort]> <port>

Mandatory. Port number of the metadata server

=item B<-p[assword]> <password>

Password of the metadata server

=item B<-di[vision]> [EnsemblVertebrates|vertebrates|EnsemblBacteria|bacteria|EnsemblFungi|fungi|EnsemblPlants|plants|EnsemblProtists|protists|EnsemblMetazoa|metazoa]

Name of the division.
If not defined, the script will process all the divisions

=item B<-r[elease]> <release>

Release number of the vertebrates or non-vertebrates release
If not defined, the script will get the current release if division is specified

=item B<-o[output_format]> <output_format> [txt|json]

Script output format, options in text files one per change type, see description
Json to print the summary on json on the screen and inside an output file
Default option is text

=item B<-h[elp]>

Print usage information.

=item B<-m[man]>

Print full usage information.

=back

=head1 AUTHOR

dstaines

=head1 MAINTANER

tmaurel

=head1 VERSION

$Revision$
=cut

use strict;
use warnings;

use Pod::Usage;
use Bio::EnsEMBL::Utils::CliHelper;
use Bio::EnsEMBL::DBSQL::DBConnection;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::Base qw(process_division_names fetch_and_set_release check_assembly_update check_genebuild_update);
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Carp;
use JSON;

Log::Log4perl->easy_init($INFO);
my $logger = get_logger();

my $cli_helper = Bio::EnsEMBL::Utils::CliHelper->new();
# get the basic options for connecting to a database server
my $optsd = [@{$cli_helper->get_dba_opts()}, "division:s", "output_format:s", "release:i", "help", "man"];

my $opts = $cli_helper->process_args($optsd, \&pod2usage);
$opts->{dbname} ||= 'ensembl_metadata';
pod2usage(1) if $opts->{help};
pod2usage(-verbose => 2) if $opts->{man};

my ($args) = @{ $cli_helper->get_dba_args_for_opts( $opts, 1 ) };
my $metadatadba=Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(%$args);
my $gdba = $metadatadba->get_GenomeInfoAdaptor();
my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
my $release_info;
my $release;

# get all divisions
my $dump_all = 0;
if ( !defined $opts->{division} ) {
  $opts->{divisions} = $gdba->list_divisions();
  $dump_all = 1;
}
else {
  $opts->{divisions} = [ $opts->{'division'} ];
}

if (!defined $opts->{output_format}){
  $opts->{output_format} = 'txt';
}
elsif ($opts->{output_format} ne 'txt' and $opts->{output_format} ne 'json'){
  die "$opts->{output_format} is not valid, it should be txt|json";
}

my $report_updates = {};

foreach my $div (@{$opts->{divisions}}){
  #Get both division short and full name from a division short or full name
  my ($division,$division_name)=process_division_names($div);

  #Get the release for the given division
  my ($release,$release_info);
  ($rdba,$gdba,$release,$release_info) = fetch_and_set_release($opts->{release},$rdba,$gdba);
  #Create report
  my $report = {
   eg_version=> $gdba->data_release()->ensembl_genomes_version(),
   ensembl_version=> $gdba->data_release()->ensembl_version()
  };

  $logger->info("Getting genomes from release ".$release." for ".$division);
  my $genomes = get_genomes($gdba, $division_name);
  $logger->info("Found ".scalar(keys %$genomes)." genomes from from release ".$release." for ".$division);
  # decrement releases
  if ( $division eq "vertebrates" ) {
    my $prev_ens = $gdba->data_release()->ensembl_version()-1;
    $logger->info("Switching release to Ensembl $prev_ens");
    $gdba->set_ensembl_release($prev_ens);
    } else {
      my $prev_eg = $gdba->data_release()->ensembl_genomes_version()-1;
      $logger->info("Switching release to EG $prev_eg");
      $gdba->set_ensembl_genomes_release($gdba->data_release()->ensembl_genomes_version()-1);
    }
  $logger->info("Getting genomes from previous release for ".$division);
  my $prev_genomes = get_genomes($gdba, $division_name);
  $logger->info("Found ".scalar(keys %$prev_genomes)." genomes from previous release for ".$division);

  my $dbs = {};
  my $species = {};
  $logger->info("Comparing releases");
  while (my ($set_chain, $genome) = each %{$genomes}) {
    $species->{$genome->{species_taxonomy_id}}++;
    $dbs->{$genome->{database}}++;
    $report->{protein_coding} += $genome->{protein_coding};
    $report->{genomes}++;
    my $prev_genome = $prev_genomes->{$set_chain};
    # Gather list of new genomes
    if (!defined $prev_genome) {
      $report_updates->{$division}->{new_genomes}->{$genome->{name}} = {name=>$genome->{name},assembly=>$genome->{assembly},database=>$genome->{database},species_id=>$genome->{species_id},display_name=>$genome->{display_name}};
      } else {
          # Gather list of updated assemblies and genebuild
          my $updated_assembly=check_assembly_update($genome->{genome},$prev_genome->{genome});
          my $updated_genebuild=check_genebuild_update($genome->{genome},$prev_genome->{genome});
          if ($updated_assembly) {
            $report_updates->{$division}->{updated_assemblies}->{$genome->{name}} = {name=>$genome->{name},assembly=>$genome->{assembly},old_assembly=>$prev_genome->{assembly},database=>$genome->{database},species_id=>$genome->{species_id}};
          } elsif ($updated_genebuild) {
            $report_updates->{$division}->{updated_annotations}->{$genome->{name}} = {name=>$genome->{name},assembly=>$genome->{assembly},new_genebuild=>$genome->{genebuild},old_genebuild=>$prev_genome->{genebuild},database=>$genome->{database},species_id=>$genome->{species_id}};
          }
        }
  }
  # Gather list of removed genomes
  while (my ($set_chain, $genome) = each %{$prev_genomes}) {
    if (!defined $genomes->{$set_chain}) {
      $report_updates->{$division}->{removed_genomes}->{$genome->{name}} = {name=>$genome->{name},assembly=>$genome->{assembly},database=>$genome->{database},species_id=>$genome->{species_id},display_name=>$genome->{display_name}};
    }
  }
  # Gather list of renamed genomes
  for my $new_genome (keys %{$report_updates->{$division}->{new_genomes}}){
    for my $removed_genome (keys %{$report_updates->{$division}->{removed_genomes}}){
      # If the assembly name or display name is the same between a removed genomes and new genomes then it extremely likely that it has been renamed.
      if ($report_updates->{$division}->{new_genomes}->{$new_genome}->{assembly} eq $report_updates->{$division}->{removed_genomes}->{$removed_genome}->{assembly}  or $report_updates->{$division}->{new_genomes}->{$new_genome}->{display_name} eq $report_updates->{$division}->{removed_genomes}->{$removed_genome}->{display_name}){
        $report_updates->{$division}->{renamed_genomes}->{$new_genome} = {name=>$report_updates->{$division}->{new_genomes}->{$new_genome}->{name},assembly=>$report_updates->{$division}->{new_genomes}->{$new_genome}->{assembly},old_name=>$report_updates->{$division}->{removed_genomes}->{$removed_genome}->{name},database=>$report_updates->{$division}->{new_genomes}->{$new_genome}->{database},species_id=>$report_updates->{$division}->{new_genomes}->{$new_genome}->{species_id}};
      }
    }
  }
  # Renamed genomes will appear in both new_genomes and removed_genomes so these hashes need to be cleaned up
  for my $renamed_genome (keys %{$report_updates->{$division}->{renamed_genomes}}){
    delete $report_updates->{$division}->{new_genomes}->{$report_updates->{$division}->{renamed_genomes}->{$renamed_genome}->{name}};
    delete $report_updates->{$division}->{removed_genomes}->{$report_updates->{$division}->{renamed_genomes}->{$renamed_genome}->{old_name}};
  }
  #Get a count for each type of updates and store in report hash
  $report->{databases} = scalar keys %$dbs;
  $report->{species} = scalar keys %$species;
  $report->{new_genomes}     = (keys %{$report_updates->{$division}->{new_genomes}} ? scalar keys %{$report_updates->{$division}->{new_genomes}} : 0);
  $report->{updated_assemblies}  = (keys %{$report_updates->{$division}->{updated_assemblies}} ? scalar keys %{$report_updates->{$division}->{updated_assemblies}} : 0);
  $report->{updated_annotations} = (keys %{$report_updates->{$division}->{updated_annotations}} ? scalar keys %{$report_updates->{$division}->{updated_annotations}}: 0);
  $report->{renamed_genomes} = (keys %{$report_updates->{$division}->{renamed_genomes}} ? scalar keys %{$report_updates->{$division}->{renamed_genomes}} : 0);
  $report->{removed_genomes} = (keys %{$report_updates->{$division}->{removed_genomes}} ? scalar keys %{$report_updates->{$division}->{removed_genomes}} : 0);
  # If output format is txt, export all changes into multiple tab separated text files
  if ($opts->{output_format} eq 'txt'){
    write_output_to_file($report_updates,$dump_all,$division,$release,$report);
  }
}
#If output format is json, convert report_updates hash in pretty json
# Print it on screen and export it in a file
if ($opts->{output_format} eq 'json'){
  my $report_json = JSON->new->pretty->encode($report_updates);
  print "$report_json\n";
  open my $fh, ">", "report_updates.json";
  print $fh $report_json;
  close $fh;
}

sub write_output_to_file {
  my ($report_updates,$dump_all,$division,$release,$report) = @_;
  # print to file
  # new genomes
  # name assembly database species_id
  write_to_file(
    $report_updates->{$division}->{new_genomes},
    $dump_all ? "$division-new_genomes.txt" : "new_genomes.txt",
    [qw/name assembly database species_id/],
    sub {
     return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{database}, $_[0]->{species_id}];
     });

  # updated assemblies
  # name old_assembly new_assembly database species_id
  write_to_file(
    $report_updates->{$division}->{updated_assemblies},
    $dump_all ? "$division-updated_assemblies.txt" : "updated_assemblies.txt",
    [qw/name assembly old_assembly  database species_id/],
    sub {
     return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{old_assembly}, $_[0]->{database}, $_[0]->{species_id}];
     });

  # updated annotation
  # name assembly old_genebuild new_genebuild database species_id
  write_to_file(
    $report_updates->{$division}->{updated_annotations},
    $dump_all ? "$division-updated_annotations.txt" : "updated_annotations.txt",
    [qw/name assembly new_genebuild old_genebuild database species_id/],
    sub {
      return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{new_genebuild}, $_[0]->{old_genebuild}, $_[0]->{database}, $_[0]->{species_id}];
      });

  # renamed genomes
  # name assembly old_name database species_id
  write_to_file(
    $report_updates->{$division}->{renamed_genomes},
    $dump_all ? "$division-renamed_genomes.txt" : "renamed_genomes.txt",
    [qw/ name assembly old_name database species_id /],
    sub {
     return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{old_name}, $_[0]->{database}, $_[0]->{species_id}];
     });

  # removed genomes
  # name assembly database species_id
  write_to_file(
    $report_updates->{$division}->{removed_genomes},
    $dump_all ? "$division-renamed_genomes.txt" : "removed_genomes.txt",
    [qw/ name assembly database species_id /],
    sub {
      return [$_[0]->{name}, $_[0]->{assembly}, $_[0]->{database}, $_[0]->{species_id}];
      });


  my $summary_file = $dump_all ? "$division-summary.txt" : "summary.txt";
  $logger->info("Writing summary to $summary_file");
  my $news='';
  my $url;
  if ($division eq "vertebrates"){
    $url = "ftp://ftp.ensembl.org/pub/release-".$release."/"
  }
  else{
    $url = "ftp://ftp.ensemblgenomes.org/pub/release-".$release."/$division/";
  }

  if($division eq 'bacteria') {
    # get counts of bacteria and archaea
    my $taxon_sql = q/select count(*) from ncbi_taxonomy.ncbi_taxa_name n join ncbi_taxonomy.ncbi_taxa_node p on (n.taxon_id=p.taxon_id) join ncbi_taxonomy.ncbi_taxa_node c on (c.left_index between p.left_index and p.right_index) join organism o on (o.taxonomy_id=c.taxon_id) join genome using (organism_id) where n.name=? and n.name_class='scientific name' and data_release_id=?/;
    my $number_bacteria = $gdba->dbc()->sql_helper()->execute_single_result(-SQL=>$taxon_sql, -PARAMS=>['Bacteria',$gdba->data_release()->dbID()]);
    my $number_archaea = $gdba->dbc()->sql_helper()->execute_single_result(-SQL=>$taxon_sql, -PARAMS=>['Archaea',$gdba->data_release()->dbID()]);
    $report->{bacteria} =  defined $number_bacteria ? $number_bacteria : 0;
    $report->{archaea} =  defined $number_archaea ? $number_archaea : 0;
    $news = <<"END_B";
Release $release of Ensembl $division has been loaded from EMBL-Bank release XXX into $report->{databases} multispecies Ensembl v$report->{ensembl_version} databases.  The current dataset contains $report->{genomes} genomes ($report->{bacteria} bacteria and $report->{archaea} archaea) from $report->{species} species containing $report->{protein_coding} protein coding genes. This release includes <a href="${url}new_genomes.txt">$report->{new_genomes}</a> new genomes, <a href="${url}updated_assemblies.txt">$report->{updated_assemblies} genomes with updated assemblies, <a href="${url}updated_annotations.txt">$report->{updated_annotations}</a> genomes with updated annotation, <a href="${url}renamed_genomes.txt">$report->{renamed_genomes}</a> genomes where the assigned name has changed, and <a href="${url}removed_genomes.txt">$report->{removed_genomes}</a> genomes removed since the last release.
Ensembl Bacteria has been updated to include the latest versions of $report->{genomes} genomes ($report->{bacteria} bacteria and $report->{archaea} archaea) from the INSDC archives.
END_B

  } else {
    $news = <<"END";
Release $release of Ensembl $division has been loaded into $report->{databases} Ensembl v$report->{ensembl_version} databases.  The current dataset contains $report->{genomes} genomes from $report->{species} species containing $report->{protein_coding} protein coding genes. This release includes <a href="${url}new_genomes.txt">$report->{new_genomes}</a> new genomes, <a href="${url}updated_assemblies.txt">$report->{updated_assemblies}</a> genomes with updated assemblies, <a href="${url}updated_annotations.txt">$report->{updated_annotations}</a> genomes with updated annotation, <a href="${url}renamed_genomes.txt">$report->{renamed_genomes}</a> genomes where the assigned name has changed, and <a href="${url}removed_genomes.txt">$report->{removed_genomes}</a> genomes removed since the last release.
END

  }
  open my $summary, ">", "$summary_file" || croak "Could not open $summary_file for writing";
  print $summary $news;
  close $summary;
  return;
}

sub write_to_file {
  my ($data, $file_name, $header, $callback) = @_;
  $logger->info("Writing to $file_name");
  open my $file, ">", $file_name or croak "Could not open output file $file_name";
  print $file "#".join("\t", @{$header}) . "\n";
  for my $datum (sort keys %$data) {
    print $file join("\t", @{$callback->($data->{$datum})}) . "\n";
  }
  close $file;
}

sub get_genomes {
  my ($gdba, $division) = @_;
  my $genome_details = {};
  my $genomes = {};
  if(defined $division) { 
    $genomes = $gdba->fetch_all_by_division($division);
  }
  else {
      $genomes = $gdba->fetch_all();
  }
  for my $genome (@{$genomes}) {
    # name
    my $gd = {
      genome=>$genome,
      name=>$genome->name(),
      assembly=>$genome->assembly_default(),
      display_name=>$genome->display_name(),
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