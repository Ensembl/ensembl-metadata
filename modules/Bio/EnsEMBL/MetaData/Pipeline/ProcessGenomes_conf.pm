
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

Bio::EnsEMBL::MetaData::Pipeline::ProcessGenomes_conf

=head1 DESCRIPTION

Pipeline configuration to load a metadata database

=head1 AUTHOR

Dan Staines

=cut

package Bio::EnsEMBL::MetaData::Pipeline::ProcessGenomes_conf;

use strict;
use warnings;
use base qw/Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf/;

use Bio::EnsEMBL::ApiVersion;
use POSIX qw(strftime);

sub resource_classes {
  my ($self) = @_;
  return {
     'default' => { 'LSF' => '-q production-rh7' },
     'himem' =>
       { 'LSF' => '-q production-rh7 -M  16000 -R "rusage[mem=16000]"' }
  };
}

=head2 default_options

    Description : Implements default_options() interface method of Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf that is used to initialize default options.

=cut

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options()
      },    # inherit other stuff from the base class

    pipeline_name => 'process_genomes',
    species       => [],
    division      => [],
    run_all       => 0,
    antispecies   => [],
    meta_filters  => {},
    force_update  => 0,
    contigs       => 1,
    variation     => 1,
    release       => software_version(),
    eg_release    => undef,
    release_date  => strftime( "%F", localtime ) };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
  my $self = shift;
  return "-reg_conf " . $self->o("registry");
}

sub pipeline_analyses {
  my ($self) = @_;
  return [ {
          -logic_name => 'GenomeFactory',
          -module => 'Bio::EnsEMBL::MetaData::Pipeline::GenomeFactory',
          -max_retry_count => 1,
          -input_ids       => [ {} ],
          -parameters      => {
                           info_user       => $self->o('info_user'),
                           info_host       => $self->o('info_host'),
                           info_pass       => $self->o('info_pass'),
                           info_port       => $self->o('info_port'),
                           info_dbname     => $self->o('info_dbname'),
                           release         => $self->o('release'),
                           eg_release      => $self->o('eg_release'),
                           release_date    => $self->o('release_date'),
                           species         => $self->o('species'),
                           antispecies     => $self->o('antispecies'),
                           division        => $self->o('division'),
                           run_all         => $self->o('run_all'),
                           meta_filters    => $self->o('meta_filters'),
                           chromosome_flow => 0,
                           variation_flow  => 0 },
          -flow_into =>
            { '2' => ['ProcessGenome'], '5' => ['ProcessCompara'] },
          -hive_capacity => 1,
          -meadow_type   => 'LOCAL', }, {
          -logic_name => 'ProcessGenome',
          -module => 'Bio::EnsEMBL::MetaData::Pipeline::ProcessGenome',
          -hive_capacity => 50,
          -wait_for      => ['GenomeFactory'],
          -parameters    => {
                           info_user    => $self->o('info_user'),
                           info_host    => $self->o('info_host'),
                           info_pass    => $self->o('info_pass'),
                           info_port    => $self->o('info_port'),
                           info_dbname  => $self->o('info_dbname'),
                           release      => $self->o('release'),
                           eg_release   => $self->o('eg_release'),
                           release_date => $self->o('release_date'),
                           force_update => $self->o('force_update'),
                           contigs      => $self->o('contigs'),
                           variation    => $self->o('variation') } }, {
          -logic_name => 'ProcessCompara',
          -module => 'Bio::EnsEMBL::MetaData::Pipeline::ProcessCompara',
          -hive_capacity => 50,
          -wait_for      => ['ProcessGenome'],
          -rc_name       => 'himem',
          -parameters    => {
                           info_user    => $self->o('info_user'),
                           info_host    => $self->o('info_host'),
                           info_pass    => $self->o('info_pass'),
                           info_port    => $self->o('info_port'),
                           info_dbname  => $self->o('info_dbname'),
                           release      => $self->o('release'),
                           eg_release   => $self->o('eg_release'),
                           release_date => $self->o('release_date'),
                           force_update => $self->o('force_update') } },
        { -logic_name => 'UpdateBools',
          -module => 'Bio::EnsEMBL::MetaData::Pipeline::UpdateBools',
          -hive_capacity => 1,
          -input_ids     => [ {} ],
          -wait_for      => [ 'ProcessGenome', 'ProcessCompara' ],
          -parameters    => {
                           info_user    => $self->o('info_user'),
                           info_host    => $self->o('info_host'),
                           info_pass    => $self->o('info_pass'),
                           info_port    => $self->o('info_port'),
                           info_dbname  => $self->o('info_dbname'),
                           release      => $self->o('release'),
                           eg_release   => $self->o('eg_release'),
                           force_update => $self->o('force_update') } }
  ];
} ## end sub pipeline_analyses

1;

