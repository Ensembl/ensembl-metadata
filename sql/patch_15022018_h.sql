-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2020] EMBL-European Bioinformatics Institute
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
# patch_15022018_h.sql
#
# Title: Adding genome_database_id column, update index and add delete cascade for genome_database_id in genome_variation
#
# Adding db_id to the genome_variation table, add it to the unique index. Add delete cascade for genome_database_id 
ALTER TABLE genome_variation ADD COLUMN genome_database_id int(10) unsigned NOT NULL;
ALTER TABLE genome_variation DROP INDEX id_type_key;
ALTER TABLE genome_variation ADD UNIQUE KEY id_type_key (genome_id,type,name,genome_database_id);
ALTER TABLE genome_variation ADD CONSTRAINT genome_variation_ibfk_2 FOREIGN KEY (genome_database_id) REFERENCES genome_database (genome_database_id) ON DELETE CASCADE;

