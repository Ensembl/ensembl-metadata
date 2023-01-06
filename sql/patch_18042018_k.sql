-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2023] EMBL-European Bioinformatics Institute
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
# patch_18042018_k.sql
#
# Title: Add delete cascade for assembly and organism tables
#
# Description: Remove all the assembly and organism constraint foreign key, recreate them with "ON DELETE CASCADE". This mean that if an organism or assembly get removed all the children tables get cleaned up
ALTER TABLE assembly_sequence DROP FOREIGN KEY assembly_sequence_ibfk_1;
ALTER TABLE assembly_sequence ADD CONSTRAINT assembly_sequence_ibfk_1 FOREIGN KEY (assembly_id) REFERENCES assembly (assembly_id) ON DELETE CASCADE;
ALTER TABLE organism_alias DROP FOREIGN KEY organism_alias_ibfk_1;
ALTER TABLE organism_alias ADD CONSTRAINT organism_alias_ibfk_1 FOREIGN KEY (organism_id) REFERENCES organism (organism_id) ON DELETE CASCADE;
ALTER TABLE organism_publication DROP FOREIGN KEY organism_publication_ibfk_1;
ALTER TABLE organism_publication ADD CONSTRAINT organism_publication_ibfk_1 FOREIGN KEY (organism_id) REFERENCES organism (organism_id) ON DELETE CASCADE;
