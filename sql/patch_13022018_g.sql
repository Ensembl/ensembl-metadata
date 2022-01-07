-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2022] EMBL-European Bioinformatics Institute
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
# patch_13022018_g.sql
#
# Title: Add delete cascade for compara_analysis
#
# Description: Remove the compara_analysis constraint foreign key, recreate them with "ON DELETE CASCADE". This mean that if a compara_analysis get removed the children genome_compara_analysis table get cleaned up
ALTER TABLE genome_compara_analysis DROP FOREIGN KEY genome_compara_analysis_ibfk_2;
ALTER TABLE genome_compara_analysis ADD CONSTRAINT genome_compara_analysis_ibfk_2 FOREIGN KEY (compara_analysis_id) REFERENCES compara_analysis (compara_analysis_id) ON DELETE CASCADE;
