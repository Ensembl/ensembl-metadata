-- MySQL dump 10.14  Distrib 5.5.34-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: genome_info
-- ------------------------------------------------------
-- Server version	5.5.34-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `genome`
--

DROP TABLE IF EXISTS `genome`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
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
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_annotation`
--

DROP TABLE IF EXISTS `genome_annotation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_annotation` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type` (`genome_id`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_feature`
--

DROP TABLE IF EXISTS `genome_feature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_feature` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `analysis` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type_analysis` (`genome_id`,`type`,`analysis`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_sequence`
--

DROP TABLE IF EXISTS `genome_sequence`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_sequence` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_name` varchar(40) NOT NULL,
  UNIQUE KEY `id_alias` (`genome_id`,`seq_name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `genome_variation`
--

DROP TABLE IF EXISTS `genome_variation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `genome_variation` (
  `genome_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `type` varchar(32) NOT NULL,
  `key` varchar(128) NOT NULL,
  `count` int(10) unsigned NOT NULL,
  UNIQUE KEY `id_type_key` (`genome_id`,`type`,`key`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-01-29 22:19:13
