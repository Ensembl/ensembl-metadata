#!perl
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

use Test::More;
use Bio::EnsEMBL::MetaData::GenomeInfo;
{
  my $type =
    Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type("homo_sapiens_core_84_38");
  is( 'core', $type, "Parsing current core" );
}
{
  my $type =
    Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type("homo_sapiens_core_84_38a");
  is( 'core', $type, "Parsing old core" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                             "anopheles_gambiae_core_31_84_10");
  is( 'core', $type, "Parsing EG core" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                          "bacteria_1_collection_core_31_84_1");
  is( 'core', $type, "Parsing EG collection" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                       "fungi_mouldy1_collection_core_31_84_1");
  is( 'core', $type, "Parsing EG collection 2" );
}
{
   my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                       "gorilla_gorilla_gorilla_core_84_1");
  is( 'core', $type, "Parsing trinomial" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                                "homo_sapiens_variation_84_38");
  is( 'variation', $type, "Parsing variation" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                        "anopheles_gambiae_variation_31_84_10");
  is( 'variation', $type, "Parsing EG variation" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                        "homo_sapiens_funcgen_84_38");
  is( 'funcgen', $type, "Parsing funcgen" );
}
{
  my $type = Bio::EnsEMBL::MetaData::GenomeInfo::_parse_type(
                                        "homo_sapiens_otherfeatures_84_38");
  is( 'otherfeatures', $type, "Parsing otherfeatures" );
}

done_testing;
