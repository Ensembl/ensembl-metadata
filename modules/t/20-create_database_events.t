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
use Bio::EnsEMBL::MetaData::EventInfo;
use Bio::EnsEMBL::MetaData::DataReleaseInfo;

my $release =
  Bio::EnsEMBL::MetaData::DataReleaseInfo->new( -ENSEMBL_VERSION         => 99,
                                                -ENSEMBL_GENOMES_VERSION => 66,
                                                -RELEASE_DATE => '2015-09-29',
                                                -IS_CURRENT => 1 );

ok( defined $release, "Release object exists" );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba =
  $multi->get_DBAdaptor('empty_metadata')->get_DataReleaseInfoAdaptor();
$release->add_database( "smelly_mart_27",     "EnsemblNanas" );
$release->add_database( "smelly_snp_mart_27", "EnsemblNanas" );
$release->add_database( "weird_db_27",        "EnsemblNanas" );
$gdba->store($release);
my $database = $release->databases()->[0];

my $ea = $multi->get_DBAdaptor('empty_metadata')->get_EventInfoAdaptor();
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $database,
                                                    -TYPE    => "creation",
                                                    -SOURCE  => "me",
                                                    -DETAILS => "stuff" ) );
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $database,
                                                    -TYPE    => "update",
                                                    -SOURCE  => "you",
                                                    -DETAILS => "more stuff" )
);
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $database,
                                                    -TYPE    => "patch",
                                                    -SOURCE  => "pegleg",
                                                    -DETAILS => "arhhh" ) );

my $events = $ea->fetch_events($database);
is( scalar(@$events), 3, "Expected number of events" );
diag $events->[0]->to_string();
is( $events->[0]->subject()->dbID(), $database->dbID(), "Correct subject" );
is( $events->[0]->type(),            "creation",        "Correct type" );
is( $events->[0]->source(),          "me",              "Correct source" );
is( $events->[0]->details(),         "stuff",           "Correct details" );
ok( defined $events->[0]->timestamp(), "Timestamp set" );

diag $events->[1]->to_string();
is( $events->[1]->subject()->dbID(), $database->dbID(), "Correct subject" );
is( $events->[1]->type(),            "update",          "Correct type" );
is( $events->[1]->source(),          "you",             "Correct source" );
is( $events->[1]->details(),         "more stuff",      "Correct details" );
ok( defined $events->[1]->timestamp(), "Timestamp set" );

diag $events->[2]->to_string();
is( $events->[2]->subject()->dbID(), $database->dbID(), "Correct subject" );
is( $events->[2]->type(),            "patch",           "Correct type" );
is( $events->[2]->source(),          "pegleg",          "Correct source" );
is( $events->[2]->details(),         "arhhh",           "Correct details" );
ok( defined $events->[2]->timestamp(), "Timestamp set" );

done_testing;

$multi->cleanup();
