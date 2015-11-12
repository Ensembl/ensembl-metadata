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

#my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
#my $gdba  = $multi->get_DBAdaptor('info');

my %args = ( '-NAME'                => "test",
			 '-SPECIES'             => "Testus testa",
			 '-TAXONOMY_ID'         => 999,
			 '-SPECIES_TAXONOMY_ID' => 99,
			 '-STRAIN'              => 'stress',
			 '-SEROTYPE'            => 'icky',
			 '-IS_REFERENCE'        => 1 );
my $genome = Bio::EnsEMBL::MetaData::GenomeOrganismInfo->new(%args);

ok( defined $genome, "Organism object exists" );
ok( $genome->name()                eq $args{-NAME} );
ok( $genome->species()             eq $args{-SPECIES} );
ok( $genome->taxonomy_id()         eq $args{-TAXONOMY_ID} );
ok( $genome->species_taxonomy_id() eq $args{-SPECIES_TAXONOMY_ID} );
ok( $genome->strain()              eq $args{-STRAIN} );
ok( $genome->serotype()            eq $args{-SEROTYPE} );
ok( $genome->is_reference()        eq $args{-IS_REFERENCE} );

done_testing;
