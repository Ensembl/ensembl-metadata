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
# patch_07022018_d.sql
#
# Title: Adding genome_database_id column to genome_alignment,genome_annotation and genome_feature
#
# Description: Adding db_id to the genome_alignment and genome_feature tables to keep track where annotation/feature is coming from.
ALTER TABLE genome_alignment ADD COLUMN genome_database_id int(10) unsigned NOT NULL;
ALTER TABLE genome_feature ADD COLUMN genome_database_id int(10) unsigned NOT NULL;
ALTER TABLE genome_annotation ADD COLUMN genome_database_id int(10) unsigned NOT NULL;
