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
use Bio::EnsEMBL::MetaData::ReleaseInfo;

my %args = ( -ENSEMBL_VERSION => 99, -EG_VERSION => 66, -DATE => '2015-09-29' );
my $release = Bio::EnsEMBL::MetaData::ReleaseInfo->new(%args);

ok( defined $release, "Release object exists" );
ok( $release->ensembl_version() eq $args{-ENSEMBL_VERSION},
	"e! Version correct" );
ok( $release->eg_version() eq $args{-EG_VERSION}, "EG Version correct" );
ok( $release->date()       eq $args{-DATE},       "Date correct" );

my $release2 = Bio::EnsEMBL::MetaData::ReleaseInfo->new();
ok( defined $release2,                    "Release object exists" );
ok( defined $release2->ensembl_version(), "Default version exists" );
ok( !defined $release2->eg_version(),     "No EG version" );
ok( defined $release2->date(),            "Date exists" );

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $gdba  = $multi->get_DBAdaptor('empty_metadata');

done_testing;
