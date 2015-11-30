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

my %args = ( '-NAME'                => "test",
			 '-SPECIES'             => "Testus testa",
			 '-DBNAME'              => "test_species_core_27_80_1",
			 '-SPECIES_ID'          => 1,
			 '-TAXONOMY_ID'         => 999,
			 '-SPECIES_TAXONOMY_ID' => 99,
			 '-ASSEMBLY_NAME'       => "v2.0",
			 '-ASSEMBLY_ID'         => 'GCA_181818181',
			 '-ASSEMBLY_LEVEL'      => 'chromosome',
			 '-GENEBUILD'           => 'awesomeBuild1',
			 '-DIVISION'            => 'EnsemblSomewhere',
			 '-STRAIN'              => 'stress',
			 '-SEROTYPE'            => 'icky',
			 '-IS_REFERENCE'        => 1 );
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
ok( defined $genome, "Genome object exists" );
ok( $genome->dbname() eq $args{-DBNAME}, "dbname correct" );
ok( $genome->species_id()     eq $args{-SPECIES_ID},     "species_id correct" );
ok( $genome->division()       eq $args{-DIVISION},       "division correct" );
ok( $genome->assembly_name()  eq $args{-ASSEMBLY_NAME},  "ass name correct" );
ok( $genome->assembly_id()    eq $args{-ASSEMBLY_ID},    "ass ID correct" );
ok( $genome->assembly_level() eq $args{-ASSEMBLY_LEVEL}, "ass level correct" );
ok( $genome->genebuild()      eq $args{-GENEBUILD},      "genebuild correct" );
ok( $genome->name()           eq $args{-NAME},           "name correct" );
ok( $genome->species()        eq $args{-SPECIES},        "species ID correct" );
ok( $genome->taxonomy_id()    eq $args{-TAXONOMY_ID},    "taxid correct" );
ok( $genome->species_taxonomy_id() eq $args{-SPECIES_TAXONOMY_ID},
	"species taxid correct" );
ok( $genome->strain()       eq $args{-STRAIN},       "strain correct" );
ok( $genome->serotype()     eq $args{-SEROTYPE},     "serotype correct" );
ok( $genome->is_reference() eq $args{-IS_REFERENCE}, "is_reference correct" );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba  = $multi->get_DBAdaptor('empty_metadata');

done_testing;
