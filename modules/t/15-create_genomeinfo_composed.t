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
use Data::Dumper;
use Test::More;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::MetaData::GenomeInfo;
use Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;
use Bio::EnsEMBL::MetaData::GenomeOrganismInfo;

my %org_args = ( '-NAME'                => "test",
                 '-DISPLAY_NAME'        => "Testus testa",
                 '-TAXONOMY_ID'         => 999,
                 '-SPECIES_TAXONOMY_ID' => 99,
                 '-STRAIN'              => 'stress',
                 '-SEROTYPE'            => 'icky',
                 '-IS_REFERENCE'        => 1 );
my $org = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%org_args);

ok( defined $org, "Organism object exists" );
ok( $org->name()        eq $org_args{-NAME},         "name correct" );
ok( $org->display_name()     eq $org_args{-DISPLAY_NAME}, "species ID correct" );
ok( $org->taxonomy_id() eq $org_args{-TAXONOMY_ID},  "taxid correct" );
ok( $org->species_taxonomy_id() eq $org_args{-SPECIES_TAXONOMY_ID},
    "species taxid correct" );
ok( $org->strain()       eq $org_args{-STRAIN},       "strain correct" );
ok( $org->serotype()     eq $org_args{-SEROTYPE},     "serotype correct" );
ok( $org->is_reference() eq $org_args{-IS_REFERENCE}, "is_ref correct" );

my %ass_args = ( '-ASSEMBLY_NAME'      => "v2.0",
                 '-ASSEMBLY_ACCESSION' => 'GCA_181818181',
                 '-ASSEMBLY_LEVEL'     => 'chromosome');
my $ass = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%ass_args);

ok( defined $ass, "Assembly object exists" );
ok( $ass->assembly_name() eq $ass_args{-ASSEMBLY_NAME}, "ass name correct" );
ok( $ass->assembly_accession() eq $ass_args{-ASSEMBLY_ACCESSION},
    "ass ID correct" );
ok( $ass->assembly_level() eq $ass_args{-ASSEMBLY_LEVEL}, "ass level correct" );

my %g_args = ( '-DBNAME'     => "test_species_core_27_80_1",
               '-SPECIES_ID' => 1,
               '-GENEBUILD'  => 'awesomeBuild1',
               '-DIVISION'   => 'EnsemblSomewhere',
               '-ASSEMBLY'   => $ass,
               '-ORGANISM'   => $org);
my $genome = Bio::EnsEMBL::MetaData::GenomeInfo->new(%g_args);

ok( defined $genome, "Genome object exists" );
ok( $genome->dbname()     eq $g_args{-DBNAME},     "dbname correct" );
ok( $genome->species_id() eq $g_args{-SPECIES_ID}, "species_id correct" );
ok( $genome->division()   eq $g_args{-DIVISION},   "division correct" );
ok( $genome->assembly_name() eq $ass_args{-ASSEMBLY_NAME}, "ass name correct" );
ok( $genome->assembly_accession() eq $ass_args{-ASSEMBLY_ACCESSION},
    "ass ID correct" );
ok( $genome->assembly_level() eq $ass_args{-ASSEMBLY_LEVEL},
    "ass level correct" );
ok( $genome->genebuild()   eq $g_args{-GENEBUILD},      "genebuild correct" );
ok( $genome->name()        eq $org_args{-NAME},         "name correct" );
ok( $genome->display_name()     eq $org_args{-DISPLAY_NAME}, "species ID correct" );
ok( $genome->taxonomy_id() eq $org_args{-TAXONOMY_ID},  "taxid correct" );
ok( $genome->species_taxonomy_id() eq $org_args{-SPECIES_TAXONOMY_ID},
    "species taxid correct" );
ok( $genome->strain()   eq $org_args{-STRAIN},   "strain correct" );
ok( $genome->serotype() eq $org_args{-SEROTYPE}, "serotype correct" );
ok( $genome->is_reference() eq $org_args{-IS_REFERENCE},
    "is_reference correct" );

done_testing;
