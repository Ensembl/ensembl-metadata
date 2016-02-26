
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

package Bio::EnsEMBL::MetaData::Pipeline::UpdateBools;

use base qw/Bio::EnsEMBL::Production::Pipeline::Base/;

use Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor;
use Bio::EnsEMBL::MetaData::AnnotationAnalyzer;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

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
    my ($self) = @_;
    $log->info("Connecting to info database");
    $log->info("Connecting to info database");
    my $dba = Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor->new(
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
    $log->info("Updating booleans");
    $gdba->update_booleans();
    $log->info("Completed updating booleans");
    return;
}

sub write_output {
    my ($self) = @_;
    return;
}

1;

