-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2021] EMBL-European Bioinformatics Institute
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
# patch_26112018_m
#
# Title: Update Assembly unique index to allow more flexibility
#
# Description: Update Assemnly unique index to allow more flexibility, I think its fine if a genome as duplicated accession as long as the assembly name and default are different
DROP INDEX assembly_accession_idx on assembly;
ALTER TABLE assembly ADD UNIQUE assembly_idx (assembly_accession,assembly_default);
