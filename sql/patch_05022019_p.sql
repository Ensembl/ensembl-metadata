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
# patch_04022019_p
#
# Title: Add delete cascade for organisms
#
# Description: Remove the organism_id constraint foreign key from genome table, recreate it with "ON DELETE CASCADE". This mean that if an organism get deleted all the associated genome and genome_* tables get cleaned up to
ALTER TABLE genome DROP FOREIGN KEY genome_ibfk_3;
ALTER TABLE genome ADD CONSTRAINT genome_ibfk_3 FOREIGN KEY (organism_id) REFERENCES organism (organism_id) ON DELETE CASCADE;