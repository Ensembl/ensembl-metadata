# Copyright [2009-2017] EMBL-European Bioinformatics Institute
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

use Data::Dumper;


my %args = ( '-ASSEMBLY_NAME'      => "v2.0",
             '-ASSEMBLY_DEFAULT'   => "v2_0",
             '-ASSEMBLY_USCS'      => "wotevs",
			 '-ASSEMBLY_ACCESSION' => 'GCA_181818181.1',
			 '-ASSEMBLY_LEVEL'     => 'chromosome',
			 '-BASE_COUNT'         => 99 );

diag "Testing creation";
my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%args);
$assembly->sequences(
				 [ { name => 'a', acc => 'b.1' }, { name => 'c', acc => 'd.2' } ] );

ok( defined $assembly, "Assembly object exists" );
ok( $assembly->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $assembly->assembly_default()         eq $args{-ASSEMBLY_DEFAULT} );
ok( $assembly->assembly_ucsc()            eq $args{-ASSEMBLY_UCSC} );
ok( $assembly->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $assembly->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $assembly->base_count()               eq $args{-BASE_COUNT} );
ok( scalar( @{ $assembly->sequences() } ) eq 2 );

diag "Testing storage";
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval {
     $multi->load_database('empty_metadata');
};

my $gdba  = $multi->get_DBAdaptor('empty_metadata');
my $aa    = $gdba->get_GenomeAssemblyInfoAdaptor();
ok( defined $aa &&
	$aa->isa('Bio::EnsEMBL::MetaData::DBSQL::GenomeAssemblyInfoAdaptor') );

$aa->store($assembly);
ok( defined $assembly->dbID() );
ok( $aa->db()->dbc()->sql_helper()
	->execute_single_result( -SQL => "select count(*) from assembly" ) eq
	'1' );
ok( $aa->db()->dbc()->sql_helper()->execute_single_result(
							   -SQL => "select count(*) from assembly_sequence where assembly_id=?", 
                                                           -PARAMS=>[$assembly->dbID()]
	  )
	  eq '2' );

diag "Testing storage with reuse";
my $assa = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%args);
$assa->sequences(
				 [ { name => 'a', acc => 'b.1' }, { name => 'c', acc => 'd.2' } ] );

$aa->store($assa);
ok($assembly->dbID() eq $assa->dbID(), "dbID reuse");

diag "Testing retrieval with cache";	  
my $ass2 = $aa->fetch_by_dbID($assembly->dbID());
ok( defined $ass2, "Assembly object exists" );
ok( $ass2->dbID()            eq $assembly->dbID() );
ok( $ass2->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $ass2->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $ass2->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $ass2->base_count()               eq $args{-BASE_COUNT} );
$aa->_clear_cache();

diag "Testing retrieval without cache";
my $ass3 = $aa->fetch_by_dbID($assembly->dbID());
ok( defined $ass3, "Assembly object exists" );
ok( $ass3->dbID()            eq $assembly->dbID() );
ok( $ass3->assembly_name()            eq $args{-ASSEMBLY_NAME} );
ok( $ass3->assembly_accession()       eq $args{-ASSEMBLY_ACCESSION} );
ok( $ass3->assembly_level()           eq $args{-ASSEMBLY_LEVEL} );
ok( $ass3->base_count()               eq $args{-BASE_COUNT} );

diag "Testing fetch methods";
{
  diag "Testing fetch by fetch_all_by_sequence_accession";
  my $asses = $aa->fetch_all_by_sequence_accession("b");
  ok(defined $asses && $asses->[0]->assembly_name() eq "v2.0");
}
{
  diag "Testing fetch by fetch_all_by_sequence_accession";
  my $asses = $aa->fetch_all_by_sequence_accession("b.1");
  ok(defined $asses && $asses->[0]->assembly_name() eq "v2.0");
}
{
  diag "Testing fetch by fetch_all_by_sequence_accession_unversioned";
  my $asses = $aa->fetch_all_by_sequence_accession_unversioned("b");
  ok(defined $asses && $asses->[0]->assembly_name() eq "v2.0");
}
{
  diag "Testing fetch by fetch_all_by_sequence_accession_versioned";
    my $asses = $aa->fetch_all_by_sequence_accession_versioned("b.1");
  ok(defined $asses && $asses->[0]->assembly_name() eq "v2.0");
}
{
  diag "Testing fetch by fetch_by_assembly_accession";
  my $ass = $aa->fetch_by_assembly_accession("GCA_181818181.1");
  ok(defined $ass && $ass->assembly_name() eq "v2.0")
}
{
  diag "Testing fetch by fetch_all_by_assembly_set_chain";
  my $asses = $aa->fetch_all_by_assembly_set_chain("GCA_181818181");
  ok(defined $asses && $asses->[0]->assembly_name() eq "v2.0")
}

done_testing;
$multi->cleanup();