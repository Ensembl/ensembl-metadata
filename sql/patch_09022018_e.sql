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
# patch_09022018_e.sql
#
# Title: Updating genome_alignment, genome_annotation and genome_feature unique index to include genome_database_id
#
# Description: We want to capture genome_alignment and genome_feature data for core and core like dbs

ALTER TABLE genome_alignment DROP INDEX id_type_key;
ALTER TABLE genome_alignment ADD UNIQUE KEY id_type_key (genome_id,type,name,genome_database_id);
ALTER TABLE genome_feature DROP INDEX id_type_analysis;
ALTER TABLE genome_feature ADD UNIQUE KEY id_type_analysis (genome_id,type,analysis,genome_database_id);
ALTER TABLE genome_annotation DROP INDEX id_type;
ALTER TABLE genome_annotation ADD UNIQUE KEY id_type (genome_id,type,genome_database_id);
