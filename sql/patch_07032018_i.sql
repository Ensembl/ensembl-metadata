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
# patch_07032018_i.sql
#
# Title: Add delete cascade for event tables
#
# Remove the constraint foreign key, recreate them with "ON DELETE CASCADE". This mean that if an object get removed the children *event tables get cleaned up
ALTER TABLE data_release_database_event DROP FOREIGN KEY data_release_database_event_ibfk_1;
ALTER TABLE data_release_database_event ADD CONSTRAINT data_release_database_event_ibfk_1 FOREIGN KEY (data_release_database_id) REFERENCES data_release_database (data_release_database_id) ON DELETE CASCADE;
ALTER TABLE compara_analysis_event DROP FOREIGN KEY compara_analysis_event_ibfk_1;
ALTER TABLE compara_analysis_event ADD CONSTRAINT compara_analysis_event_ibfk_1 FOREIGN KEY (compara_analysis_id) REFERENCES compara_analysis (compara_analysis_id) ON DELETE CASCADE;
