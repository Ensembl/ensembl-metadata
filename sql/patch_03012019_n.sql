-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2019] EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
# patch_03012019_n
#
# Title: Update Genome unique index to allow a given genome to be linked to multiple divisions
#
# Description: Update genome unique index to allow a genome to be linked to multiple divisions, e.g: drosophila_melanogaster
ALTER TABLE genome DROP KEY release_genome ,ADD UNIQUE KEY release_genome_division (data_release_id,genome_id,division_id);