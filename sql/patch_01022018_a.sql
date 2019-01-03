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
# patch_01022018_a.sql
#
# Title: Set is_current default to 0 instead of NULL
#
# Description:
# Set old releases is_current column to 0 instead of NULL in data_release. Update is_current column from data_release default to be 0 instead of NULL.
UPDATE data_release set is_current=0 where is_current is null;
ALTER TABLE data_release MODIFY COLUMN is_current tinyint(3) unsigned NOT NULL DEFAULT '0';
