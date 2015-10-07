
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

package Bio::EnsEMBL::Utils::MetaData::Pipeline::ProcessGenomes_conf;

use strict;
use warnings;
use Data::Dumper;
use base qw/Bio::EnsEMBL::EGPipeline::PipeConfig::EGGeneric_conf/;

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
		variation     => 1
	};
} ## end sub default_options

sub resource_classes {
	my ($self) = @_;
	return { ' default ' => { ' LSF ' => ' - q production-rh6' } };
}

# Force an automatic loading of the registry in all workers.
sub beekeeper_extra_cmdline_options {
	my $self = shift;
	return "-reg_conf " . $self->o("registry");
}

sub pipeline_analyses {
	my ($self) = @_;
	return [

		{
			-logic_name => 'SpeciesFactory',
			-module =>
			  'Bio::EnsEMBL::EGPipeline::Common::RunnableDB::EGSpeciesFactory',
			-max_retry_count => 1,
			-input_ids       => [ {} ],
			-parameters      => {
				species         => $self->o('species'),
				antispecies     => $self->o('antispecies'),
				division        => $self->o('division'),
				run_all         => $self->o('run_all'),
				meta_filters    => $self->o('meta_filters'),
				chromosome_flow => 0,
				variation_flow  => 0
			},
			-flow_into   => { '2' => ['ProcessGenome'], },
			-meadow_type => 'LOCAL',
		},
		{
			-logic_name => 'ProcessGenome',
			-module => 'Bio::EnsEMBL::Utils::MetaData::Pipeline::ProcessGenome',
			-meadow_type       => 'LSF',
			-analysis_capacity => 50,
			-hive_capacity     => -1,      # turn off the reciprocal limiter
			-parameters        => {
				info_user       => $self->o('info_user'),
				info_host       => $self->o('info_host'),
				info_pass       => $self->o('info_pass'),
				info_port       => $self->o('info_port'),
				info_dbname     => $self->o('info_dbname'),
				force_update    => $self->o('force_update'),
				contigs         => $self->o('contigs'),
				variation       => $self->o('variation'),
			  }

		}
	];
} ## end sub pipeline_analyses

1;

