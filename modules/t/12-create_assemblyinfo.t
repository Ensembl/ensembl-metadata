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

use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;

my %oargs = ( '-NAME'                => "test",
			  '-SPECIES'             => "Testus testa",
			  '-TAXONOMY_ID'         => 999,
			  '-SPECIES_TAXONOMY_ID' => 99,
			  '-STRAIN'              => 'stress',
			  '-SEROTYPE'            => 'icky',
			  '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);

my %args = ( '-ASSEMBLY_NAME'      => "v2.0",
			 '-ASSEMBLY_ACCESSION' => 'GCA_181818181',
			 '-ASSEMBLY_LEVEL'     => 'chromosome',
			 '-BASE_COUNT'         => 99,
			 '-ORGANISM'           => $org );

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%args);
$assembly->sequences(
				 [ { name => 'a', acc => 'b' }, { name => 'c', acc => 'd' } ] );

ok( defined $assembly, "Assembly object exists" );
ok( $assembly->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $assembly->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $assembly->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $assembly->base_count()               eq $args{-BASE_COUNT} );
ok( $assembly->organism()->name()         eq $args{-ORGANISM}->name() );
ok( scalar( @{ $assembly->sequences() } ) eq 2 );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba  = $multi->get_DBAdaptor('empty_metadata');
my $aa    = $gdba->get_GenomeAssemblyInfoAdaptor();
ok( defined $aa &&
	$aa->isa('Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor') );

$aa->store($assembly);
ok( defined $assembly->dbID() );
ok( $aa->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from organism" ) eq
	'1' );
ok( $aa->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from assembly" ) eq
	'1' );
ok( $aa->db()->dbc()->sql_helper()->execute_single_result(
							   -SQL => "select count(*) from assembly_sequence"
	  )
	  eq '2' );

my $assa = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%args);
$aa->store($assa);
ok($assembly->dbID() eq $assa->dbID(), "dbID reuse");
	  
my $ass2 = $aa->fetch_by_dbID($assembly->dbID());
ok( defined $ass2, "Assembly object exists" );
ok( $ass2->dbID()            eq $assembly->dbID() );
ok( $ass2->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $ass2->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $ass2->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $ass2->base_count()               eq $args{-BASE_COUNT} );
ok( $ass2->organism()->name()         eq $args{-ORGANISM}->name() );
$aa->_clear_cache();
my $ass3 = $aa->fetch_by_dbID($assembly->dbID());
ok( defined $ass3, "Assembly object exists" );
ok( $ass3->dbID()            eq $assembly->dbID() );
ok( $ass3->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $ass3->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $ass3->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $ass3->base_count()               eq $args{-BASE_COUNT} );
ok( $ass3->organism()->name()         eq $args{-ORGANISM}->name() );

done_testing;
