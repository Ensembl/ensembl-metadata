=head1 LICENSE

Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

  Bio::EnsEMBL::Production::Pipeline::CopyDatabases::CopyDatabaseHive;

=head1 DESCRIPTION

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHiveProcessDb; 

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;

sub run {
my ($self) = @_;
my $metadata_uri = $self->param_required('metadata_uri');
my $database_uri = $self->param_required('database_uri');
my $species = $self->param('species');
my $db_type = $self->param('db_type');
my $release_date = $self->param('release_date');
my $e_release = $self->param('e_release');
my $eg_release = $self->param('eg_release');
my $current_release = $self->param('current_release');
$DB::single = 1;


if ($db_type eq "core"){
  $self->dataflow_output_id({
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'species' => $species,
             'db_type' => $db_type,
             'release_date' => $release_date,
             'e_release' => $e_release,
             'eg_release' => $eg_release,
             'current_release' => $current_release
			      }, 2);
}
elsif ($db_type eq "compara"){
  $self->dataflow_output_id({
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'species' => $species,
             'db_type' => $db_type,
             'release_date' => $release_date,
             'e_release' => $e_release,
             'eg_release' => $eg_release,
             'current_release' => $current_release
			      }, 4);
}
else {
  $self->dataflow_output_id({
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'species' => $species,
             'db_type' => $db_type,
             'release_date' => $release_date,
             'e_release' => $e_release,
             'eg_release' => $eg_release,
             'current_release' => $current_release
			      }, 3);
}
return;
}

1;
