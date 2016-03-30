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
              '-DISPLAY_NAME'        => "Testus testa",
              '-TAXONOMY_ID'         => 999,
              '-SPECIES_TAXONOMY_ID' => 99,
              '-STRAIN'              => 'stress',
              '-SEROTYPE'            => 'icky',
              '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);
$org->aliases( ["alias"] );

my %aargs = ( '-ASSEMBLY_NAME'      => "v2.0",
              '-ASSEMBLY_ACCESSION' => 'GCA_181818181.1',
              '-ASSEMBLY_LEVEL'     => 'chromosome',
              '-BASE_COUNT'         => 99,
              '-ORGANISM'           => $org );

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%aargs);
$assembly->sequences( [ { name => "a", acc => "xyz.1" } ] );

my %rargs = ( -ENSEMBL_VERSION         => 99,
              -ENSEMBL_GENOMES_VERSION => 66,
              -RELEASE_DATE            => '2015-09-29' );
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my %args = ( '-DBNAME'       => "test_species_core_27_80_1",
             '-SPECIES_ID'   => 1,
             '-GENEBUILD'    => 'awesomeBuild1',
             '-DIVISION'     => 'EnsemblSomewhere',
             '-IS_REFERENCE' => 1,
             '-ASSEMBLY'     => $assembly,
             '-DATA_RELEASE' => $release );
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
ok( defined $genome, "Genome object exists" );

$genome->add_database("test_species_variation_27_80_1");
$genome->add_database("test_species_otherfeatures_27_80_1");
$genome->add_database("test_species_funcgen_27_80_1");

is ($genome->databases()->{core}->{dbname}, 'test_species_core_27_80_1', "Has core");
is ($genome->databases()->{core}->{species_id}, 1, "Has core species_id");
is ($genome->databases()->{variation}->{dbname}, 'test_species_variation_27_80_1', "Has variation");
is ($genome->databases()->{variation}->{species_id}, 1, "Has variation species_id");
is ($genome->databases()->{otherfeatures}->{dbname}, 'test_species_otherfeatures_27_80_1', "Has otherfeatures");
is ($genome->databases()->{otherfeatures}->{species_id}, 1, "Has otherfeatures species_id");
is ($genome->databases()->{funcgen}->{dbname}, 'test_species_funcgen_27_80_1', "Has funcgen");
is ($genome->databases()->{funcgen}->{species_id}, 1, "Has funcgen species_id");

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval {
     $multi->load_database('empty_metadata');
};

my $gdba  = $multi->get_DBAdaptor('empty_metadata')->get_GenomeInfoAdaptor();
$gdba->data_release($release);

$gdba->store($genome);
ok( defined $genome->dbID(), "DBID" );
ok( $gdba->db()->dbc()->sql_helper()
    ->execute_single_result( -SQL => "select count(*) from organism" ) eq '1' );
ok( $gdba->db()->dbc()->sql_helper()
    ->execute_single_result( -SQL => "select count(*) from assembly" ) eq '1' );
ok( $gdba->db()->dbc()->sql_helper()
    ->execute_single_result( -SQL => "select count(*) from genome" ) eq '1' );

my $genome2 = $gdba->fetch_by_dbID( $genome->dbID() );
ok( defined $genome2, "Genome object exists" );

is ($genome2->databases()->{core}->{dbname}, 'test_species_core_27_80_1', "Has core");
is ($genome2->databases()->{core}->{species_id}, 1, "Has core species_id");
is ($genome2->databases()->{variation}->{dbname}, 'test_species_variation_27_80_1', "Has variation");
is ($genome2->databases()->{variation}->{species_id}, 1, "Has variation species_id");
is ($genome2->databases()->{otherfeatures}->{dbname}, 'test_species_otherfeatures_27_80_1', "Has otherfeatures");
is ($genome2->databases()->{otherfeatures}->{species_id}, 1, "Has otherfeatures species_id");
is ($genome2->databases()->{funcgen}->{dbname}, 'test_species_funcgen_27_80_1', "Has funcgen");
is ($genome2->databases()->{funcgen}->{species_id}, 1, "Has funcgen species_id");

$gdba->_clear_cache();
my $genome3 = $gdba->fetch_by_dbID( $genome->dbID() );
ok( defined $genome3, "Genome object exists" );

is ($genome3->databases()->{core}->{dbname}, 'test_species_core_27_80_1', "Has core");
is ($genome3->databases()->{core}->{species_id}, 1, "Has core species_id");
is ($genome3->databases()->{variation}->{dbname}, 'test_species_variation_27_80_1', "Has variation");
is ($genome3->databases()->{variation}->{species_id}, 1, "Has variation species_id");
is ($genome3->databases()->{otherfeatures}->{dbname}, 'test_species_otherfeatures_27_80_1', "Has otherfeatures");
is ($genome3->databases()->{otherfeatures}->{species_id}, 1, "Has otherfeatures species_id");
is ($genome3->databases()->{funcgen}->{dbname}, 'test_species_funcgen_27_80_1', "Has funcgen");
is ($genome3->databases()->{funcgen}->{species_id}, 1, "Has funcgen species_id");

{
  my $dbs = $gdba->fetch_databases();
  is(scalar @$dbs, 4, "4 dbs found");
}

done_testing;

$multi->cleanup();
