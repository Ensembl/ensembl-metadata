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
-- Table structure for table `regulatory_feature_variation`
--

DROP TABLE IF EXISTS `regulatory_feature_variation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `regulatory_feature_variation` (
  `regulatory_feature_variation_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `variation_feature_id` int(11) unsigned NOT NULL,
  `feature_stable_id` varchar(128) DEFAULT NULL,
  `feature_type` text,
  `allele_string` text,
  `somatic` tinyint(1) NOT NULL DEFAULT '0',
  `consequence_types` set('regulatory_region_variant','regulatory_region_ablation','regulatory_region_fusion','regulatory_region_amplification','regulatory_region_translocation') DEFAULT NULL,
  PRIMARY KEY (`regulatory_feature_variation_id`),
  KEY `variation_feature_idx` (`variation_feature_id`),
  KEY `consequence_type_idx` (`consequence_types`),
  KEY `somatic_feature_idx` (`feature_stable_id`,`somatic`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2015-12-16 16:46:49
