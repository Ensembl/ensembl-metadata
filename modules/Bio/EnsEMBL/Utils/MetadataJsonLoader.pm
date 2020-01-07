#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::Utils::MetadataJsonLoader;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = qw(load_json);
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);
my $log = get_logger();
use Bio::EnsEMBL::Hive::Utils::URL;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;
use Bio::EnsEMBL::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::MetaData::EventInfo;
use JSON;

sub load_json {
  my ($metadata_uri,$json_location,$release_date,$e_release,$eg_release,$current_release,$email,$comment,$update_type,$source)  = @_;
  #Connect to metadata database
  my $metadatadba = create_metadata_dba($metadata_uri);
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  if (defined $e_release) {
    # Check if release already exist or create it
    $gdba = update_release_and_process_release_db($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$update_type,$comment,$source);
  }
  my $release_id = $gdba->{data_release}->{dbID};
  #Load the json file into memory
  my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $json_location)
      or die("Can't open \$json_location\": $!\n");
   local $/;
   <$json_fh>
};

  my $json = JSON->new;
  my $data = $json->decode($json_text);
  
  foreach my $species ( @{$data} ) {
    my $division = $metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from division where name=?/, -USE_HASHREFS => 1, -PARAMS => [$species->{division}]);
    my $organism = populate_organism_tables($metadatadba,$species);
    my $assembly = populate_assembly_tables($metadatadba,$species);
    populate_genome_tables($metadatadba,$species,$organism,$release_id,$assembly,$division,$email,$comment,$update_type,$source);
  }
  # Disconnecting from server
  $gdba->dbc()->disconnect_if_idle();
  $metadatadba->dbc()->disconnect_if_idle();
  $log->info("All done");
  return;
} ## end sub run

sub populate_organism_tables{
  my ($metadatadba,$species) = @_;
  my $organism = $metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from organism where name=?/, -USE_HASHREFS => 1, -PARAMS => [$species->{species}]);
  if (@$organism){
    $log->info("Organism ".$species->{species}." already exist, reusing it");
    return $organism;
  }
  else{
    $log->info("Populating organism info for ".$species->{species});
    $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO organism (taxonomy_id,is_reference,species_taxonomy_id,name,url_name,display_name,scientific_name,strain,serotype,description,image) VALUES(?,?,?,?,?,?,?,?,?,?,?)/, -PARAMS => [$species->{taxonomy_id},$species->{is_reference} || 0,$species->{species_taxonomy_id}, $species->{species},ucfirst($species->{species}),$species->{name},$species->{name},$species->{strain},$species->{serotype},undef,undef]);
    my $organism=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from organism where name=?/,-USE_HASHREFS => 1, -PARAMS => [$species->{species}]);
    $log->info("Populating organism aliases for ".$species->{species});
    foreach my $alias (@{$species->{aliases}}){
      # Removing non ascii char because of weird char in campylobacter_jejuni_subsp_jejuni_2008_1025 aliases
      $alias =~ s/[^[:ascii:]]//g;
      $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO organism_alias (organism_id,alias) VALUES(?,?)/, -PARAMS => [$organism->[0]->{organism_id},$alias]);
    }
    $log->info("Populating organism publications for ".$species->{species});
    foreach my $publication (@{$species->{publications}}){
      $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO organism_publication (organism_id,publication) VALUES(?,?)/, -PARAMS => [$organism->[0]->{organism_id},$publication]);
    }
    return $organism;
  }
}

sub populate_assembly_tables{
  my ($metadatadba,$species) = @_;
  my $assembly = $metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from assembly where assembly_name=?/,-USE_HASHREFS => 1, -PARAMS => [$species->{assembly_name}]);
  if (@$assembly){
    $log->info("Assembly for ".$species->{species}." already exist, reusing it");
    return $assembly;
  }
  else {
      $assembly = $metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from assembly where assembly_accession=?/,-USE_HASHREFS => 1, -PARAMS => [$species->{assembly_id}]);
      if (@$assembly){
        $log->info("Assembly for ".$species->{species}." already exist, reusing it");
        return $assembly;
      }
      else{
        $log->info("Populating assembly table for ".$species->{species});
          $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO assembly (assembly_accession,assembly_name,assembly_default,assembly_ucsc,assembly_level,base_count) VALUES(?,?,?,?,?,?)/, -PARAMS => [$species->{assembly_id},$species->{assembly_name},$species->{assembly_name},undef,$species->{assembly_level},$species->{base_count}]);
          $assembly=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from assembly where assembly_name=?/,-USE_HASHREFS => 1, -PARAMS => [$species->{assembly_name}]);
        $log->info("Populating assembly sequence for ".$species->{species});
        foreach my $sequence (@{$species->{sequences}}){
            $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO assembly_sequence (assembly_id,name,acc) VALUES(?,?,?)/, -PARAMS => [$assembly->[0]->{assembly_id},$sequence->{'name'},$sequence->{'acc'}]);
        }
        return $assembly;
      }
  }
  return;
}

sub populate_genome_tables{
  my ($metadatadba,$species,$organism,$release_id,$assembly,$division,$email,$comment,$update_type,$source) = @_;
  my $genome=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from genome where organism_id=? and data_release_id=?/, -USE_HASHREFS => 1, -PARAMS => [$organism->[0]->{organism_id},$release_id]);
  if (@$genome){
    $log->info("Genome for ".$species->{species}." and release ".$release_id." already exist, deleting it");
    $metadatadba->dbc()->sql_helper()->execute_update( -SQL =>qq/DELETE from genome where organism_id=? and data_release_id=?/, -USE_HASHREFS => 1, -PARAMS => [$organism->[0]->{organism_id},$release_id]);
  }
  $log->info("Populating genome table for ".$species->{species});
  $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome (data_release_id,assembly_id,organism_id,genebuild,division_id,has_pan_compara,has_variations,has_peptide_compara,has_genome_alignments,has_synteny,has_other_alignments) VALUES(?,?,?,?,?,?,?,?,?,?,?)/, -PARAMS => [$release_id,$assembly->[0]->{assembly_id},$organism->[0]->{organism_id},$species->{genebuild},$division->[0]->{division_id},$species->{has_pan_compara},$species->{has_variations},$species->{has_peptide_compara},$species->{has_genome_alignments},$species->{has_synteny} || 0,$species->{has_other_alignments}]);
  $genome=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from genome where organism_id=? and data_release_id=?/, -USE_HASHREFS => 1,-PARAMS => [$organism->[0]->{organism_id},$release_id]);
  my $db_type=get_species_and_dbtype($species);
  $log->info("Populating genome_database table for ".$species->{species});
  $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_database (genome_id,dbname,species_id,type) VALUES(?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$species->{dbname},$species->{species_id},$db_type]);
  my $genome_database=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from genome_database where dbname=? and species_id=? and genome_id=?/,-USE_HASHREFS => 1, -PARAMS => [$species->{dbname},$species->{species_id},$genome->[0]->{genome_id}]);

  if ($species->{has_genome_alignments}){

    $log->info("Populating genome_alignment table for ".$species->{species});
    for my $type (keys %{$species->{other_alignments}}) {
      if ($type) {
        for my $name (keys %{$species->{other_alignments}->{$type}}) {
          $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_alignment (genome_id,type,name,count,genome_database_id) VALUES(?,?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$type,$name,$species->{other_alignments}->{$type}->{$name},$genome_database->[0]->{genome_database_id}]);
        }
      }
    }
  }
  
  $log->info("Populating genome_annotation table for ".$species->{species});
  for my $type (keys %{$species->{annotations}}) {
    $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_annotation (genome_id,type,value,genome_database_id) VALUES(?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$type,$species->{annotations}->{$type},$genome_database->[0]->{genome_database_id}]);
  }

  $log->info("Populating genome_feature table for ".$species->{species});
  for my $type (keys %{$species->{features}}) {
    for my $analysis (keys %{$species->{features}->{$type}}) {
      $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_feature (genome_id,type,analysis,count,genome_database_id) VALUES(?,?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$type,$analysis,$species->{features}->{$type}->{$analysis},$genome_database->[0]->{genome_database_id}]);
    }
  }
  
  if ($species->{has_variations}){
    $log->info("Populating genome_variation table for ".$species->{species});
    for my $type (keys %{$species->{variations}}) {
      for my $name (keys %{$species->{variations}->{$type}}) {
        $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_variation (genome_id,type,name,count,genome_database_id) VALUES(?,?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$type,$name,$species->{variations}->{$type}->{$name},$genome_database->[0]->{genome_database_id}]);
      }
    }
  }
  if ($species->{has_peptide_compara} or $species->{has_pan_compara}){
    $log->info("Populating genome_compara_analysis table for ".$species->{species});
    foreach my $compara (@{$species->{compara}}){
      my $compara_analysis=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from compara_analysis where data_release_id=? and division_id=? and method=? and set_name=? and dbname=?/, -USE_HASHREFS => 1, -PARAMS => [$release_id,$division->[0]->{division_id},$compara->{method},$compara->{set_name},$compara->{dbname}]);
      if (@$compara_analysis){
        $log->info("Compara analysis already exist, reusing it");
      }
      else{
        $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO compara_analysis (data_release_id,division_id,method,set_name,dbname) VALUES(?,?,?,?,?)/, -PARAMS => [$release_id,$division->[0]->{division_id},$compara->{method},$compara->{set_name},$compara->{dbname}]);
        $compara_analysis=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from compara_analysis where data_release_id=? and division_id=? and method=? and set_name=? and dbname=?/, -USE_HASHREFS => 1, -PARAMS => [$release_id,$division->[0]->{division_id},$compara->{method},$compara->{set_name},$compara->{dbname}]);
        $log->info("Populate Compara analysis event table");
        $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO compara_analysis_event (compara_analysis_id,type,source,details) VALUES(?,?,?,?)/, -PARAMS => [$compara_analysis->[0]->{compara_analysis_id},$update_type,$source,encode_json({"email"=>$email,"comment"=>$comment})]);
      }
      my $genome_compara_analysis=$metadatadba->dbc()->sql_helper()->execute( -SQL =>qq/select * from genome_compara_analysis where genome_id=? and compara_analysis_id=?/, -USE_HASHREFS => 1, -PARAMS => [$genome->[0]->{genome_id},$compara_analysis->[0]->{compara_analysis_id}]);
      if (@$genome_compara_analysis){ 
        $log->info("genome_compara analysis already linked to species".$species->{species}." skipping...");
      }
      else{
        $log->info("Linking genome_compara analysis for species".$species->{species});
        $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_compara_analysis (genome_id,compara_analysis_id) VALUES(?,?)/, -PARAMS => [$genome->[0]->{genome_id},$compara_analysis->[0]->{compara_analysis_id}]);
      }
    }
  }
  $log->info("Populating genome_event table for ".$species->{species});
  $metadatadba->dbc()->sql_helper()->execute_update(-SQL =>qq/INSERT INTO genome_event (genome_id,type,source,details) VALUES(?,?,?,?)/, -PARAMS => [$genome->[0]->{genome_id},$update_type,$source,encode_json({"email"=>$email,"comment"=>$comment})]);
  return;
}


sub create_metadata_dba {
  my ($metadata_uri)=@_;
  my $metadata = get_db_connection_params( $metadata_uri);
  $log->info("Connecting to Metadata database $metadata->{dbname}");
  my $metadatadba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
                                             -USER =>,
                                             $metadata->{user},
                                             -PASS =>,
                                             $metadata->{pass},
                                             -HOST =>,
                                             $metadata->{host},
                                             -PORT =>,
                                             $metadata->{port},
                                             -DBNAME =>,
                                             $metadata->{dbname},);
  return $metadatadba;
}

sub update_release_and_process_release_db {
  my ($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$update_type,$comment,$source) = @_;
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my $release;
  if ( defined $eg_release ) {
    $release = $rdba->fetch_by_ensembl_genomes_release($eg_release);
    if (!defined $release){
      store_new_release($rdba,$e_release,$eg_release,$release_date,$current_release);
      $release = $rdba->fetch_by_ensembl_genomes_release($eg_release);
    }
    else {
      $log->info("release e$e_release" . ( ( defined $eg_release ) ?
                  "/EG$eg_release" : "" ) .
                " $release_date already exist, reusing it");
    }
  }
  else {
    $release = $rdba->fetch_by_ensembl_release($e_release);
    if (!defined $release){
      store_new_release($rdba,$e_release,$eg_release,$release_date,$current_release);
      $release = $rdba->fetch_by_ensembl_release($e_release);
    }
    else{
      $log->info("release e$e_release" . ( ( defined $eg_release ) ?
                  "/EG$eg_release" : "" ) .
                " $release_date already exist, reusing it");
    }
  }
  $gdba->data_release($release);
  $rdba->dbc()->disconnect_if_idle();
  return $gdba;
}

#Subroutine to parse Server URI and return connection details
sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

#Subroutine to store a new release in metadata database
sub store_new_release {
  my ($rdba,$e_release,$eg_release,$release_date,$is_current)=@_;
  $log->info( "Storing release e$e_release" . ( ( defined $eg_release ) ?
                "/EG$eg_release" : "" ) .
              " $release_date" );
  $rdba->store( Bio::EnsEMBL::MetaData::DataReleaseInfo->new(
                                        -ENSEMBL_VERSION         => $e_release,
                                        -ENSEMBL_GENOMES_VERSION => $eg_release,
                                        -RELEASE_DATE => $release_date,
                                        -IS_CURRENT => $is_current ) );
  $log->info("Created release entries");
  return;
}

sub get_species_and_dbtype {
  my ($species)=@_;
  my $db_type;
  #dealing with Compara
  if ($species->{dbname} =~ m/_compara_/){
    $db_type="compara";
  }
  #dealing with collections
  elsif ($species->{dbname} =~ m/_collection_([a-z]+)/){
    $db_type=$1;
  }
  #dealing with Variation
  elsif ($species->{dbname} =~ m/_variation_/){
    $db_type="variation";
  }
  #dealing with Regulation
  elsif ($species->{dbname} =~ m/_funcgen_/){
    $db_type="funcgen";
  }
  #dealing with Core
  elsif ($species->{dbname} =~ m/_core_/){
      $db_type="core";
  }
    #dealing with otherfeatures
    elsif ($species->{dbname} =~ m/_otherfeatures_/){
      $db_type="otherfeatures";
    }
      #dealing with rnaseq
    elsif ($species->{dbname} =~ m/_rnaseq_/){
      $db_type="rnaseq";
    }
      #dealing with cdna
    elsif ($species->{dbname} =~ m/_cdna_/){
      $db_type="cdna";
    }
    # Dealing with other databases like mart, ontology,...
    elsif ($species->{dbname} =~ m/^\w+_?\d*_\d+$/){
      $db_type="other";
    }
    #Dealing with anything else
    else{
      die "Can't find data_type for database $species->{dbname}";
    }
  return ($db_type);
}

1;
