=head1 LICENSE

Copyright [2016-2019] EMBL-European Bioinformatics Institute

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
my $release_date = $self->param('release_date');
my $e_release = $self->param('e_release');
my $eg_release = $self->param('eg_release');
my $current_release = $self->param('current_release');
my $email = $self->param_required('email');
my $timestamp = $self->param('timestamp');
my $comment = $self->param('comment');
my $source = $self->param('source');

my $output_hash;
if (!defined $e_release){
  $output_hash={
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'email' => $email,
             'comment' => $comment,
             'source' => $source,
             'timestamp' => $timestamp
			      };
}
elsif (!defined $eg_release){
  $output_hash={
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'release_date' => $release_date,
             'e_release' => $e_release,
             'current_release' => $current_release,
             'email' => $email,
             'comment' => $comment,
             'source' => $source,
             'timestamp' => $timestamp
			      };
}
else {
    $output_hash={
			       'metadata_uri' => $metadata_uri,
             'database_uri' => $database_uri,
             'release_date' => $release_date,
             'e_release' => $e_release,
             'eg_release' => $eg_release,
             'current_release' => $current_release,
             'comment' => $comment,
             'source' => $source,
             'email' => $email,
             'timestamp' => $timestamp
			      };
}

my $database = get_db_connection_params( $database_uri);
if ($database->{dbname} =~ m/_core_/){
  $self->dataflow_output_id($output_hash, 2);
}
elsif ($database->{dbname} =~ m/_compara_/){
  $self->dataflow_output_id($output_hash, 4);
}
else {
  $self->dataflow_output_id($output_hash, 3);
}
return;
}

#Subroutine to parse Server URI and return connection details
sub get_db_connection_params {
  my ($uri) = @_;
  return '' unless defined $uri;
  my $db = Bio::EnsEMBL::Hive::Utils::URL::parse($uri);
  return $db;
}

1;
