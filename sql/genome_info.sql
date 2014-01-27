CREATE TABLE `genome` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
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
  PRIMARY KEY (`genome_id`),
  UNIQUE KEY `name` (`name`),
  UNIQUE KEY `dbname_species_id` (`dbname`,`species_id`),
  UNIQUE KEY `assembly_id` (`assembly_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;