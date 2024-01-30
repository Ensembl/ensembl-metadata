-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2024] EMBL-European Bioinformatics Institute
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
# patch_13022019_q
#
# Title: Allow organism to have same assembly default, accession but different base_count.
#
# Description: Remove the assembly_idx on assembly_default and assembly_accession, create new assembly_idx including base_count. The assembly can be the same but the underlying sequence have changed (e.g: new MT, new scaffolds..)
DROP INDEX assembly_idx on assembly;
ALTER TABLE assembly ADD UNIQUE assembly_idx (assembly_accession,assembly_default,base_count);