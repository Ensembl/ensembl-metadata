
=head1 LICENSE

Copyright 2015 EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

use warnings;
use strict;

package Bio::EnsEMBL::MetaData::Pipeline::GenomeFactory;

use base qw/Bio::EnsEMBL::Production::Pipeline::BaseSpeciesFactory/;

use Bio::EnsEMBL::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::DataReleaseInfo;

use Carp;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);
my $log = get_logger();

sub run {
  my ($self) = @_;

  # create a release to use
  $log->info("Connecting to info database");
  my $dba =
    Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
                                                     -USER =>,
                                                     $self->param('info_user'),
                                                     -PASS =>,
                                                     $self->param('info_pass'),
                                                     -HOST =>,
                                                     $self->param('info_host'),
                                                     -PORT =>,
                                                     $self->param('info_port'),
                                                     -DBNAME =>,
                                                     $self->param('info_dbname')
    );

  my $rdba         = $dba->get_DataReleaseInfoAdaptor();
  my $release      = $self->param('release');
  my $eg_release   = $self->param('eg_release');
  my $release_date = $self->param('release_date');
  $log->info( "Storing release e$release" . ( ( defined $eg_release ) ?
                  "/EG$eg_release" : "" ) .
                " $release_date" );

  $rdba->store(
    Bio::EnsEMBL::MetaData::DataReleaseInfo->new(
                                        -ENSEMBL_VERSION         => $release,
                                        -ENSEMBL_GENOMES_VERSION => $eg_release,
                                        -RELEASE_DATE => $release_date )
  );

  $log->info("Completed release creation");

  # run rest of process
  $self->SUPER::run();
  return;
} ## end sub run

1;

