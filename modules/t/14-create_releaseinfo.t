# Copyright [2009-2023] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::MetaData::DataReleaseInfo;

my $release =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION         => 99,
                                                -ENSEMBL_GENOMES_VERSION => 66,
                                                -RELEASE_DATE => '2015-09-29',
                                                -IS_CURRENT => 1);

ok( defined $release, "Release object exists" );
ok( $release->ensembl_version()         eq 99,           "e! Version correct" );
ok( $release->ensembl_genomes_version() eq 66,           "EG Version correct" );
ok( $release->release_date()            eq '2015-09-29', "Date correct" );
ok( $release->is_current()              eq 1, "Current flag correct" );

my $release2 =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION => 99,
                                                -RELEASE_DATE    => '2015-09-29',
                                                -IS_CURRENT => 1);
ok( defined $release2,                             "Release object exists" );
ok( defined $release2->ensembl_version(),          "Default version exists" );
ok( !defined $release2->ensembl_genomes_version(), "No EG version" );
ok( defined $release2->release_date(),             "Date exists" );
ok( defined $release2->is_current(),              "Current flag exist" );

my $release3 =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION => 98,
                                                -RELEASE_DATE    => '2014-09-29',
                                                -IS_CURRENT => 0);
my $release4 =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION         => 98,
                                                -ENSEMBL_GENOMES_VERSION => 65,
                                                -RELEASE_DATE => '2014-09-29',
                                                -IS_CURRENT => 0);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba =
  $multi->get_DBAdaptor('empty_metadata')->get_DataReleaseInfoAdaptor();

$gdba->store($release2);
ok( defined( $release2->dbID() ),    "dbID" );
ok( defined( $release2->adaptor() ), "Adaptor" );
$gdba->store($release);
ok( defined( $release->dbID() ),    "dbID" );
ok( defined( $release->adaptor() ), "Adaptor" );
$gdba->store($release3);
ok( defined( $release3->dbID() ),    "dbID" );
ok( defined( $release3->adaptor() ), "Adaptor" );
$gdba->store($release4);
ok( defined( $release4->dbID() ),    "dbID" );
ok( defined( $release4->adaptor() ), "Adaptor" );

my $e = $gdba->fetch_by_ensembl_release( $release2->ensembl_version() );
ok( defined $e,               "Obj" );
ok( defined( $e->dbID() ),    "dbID" );
ok( defined( $e->adaptor() ), "Adaptor" );
is( $e->ensembl_version(), $release2->ensembl_version(), "E version" );
ok( !defined $e->ensembl_genomes_version(), "EG version" );
my $eg =
  $gdba->fetch_by_ensembl_genomes_release($release->ensembl_genomes_version() );
ok( defined $eg,               "Obj" );
ok( defined( $eg->dbID() ),    "dbID" );
ok( defined( $eg->adaptor() ), "Adaptor" );
is( $eg->ensembl_version(), $release->ensembl_version(), "E version" );
is( $eg->ensembl_genomes_version(),
    $release->ensembl_genomes_version(),
    "EG version" );
my $c_e = $gdba->fetch_current_ensembl_release();
ok( defined $c_e,               "Obj" );
ok( defined( $c_e->dbID() ),    "dbID" );
ok( defined( $c_e->adaptor() ), "Adaptor" );
is( $c_e->ensembl_version(), $release2->ensembl_version(), "E version" );
ok( !defined $c_e->ensembl_genomes_version(), "EG version" );
my $c_eg = $gdba->fetch_current_ensembl_genomes_release();
ok( defined $c_eg,               "Obj" );
ok( defined( $c_eg->dbID() ),    "dbID" );
ok( defined( $c_eg->adaptor() ), "Adaptor" );
is( $c_eg->ensembl_version(), $release->ensembl_version(), "E version" );
is( $c_eg->ensembl_genomes_version(),
    $release->ensembl_genomes_version(),
    "EG version" );
# $multi->cleanup();
done_testing();
