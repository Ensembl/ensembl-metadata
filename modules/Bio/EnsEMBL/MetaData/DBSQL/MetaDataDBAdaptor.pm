
=head1 LICENSE

Copyright [2009-2020] EMBL-European Bioinformatics Institute

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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::DBSQL::MetaDataDBAdaptor

=head1 DESCRIPTION

Specialised DBAdaptor for connecting to the ensembl_metadata MySQL database

=head1 SYNOPSIS

# instantiate directly
my $dba = Bio::EnsEMBL::DBSQL::MetaDataDBAdaptor->new();

# retrieve from Registry
my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor("multi", "metadata");

# retrieve adaptors
my $adaptor = $dba->get_GenomeInfoAdaptor();
									  
=head DESCRIPTION

A specialised DBAdaptor allowing connection to a metadata database. 
Can be used to retrieve instances of:
    Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
    Bio::EnsEMBL::MetaData::DBSQL::DataReleaseInfoAdaptor
    Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor
    Bio::EnsEMBL::MetaData::DBSQL::GenomeOrganismInfoAdaptor
    Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor
    Bio::EnsEMBL::MetaData::DBSQL::DatabaseInfoAdaptor


=head1 SEE ALSO

Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor
Bio::EnsEMBL::MetaData::DBSQL::DataReleaseInfoAdaptor
Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor
Bio::EnsEMBL::MetaData::DBSQL::GenomeOrganismInfoAdaptor
Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor
Bio::EnsEMBL::MetaData::DBSQL::DatabaseInfoAdaptor
    
=head1 AUTHOR

Dan Staines

=cut		

package Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

use strict;
use warnings;

use base qw ( Bio::EnsEMBL::DBSQL::DBAdaptor );
use Data::Dumper;

use Bio::EnsEMBL::Utils::Exception qw(throw);

=head1 SUBROUTINES/METHODS

=head2 get_available_adaptors	

	Description	: Retrieve all adaptors supported by this database
	Returns		: Hash of adaptor modules by name
=cut

sub get_available_adaptors {
  return {
    GenomeInfo      => 'Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor',
    DataReleaseInfo => 'Bio::EnsEMBL::MetaData::DBSQL::DataReleaseInfoAdaptor',
    GenomeComparaInfo =>
      'Bio::EnsEMBL::MetaData::DBSQL::GenomeComparaInfoAdaptor',
    GenomeOrganismInfo =>
      'Bio::EnsEMBL::MetaData::DBSQL::GenomeOrganismInfoAdaptor',
    GenomeAssemblyInfo =>
      'Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor',
    DatabaseInfo =>
      'Bio::EnsEMBL::MetaData::DBSQL::DatabaseInfoAdaptor',
    EventInfo => 'Bio::EnsEMBL::MetaData::DBSQL::EventInfoAdaptor' };
}

1;

