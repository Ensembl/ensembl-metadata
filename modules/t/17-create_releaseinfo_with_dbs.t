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
use Bio::EnsEMBL::MetaData::DataReleaseInfo;
use Data::Dumper;
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval { $multi->load_database('empty_metadata'); };

my $release =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION         => 99,
                                                -ENSEMBL_GENOMES_VERSION => 66,
                                                -RELEASE_DATE => '2015-09-29' );

ok( defined $release, "Release object exists" );


my $gdba =
  $multi->get_DBAdaptor('empty_metadata')->get_DataReleaseInfoAdaptor();
$release->add_database( "smelly_mart_27",     "EnsemblNanas" );
$release->add_database( "smelly_snp_mart_27", "EnsemblNanas" );
$release->add_database( "weird_db_27",        "EnsemblNanas" );

{
  my @marts = grep {$_->type() eq 'mart'} @{$release->databases()};
  is( scalar @marts, 2, "2 marts" );
  my @others = grep {$_->type() eq 'other'} @{$release->databases()};
  is( scalar @others, 1, "1 other" );
}

{
  my $dbs = $gdba->fetch_databases($release);
  is( scalar @$dbs, 3, "3 dbs found" );
}

$gdba->store($release);
ok( defined( $release->dbID() ),    "dbID" );
ok( defined( $release->adaptor() ), "Adaptor" );

$gdba->_clear_cache();
my $eg =
  $gdba->fetch_by_ensembl_genomes_release($release->ensembl_genomes_version() );
ok( defined $eg,               "Obj" );
ok( defined( $eg->dbID() ),    "dbID" );
ok( defined( $eg->adaptor() ), "Adaptor" );
is( $eg->ensembl_version(), $release->ensembl_version(), "E version" );
is( $eg->ensembl_genomes_version(),
    $release->ensembl_genomes_version(),
    "EG version" );

{
  my $eg_databases = $eg->databases();
  my @marts = grep {$_->type() eq 'mart'} @{$eg_databases};
  is( scalar @marts, 2, "2 marts" );
  my @others = grep {$_->type() eq 'other'} @{$eg_databases};
  is( scalar @others, 1, "1 other" );
}

{
  my $dbs = $gdba->fetch_databases($release);
  is( scalar @$dbs, 3, "3 dbs found" );
}

done_testing;
$multi->cleanup();
