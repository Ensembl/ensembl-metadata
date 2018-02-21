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

  Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHive;

=head1 DESCRIPTION

=head1 MAINTAINER

 maurel@ebi.ac.uk 

=cut
package Bio::EnsEMBL::MetaData::Pipeline::MetadataUpdaterHive;

use base ('Bio::EnsEMBL::Hive::Process');
use strict;
use warnings;
use Bio::EnsEMBL::MetaData::MetadataUpdater
  qw/process_database/;

sub run{
my ($self) = @_;
my $metadata_uri = $self->param_required('metadata_uri');
my $database_uri = $self->param_required('database_uri');
my $release_date = $self->param('release_date');
my $e_release = $self->param('e_release');
my $eg_release = $self->param('eg_release');
my $current_release = $self->param('current_release');
my $hive_dbc = $self->dbc;

$hive_dbc->disconnect_if_idle() if defined $hive_dbc;

process_database($metadata_uri,$database_uri,$release_date,$e_release,$eg_release,$current_release);

return;
}

1;
