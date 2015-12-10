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
use Data::Dumper;
use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::MetaData::GenomeInfo;

my %oargs = ( '-NAME'                => "test",
			  '-SPECIES'             => "Testus testa",
			  '-TAXONOMY_ID'         => 999,
			  '-SPECIES_TAXONOMY_ID' => 99,
			  '-STRAIN'              => 'stress',
			  '-SEROTYPE'            => 'icky',
			  '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);

my %aargs = ( '-ASSEMBLY_NAME'      => "v2.0",
			 '-ASSEMBLY_ACCESSION' => 'GCA_181818181',
			 '-ASSEMBLY_LEVEL'     => 'chromosome',
			 '-BASE_COUNT'         => 99,
			 '-ORGANISM'           => $org );

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%aargs);

my %rargs = ( -ENSEMBL_VERSION => 99, -ENSEMBL_GENOMES_VERSION => 66, -RELEASE_DATE => '2015-09-29' );
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my %args = ( 
			 '-DBNAME'              => "test_species_core_27_80_1",
			 '-SPECIES_ID'          => 1,
			 '-GENEBUILD'           => 'awesomeBuild1',
			 '-DIVISION'            => 'EnsemblSomewhere',
			 '-IS_REFERENCE'        => 1,
                         '-ASSEMBLY' => $assembly,
                         '-DATA_RELEASE' => $release
 );
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
ok( defined $genome, "Genome object exists" );
ok( $genome->dbname() eq $args{-DBNAME}, "dbname correct" );
ok( $genome->species_id()     eq $args{-SPECIES_ID},     "species_id correct" );
ok( $genome->division()       eq $args{-DIVISION},       "division correct" );
ok( $genome->genebuild()      eq $args{-GENEBUILD},      "genebuild correct" );
ok( $genome->is_reference() eq $args{-IS_REFERENCE}, "is_reference correct" );
ok( $genome->assembly_name()  eq $aargs{-ASSEMBLY_NAME},  "ass name correct" );
ok( $genome->assembly_accession()    eq $aargs{-ASSEMBLY_ACCESSION},    "ass ID correct" );
ok( $genome->assembly_level() eq $aargs{-ASSEMBLY_LEVEL}, "ass level correct" );
ok( $genome->name()           eq $oargs{-NAME},           "name correct" );
ok( $genome->species()        eq $oargs{-SPECIES},        "species ID correct" );
ok( $genome->taxonomy_id()    eq $oargs{-TAXONOMY_ID},    "taxid correct" );
ok( $genome->species_taxonomy_id() eq $oargs{-SPECIES_TAXONOMY_ID},
	"species taxid correct" );
ok( $genome->strain()       eq $oargs{-STRAIN},       "strain correct" );
ok( $genome->serotype()     eq $oargs{-SEROTYPE},     "serotype correct" );


my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba  = $multi->get_DBAdaptor('empty_metadata')->get_GenomeInfoAdaptor();

$gdba->store($genome);
ok(defined $genome->dbID(),"DBID");
ok( $gdba->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from organism" ) eq
	'1' );
ok( $gdba->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from assembly" ) eq
	'1' );
ok( $gdba->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from genome" ) eq
	'1' );

my $genome2 = $gdba->fetch_by_dbID($genome->dbID());
ok( defined $genome2, "Genome object exists" );
ok($genome->dbID() eq $genome2->dbID(),"DBID"); 
ok( $genome2->dbname() eq $args{-DBNAME}, "dbname correct" );
ok( $genome2->species_id()     eq $args{-SPECIES_ID},     "species_id correct" );
ok( $genome2->division()       eq $args{-DIVISION},       "division correct" );
ok( $genome2->genebuild()      eq $args{-GENEBUILD},      "genebuild correct" );
ok( $genome2->is_reference() eq $args{-IS_REFERENCE}, "is_reference correct" );
ok( $genome2->assembly_name()  eq $aargs{-ASSEMBLY_NAME},  "ass name correct" );
ok( $genome2->assembly_accession()    eq $aargs{-ASSEMBLY_ACCESSION},    "ass ID correct" );
ok( $genome2->assembly_level() eq $aargs{-ASSEMBLY_LEVEL}, "ass level correct" );
ok( $genome2->name()           eq $oargs{-NAME},           "name correct" );
ok( $genome2->species()        eq $oargs{-SPECIES},        "species ID correct" );
ok( $genome2->taxonomy_id()    eq $oargs{-TAXONOMY_ID},    "taxid correct" );
ok( $genome2->species_taxonomy_id() eq $oargs{-SPECIES_TAXONOMY_ID},
	"species taxid correct" );
ok( $genome2->strain()       eq $oargs{-STRAIN},       "strain correct" );
ok( $genome2->serotype()     eq $oargs{-SEROTYPE},     "serotype correct" );

$gdba->_clear_cache();
my $genome3 = $gdba->fetch_by_dbID($genome->dbID());
ok( defined $genome3, "Genome object exists" );
ok($genome->dbID() eq $genome3->dbID(),"DBID"); 
ok( $genome3->dbname() eq $args{-DBNAME}, "dbname correct" );
ok( $genome3->species_id()     eq $args{-SPECIES_ID},     "species_id correct" );
ok( $genome3->division()       eq $args{-DIVISION},       "division correct" );
ok( $genome3->genebuild()      eq $args{-GENEBUILD},      "genebuild correct" );
ok( $genome3->is_reference() eq $args{-IS_REFERENCE}, "is_reference correct" );
ok( $genome3->assembly_name()  eq $aargs{-ASSEMBLY_NAME},  "ass name correct" );
ok( $genome3->assembly_accession()    eq $aargs{-ASSEMBLY_ACCESSION},    "ass ID correct" );
ok( $genome3->assembly_level() eq $aargs{-ASSEMBLY_LEVEL}, "ass level correct" );
ok( $genome3->name()           eq $oargs{-NAME},           "name correct" );
ok( $genome3->species()        eq $oargs{-SPECIES},        "species ID correct" );
ok( $genome3->taxonomy_id()    eq $oargs{-TAXONOMY_ID},    "taxid correct" );
ok( $genome3->species_taxonomy_id() eq $oargs{-SPECIES_TAXONOMY_ID},
	"species taxid correct" );
ok( $genome3->strain()       eq $oargs{-STRAIN},       "strain correct" );
ok( $genome3->serotype()     eq $oargs{-SEROTYPE},     "serotype correct" );

my $genome4 = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
$gdba->store($genome4);
ok($genome4->dbID() eq $genome->dbID(),"DBID reuse");

done_testing;
