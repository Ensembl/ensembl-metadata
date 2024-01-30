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
# patch_07022018_c.sql
#
# Title: Add delete cascade for genomes
#
# Description: Remove all the genome_id constraint foreign key, recreate them with "ON DELETE CASCADE". This mean that if a genome get removed all the children genome_* tables get cleaned up
ALTER TABLE genome_alignment DROP FOREIGN KEY genome_alignment_ibfk_1;
ALTER TABLE genome_alignment ADD CONSTRAINT genome_alignment_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_annotation DROP FOREIGN KEY genome_annotation_ibfk_1;
ALTER TABLE genome_annotation ADD CONSTRAINT genome_annotation_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_compara_analysis DROP FOREIGN KEY genome_compara_analysis_ibfk_1;
ALTER TABLE genome_compara_analysis ADD CONSTRAINT genome_compara_analysis_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_database DROP FOREIGN KEY genome_database_ibfk_1;
ALTER TABLE genome_database ADD CONSTRAINT genome_database_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_event DROP FOREIGN KEY genome_event_ibfk_1;
ALTER TABLE genome_event ADD CONSTRAINT genome_event_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_feature DROP FOREIGN KEY genome_feature_ibfk_1;
ALTER TABLE genome_feature ADD CONSTRAINT genome_feature_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
ALTER TABLE genome_variation DROP FOREIGN KEY genome_variation_ibfk_1;
ALTER TABLE genome_variation ADD CONSTRAINT genome_variation_ibfk_1 FOREIGN KEY (genome_id) REFERENCES genome (genome_id) ON DELETE CASCADE;
