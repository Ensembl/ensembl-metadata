#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::MetaData::Base qw(get_division check_assembly_update check_genebuild_update);
use JSON;

sub process_database {
  my ($metadata_uri,$database_uri,$release_date,$e_release,$eg_release,$current_release,$email,$comment,$source)  = @_;
  #Connect to metadata database
  my $metadatadba = create_metadata_dba($metadata_uri);
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  my $events;
  # Get database db_type and species  
  my ($species,$db_type,$database,$species_ids,$dba)=get_species_and_dbtype($database_uri);
  if (defined $e_release) {
    # Check if release already exist or create it
    $gdba = update_release_and_process_release_db($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$comment,$source,$db_type,$database);
  }
  #get current release and process release db
  else {
    $gdba = get_release_and_process_release_db($metadatadba,$gdba,$database,$email,$comment,$source,$db_type);
  }
  if ($db_type eq "core"){
    $events = process_core($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba);
  }
  elsif ($db_type eq "compara") {
    $events = process_compara($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba);
  }
  #Already processed mart, ontology, in get_release...
  elsif ($db_type eq "other"){
    1;
  }
  else {
    $events = process_other_database($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba);
  }
  # Disconnecting from server
  $gdba->_clear_cache();
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
  my ($metadatadba,$eg_release,$e_release,$release_date,$current_release,$gdba,$email,$comment,$source,$db_type,$database) = @_;
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my $release;
  my ($e_version,$eg_version)=get_release_from_db($database->{dbname});
  if ( defined $eg_version ) {
    if ($eg_release != $eg_version){
        die "Database release $eg_version does not match given release $eg_release";
    }
    elsif (defined $e_version and $e_release != $e_version){
      die "Database release $e_version does not match given release $e_release";
    }
    elsif ($e_release != ($eg_release + 53) ){
        die "Given non-vertebrate release is $eg_release, Vertebrate release should be ".($eg_release + 53)." instead of $e_release";
    }
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
    if (defined $e_version and $e_release != $e_version){
      die "Database release $e_version does not match given release $e_release";
    }
    elsif ($eg_release != ($e_release - 53) ){
      die "Given Vertebrate release is $e_release, non-vertebrate release should be ".($e_release - 53)." instead of $eg_release";
    }
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
    process_release_database($metadatadba,$gdba,$release,$database,$email,$comment,$source);
  }
  $gdba->data_release($release);
  $rdba->dbc()->disconnect_if_idle();
  return $gdba;
}

sub get_release_and_process_release_db {
  my ($metadatadba,$gdba,$database,$email,$comment,$source,$db_type) = @_;
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my $release;
  my ($e_version,$eg_version)=get_release_from_db($database->{dbname});
  if (defined $eg_version){
  $release = $rdba->fetch_by_ensembl_genomes_release($eg_version);
    if (defined $release){
      $log->info("Using release e".$release->{ensembl_version}."" . ( ( defined $release->{ensembl_genomes_version} ) ?
                    "/EG".$release->{ensembl_genomes_version}."" : "" ) .
                  " ".$release->{release_date});
    }
    else{
      die "Can't find release $release for EG in metadata database";
    }
  }
  elsif (defined $e_version){
    $release = $rdba->fetch_by_ensembl_release($e_version);
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
    process_release_database($metadatadba,$gdba,$release,$database,$email,$comment,$source);
  }
  $gdba->data_release($release);
  $rdba->dbc()->disconnect_if_idle();
  return $gdba;
}
sub get_species_and_dbtype {
  my ($database_uri)=@_;
  my $database = get_db_connection_params($database_uri);
  my ($db_type,$species,$dba,$species_ids);
  $log->info("Connecting to database $database->{dbname}");
  #dealing with Compara
  if ($database->{dbname} =~ m/_compara_/){
    $db_type="compara";
    $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
      -user   => $database->{user},
      -dbname => $database->{dbname},
      -host   => $database->{host},
      -port   => $database->{port},
      -pass => $database->{pass},
      -group => $db_type
    );
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
      my $species_id=$dba->dbc()->sql_helper()->execute_simple( -SQL =>qq/select species_id from meta where meta_key=? and meta_value=?/, -PARAMS => ['species.db_name',$species_name]);
      $species_ids->{$species_name}=$species_id->[0];
    }
  }
  #dealing with Variation
  elsif ($database->{dbname} =~ m/^(.*)_variation_/){
    $db_type="variation";
    $dba = Bio::EnsEMBL::Variation::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $1,
    );
  }
  #dealing with Regulation
  elsif ($database->{dbname} =~ m/^(.*)_funcgen_/){
    $db_type="funcgen";
    $dba = Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $1,
    );
  }
  #dealing with Core
  elsif ($database->{dbname} =~ m/^(.*)_core_/){
      $db_type="core";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type,
        -species => $1
      );
    }
    #dealing with otherfeatures
    elsif ($database->{dbname} =~ m/^(.*)_otherfeatures_/){
      $db_type="otherfeatures";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type,
        -species => $1
      );
    }
      #dealing with rnaseq
    elsif ($database->{dbname} =~ m/^(.*)_rnaseq_/){
      $db_type="rnaseq";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type,
        -species => $1
      );
    }
      #dealing with cdna
    elsif ($database->{dbname} =~ m/^(.*)_cdna_/){
      $db_type="cdna";
      $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -user   => $database->{user},
        -dbname => $database->{dbname},
        -host   => $database->{host},
        -port   => $database->{port},
        -pass => $database->{pass},
        -group => $db_type,
        -species => $1
      );
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
    if (!defined $species or $species eq ''){
      push @{$species},$1;
    }
  return ($species,$db_type,$database,$species_ids,$dba);
}

#Subroutine to create a DBA object for a species in a collection database
sub create_species_collection_database_dba {
  my ($database,$species,$db_type,$species_ids,$original_dba)=@_;
  my $dba;
  $log->info("Connecting to database ".$database->{dbname}." with species $species");
  #dealing with collections
  my $species_id = $species_ids->{$species};
  $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -dbconn => $original_dba->dbc,
    -multispecies_db => 1,
    -species => $species,
    -group => $db_type,
    -species_id => $species_id
  );
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
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba) = @_;
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
                                                    -TYPE    => 'other',
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
  my ($metadatadba,$gdba,$release,$database,$email,$comment,$source) = @_;
  my $division;
  my @events;
  #Check pan division databases
  if (check_pan_databases($database->{dbname})){
    $division="EnsemblPan";
  }
  #Specific case for ancestral and production db.
  elsif ($database->{dbname} =~ m/^ensembl_ancestral_\d+$/ or $database->{dbname} =~ m/^ensembl_production_\d+$/){
    $division = "EnsemblVertebrates";
  }
  #for the marts, get division name from database prefix.
  # e.g: plants_gene_mart_42
  elsif ($database->{dbname} =~ m/^(fungi|plants|metazoa|protists|)_?\w*_mart_\d+$/){
    if ($1){
      $division = "Ensembl".ucfirst($1);
    }
    else{
      $division = "EnsemblVertebrates";
    }
  }
  else{
    die "Can't find division for database ".$database->{dbname};
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
                                                  -TYPE    => 'other',
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
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba) = @_;
  die "Problem with ".$database->{dbname}.", can't find species name. Check species.production_name meta key" if !check_array_ref_empty($species);
  my @events;
  # if processing a collection database, delete genomes from metadata genomes that don't exist anymore or have been renamed in the new handed over database
  if ($dba->is_multispecies){
    cleanup_removed_genomes_collections($species,$database,$gdba);
  }
  foreach my $species_name (@{$species}){
    my $update_type='other';
    if ($dba->is_multispecies){
      $dba=create_species_collection_database_dba($database,$species_name,$db_type,$species_ids,$dba);
    }
    else{
      $dba->species($species_name);
    }
    $log->info("Processing $species_name in database ".$dba->dbc()->dbname());
    my $opts = { -INFO_ADAPTOR => $gdba,
                -ANNOTATION_ANALYZER =>
                  Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
                -COMPARA      => 0,
                -CONTIGS      => 1,
                -FORCE_UPDATE => 0,
                -VARIATION => 0};
    my $processor = Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);
    my $md = $processor->process_core($dba);
    #Check if this is a new genebuild
    $update_type = check_new_genebuild($dba, $gdba, $species_name, $update_type, $md);
    #Check if this is a new assembly
    my $old_assembly_database_list;
    ($update_type,$old_assembly_database_list) = check_new_assembly($dba, $gdba, $species_name, $update_type, $md);
    $log->info( "Storing " . $md->name() );
    $gdba->store($md);
    my $ea = $metadatadba->get_EventInfoAdaptor();
    $log->info( "Storing event for $species_name in database ".$dba->dbc()->dbname() );
    my $event_details={"email"=>$email,"comment"=>$comment};
    $event_details->{'old_assembly_database_list'} = $old_assembly_database_list if defined $old_assembly_database_list;
    my $event = Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $md,
                                                    -TYPE    => $update_type,
                                                    -SOURCE  => $source,
                                                    -DETAILS => encode_json($event_details) );
    $ea->store( $event );
    my $event_hash = to_hash($event);
    push @events, $event_hash;
  }
  $dba->dbc()->disconnect_if_idle();
  return \@events;
}

#Subroutine to add or force update a species database
sub process_other_database {
  my ($species,$metadatadba,$gdba,$db_type,$database,$species_ids,$email,$comment,$source,$dba) = @_;
  die "Problem with ".$database->{dbname}.", can't find species name. Check species.production_name meta key" if !check_array_ref_empty($species);
  my @events;
  foreach my $species_name (@{$species}){
    if ($dba->is_multispecies){
      $dba=create_species_collection_database_dba($database,$species_name,$db_type,$species_ids,$dba);
    }
    else{
      $dba->species($species_name);
    }
    check_if_coredb_exist($dba,$gdba,$species_name,$metadatadba);
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
                                                    -TYPE    => 'other',
                                                    -SOURCE  => $source,
                                                    -DETAILS => encode_json({"email"=>$email,"comment"=>$comment}) );
    $ea->store( $event );
    my $event_hash = to_hash($event);
    push @events, $event_hash;
  }
  $dba->dbc()->disconnect_if_idle();
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
  my ($dba,$gdba,$species_name,$metadatadba) = @_;
  my $dbia = $metadatadba->get_DatabaseInfoAdaptor();
  my $division = get_division($dba);
  my $mds=$gdba->fetch_by_name($species_name);
  my $md;
  foreach my $genome (@{$mds}){
    if ($genome->division() eq $division){
      $md = $genome;
    }
  }
  my @databases;
  eval{
    @databases = @{$dbia->fetch_databases($md)};
  }
  or do{
    $dba->dbc()->disconnect_if_idle();
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
    $dba->dbc()->disconnect_if_idle();
    die "$species_name core database need to be loaded first for this release";
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
  my ($dba, $gdba, $species_name, $update_type, $updated_genome) = @_;
  my $old_assembly_database_list;
  my $division = get_division($dba);
  my $current_genomes=$gdba->fetch_by_name($species_name);
  my $current_genome;
  foreach my $genome (@{$current_genomes}){
    $current_genome = $genome if ($genome->division() eq $division);
  }
  #Checking if this is a new species
  if (defined $current_genome){
    my $updated_assembly=check_assembly_update($updated_genome,$current_genome);
    if ($updated_assembly){
      $update_type = 'new_assembly';
      # We don't want to drop the database if a genome in a collection has changed.
      if ($dba->dbc->dbname !~ /_collection_/){
        my $old_databases = $current_genome->databases();
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
  my ($dba, $gdba, $species_name, $update_type, $updated_genome) = @_;
  my $meta = $dba->get_MetaContainer();
  my $division = get_division($dba);
  my $current_genomes=$gdba->fetch_by_name($species_name);
  my $current_genome;
  foreach my $genome (@{$current_genomes}){
    $current_genome = $genome if ($genome->division() eq $division);
  }
  #If this species exist already
  if (defined $current_genome){
    my $updated_genebuild=check_genebuild_update($updated_genome,$current_genome);
    if ($updated_genebuild){
      $update_type = 'new_genebuild';
    }
  }
  return ($update_type);
}

sub cleanup_removed_genomes_collections {
  # This subroutine will remove from the metadata database, genomes that have been removed or renamed from a newly handed over collection database.
  # When we run the pre-handover metadata load, we load all the databases from staging MySQL servers. If a collection database is handed over minus some genomes or some genomes have been renamed, the old records will still be present in the metadata db
  # This compares the list of current genomes from the metadata database with the list of genomes from the new collection database and cleanup the metadata database
  my ($species,$database,$gdba) = @_;
  my $current_genomes = $gdba->fetch_all_by_dbname($database->{dbname});
  foreach my $current_genome (@{$current_genomes}){
    if (grep $_ eq $current_genome->name(), @{$species}){
      next;
    }
    else{
      # If the genome is not anymore in the collection database, delete it from the metadata database
      $gdba->clear_genome($current_genome);
    }
  }
return 1;
}

sub get_release_from_db {
  # Get the Vertebrates and non-vertebrates release numbers from the database name.
  my ($database_name) = @_;
  my ($e_version,$eg_version);
  # Parse EG databases including core, core like, variation, funcgen and compara
  if (($database_name =~ m/(?:core|otherfeatures|rnaseq|cdna|variation|funcgen)_(\d+)_(\d+)_\d+$/) or ($database_name =~ m/ensembl_compara_(?:fungi|metazoa|protists|bacteria|plants|pan_homology)_(\d+)_(\d+)$/) or ($database_name =~ m/(?:fungi|plants|metazoa|protists)_?\w*_mart_(\d+)$/) or ($database_name =~ m/ensemblgenomes_info_(\d+)$/)or ($database_name =~ m/ensemblgenomes_stable_ids_(\d+)_(\d+)$/)){
    $eg_version=$1;
    $e_version=$2 if defined $2;
  }
  # Parse Ensembl release
  elsif(($database_name =~ m/(?:core|otherfeatures|rnaseq|cdna|variation|funcgen)_(\d+)_\d+$/) or ($database_name =~ m/ensembl_compara_(\d+)$/) or ($database_name =~ m/\w+_mart_(\d+)$/) or ($database_name =~ m/_(\d+)$/)){
    $e_version=$1;
  }
  return($e_version,$eg_version);
}
1;
