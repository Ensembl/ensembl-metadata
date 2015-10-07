
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

package Bio::EnsEMBL::Utils::MetaData::Pipeline::ProcessGenome;

use base qw/Bio::EnsEMBL::EGPipeline::Common::RunnableDB::Base/;

use Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor;
use Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer;

use Carp;
use Data::Dumper;
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
	print Dumper($dbas);
	$log->info("Connecting to info database");
	my $gdba = Bio::EnsEMBL::Utils::MetaData::DBSQL::GenomeInfoAdaptor->new(
		-DBC => Bio::EnsEMBL::DBSQL::DBConnection->new(
			-USER =>,
			$self->param('info_user'),
			-PASS =>,
			$self->param('info_pass'),
			-HOST =>,
			$self->param('info_host'),
			-PORT =>,
			$self->param('info_port'),
			-DBNAME =>,
			$self->param('info_dbname'),
		  )
	);

	my $upd = $self->param('force_update') || 0;

	my $opts = {
		-INFO_ADAPTOR => $gdba,
		-ANNOTATION_ANALYZER =>
		  Bio::EnsEMBL::Utils::MetaData::AnnotationAnalyzer->new(),
		-COMPARA      => 0,
		-CONTIGS      => $self->param('contigs') || 1,
		-FORCE_UPDATE => $upd,
		-VARIATION    => $self->param('variation') || 1
	};

	my $processor =
	  Bio::EnsEMBL::Utils::MetaData::MetaDataProcessor->new(%$opts);

	$log->info("Processing $species");

	my $md = $processor->process_genome($dbas);

	if ( defined $md->dbID() && $upd == 1 ) {
		$log->info( "Updating " . $md->species() );
		$gdba->update($md);
	}
	elsif ( !defined $md->dbID() ) {
		$log->info( "Storing " . $md->species() );
		$gdba->store($md);
	}

	$log->info("Completed processing $species");
	return;
}

sub write_output {
	my ($self) = @_;
	return;
}

1;

