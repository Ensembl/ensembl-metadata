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
# patch_11022020_r
#
# Title: Group unique keys genome_database table
#
# Description: Group the two unique keys from genome_database in one to avoid deadlocks
ALTER TABLE genome_database DROP FOREIGN KEY genome_database_ibfk_1;
DROP INDEX id_dbname on genome_database;
DROP INDEX dbname_species_id on genome_database;
ALTER TABLE genome_database ADD UNIQUE genome_db_species (genome_id,dbname,species_id);
ALTER TABLE genome_database ADD CONSTRAINT genome_database_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;