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

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('eg');
my $gdba  = $multi->get_DBAdaptor('info');

my %args = ( -DBNAME   => "my_little_compara",
			 -DIVISION => "EnsemblVeggies",
			 -METHOD   => "myway",
			 -SET_NAME => "cassette",
			 -GENOMES  => [ "A", "B" ] );
my $genome = Bio::EnsEMBL::MetaData::GenomeComparaInfo->new(%args);

ok( defined $genome, "Compara object exists" );
ok( $genome->dbname()                 eq $args{-DBNAME},   "dbname exists" );
ok( $genome->division()               eq $args{-DIVISION}, "division exists" );
ok( $genome->method()                 eq $args{-METHOD},   "method exists" );
ok( $genome->set_name()               eq $args{-SET_NAME}, "set_name exists" );
ok( scalar( @{ $genome->genomes() } ) eq 2,                "genomes correct" );

done_testing;
