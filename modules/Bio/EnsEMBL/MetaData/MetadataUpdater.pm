#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

package Bio::EnsEMBL::MetaData::MetadataUpdater;

use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT_OK = qw(process_database);
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

sub process_database {
  my ($metadata_uri,$database_uri,$release_date,$e_release,$eg_release,$current_release,$email,$comment,$update_type,$source)  = @_;
  #Connect to metadata database
  my $metadatadba = create_metadata_dba($metadata_uri);
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  my $events;
  # Get database db_type and species  
  my ($species,$db_type,$database,$species_ids)=get_species_and_dbtype($database_uri);
  if (defined $e_release) {
    # Check if release already exist or create it
    $gdba = update_release_and_process_release_db($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$update_type,$comment,$source,$db_type,$database);
  }
  #get current release and process release db
  else {
    $gdba = get_release_and_process_release_db($metadatadba,$gdba,$database,$email,$update_type,$comment,$source,$db_type);
  }
  if ($db_type eq "core"){
    $events = process_core($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source);
  }
  elsif ($db_type eq "compara") {
    $events = process_compara($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source);
  }
  #Already processed mart, ontology, in get_release...
  elsif ($db_type eq "other"){
    1;
  }
  else {
    check_if_coredb_exist($gdba,$species,$metadatadba);
    $events = process_other_database($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source);
  }
  # Disconnecting from server
  $gdba->dbc()->disconnect_if_idle();
  $metadatadba->dbc()->disconnect_if_idle();
  $log->info("All done");
  return $events;
} ## end sub run

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
  my ($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$update_type,$comment,$source,$db_type,$database) = @_;
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
  if ($db_type eq "other"){
    process_release_database($metadatadba,$gdba,$release,$database,$email,$update_type,$comment,$source);
  }
  $gdba->data_release($release);
  $rdba->dbc()->disconnect_if_idle();
  return $gdba;
}

sub get_release_and_process_release_db {
  my ($metadatadba,$gdba,$database,$email,$update_type,$comment,$source,$db_type) = @_;
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my $release;
  # Parse EG databases including core, core like, variation, funcgen and compara
  if (($database->{dbname} =~ m/(?:core|otherfeatures|rnaseq|cdna|variation|funcgen)_(\d+)_\d+_\d+$/) or ($database->{dbname} =~ m/ensembl_compara_(?:fungi|metazoa|protists|bacteria|plants|pan_homology)_(\d+)_\d+$/) or ($database->{dbname} =~ m/(?:fungi|plants|metazoa|protists)_\w+_mart_(\d+)$/) or ($database->{dbname} =~ m/ensemblgenomes_info_(\d+)$/)or ($database->{dbname} =~ m/ensemblgenomes_stable_ids_(\d+)_\d+$/)){
    $release = $rdba->fetch_by_ensembl_genomes_release($1);
    if (defined $release){
      $log->info("Using release e".$release->{ensembl_version}."" . ( ( defined $release->{ensembl_genomes_version} ) ?
                    "/EG".$release->{ensembl_genomes_version}."" : "" ) .
                  " ".$release->{release_date});
    }
    else{
      die "Can't find release $release for EG in metadata database";
    }
  }
  # Parse Ensembl release
  elsif(($database->{dbname} =~ m/(?:core|otherfeatures|rnaseq|cdna|variation|funcgen)_(\d+)_\d+$/) or ($database->{dbname} =~ m/ensembl_compara_(\d+)$/) or ($database->{dbname} =~ m/\w+_mart_(\d+)$/)){
    $release = $rdba->fetch_by_ensembl_release($1);
    if (defined $release){
      $log->info("Using release e".$release->{ensembl_version}."" . ( ( defined $release->{ensembl_genomes_version} ) ?
                "/EG".$release->{ensembl_genomes_version}."" : "" ) .
              " ".$release->{release_date});
    }
    else{
      die "Can't find release $release for Ensembl or EG in metadata database";
    }
  }
  elsif($database->{dbname} =~ m/_(\d+)$/){
    $release = $rdba->fetch_by_ensembl_release($1);
    if (defined $release){
      $log->info("Using release e".$release->{ensembl_version}."" . ( ( defined $release->{ensembl_genomes_version} ) ?
                "/EG".$release->{ensembl_genomes_version}."" : "" ) .
              " ".$release->{release_date});
    }
    else{
      die "Can't find release $release for Ensembl in metadata database";
    }
  }
  else{
    die "Can't find release for database $database->{dbname}";
  }
  if ($db_type eq "other"){
    process_release_database($metadatadba,$gdba,$release,$database,$email,$update_type,$comment,$source);
  }
  $gdba->data_release($release);
  $rdba->dbc()->disconnect_if_idle();
  return $gdba;
}
sub get_species_and_dbtype {
  my ($database_uri)=@_;
  my $database = get_db_connection_params( $database_uri);
  my $db_type;
  my $species;
  my $dba;
  my $species_ids;
  $log->info("Connecting to database $database->{dbname}");
  #dealing with Compara
  if ($database->{dbname} =~ m/_compara_/){
    $species="multi";
    $db_type="compara";
  }
  #dealing with collections
  elsif ($database->{dbname} =~ m/_collection_/){
     $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user   => $database->{user},
      -dbname => $database->{dbname},
      -host   => $database->{host},
      -port   => $database->{port},
      -pass => $database->{pass},
      -multispecies_db => 1
    );
    $species = $dba->all_species();
    $db_type=$dba->group();
    foreach my $species_name (@{$species}){
      my $species_id=$dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select species_id from meta where meta_key=? and meta_value=?/, -PARAMS => ['species.production_name',$species_name]);
      $species_ids->{$species_name}=$species_id->[0];
    }
    $dba->dbc()->disconnect_if_idle();
  }
  #dealing with Variation
  elsif ($database->{dbname} =~ m/_variation_/){
    $db_type="variation";
    $dba = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass}
    );
    $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
    $dba->dbc()->disconnect_if_idle();
  }
  #dealing with Regulation
  elsif ($database->{dbname} =~ m/_funcgen_/){
    $db_type="funcgen";
    $dba = Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass}
    );
    $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
    $dba->dbc()->disconnect_if_idle();
  }
  #dealing with Core
  elsif ($database->{dbname} =~ m/_core_/){
      $db_type="core";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type
      );
      $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
      $dba->dbc()->disconnect_if_idle();
    }
    #dealing with otherfeatures
    elsif ($database->{dbname} =~ m/_otherfeatures_/){
      $db_type="otherfeatures";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type
      );
      $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
      $dba->dbc()->disconnect_if_idle();
    }
      #dealing with rnaseq
    elsif ($database->{dbname} =~ m/_rnaseq_/){
      $db_type="rnaseq";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type
      );
      $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
      $dba->dbc()->disconnect_if_idle();
    }
      #dealing with cdna
    elsif ($database->{dbname} =~ m/_cdna_/){
      $db_type="cdna";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type
      );
      $species = $dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select meta_value from meta where meta_key=?/, -PARAMS => ['species.production_name']);
      $dba->dbc()->disconnect_if_idle();
    }
    # Dealing with other versionned databases like mart, ontology,...
    elsif ($database->{dbname} =~ m/^\w+_?\d*_\d+$/){
      $db_type="other";
    }
    # Check other non versionned databases like ncbi_taxonomy, ensembl_metadata
    elsif (check_pan_databases($database->{dbname})){
      $db_type="other";
    }
    #Dealing with anything else
    else{
      die "Can't find data_type for database $database->{dbname}";
    }
  return ($species,$db_type,$database,$species_ids);
}

sub create_database_dba {
  my ($database,$species,$db_type,$species_ids)=@_;
  my $dba;
  $log->info("Connecting to database ".$database->{dbname}." with species $species");
  #dealing with Compara
  if ($database->{dbname} =~ m/_compara_/){
    $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
      -user   => $database->{user},
      -dbname => $database->{dbname},
      -host   => $database->{host},
      -port   => $database->{port},
      -pass => $database->{pass},
      -species => $species,
      -group => $db_type
    );
  }
  #dealing with collections
  elsif ($database->{dbname} =~ m/_collection_/){
     my $species_id = $species_ids->{$species};
     $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user   => $database->{user},
      -dbname => $database->{dbname},
      -host   => $database->{host},
      -port   => $database->{port},
      -pass => $database->{pass},
      -multispecies_db => 1,
      -species => $species,
      -group => $db_type,
      -species_id => $species_id
    );
  }
  elsif ($database->{dbname} =~ m/_variation_/){
    $dba = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $species
    );
  }
  #dealing with Regulation
  elsif ($database->{dbname} =~ m/_funcgen_/){
    $dba = Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $species
    );
  }
  #Dealing with anything else
  else{
    $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -user   => $database->{user},
      -dbname => $database->{dbname},
      -host   => $database->{host},
      -port   => $database->{port},
      -pass => $database->{pass},
      -species => $species,
      -group => $db_type
    );
  }
  return ($dba); 
}
#Subroutine to parse Server URI and return connection details
sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

#Subroutine to process compara database and add or force update
sub process_compara {
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source) = @_;
  my $dba=create_database_dba($database,$species,$db_type,$species_ids);
  my @events;
  my $cdba = $metadatadba->get_GenomeComparaInfoAdaptor();
  my $opts = { -INFO_ADAPTOR => $gdba,
               -ANNOTATION_ANALYZER =>
                 Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
               -COMPARA      => 1,
               -CONTIGS      => 0,
               -FORCE_UPDATE => 0,
               -VARIATION    => 0 };
  my $processor = Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);
  my $compara_infos = $processor->process_compara( $dba, {});
  my $ea = $metadatadba->get_EventInfoAdaptor();
  for my $compara_info (@$compara_infos) {
    my $nom = $compara_info->method() . "/" . $compara_info->set_name();
    $log->info( "Storing/Updating compara info for " . $nom );
    $cdba->store($compara_info);
    $log->info( "Storing compara event for " . $nom );
    my $event = Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $compara_info,
                                                    -TYPE    => $update_type,
                                                    -SOURCE  => $source,
                                                    -DETAILS => encode_json({"email"=>$email,"comment"=>$comment}) );
    $ea->store( $event );
    my $event_hash = to_hash($event);
    push @events, $event_hash;
  }
  $cdba->dbc()->disconnect_if_idle();
  $dba->dbc()->disconnect_if_idle();
  $log->info("Completed processing compara ".$dba->dbc()->dbname());
  return \@events;
}

#Subroutine to process release databases like mart or ontology
sub process_release_database {
  my ($metadatadba,$gdba,$release,$database,$email,$update_type,$comment,$source) = @_;
  my $division;
  my @events;
  if (defined $release->{ensembl_genomes_version}){
    #Check pan division databases
    if (check_pan_databases($database->{dbname})){
      $division="EnsemblPan";
    }
    #If not in the Pan division list, get division name from database prefix.
    # e.g: plants_gene_mart_42
    elsif ($database->{dbname} =~ m/^([a-z]+)_/){
      $division = "Ensembl".ucfirst($1);
    }
    else{
      die "Can't find division for database ".$database->{dbname};
    }
  }
  else{
    #Check pan division databases
    if (check_pan_databases($database->{dbname})){
      $division="EnsemblPan";
    }
    else{
      $division = "EnsemblVertebrates";
    }
  }
  $log->info( "Adding database " . $database->{dbname} . " to release" );
  $release->add_database($database->{dbname},$division);
  $log->info( "Updating release");
  $gdba->update($release);
  my $release_database;
  foreach my $db (@{$release->databases()}){
    if ($db->{dbname} eq $database->{dbname}){
      $release_database = $db;
    }
  }
  if (!defined $release_database){
    die "Can't find release database ".$database->{dbname}." in metadata database";
  }
  my $ea = $metadatadba->get_EventInfoAdaptor();
  $log->info( "Storing release event for " . $database->{dbname} );
  my $event = Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $release_database,
                                                  -TYPE    => $update_type,
                                                  -SOURCE  => $source,
                                                  -DETAILS => encode_json({"email"=>$email,"comment"=>$comment}) );
  $ea->store( $event );
  my $event_hash = to_hash($event);
  push @events, $event_hash;
  $log->info("Completed processing ".$database->{dbname});
  return \@events;
}
#Check pan division databases like ontology db, ncbi_taxonomy, ensembl_metadata,...
sub check_pan_databases {
  my ($database_name) = @_;
  return $database_name =~ m/(ontology|ensembl_metadata|ensembl_website|ncbi_taxonomy|ensembl_accounts|ensembl_archive|ensembl_stable_ids|ensemblgenomes_stable_ids)/;
}

#Subroutine to add or force update a species database
sub process_core {
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source) = @_;
  die "Problem with ".$database->{dbname}.", can't find species name. Check species.production_name meta key" if !check_array_ref_empty($species);
  my @events;
  foreach my $species_name (@{$species}){
    my $update=$update_type;
    my $dba=create_database_dba($database,$species_name,$db_type,$species_ids);
    $log->info("Processing $species_name in database ".$dba->dbc()->dbname());
    #Check if this is a new genebuild
    $update = check_new_genebuild($dba, $gdba, $species_name, $update);
    #Check if this is a new assembly
    my $old_assembly_database_list;
    ($update,$old_assembly_database_list) = check_new_assembly($dba, $gdba, $species_name, $update);
    my $opts = { -INFO_ADAPTOR => $gdba,
                -ANNOTATION_ANALYZER =>
                  Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
                -COMPARA      => 0,
                -CONTIGS      => 1,
                -FORCE_UPDATE => 0,
                -VARIATION => 0};

    my $processor = Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);
    my $md = $processor->process_core($dba);
    $log->info( "Storing " . $md->name() );
    $gdba->store($md);
    my $ea = $metadatadba->get_EventInfoAdaptor();
    $log->info( "Storing event for $species_name in database ".$dba->dbc()->dbname() );
    my $event_details={"email"=>$email,"comment"=>$comment};
    $event_details->{'old_assembly_database_list'} = $old_assembly_database_list if defined $old_assembly_database_list;
    my $event = Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $md,
                                                    -TYPE    => $update,
                                                    -SOURCE  => $source,
                                                    -DETAILS => encode_json($event_details) );
    $ea->store( $event );
    my $event_hash = to_hash($event);
    push @events, $event_hash;
    $dba->dbc()->disconnect_if_idle();
  }
  return \@events;
}

#Subroutine to add or force update a species database
sub process_other_database {
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$update_type,$comment,$source) = @_;
  die "Problem with ".$database->{dbname}.", can't find species name. Check species.production_name meta key" if !check_array_ref_empty($species);
  my @events;
  foreach my $species_name (@{$species}){
    my $dba=create_database_dba($database,$species_name,$db_type,$species_ids);
    my $opts = { -INFO_ADAPTOR => $gdba,
                -ANNOTATION_ANALYZER =>
                  Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
                -COMPARA      => 0,
                -CONTIGS      => 1,
                -FORCE_UPDATE => 0,
                -VARIATION => $db_type =~ "variation" ? 1 : 0 };
    my $processor = Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);
    my $process_db_type_method = "process_".$db_type;
    my $md = $processor->$process_db_type_method($dba);
    $log->info( "Updating " . $md->name() );
    $gdba->update($md);
    my $ea = $metadatadba->get_EventInfoAdaptor();
    $log->info( "Storing event for $species_name in database ".$dba->dbc()->dbname() );
    my $event = Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $md,
                                                    -TYPE    => $update_type,
                                                    -SOURCE  => $source,
                                                    -DETAILS => encode_json({"email"=>$email,"comment"=>$comment}) );
    $ea->store( $event );
    my $event_hash = to_hash($event);
    push @events, $event_hash;
    $dba->dbc()->disconnect_if_idle();
  }
  return \@events;
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

sub check_if_coredb_exist {
  my ($gdba,$species,$metadatadba) = @_;
  my $dbia = $metadatadba->get_DatabaseInfoAdaptor();
  foreach my $species_name (@{$species}){
    my $md=$gdba->fetch_by_name($species_name);
    my @databases;
    eval{
      @databases = @{$dbia->fetch_databases($md)};
    }
    or do{
      die "$species_name core database need to be loaded first for this release";
    };
    my $coredbfound=0;
    foreach my $db (@databases){
      if ($db->{type} eq "core")
      {
        $coredbfound=1;
      }
    }
    if ($coredbfound){
      1;
    }
    else{
      die "$species_name core database need to be loaded first for this release";
    }
  }
  return;
}

sub to_hash {
  my ($event) = @_;
  my %event_hash;
  $event_hash{'details'}=$event->{details};
  $event_hash{'source'}= $event->{source};
  $event_hash{'type'} = $event->{type};
  $event_hash{'genome'}=$event->{subject}->{organism}->{name};
  return \%event_hash;
}

sub check_array_ref_empty {
  my ($array_ref) = @_;
  return scalar @$array_ref;
}

sub check_new_assembly {
  #Check the core database assembly value and compare it with what we have in the Metadata database
  #if the assembly doesn't exist in the metadata database then it's a new species, update the handover type
  #if the assembly is the same, all good, nothing to do here
  #if the assembly is different, make sure that we update the handover type and generate a list of old assembly databases to clean up except for collections
  my ($dba, $gdba, $species_name, $update_type) = @_;
  my $old_assembly_database_list;
  my $meta = $dba->get_MetaContainer();
  my $assembly_default = $meta->single_value_by_key('assembly.default');
  my $md = $gdba->fetch_by_name($species_name);
  #Checking if this is a new species
  if (defined $md){
    if ($assembly_default ne $md->assembly()->{assembly_default}){
      $update_type = 'new_assembly';
      # We don't want to drop the database if a genome in a collection has changed.
      if ($dba->dbc->dbname !~ /_collection_/){
        my $old_databases = $md->databases();
        foreach my $old_database (@{$old_databases})
        {
          push @{$old_assembly_database_list}, $old_database->dbname
        }
      }
    }
  }
  #If the species is not in the metadata database then flag is as a new assembly
  else {
    $update_type = 'new_assembly';
  }
  return ($update_type,$old_assembly_database_list);
}

sub check_new_genebuild {
  # Check the core database genebuild.version or (genebuild.start_date/genebuild.last_geneset_update) value and compare it with what we have in the Metadata database
  #if the Genebuild is the same, all good, nothing to do here
  #if the Genebuild is different, make sure that we update the handover type
  my ($dba, $gdba, $species_name, $update_type) = @_;
  my $old_assembly_database_list;
  my $meta = $dba->get_MetaContainer();
  my ($genebuild)        = @{$meta->list_value_by_key('genebuild.start_date')};
  my ($genebuild_version)= @{$meta->list_value_by_key('genebuild.version')};
  my ($genebuild_upd)    = @{$meta->list_value_by_key('genebuild.last_geneset_update')};
  my $gb_string = $genebuild_version;
  if(!defined $gb_string) {
    $gb_string = $genebuild;
    $gb_string .= "/".$genebuild_upd if defined $genebuild_upd;
  }
  my $md = $gdba->fetch_by_name($species_name);
  #If this species exist already
  if (defined $md){
    if ($gb_string ne $md->genebuild()){
      $update_type = 'new_genebuild';
    }
  }
  return ($update_type);
}

1;