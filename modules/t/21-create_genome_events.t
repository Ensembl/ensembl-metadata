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
use Data::Dumper;
use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::MetaData::GenomeInfo;
use Bio::EnsEMBL::MetaData::EventInfo;

my %oargs = ( '-NAME'                => "test",
              '-DISPLAY_NAME'        => "Testus testa",
              '-SCIENTIFIC_NAME'     => "Testus testa",
              '-URL_NAME'            => "Testus_testa",
              '-TAXONOMY_ID'         => 999,
              '-SPECIES_TAXONOMY_ID' => 99,
              '-STRAIN'              => 'stress',
              '-SEROTYPE'            => 'icky',
              '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%oargs);
$org->aliases( ["alias"] );

my %aargs = ( '-ASSEMBLY_NAME'      => "v2.0",
              '-ASSEMBLY_DEFAULT'   => "v2.0",    
              '-ASSEMBLY_ACCESSION' => 'GCA_181818181.1',
              '-ASSEMBLY_LEVEL'     => 'chromosome',
              '-BASE_COUNT'         => 99 );

my $assembly = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%aargs);
$assembly->sequences( [ { name => "a", acc => "xyz.1" } ] );

my %rargs = ( -ENSEMBL_VERSION         => 99,
              -ENSEMBL_GENOMES_VERSION => 66,
              -RELEASE_DATE            => '2015-09-29',
              -IS_CURRENT              => 1 );
my $release = Bio::EnsEMBL::MetaData::DataReleaseInfo->new(%rargs);

my %args = ( '-DBNAME'       => "test_species_core_27_80_1",
             '-SPECIES_ID'   => 1,
             '-GENEBUILD'    => 'awesomeBuild1',
             '-DIVISION'     => 'EnsemblSomewhere',
             '-IS_REFERENCE' => 1,
             '-ASSEMBLY'     => $assembly,
             '-DATA_RELEASE' => $release,
              '-ORGANISM'           => $org );
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%args);
ok( defined $genome, "Genome object exists" );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
eval { $multi->load_database('empty_metadata'); };

my $gdba = $multi->get_DBAdaptor('empty_metadata')->get_GenomeInfoAdaptor();
$gdba->data_release($release);

$gdba->store($genome);
ok( defined $genome->dbID(), "DBID" );

my $ea = $multi->get_DBAdaptor('empty_metadata')->get_EventInfoAdaptor();
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $genome,
                                                    -TYPE    => "creation",
                                                    -SOURCE  => "me",
                                                    -DETAILS => "stuff" ) );
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $genome,
                                                    -TYPE    => "update",
                                                    -SOURCE  => "you",
                                                    -DETAILS => "more stuff" )
);
$ea->store( Bio::EnsEMBL::MetaData::EventInfo->new( -SUBJECT => $genome,
                                                    -TYPE    => "patch",
                                                    -SOURCE  => "pegleg",
                                                    -DETAILS => "arhhh" ) );

my $events = $ea->fetch_events($genome);
is( scalar(@$events), 3, "Expected number of events" );
diag $events->[0]->to_string();
is( $events->[0]->subject()->dbID(), $genome->dbID(), "Correct subject" );
is( $events->[0]->type(),            "creation",      "Correct type" );
is( $events->[0]->source(),          "me",            "Correct source" );
is( $events->[0]->details(),         "stuff",         "Correct details" );
ok( defined $events->[0]->timestamp(), "Timestamp set" );

diag $events->[1]->to_string();
is( $events->[1]->subject()->dbID(), $genome->dbID(), "Correct subject" );
is( $events->[1]->type(),            "update",        "Correct type" );
is( $events->[1]->source(),          "you",           "Correct source" );
is( $events->[1]->details(), "more stuff", "Correct details" );
ok( defined $events->[1]->timestamp(), "Timestamp set" );

diag $events->[2]->to_string();
is( $events->[2]->subject()->dbID(), $genome->dbID(), "Correct subject" );
is( $events->[2]->type(),            "patch",         "Correct type" );
is( $events->[2]->source(),          "pegleg",        "Correct source" );
is( $events->[2]->details(),         "arhhh",         "Correct details" );
ok( defined $events->[2]->timestamp(), "Timestamp set" );

done_testing;

$multi->cleanup();
