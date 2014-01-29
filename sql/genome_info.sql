CREATE TABLE `genome` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `species` varchar(128) NOT NULL,
  `name` varchar(128) NOT NULL,
  `strain` varchar(128) DEFAULT NULL,
  `serotype` varchar(128) DEFAULT NULL,
  `division` varchar(32) NOT NULL,
  `taxonomy_id` int(10) unsigned NOT NULL,
  `assembly_id` varchar(16) DEFAULT NULL,
  `assembly_name` varchar(200) NOT NULL,
  `assembly_level` varchar(50) NOT NULL,
  `base_count` int(10) unsigned NOT NULL,
  `genebuild` varchar(64) NOT NULL,
  `dbname` varchar(64) NOT NULL,
  `species_id` int(10) unsigned NOT NULL,
  `has_pan_compara` tinyint(3) unsigned DEFAULT '0',
  `has_variation` tinyint(3) unsigned DEFAULT '0',
  `has_peptide_compara` tinyint(3) unsigned DEFAULT '0',
  `has_genome_alignments` tinyint(3) unsigned DEFAULT '0',
  `has_other_alignments` tinyint(3) unsigned DEFAULT '0',
  PRIMARY KEY (`genome_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `dbname_species_id` (`dbname`,`species_id`),
  UNIQUE KEY `assembly_id` (`assembly_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genome_alias` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `alias` varchar(255) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,  
   UNIQUE KEY `id_alias` (`genome_id`,`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genome_sequence` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_name` varchar(40) NOT NULL,
   UNIQUE KEY `id_alias` (`genome_id`,`seq_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genome_annotation` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `count` int(10) unsigned NOT NULL,
   UNIQUE KEY `id_type` (`genome_id`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genome_variation` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `key` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
   UNIQUE KEY `id_type_key` (`genome_id`,`type`,`key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `genome_feature` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `analysis` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
   UNIQUE KEY `id_type_analysis` (`genome_id`,`type`,`analysis`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
