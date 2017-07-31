
=head1 LICENSE

Copyright [2009-2017] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::MetaData::Pipeline::ProcessGenome

=head1 DESCRIPTION

Runnable to process a species

=head1 AUTHOR

Dan Staines

=cut

use warnings;
use strict;

package Bio::EnsEMBL::MetaData::Pipeline::ProcessGenome;

use base qw/Bio::EnsEMBL::Production::Pipeline::Common::Base/;

use Bio::EnsEMBL::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;
use Bio::EnsEMBL::MetaData::AnnotationAnalyzer;

use Carp;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($INFO);
my $log = get_logger();

sub param_defaults {
  my ($self) = @_;
  return {};
}

sub fetch_input {
  my ($self) = @_;
  return;
}

sub run {
  my ($self)  = @_;
  my $dbas    = {};
  my $species = $self->param_required('species');

  return if $species eq 'Ancestral sequences';

  $log->info("Finding DBAdaptors for $species");
  for my $type (qw/core variation otherfeatures funcgen/) {
    $dbas->{$type} = $self->get_DBAdaptor($type);
  }
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
  my $gdba = $dba->get_GenomeInfoAdaptor();

  # set the release to use when storing genomes
  my $rdba = $dba->get_DataReleaseInfoAdaptor();
  my $release;
  if ( defined $self->param('eg_release') ) {
    $release =
      $rdba->fetch_by_ensembl_genomes_release(
                                           $self->param('eg_release') );
  }
  else {
    $release =
      $rdba->fetch_by_ensembl_release( $self->param('release') );
  }
  $gdba->data_release($release);

  my $upd = $self->param('force_update') || 0;

  my $opts = { -INFO_ADAPTOR => $gdba,
               -ANNOTATION_ANALYZER =>
                 Bio::EnsEMBL::MetaData::AnnotationAnalyzer->new(),
               -COMPARA      => 0,
               -CONTIGS      => $self->param('contigs') || 1,
               -FORCE_UPDATE => $upd,
               -VARIATION    => $self->param('variation') || 1 };

  $self->hive_dbc()->disconnect_if_idle();

  my $processor =
    Bio::EnsEMBL::MetaData::MetaDataProcessor->new(%$opts);

  $log->info("Processing $species");

  my $md = $processor->process_genome($dbas);

  if ( defined $md->dbID() && $upd == 1 ) {
    $log->info( "Updating " . $md->name() );
    $gdba->update($md);
  }
  elsif ( !defined $md->dbID() ) {
    $log->info( "Storing " . $md->name() );
    $gdba->store($md);
  }

  $dba->dbc()->disconnect_if_idle();
  $gdba->dbc()->disconnect_if_idle();

  $log->info("Completed processing $species");
  return;
} ## end sub run

sub write_output {
  my ($self) = @_;
  return;
}

1;

