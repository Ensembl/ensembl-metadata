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
use Bio::EnsEMBL::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::AnnotationAnalyzer;

sub process_database {
  my ($metadata_uri,$database_uri,$species,$db_type,$release_date,$e_release,$eg_release,$current_release)  = @_;
  #Connect to metadata database
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
                                             $metadata->{dbname});
  my $gdba = $metadatadba->get_GenomeInfoAdaptor();
  # Check if release already exist or create it
  my $rdba = $metadatadba->get_DataReleaseInfoAdaptor();
  my $release;
  if ( defined $eg_release ) {
    $release = $rdba->fetch_by_ensembl_genomes_release($eg_release);
    if (!defined $release){
      store_new_release($rdba,$e_release,$eg_release,$release_date,$current_release)
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
      store_new_release($rdba,$e_release,$eg_release,$release_date,$current_release)
    }
    else{
      $log->info("release e$e_release" . ( ( defined $eg_release ) ?
                  "/EG$eg_release" : "" ) .
                " $release_date already exist, reusing it");
    }
  }
  $gdba->data_release($release);
  # Check if we are working with Compara or species database
  if ($db_type eq "core"){
    process_core($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba);
  }
  elsif ($db_type eq "compara") {
    process_compara($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba);
  }
  else {
    check_if_coredb_exist($gdba,$species,$metadatadba);
    process_other_database($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba);
  }
  #Updating booleans
  $log->info("Updating booleans");
  $gdba->update_booleans();
  $log->info("Completed updating booleans");
  # Disconnecting from server
  $rdba->dbc()->disconnect_if_idle();
  $gdba->dbc()->disconnect_if_idle();
  $metadatadba->dbc()->disconnect_if_idle();
  $log->info("All done");
  return;
} ## end sub run

#Subroutine to parse Server URI and return connection details
sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

#Subroutine to process compara database and add or force update
sub process_compara {
  my ($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba) = @_;

  my $database = get_db_connection_params( $database_uri);

  my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $species,
    -group => $db_type
  );
  my $cdba = $metadatadba->get_GenomeComparaInfoAdaptor();
  my $opts = { -INFO_ADAPTOR => $gdba,
               -ANNOTATION_ANALYZER =>
                 Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
               -COMPARA      => 1,
               -CONTIGS      => 0,
               -FORCE_UPDATE => 0,
               -VARIATION    => 0 };
  my $processor = Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);
  my $compara_infos = $processor->process_compara( $compara_dba, {});

  for my $compara_info (@$compara_infos) {
    my $nom = $compara_info->method() . "/" . $compara_info->set_name();
    if ( defined $compara_info->dbID() ) {
      $log->info( "Updating compara info for " . $nom );
      $cdba->update($compara_info);
    }
    else {
      $log->info( "Storing compara info for " . $nom );
      $cdba->store($compara_info);
    }
  }
  $cdba->dbc()->disconnect_if_idle();
  $compara_dba->dbc()->disconnect_if_idle();
  $log->info("Completed processing compara $compara_dba->{dbname}");
  return;
}

#Subroutine to add or force update a species database
sub process_core {
  my ($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba) = @_;
  my $database = get_db_connection_params( $database_uri);

  $log->info("Connecting to database $database->{dbname}");
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $species,
    -group => $db_type);

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
  $dba->dbc()->disconnect_if_idle();
  $log->info("Completed processing Core $database->{dbname} for $species");
  return ;
}

#Subroutine to add or force update a species database
sub process_other_database {
  my ($database_uri,$db_type,$species,$metadatadba,$gdba,$rdba,) = @_;
  my $database = get_db_connection_params( $database_uri);

  $log->info("Connecting to database $database->{dbname}");
  my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -user   => $database->{user},
    -dbname => $database->{dbname},
    -host   => $database->{host},
    -port   => $database->{port},
    -pass => $database->{pass},
    -species => $species,
    -group => $db_type);

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
  $dba->dbc()->disconnect_if_idle();
  $log->info("Completed processing $db_type $database->{dbname} for $species");
  return ;
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
  my $md=$gdba->fetch_by_name($species);
  my @databases;
  eval{
    @databases = @{$dbia->fetch_databases($md)};
  }
  or do{
    die "$species core database need to be loaded first for this release";
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
    die "$species core database need to be loaded first for this release";
  }
  return;
}
1;