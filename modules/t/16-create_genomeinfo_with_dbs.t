# Copyright [2009-2019] EMBL-European Bioinformatics Institute
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
              '-URL_NAME'            => "Testus_testa",
              '-TAXONOMY_ID'         => 999,
              '-SPECIES_TAXONOMY_ID' => 99,
              '-STRAIN'              => 'stress',
              '-SEROTYPE'            => 'icky',
              '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);
$org->aliases( ["alias"] );

my %aargs = ( '-ASSEMBLY_NAME'      => "v2.0",
              '-ASSEMBLY_DEFAULT'   => "v2_0",
              '-ASSEMBLY_ACCESSION' => 'GCA_181818181.1',
              '-ASSEMBLY_LEVEL'     => 'chromosome',
              '-BASE_COUNT'         => 99);

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%aargs);
$assembly->sequences( [ { name => "a", acc => "xyz.1" } ] );

my %rargs = ( -ENSEMBL_VERSION         => 99,
              -ENSEMBL_GENOMES_VERSION => 66,
              -RELEASE_DATE            => '2015-09-29',
              -IS_CURRENT              => 1 );
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval {
     $multi->load_database('empty_metadata');
};
my $gdba  = $multi->get_DBAdaptor('empty_metadata')->get_GenomeInfoAdaptor();
$gdba->data_release($release);

my %args = ( '-DBNAME'       => "test_species_core_27_80_1",
             '-SPECIES_ID'   => 1,
             '-GENEBUILD'    => 'awesomeBuild1',
             '-DIVISION'     => 'EnsemblSomewhere',
             '-IS_REFERENCE' => 1,
             '-ASSEMBLY'     => $assembly,
             '-DATA_RELEASE' => $release,
             '-ORGANISM'     => $org  );
             
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
ok( defined $genome, "Genome object exists" );

$genome->add_database("test_species_variation_27_80_1");
$genome->add_database("test_species_otherfeatures_27_80_1");
$genome->add_database("test_species_funcgen_27_80_1");

is (scalar(grep {$_->dbname() eq 'test_species_core_27_80_1'} grep {$_->type() eq 'core'} @{$genome->databases()}), 1, "Has core");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'core'} @{$genome->databases()}), 1, "Has core species_id");
is (scalar(grep {$_->dbname() eq 'test_species_variation_27_80_1'} grep {$_->type() eq 'variation'} @{$genome->databases()}), 1, "Has variation");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'variation'} @{$genome->databases()}), 1, "Has variation species_id");
is (scalar(grep {$_->dbname() eq 'test_species_otherfeatures_27_80_1'} grep {$_->type() eq 'otherfeatures'} @{$genome->databases()}), 1, "Has otherfeatures");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'otherfeatures'} @{$genome->databases()}), 1, "Has otherfeatures species_id");
is (scalar(grep {$_->dbname() eq 'test_species_funcgen_27_80_1'} grep {$_->type() eq 'funcgen'} @{$genome->databases()}), 1, "Has funcgen");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'funcgen'} @{$genome->databases()}), 1, "Has funcgen species_id");

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

my $genome2_dbs = $genome2->databases();
is (scalar(grep {$_->dbname() eq 'test_species_core_27_80_1'} grep {$_->type() eq 'core'} @{$genome2_dbs}), 1, "Has core");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'core'} @{$genome2_dbs}), 1, "Has core species_id");
is (scalar(grep {$_->dbname() eq 'test_species_variation_27_80_1'} grep {$_->type() eq 'variation'} @{$genome2_dbs}), 1, "Has variation");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'variation'} @{$genome2_dbs}), 1, "Has variation species_id");
is (scalar(grep {$_->dbname() eq 'test_species_otherfeatures_27_80_1'} grep {$_->type() eq 'otherfeatures'} @{$genome2_dbs}), 1, "Has otherfeatures");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'otherfeatures'} @{$genome2_dbs}), 1, "Has otherfeatures species_id");
is (scalar(grep {$_->dbname() eq 'test_species_funcgen_27_80_1'} grep {$_->type() eq 'funcgen'} @{$genome2_dbs}), 1, "Has funcgen");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'funcgen'} @{$genome2_dbs}), 1, "Has funcgen species_id");

{
  diag("testing core database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_core_27_80_1');
  is(scalar @$core_database, 1, "core db found");
}
{
  diag("testing variation database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_variation_27_80_1');
  is(scalar @$core_database, 1, "variation db found");
}
{
  diag("testing otherfeatures database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_otherfeatures_27_80_1');
  is(scalar @$core_database, 1, "otherfeatures db found");
}
{
  diag("testing funcgen database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_funcgen_27_80_1');
  is(scalar @$core_database, 1, "funcgen db found");
}

$gdba->_clear_cache();
my $genome3 = $gdba->fetch_by_dbID( $genome->dbID() );
my $genome3_dbs = $genome3->databases();
ok( defined $genome3, "Genome object exists" );

is (scalar(grep {$_->dbname() eq 'test_species_core_27_80_1'} grep {$_->type() eq 'core'} @{$genome3_dbs}), 1, "Has core");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'core'} @{$genome3_dbs}), 1, "Has core species_id");
is (scalar(grep {$_->dbname() eq 'test_species_variation_27_80_1'} grep {$_->type() eq 'variation'} @{$genome3_dbs}), 1, "Has variation");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'variation'} @{$genome3_dbs}), 1, "Has variation species_id");
is (scalar(grep {$_->dbname() eq 'test_species_otherfeatures_27_80_1'} grep {$_->type() eq 'otherfeatures'} @{$genome3_dbs}), 1, "Has otherfeatures");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'otherfeatures'} @{$genome3_dbs}), 1, "Has otherfeatures species_id");
is (scalar(grep {$_->dbname() eq 'test_species_funcgen_27_80_1'} grep {$_->type() eq 'funcgen'} @{$genome3_dbs}), 1, "Has funcgen");
is (scalar(grep {$_->species_id() == 1} grep {$_->type() eq 'funcgen'} @{$genome3_dbs}), 1, "Has funcgen species_id");

{
  my $dbs = $gdba->fetch_databases();
  is(scalar @$dbs, 4, "4 dbs found");
}
{
  diag("testing core database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_core_27_80_1');
  is(scalar @$core_database, 1, "core db found");
}
{
  diag("testing variation database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_variation_27_80_1');
  is(scalar @$core_database, 1, "variation db found");
}
{
  diag("testing otherfeatures database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_otherfeatures_27_80_1');
  is(scalar @$core_database, 1, "otherfeatures db found");
}
{
  diag("testing funcgen database retrieval");
  my $core_database = $gdba->fetch_all_by_dbname('test_species_funcgen_27_80_1');
  is(scalar @$core_database, 1, "funcgen db found");
}

done_testing;

$multi->cleanup();
