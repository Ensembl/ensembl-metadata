# Copyright [2009-2018] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::MetaData::GenomeComparaInfo;
use Bio::EnsEMBL::MetaData::DataReleaseInfo;

my %rargs = ( -ENSEMBL_VERSION         => 99,
              -ENSEMBL_GENOMES_VERSION => 66,
              -RELEASE_DATE            => '2015-09-29',
							-IS_CURRENT              => 1 );
              
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my %args = ( -DBNAME   => "my_little_compara",
			 -DIVISION => "EnsemblVeggies",
			 -METHOD   => "myway",
			 -SET_NAME => "cassette",
			 -DATA_RELEASE => $release );
						 
my $compara = Bio::EnsEMBL::MetaData::GenomeComparaInfo->new(%args);

ok( defined $compara, "Compara object exists" );
ok( $compara->dbname()                 eq $args{-DBNAME},   "dbname exists" );
ok( $compara->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara->set_name()               eq $args{-SET_NAME}, "set_name exists" );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba  = $multi->get_DBAdaptor('empty_metadata')->get_GenomeComparaInfoAdaptor();
$gdba->data_release($release);

ok(!defined $compara->dbID(),"No DBID");
$gdba->store($compara);
ok(defined $compara->dbID(),"DBID");
ok( $compara->dbname()                 eq $args{-DBNAME},   "dbname exists" );
ok( $compara->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara->set_name()               eq $args{-SET_NAME}, "set_name exists" );

my $compara2 = $gdba->fetch_by_dbID($compara->dbID());
ok( $compara2->dbname()                 eq $args{-DBNAME},   "dbname exists" );
ok( $compara2->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara2->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara2->set_name()               eq $args{-SET_NAME}, "set_name exists" );

$gdba->_clear_cache();
my $compara2a = $gdba->fetch_by_dbID($compara->dbID());
ok( $compara2a->dbname()                 eq $args{-DBNAME},   "dbname exists" );
ok( $compara2a->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara2a->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara2a->set_name()               eq $args{-SET_NAME}, "set_name exists" );

my $c2 = "my_big_fat_compara";
$compara->dbname($c2);
$gdba->store($compara);
ok( $compara->dbname()                 eq $c2,   "dbname exists" );
ok( $compara->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara->set_name()               eq $args{-SET_NAME}, "set_name exists" );

$gdba->_clear_cache();
my $compara3 = $gdba->fetch_by_dbID($compara->dbID());
ok( $compara3->dbname()                 eq $c2,   "dbname exists" );
ok( $compara3->division()               eq $args{-DIVISION}, "division exists" );
ok( $compara3->method()                 eq $args{-METHOD},   "method exists" );
ok( $compara3->set_name()               eq $args{-SET_NAME}, "set_name exists" );

{
  my $dbs = $gdba->fetch_databases();
  is(scalar @$dbs, 1, "1 db found");
}

done_testing;
