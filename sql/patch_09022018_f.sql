-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
# patch_09022018_f.sql
#
# Title: Adding delete cascade for genome_database_id in genome_alignment, genome_annotation and genome_feature
#
# Description: Adding delete cascade for genome_database_id in genome_alignment and genome_feature.
# This is to make sure that when we delete a database from genome_database, associated annotation get removed too

ALTER TABLE genome_alignment ADD CONSTRAINT genome_alignment_ibfk_2 FOREIGN KEY (genome_database_id) REFERENCES genome_database (genome_database_id) ON DELETE CASCADE;
ALTER TABLE genome_feature ADD CONSTRAINT genome_feature_ibfk_2 FOREIGN KEY (genome_database_id) REFERENCES genome_database (genome_database_id) ON DELETE CASCADE;
ALTER TABLE genome_annotation ADD CONSTRAINT genome_annotation_ibfk_2 FOREIGN KEY (genome_database_id) REFERENCES genome_database (genome_database_id) ON DELETE CASCADE;