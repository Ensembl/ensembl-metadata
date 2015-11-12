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
use Bio::EnsEMBL::MetaData::GenomeAssemblyInfo;

#my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
#my $gdba  = $multi->get_DBAdaptor('info');

my %args = ( '-ASSEMBLY_NAME'       => "v2.0",
			 '-ASSEMBLY_ID'         => 'GCA_181818181',
			 '-ASSEMBLY_LEVEL'      => 'chromosome' );
my $genome = Bio::EnsEMBL::MetaData::GenomeAssemblyInfo->new(%args);

ok( defined $genome, "Assembly object exists" );
ok( $genome->assembly_name()       eq $args{-ASSEMBLY_NAME} );
ok( $genome->assembly_id()         eq $args{-ASSEMBLY_ID} );
ok( $genome->assembly_level()      eq $args{-ASSEMBLY_LEVEL} );

done_testing;
