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
use Bio::EnsEMBL::MetaData::GenomeOrganismInfo;
use Bio::EnsEMBL::MetaData::DBSQL::MetaDataDBAdaptor;

my %args = ( '-NAME'                => "test",
             '-DISPLAY_NAME'        => "Testus testa",
             '-SCIENTIFIC_NAME'        => "Testus testa",
             '-TAXONOMY_ID'         => 999,
             '-SPECIES_TAXONOMY_ID' => 99,
             '-STRAIN'              => 'stress',
             '-SEROTYPE'            => 'icky',
             '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%args);

ok( defined $org, "Organism object exists" );
ok( $org->name()                eq $args{-NAME} );
ok( $org->display_name()        eq $args{-DISPLAY_NAME} );
ok( $org->scientific_name()        eq $args{-SCIENTIFIC_NAME} );
ok( $org->taxonomy_id()         eq $args{-TAXONOMY_ID} );
ok( $org->species_taxonomy_id() eq $args{-SPECIES_TAXONOMY_ID} );
ok( $org->strain()              eq $args{-STRAIN} );
ok( $org->serotype()            eq $args{-SEROTYPE} );
ok( $org->is_reference()        eq $args{-IS_REFERENCE} );
$org->publications( [ 1, 2, 3, 4 ] );
ok( scalar @{ $org->publications() } eq 4 );
$org->aliases( [ "one", "two" ] );
ok( scalar @{ $org->aliases() } eq 2 );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval {
     $multi->load_database('empty_metadata');
};
my $mdba  = $multi->get_DBAdaptor('empty_metadata');
my $odba  = $mdba->get_GenomeOrganismInfoAdaptor();

$odba->store($org);
ok( defined( $org->dbID() ),    "dbID" );
ok( defined( $org->adaptor() ), "Adaptor" );

ok( $odba->db()->dbc()->sql_helper()
    ->execute_single_result( -SQL => "select count(*) from organism" ) eq '1' );
ok( $odba->db()->dbc()->sql_helper()->execute_single_result(
                             -SQL => "select count(*) from organism_publication"
    ) eq '4' );
ok( $odba->db()->dbc()->sql_helper()
    ->execute_single_result( -SQL => "select count(*) from organism_alias" ) eq
    '2' );

diag "Testing storage";
my $orga = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%args);
$orga->publications( [ 1, 2, 3, 4 ] );
$orga->aliases( [ "one", "two" ] );
$odba->store($orga);
ok( $org->dbID() eq $orga->dbID(), "dbID reuse" );

diag "Testing retrieval";
my $org2 = $odba->fetch_by_dbID( $org->dbID() );
ok( $org2->name()                     eq $args{-NAME} );
ok( $org2->display_name()             eq $args{-DISPLAY_NAME} );
ok( $org2->taxonomy_id()              eq $args{-TAXONOMY_ID} );
ok( $org2->species_taxonomy_id()      eq $args{-SPECIES_TAXONOMY_ID} );
ok( $org2->strain()                   eq $args{-STRAIN} );
ok( $org2->serotype()                 eq $args{-SEROTYPE} );
ok( $org2->is_reference()             eq $args{-IS_REFERENCE} );
ok( scalar @{ $org2->publications() } eq 4 );
ok( scalar @{ $org2->aliases() }      eq 2 );
$odba->_clear_cache();

diag "Testing retrieval with no cache";
$org2 = $odba->fetch_by_dbID( $org->dbID() );
ok( $org2->name()                     eq $args{-NAME} );
ok( $org2->display_name()             eq $args{-DISPLAY_NAME} );
ok( $org2->taxonomy_id()              eq $args{-TAXONOMY_ID} );
ok( $org2->species_taxonomy_id()      eq $args{-SPECIES_TAXONOMY_ID} );
ok( $org2->strain()                   eq $args{-STRAIN} );
ok( $org2->serotype()                 eq $args{-SEROTYPE} );
ok( $org2->is_reference()             eq $args{-IS_REFERENCE} );
ok( scalar @{ $org2->publications() } eq 4 );
ok( scalar @{ $org2->aliases() }      eq 2 );

diag "Testing update";
$org2->serotype("zerotype");
$odba->store($org2);
my $org3 = $odba->fetch_by_dbID( $org->dbID() );
ok( $org3->serotype()                 eq "zerotype" );
ok( scalar @{ $org3->publications() } eq 4 );
ok( scalar @{ $org3->aliases() }      eq 2 );

# see if we get the same one back by storing the same thing
diag "Testing store of same organism";
my $org4 = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%args);
$org4->publications( [ 1, 2, 3, 4 ] );
$org4->aliases( [ "one", "two" ] );
ok( !defined $org4->dbID() );
$odba->store($org4);
ok( $org4->dbID() eq $org->dbID() );

# do some testing of retrieval
{
  diag("testing name retrieval");
  my $org = $odba->fetch_by_name("test");
  ok( defined $org );
  is( $org->name(), "test" );
}
{
  diag("testing display_name retrieval");
  my $org = $odba->fetch_by_display_name("Testus testa");
  ok( defined $org );
  is( $org->name(), "test" )
}
{
  diag("testing any name retrieval");
  my $org = $odba->fetch_by_any_name("test");
  ok( defined $org );
  is( $org->name(), "test" )
}
{
  diag("testing any name retrieval");
  my $org = $odba->fetch_by_any_name("Testus testa");
  ok( defined $org );
  is( $org->name(), "test" )
}
{
  diag("testing taxid retrieval");
  my $orgs = $odba->fetch_all_by_taxonomy_id(999);
  ok( defined $orgs );
  is( $orgs->[0]->name(), "test" )
}
{
  diag("testing taxids retrieval");
  my $orgs = $odba->fetch_all_by_taxonomy_ids( [ 999, 1000, 1001 ] );
  ok( defined $orgs );
  is( $orgs->[0]->name(), "test" )
}
{
  diag("testing name pattern retrieval");
  my $orgs = $odba->fetch_all_by_name_pattern("t.*");
  ok( defined $orgs );
  is( $orgs->[0]->name(), "test" )
}
{
  diag("testing alias retrieval");
  my $org = $odba->fetch_by_alias("one");
  ok( defined $org );
  is( $org->name(), "test" )
}
{
  diag("testing scientific retrieval");
  my $org = $odba->fetch_by_scientific_name("Testus testa");
  ok( defined $org );
  is( $org->name(), "test" )
}
done_testing;
$multi->cleanup();