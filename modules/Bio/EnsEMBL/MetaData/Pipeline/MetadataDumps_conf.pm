=pod 
=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION  

=head1 LICENSE
    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2024] EMBL-European Bioinformatics Institute
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
         http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.
=head1 CONTACT
    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates
=cut

package Bio::EnsEMBL::MetaData::Pipeline::MetadataDumps_conf;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf')
  ; # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly
use Bio::EnsEMBL::ApiVersion;
use Cwd;

sub resource_classes {
  my ($self) = @_;
  return { 
	  'default' => { 'LSF' => '-q production' , 'SLURM' => '--partition=production --time=1-00:00:00 --mem=1G'},
	  'himem' => { 'LSF' => '-q production -M 20000 -R "rusage[mem=20000]"', 'SLURM' => '--partition=production --time=1-00:00:00 --mem=2G' }
	 };
}

sub default_options {
  my ($self) = @_;
  return { %{ $self->SUPER::default_options },
           'user'      => undef,
           'port'      => undef,
           'host'      => undef,
           'dbname'      => 'ensembl_metadata',
           'division'      => [],
           'base_dir'     => getcwd,
           'release'  => undef,
           'pipeline_name' => 'metadata_dumps_'.$self->o('release'), 
           'dump_path' => '/hps/nobackup2/production/ensembl/$USER/metadata_dumps_'.$self->o('release')};
}

=head2 pipeline_wide_parameters
=cut

sub pipeline_wide_parameters {
  my ($self) = @_;
  return {
    %{ $self->SUPER::pipeline_wide_parameters
      } # here we inherit anything from the base class, then add our own stuff
  };
}

=head2 pipeline_analyses
=cut

sub pipeline_analyses {
  my ($self) = @_;
  return [
    {
      -logic_name      => 'InitialisePipeline',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids       => [ {} ],
      -parameters      => {},
      -max_retry_count => 0,
      -rc_name         => 'default',
      -flow_into       => {
                            '1' => ['metadata_txt_dumps','metadata_xml_dumps','metadata_json_dumps','metadata_uniprot_dumps','metadata_genome_reports_dumps'],
                          }
    },
    { 
      -logic_name  => 'metadata_txt_dumps',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -rc_name         => 'default',
      -parameters  => {
        'cmd' => 'perl #base_dir#/ensembl-metadata/misc_scripts/dump_metadata.pl -user #user# -port #port# -host #host# -dbname #dbname# -dumper Bio::EnsEMBL::MetaData::MetaDataDumper::TextMetaDataDumper -release #release# -dump_path #dump_path# -division #expr( join(" -division ", @{ #division# }) )expr#',
        'dbname' => $self->o('dbname'),
        'user' => $self->o('user'),
        'host' => $self->o('host'),
        'port' => $self->o('port'),
        'base_dir' => $self->o('base_dir'),
        'release' => $self->o('release'),
        'division' => $self->o('division'),
        'dump_path' => $self->o('dump_path'),
         },
    },
    { 
      -logic_name  => 'metadata_xml_dumps',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -rc_name         => 'himem',
      -parameters  => {
        'cmd' =>'perl #base_dir#/ensembl-metadata/misc_scripts/dump_metadata.pl -user #user# -port #port# -host #host# -dbname #dbname# -dumper Bio::EnsEMBL::MetaData::MetaDataDumper::XMLMetaDataDumper -release #release# -dump_path #dump_path# -division #expr( join(" -division ", @{ #division# }) )expr#',
        'dbname' => $self->o('dbname'),
        'user' => $self->o('user'),
        'host' => $self->o('host'),
        'port' => $self->o('port'),
        'base_dir' => $self->o('base_dir'),
        'release' => $self->o('release'),
        'division' => $self->o('division'),
        'dump_path' => $self->o('dump_path'),
         },
    },
    { 
      -logic_name  => 'metadata_json_dumps',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -rc_name         => 'himem',
      -parameters  => {
        'cmd' =>'perl #base_dir#/ensembl-metadata/misc_scripts/dump_metadata.pl -user #user# -port #port# -host #host# -dbname #dbname# -dumper Bio::EnsEMBL::MetaData::MetaDataDumper::JsonMetaDataDumper -release #release# -dump_path #dump_path# -division #expr( join(" -division ", @{ #division# }) )expr#',
        'dbname' => $self->o('dbname'),
        'user' => $self->o('user'),
        'host' => $self->o('host'),
        'port' => $self->o('port'),
        'base_dir' => $self->o('base_dir'),
        'release' => $self->o('release'),
        'division' => $self->o('division'),
        'dump_path' => $self->o('dump_path'),
         },
    },
    { 
      -logic_name  => 'metadata_uniprot_dumps',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -rc_name         => 'default',
      -parameters  => {
        'cmd' =>'perl #base_dir#/ensembl-metadata/misc_scripts/dump_metadata.pl -user #user# -port #port# -host #host# -dbname #dbname# -dumper Bio::EnsEMBL::MetaData::MetaDataDumper::UniProtReportDumper -release #release# -dump_path #dump_path# -division #expr( join(" -division ", @{ #division# }) )expr#',
        'dbname' => $self->o('dbname'),
        'user' => $self->o('user'),
        'host' => $self->o('host'),
        'port' => $self->o('port'),
        'base_dir' => $self->o('base_dir'),
        'release' => $self->o('release'),
        'division' => $self->o('division'),
        'dump_path' => $self->o('dump_path'),
         },
    },
    { 
      -logic_name  => 'metadata_genome_reports_dumps',
      -module      => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
      -meadow_type => 'LSF',
      -rc_name         => 'default',
      -parameters  => {
        'cmd' =>'for DIVISION in #expr( join(" ", @{ #division# }) )expr#;do echo "processing $DIVISION"; perl #base_dir#/ensembl-metadata/misc_scripts/report_genomes.pl -user #user# -port #port# -host #host# -dbname #dbname# -dump_path #dump_path#/$DIVISION -division $DIVISION -release #release#;done',
        'dbname' => $self->o('dbname'),
        'user' => $self->o('user'),
        'host' => $self->o('host'),
        'port' => $self->o('port'),
        'base_dir' => $self->o('base_dir'),
        'release' => $self->o('release'),
        'division' => $self->o('division'),
        'dump_path' => $self->o('dump_path'),
         },
    },
  ];
} ## end sub pipeline_analyses
1;
