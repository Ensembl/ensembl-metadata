#!perl
# Copyright [2009-2014] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use Test::More;

BEGIN {
	use_ok( 'Bio::EnsEMBL::LookUp' );
	use_ok( 'Bio::EnsEMBL::LookUp::LocalLookUp' );
	use_ok( 'Bio::EnsEMBL::LookUp::RemoteLookUp' );
	use_ok( 'Bio::EnsEMBL::MetaData::GenomeInfo' );
	use_ok( 'Bio::EnsEMBL::MetaData::GenomeComparaInfo' );
	use_ok( 'Bio::EnsEMBL::MetaData::GenomeOrganismInfo' );
	use_ok( 'Bio::EnsEMBL::MetaData::GenomeAssemblyInfo' );
	use_ok( 'Bio::EnsEMBL::MetaData::ReleaseInfo' );
	use_ok( 'Bio::EnsEMBL::MetaData::DBSQL::GenomeInfoAdaptor' );
}

diag( "Testing ensembl-metadata, Perl $], $^X" );
done_testing;
