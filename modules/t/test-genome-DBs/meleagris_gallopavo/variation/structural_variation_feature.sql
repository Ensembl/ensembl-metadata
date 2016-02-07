-- MySQL dump 10.13  Distrib 5.6.26, for Linux (x86_64)
--
-- Host: mysql-eg-devel-1.ebi.ac.uk    Database: meleagris_gallopavo_variation_83_21
-- ------------------------------------------------------
-- Server version	5.6.24

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `structural_variation_feature`
--

DROP TABLE IF EXISTS `structural_variation_feature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `structural_variation_feature` (
  `structural_variation_feature_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `seq_region_id` int(10) unsigned NOT NULL,
  `outer_start` int(11) DEFAULT NULL,
  `seq_region_start` int(11) NOT NULL,
  `inner_start` int(11) DEFAULT NULL,
  `inner_end` int(11) DEFAULT NULL,
  `seq_region_end` int(11) NOT NULL,
  `outer_end` int(11) DEFAULT NULL,
  `seq_region_strand` tinyint(4) NOT NULL,
  `structural_variation_id` int(10) unsigned NOT NULL,
  `variation_name` varchar(255) DEFAULT NULL,
  `source_id` int(10) unsigned NOT NULL,
  `study_id` int(10) unsigned DEFAULT NULL,
  `class_attrib_id` int(10) unsigned NOT NULL DEFAULT '0',
  `allele_string` longtext,
  `is_evidence` tinyint(1) NOT NULL DEFAULT '0',
  `somatic` tinyint(1) NOT NULL DEFAULT '0',
  `breakpoint_order` tinyint(4) DEFAULT NULL,
  `length` int(10) DEFAULT NULL,
  `variation_set_id` set('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23','24','25','26','27','28','29','30','31','32','33','34','35','36','37','38','39','40','41','42','43','44','45','46','47','48','49','50','51','52','53','54','55','56','57','58','59','60','61','62','63','64') NOT NULL DEFAULT '',
  PRIMARY KEY (`structural_variation_feature_id`),
  KEY `pos_idx` (`seq_region_id`,`seq_region_start`,`seq_region_end`),
  KEY `structural_variation_idx` (`structural_variation_id`),
  KEY `source_idx` (`source_id`),
  KEY `study_idx` (`study_id`),
  KEY `attrib_idx` (`class_attrib_id`),
  KEY `variation_set_idx` (`variation_set_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-12-16 16:46:49
