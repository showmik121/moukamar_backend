-- =====================================================================
-- মৌখামার — পুরো ডাটাবেজের গঠন (mysqldump দিয়ে বের করা)
--
-- এই ফাইলটা হাতে লেখা নয়। .\db.ps1 -Dump দিয়ে চলতি ডাটাবেজ থেকে
-- বের করা — তাই এতে যা আছে, ডাটাবেজে ঠিক তাই আছে।
--
-- ভেতরে: টেবিল (PK, FK, UNIQUE, CHECK, INDEX), ভিউ, FUNCTION,
--         PROCEDURE, TRIGGER আর EVENT। কোনো সারি নেই (--no-data)।
--
-- ডাটা আলাদা দুই জায়গা থেকে আসে:
--   sql/10_seed.sql           — ৬৪ জেলা, ৫০১ উপজেলা, রোগ, ফুল
--   manage.py seed_demo       — ডেমো ব্যবহারকারী ও নমুনা খামার
--
-- পড়ার মতো, ভাগ করা SQL চাইলে sql/01…11 ফাইলগুলো দেখুন — ওখানে
-- প্রতিটা অংশের ব্যাখ্যা বাংলায় লেখা আছে।
-- =====================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `moukhamar_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;

USE `moukhamar_db`;
DROP TABLE IF EXISTS `audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `table_name` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `row_pk` bigint NOT NULL,
  `action` varchar(6) COLLATE utf8mb4_unicode_ci NOT NULL,
  `old_data` json DEFAULT NULL,
  `new_data` json DEFAULT NULL,
  `changed_at` datetime(6) NOT NULL,
  `actor_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_audit_row` (`table_name`,`row_pk`),
  KEY `ix_audit_time` (`changed_at` DESC),
  KEY `fk_audit_log_actor_id` (`actor_id`),
  CONSTRAINT `fk_audit_log_actor_id` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_audit_action` CHECK ((`action` in (_utf8mb4'INSERT',_utf8mb4'UPDATE',_utf8mb4'DELETE')))
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_group`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_group` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_group_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_group_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `group_id` int NOT NULL,
  `permission_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_group_permissions_group_id_permission_id_0cd325b0_uniq` (`group_id`,`permission_id`),
  KEY `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` (`permission_id`),
  CONSTRAINT `auth_group_permissio_permission_id_84c5c92e_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  CONSTRAINT `auth_group_permissions_group_id_b120cbf9_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_permission`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_permission` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_type_id` int NOT NULL,
  `codename` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `auth_permission_content_type_id_codename_01ab375a_uniq` (`content_type_id`,`codename`),
  CONSTRAINT `auth_permission_content_type_id_2f476e4b_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=125 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bee_species`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bee_species` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sci_name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `text` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `author_id` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_comment_post` (`post_id`,`created_at`),
  KEY `fk_comments_author_id` (`author_id`),
  CONSTRAINT `fk_comments_author_id` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comments_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cropper_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cropper_profiles` (
  `user_id` bigint NOT NULL,
  `main_crop_id` bigint DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  KEY `fk_cropper_profiles_main_crop_id` (`main_crop_id`),
  CONSTRAINT `fk_cropper_profiles_main_crop_id` FOREIGN KEY (`main_crop_id`) REFERENCES `crops` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_cropper_profiles_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `crops`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `crops` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `disease_steps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `disease_steps` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kind` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `step_no` smallint unsigned NOT NULL,
  `text` varchar(300) COLLATE utf8mb4_unicode_ci NOT NULL,
  `disease_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_disease_step_order` (`disease_id`,`kind`,`step_no`),
  FULLTEXT KEY `ft_disease_step_text` (`text`),
  CONSTRAINT `fk_disease_steps_disease_id` FOREIGN KEY (`disease_id`) REFERENCES `diseases` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_disease_step_kind` CHECK ((`kind` in (_utf8mb4'sign',_utf8mb4'prevent',_utf8mb4'treat'))),
  CONSTRAINT `chk_disease_step_no` CHECK ((`step_no` between 1 and 50)),
  CONSTRAINT `disease_steps_chk_1` CHECK ((`step_no` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `disease_symptoms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `disease_symptoms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `disease_id` bigint NOT NULL,
  `symptom_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `disease_symptoms_disease_id_symptom_id_c7cfdfa6_uniq` (`disease_id`,`symptom_id`),
  KEY `fk_disease_symptoms_symptom_id` (`symptom_id`),
  CONSTRAINT `fk_disease_symptoms_disease_id` FOREIGN KEY (`disease_id`) REFERENCES `diseases` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_disease_symptoms_symptom_id` FOREIGN KEY (`symptom_id`) REFERENCES `symptoms` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `diseases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `diseases` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `kind` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `risk` varchar(5) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cause` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `spread` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  KEY `ix_disease_risk` (`risk`),
  FULLTEXT KEY `ft_disease_search` (`name`,`kind`),
  CONSTRAINT `chk_disease_risk` CHECK ((`risk` in (_utf8mb4'high',_utf8mb4'mid',_utf8mb4'low')))
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `districts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `districts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  `lat` decimal(10,7) DEFAULT NULL,
  `lng` decimal(10,7) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  CONSTRAINT `chk_district_point_in_bd` CHECK ((((`lat` is null) and (`lng` is null)) or ((`lat` between 20.5 and 26.7) and (`lng` between 88.0 and 92.7))))
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `django_admin_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_admin_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `action_time` datetime(6) NOT NULL,
  `object_id` longtext COLLATE utf8mb4_unicode_ci,
  `object_repr` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action_flag` smallint unsigned NOT NULL,
  `change_message` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_type_id` int DEFAULT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `django_admin_log_content_type_id_c4bce8eb_fk_django_co` (`content_type_id`),
  KEY `django_admin_log_user_id_c564eba6_fk_users_id` (`user_id`),
  CONSTRAINT `django_admin_log_content_type_id_c4bce8eb_fk_django_co` FOREIGN KEY (`content_type_id`) REFERENCES `django_content_type` (`id`),
  CONSTRAINT `django_admin_log_user_id_c564eba6_fk_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `django_admin_log_chk_1` CHECK ((`action_flag` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `django_content_type`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_content_type` (
  `id` int NOT NULL AUTO_INCREMENT,
  `app_label` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `model` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `django_content_type_app_label_model_76bd3d3b_uniq` (`app_label`,`model`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `django_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_migrations` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `app` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `applied` datetime(6) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `django_session`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `django_session` (
  `session_key` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `session_data` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `expire_date` datetime(6) NOT NULL,
  PRIMARY KEY (`session_key`),
  KEY `django_session_expire_date_a5c62663` (`expire_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `farm_flora`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `farm_flora` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `farm_id` bigint NOT NULL,
  `flora_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `farm_flora_farm_id_flora_id_d9f70977_uniq` (`farm_id`,`flora_id`),
  KEY `fk_farm_flora_flora_id` (`flora_id`),
  CONSTRAINT `fk_farm_flora_farm_id` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_farm_flora_flora_id` FOREIGN KEY (`flora_id`) REFERENCES `flora` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `farmer_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `farmer_profiles` (
  `user_id` bigint NOT NULL,
  `farm_name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `farm_type` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `experience_years` smallint unsigned NOT NULL,
  `rating` decimal(2,1) NOT NULL,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_farmer_profiles_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_farmer_experience_sane` CHECK ((`experience_years` <= 80)),
  CONSTRAINT `chk_farmer_rating_range` CHECK ((`rating` between 0 and 5)),
  CONSTRAINT `chk_farmer_type` CHECK ((`farm_type` in (_utf8mb4'স্থায়ী',_utf8mb4'ভ্রাম্যমাণ'))),
  CONSTRAINT `farmer_profiles_chk_1` CHECK ((`experience_years` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `farms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `farms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `farm_type` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `established_on` date DEFAULT NULL,
  `lat` decimal(10,7) DEFAULT NULL,
  `lng` decimal(10,7) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `owner_id` bigint NOT NULL,
  `upazila_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_farm_owner` (`owner_id`),
  KEY `ix_farm_upazila_status` (`upazila_id`,`status`),
  KEY `ix_farm_owner_status` (`owner_id`,`status`),
  CONSTRAINT `fk_farms_owner_id` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_farms_upazila_id` FOREIGN KEY (`upazila_id`) REFERENCES `upazilas` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_farm_point_in_bd` CHECK ((((`lat` is null) and (`lng` is null)) or ((`lat` between 20.5 and 26.7) and (`lng` between 88.0 and 92.7)))),
  CONSTRAINT `chk_farm_status` CHECK ((`status` in (_utf8mb4'সক্রিয়',_utf8mb4'বিশ্রামে',_utf8mb4'বন্ধ'))),
  CONSTRAINT `chk_farm_type` CHECK ((`farm_type` in (_utf8mb4'স্থায়ী',_utf8mb4'ভ্রাম্যমাণ')))
) ENGINE=InnoDB AUTO_INCREMENT=41 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `flora`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flora` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `where_found` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_dearth` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `flora_blooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flora_blooms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `flora_id` bigint NOT NULL,
  `month_id` smallint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `flora_blooms_flora_id_month_id_c68b36cc_uniq` (`flora_id`,`month_id`),
  KEY `fk_flora_blooms_month_id` (`month_id`),
  CONSTRAINT `fk_flora_blooms_flora_id` FOREIGN KEY (`flora_id`) REFERENCES `flora` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_flora_blooms_month_id` FOREIGN KEY (`month_id`) REFERENCES `months` (`month_no`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `harvests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `harvests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `harvest_date` date NOT NULL,
  `kg` decimal(7,2) NOT NULL,
  `moisture` decimal(5,1) DEFAULT NULL,
  `notes` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `flora_id` bigint DEFAULT NULL,
  `harvester_id` bigint DEFAULT NULL,
  `hive_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_harvest_date` (`harvest_date` DESC),
  KEY `ix_harvest_hive_date` (`hive_id`,`harvest_date` DESC),
  KEY `ix_harvest_hive_kg` (`hive_id`,`harvest_date`,`kg`),
  KEY `fk_harvests_harvester_id` (`harvester_id`),
  KEY `fk_harvests_flora_id` (`flora_id`),
  CONSTRAINT `fk_harvests_flora_id` FOREIGN KEY (`flora_id`) REFERENCES `flora` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_harvests_harvester_id` FOREIGN KEY (`harvester_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_harvests_hive_id` FOREIGN KEY (`hive_id`) REFERENCES `hives` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_harvest_kg_positive` CHECK ((`kg` > 0)),
  CONSTRAINT `chk_harvest_kg_sane` CHECK ((`kg` <= 500)),
  CONSTRAINT `chk_harvest_moisture` CHECK (((`moisture` is null) or ((`moisture` > 0) and (`moisture` <= 30))))
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_harvest_before_insert` BEFORE INSERT ON `harvests` FOR EACH ROW BEGIN
    IF NEW.harvest_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে মধু সংগ্রহ লেখা যায় না';
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_harvest_after_update` AFTER UPDATE ON `harvests` FOR EACH ROW BEGIN
    IF NOT (OLD.kg <=> NEW.kg AND OLD.moisture <=> NEW.moisture
            AND OLD.harvest_date <=> NEW.harvest_date
            AND OLD.hive_id <=> NEW.hive_id) THEN
        INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                               old_data, new_data, changed_at)
        VALUES ('harvests', OLD.id, 'UPDATE',
                (SELECT id FROM users WHERE id = @app_user_id),
                JSON_OBJECT('hive_id', OLD.hive_id, 'date', OLD.harvest_date,
                            'kg', OLD.kg, 'moisture', OLD.moisture),
                JSON_OBJECT('hive_id', NEW.hive_id, 'date', NEW.harvest_date,
                            'kg', NEW.kg, 'moisture', NEW.moisture),
                NOW());
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_harvest_after_delete` AFTER DELETE ON `harvests` FOR EACH ROW BEGIN
    INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                           old_data, new_data, changed_at)
    VALUES ('harvests', OLD.id, 'DELETE',
            (SELECT id FROM users WHERE id = @app_user_id),
            JSON_OBJECT('hive_id', OLD.hive_id, 'date', OLD.harvest_date,
                        'kg', OLD.kg, 'moisture', OLD.moisture),
            NULL, NOW());
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `hive_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hive_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `event_date` date NOT NULL,
  `kind` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` varchar(300) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `actor_id` bigint DEFAULT NULL,
  `hive_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_hive_event_date` (`hive_id`,`event_date` DESC),
  KEY `fk_hive_events_actor_id` (`actor_id`),
  CONSTRAINT `fk_hive_events_actor_id` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_hive_events_hive_id` FOREIGN KEY (`hive_id`) REFERENCES `hives` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_hive_event_kind` CHECK ((`kind` in (_utf8mb4'inspect',_utf8mb4'harvest',_utf8mb4'queen',_utf8mb4'move',_utf8mb4'disease',_utf8mb4'other')))
) ENGINE=InnoDB AUTO_INCREMENT=77 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `hives`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hives` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `frames` smallint unsigned NOT NULL,
  `filled` smallint unsigned NOT NULL,
  `state` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `installed_on` date DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `farm_id` bigint NOT NULL,
  `species_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  KEY `ix_hive_farm_state` (`farm_id`,`state`),
  KEY `fk_hives_species_id` (`species_id`),
  CONSTRAINT `fk_hives_farm_id` FOREIGN KEY (`farm_id`) REFERENCES `farms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_hives_species_id` FOREIGN KEY (`species_id`) REFERENCES `bee_species` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_hive_filled_within_frames` CHECK ((`filled` <= `frames`)),
  CONSTRAINT `chk_hive_frames_range` CHECK ((`frames` between 1 and 40)),
  CONSTRAINT `chk_hive_state` CHECK ((`state` in (_utf8mb4'সবল',_utf8mb4'দুর্বল',_utf8mb4'রানীহীন'))),
  CONSTRAINT `hives_chk_1` CHECK ((`frames` >= 0)),
  CONSTRAINT `hives_chk_2` CHECK ((`filled` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_hive_after_update` AFTER UPDATE ON `hives` FOR EACH ROW BEGIN
    -- কিছু আসলেই বদলালে তবেই লেখা — created_at ছোঁয়ার জন্য নয়
    IF NOT (OLD.code <=> NEW.code AND OLD.farm_id <=> NEW.farm_id
            AND OLD.state <=> NEW.state AND OLD.frames <=> NEW.frames
            AND OLD.filled <=> NEW.filled AND OLD.species_id <=> NEW.species_id) THEN
        INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                               old_data, new_data, changed_at)
        VALUES ('hives', OLD.id, 'UPDATE',
                (SELECT id FROM users WHERE id = @app_user_id),
                JSON_OBJECT('code', OLD.code, 'farm_id', OLD.farm_id,
                            'state', OLD.state, 'frames', OLD.frames,
                            'filled', OLD.filled, 'species_id', OLD.species_id),
                JSON_OBJECT('code', NEW.code, 'farm_id', NEW.farm_id,
                            'state', NEW.state, 'frames', NEW.frames,
                            'filled', NEW.filled, 'species_id', NEW.species_id),
                NOW());
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_hive_after_delete` AFTER DELETE ON `hives` FOR EACH ROW BEGIN
    INSERT INTO audit_log (table_name, row_pk, action, actor_id,
                           old_data, new_data, changed_at)
    VALUES ('hives', OLD.id, 'DELETE',
            (SELECT id FROM users WHERE id = @app_user_id),
            JSON_OBJECT('code', OLD.code, 'farm_id', OLD.farm_id,
                        'state', OLD.state, 'frames', OLD.frames,
                        'filled', OLD.filled),
            NULL, NOW());
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `inspection_diseases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `inspection_diseases` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `severity` varchar(5) COLLATE utf8mb4_unicode_ci NOT NULL,
  `disease_id` bigint NOT NULL,
  `inspection_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_inspection_disease` (`inspection_id`,`disease_id`),
  KEY `fk_inspection_diseases_disease_id` (`disease_id`),
  CONSTRAINT `fk_inspection_diseases_disease_id` FOREIGN KEY (`disease_id`) REFERENCES `diseases` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_inspection_diseases_inspection_id` FOREIGN KEY (`inspection_id`) REFERENCES `inspections` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_inspection_disease_severity` CHECK ((`severity` in (_utf8mb4'low',_utf8mb4'mid',_utf8mb4'high')))
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_inspection_disease_notify` AFTER INSERT ON `inspection_diseases` FOR EACH ROW BEGIN
    DECLARE v_risk    VARCHAR(5);
    DECLARE v_disease VARCHAR(100);
    DECLARE v_owner   BIGINT DEFAULT NULL;
    DECLARE v_code    VARCHAR(20);
    DECLARE v_farm    VARCHAR(120);

    SELECT risk, name INTO v_risk, v_disease
      FROM diseases WHERE id = NEW.disease_id;

    IF v_risk = 'high' THEN
        SELECT f.owner_id, h.code, f.name
          INTO v_owner, v_code, v_farm
          FROM inspections i
          JOIN hives h ON h.id = i.hive_id
          JOIN farms f ON f.id = h.farm_id
         WHERE i.id = NEW.inspection_id;

        IF v_owner IS NOT NULL THEN
            INSERT INTO notifications (recipient_id, kind, title, body,
                                       ref_table, ref_id, unread, created_at)
            VALUES (v_owner, 'disease',
                    CONCAT('বেশি ঝুঁকির রোগ — ', v_disease),
                    CONCAT(v_farm, ' খামারের ', v_code, ' বাক্সে ', v_disease,
                           ' পাওয়া গেছে। দ্রুত ব্যবস্থা নিন।'),
                    'inspection_diseases', NEW.id, 1, NOW());
        END IF;
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `inspections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `inspections` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `inspect_date` date NOT NULL,
  `frames_filled` smallint unsigned NOT NULL,
  `state` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `queen_seen` tinyint(1) NOT NULL,
  `eggs_seen` tinyint(1) NOT NULL,
  `notes` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `hive_id` bigint NOT NULL,
  `inspector_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_one_inspection_per_day` (`hive_id`,`inspect_date`),
  KEY `ix_inspection_date` (`inspect_date` DESC),
  KEY `fk_inspections_inspector_id` (`inspector_id`),
  CONSTRAINT `fk_inspections_hive_id` FOREIGN KEY (`hive_id`) REFERENCES `hives` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_inspections_inspector_id` FOREIGN KEY (`inspector_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_inspection_frames_sane` CHECK ((`frames_filled` <= 40)),
  CONSTRAINT `chk_inspection_state` CHECK ((`state` in (_utf8mb4'সবল',_utf8mb4'দুর্বল',_utf8mb4'রানীহীন'))),
  CONSTRAINT `inspections_chk_1` CHECK ((`frames_filled` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_inspection_before_insert` BEFORE INSERT ON `inspections` FOR EACH ROW BEGIN
    DECLARE v_frames SMALLINT UNSIGNED DEFAULT NULL;

    IF NEW.inspect_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে পরিদর্শন লেখা যায় না';
    END IF;

    SELECT frames INTO v_frames FROM hives WHERE id = NEW.hive_id;

    IF v_frames IS NOT NULL AND NEW.frames_filled > v_frames THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'ভরা ফ্রেম বাক্সের মোট ফ্রেমের বেশি হতে পারে না';
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `months`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `months` (
  `month_no` smallint unsigned NOT NULL,
  `name_bn` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`month_no`),
  CONSTRAINT `chk_month_range` CHECK ((`month_no` between 1 and 12)),
  CONSTRAINT `months_chk_1` CHECK ((`month_no` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `kind` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `ref_table` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ref_id` bigint DEFAULT NULL,
  `unread` tinyint(1) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `recipient_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_notif_recipient_unread` (`recipient_id`,`unread`),
  KEY `ix_notif_unread_recent` (`recipient_id`,`unread`,`created_at`),
  CONSTRAINT `fk_notifications_recipient_id` FOREIGN KEY (`recipient_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_notification_kind` CHECK ((`kind` in (_utf8mb4'spray',_utf8mb4'disease',_utf8mb4'inspection',_utf8mb4'other')))
) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `post_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_tags` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `post_id` bigint NOT NULL,
  `tag_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `post_tags_post_id_tag_id_e786772a_uniq` (`post_id`,`tag_id`),
  KEY `fk_post_tags_tag_id` (`tag_id`),
  CONSTRAINT `fk_post_tags_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_post_tags_tag_id` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `post_votes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_votes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_one_vote_per_user` (`post_id`,`user_id`),
  KEY `fk_post_votes_user_id` (`user_id`),
  CONSTRAINT `fk_post_votes_post_id` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_post_votes_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_post_vote_after_insert` AFTER INSERT ON `post_votes` FOR EACH ROW BEGIN
    UPDATE posts SET upvote_count = upvote_count + 1 WHERE id = NEW.post_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_post_vote_after_delete` AFTER DELETE ON `post_votes` FOR EACH ROW BEGIN
    -- GREATEST দিয়ে ঋণাত্মক হওয়া আটকানো
    UPDATE posts
       SET upvote_count = GREATEST(0, CAST(upvote_count AS SIGNED) - 1)
     WHERE id = OLD.post_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `posts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `category` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL,
  `title` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `resource_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `price` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `upvote_count` int unsigned NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `author_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_post_category_date` (`category`,`created_at` DESC),
  KEY `fk_posts_author_id` (`author_id`),
  CONSTRAINT `fk_posts_author_id` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_post_category` CHECK ((`category` in (_utf8mb4'flora',_utf8mb4'resource',_utf8mb4'qa',_utf8mb4'tips'))),
  CONSTRAINT `posts_chk_1` CHECK ((`upvote_count` >= 0))
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `queens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `queens` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `source` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `color_mark` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `installed_on` date NOT NULL,
  `removed_on` date DEFAULT NULL,
  `note` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `hive_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_queen_hive_active` (`hive_id`,`removed_on`),
  CONSTRAINT `fk_queens_hive_id` FOREIGN KEY (`hive_id`) REFERENCES `hives` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_queen_dates` CHECK (((`removed_on` is null) or (`removed_on` >= `installed_on`)))
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_queen_before_insert` BEFORE INSERT ON `queens` FOR EACH ROW BEGIN
    DECLARE v_active INT DEFAULT 0;

    IF NEW.removed_on IS NULL THEN
        SELECT COUNT(*) INTO v_active
          FROM queens
         WHERE hive_id = NEW.hive_id AND removed_on IS NULL;

        IF v_active > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'এই বাক্সে আগেই একজন চলতি রানী আছে';
        END IF;
    END IF;

    IF NEW.removed_on IS NOT NULL AND NEW.removed_on < NEW.installed_on THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'রানী সরানোর তারিখ বসানোর তারিখের আগে হতে পারে না';
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_queen_after_insert` AFTER INSERT ON `queens` FOR EACH ROW BEGIN
    IF NEW.removed_on IS NULL THEN
        UPDATE hives
           SET state = 'দুর্বল'
         WHERE id = NEW.hive_id AND state = 'রানীহীন';
    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `spray_alerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spray_alerts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `spray_date` date NOT NULL,
  `spray_time` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `chemical` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `notes` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `crop_id` bigint NOT NULL,
  `cropper_id` bigint NOT NULL,
  `upazila_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_spray_upazila_date` (`upazila_id`,`spray_date` DESC),
  KEY `fk_spray_alerts_cropper_id` (`cropper_id`),
  KEY `fk_spray_alerts_crop_id` (`crop_id`),
  CONSTRAINT `fk_spray_alerts_crop_id` FOREIGN KEY (`crop_id`) REFERENCES `crops` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `fk_spray_alerts_cropper_id` FOREIGN KEY (`cropper_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_spray_alerts_upazila_id` FOREIGN KEY (`upazila_id`) REFERENCES `upazilas` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `trg_spray_alert_fanout` AFTER INSERT ON `spray_alerts` FOR EACH ROW BEGIN
    INSERT INTO notifications (recipient_id, kind, title, body,
                               ref_table, ref_id, unread, created_at)
    SELECT u.id,
           'spray',
           CONCAT('কীটনাশক স্প্রে — ', up.name),
           CONCAT(DATE_FORMAT(NEW.spray_date, '%d-%m-%Y'), ' তারিখে ',
                  c.name, ' খেতে স্প্রে হবে (কৃষক: ', cu.name,
                  ')। বাক্স ঢেকে রাখুন।'),
           'spray_alerts',
           NEW.id,
           1,
           NOW()
      FROM users u
      JOIN upazilas up ON up.id = NEW.upazila_id
      JOIN crops c     ON c.id = NEW.crop_id
      JOIN users cu    ON cu.id = NEW.cropper_id
     WHERE u.role = 'farmer'
       AND u.upazila_id = NEW.upazila_id
       AND u.is_active = 1;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
DROP TABLE IF EXISTS `symptoms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `symptoms` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  FULLTEXT KEY `ft_symptom_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `upazilas`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `upazilas` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  `district_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_upazila_per_district` (`district_id`,`name`),
  KEY `ix_upazila_name` (`name`),
  CONSTRAINT `fk_upazilas_district_id` FOREIGN KEY (`district_id`) REFERENCES `districts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=506 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `password` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_login` datetime(6) DEFAULT NULL,
  `is_superuser` tinyint(1) NOT NULL,
  `phone` varchar(15) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL,
  `is_staff` tinyint(1) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `upazila_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `phone` (`phone`),
  UNIQUE KEY `email` (`email`),
  KEY `ix_user_role` (`role`),
  KEY `ix_user_upazila` (`upazila_id`),
  KEY `ix_user_role_upazila_active` (`role`,`upazila_id`,`is_active`),
  CONSTRAINT `fk_users_upazila_id` FOREIGN KEY (`upazila_id`) REFERENCES `upazilas` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_user_has_contact` CHECK (((`phone` is not null) or (`email` is not null))),
  CONSTRAINT `chk_user_phone_format` CHECK (((`phone` is null) or regexp_like(`phone`,_utf8mb4'^01[3-9][0-9]{8}$'))),
  CONSTRAINT `chk_user_role` CHECK ((`role` in (_utf8mb4'farmer',_utf8mb4'cropper',_utf8mb4'admin')))
) ENGINE=InnoDB AUTO_INCREMENT=27 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_groups` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `group_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_groups_user_id_group_id_fc7788e8_uniq` (`user_id`,`group_id`),
  KEY `users_groups_group_id_2f3517aa_fk_auth_group_id` (`group_id`),
  CONSTRAINT `users_groups_group_id_2f3517aa_fk_auth_group_id` FOREIGN KEY (`group_id`) REFERENCES `auth_group` (`id`),
  CONSTRAINT `users_groups_user_id_f500bee5_fk_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users_user_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users_user_permissions` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `permission_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_user_permissions_user_id_permission_id_3b86cbdf_uniq` (`user_id`,`permission_id`),
  KEY `users_user_permissio_permission_id_6d08dcd2_fk_auth_perm` (`permission_id`),
  CONSTRAINT `users_user_permissio_permission_id_6d08dcd2_fk_auth_perm` FOREIGN KEY (`permission_id`) REFERENCES `auth_permission` (`id`),
  CONSTRAINT `users_user_permissions_user_id_92473840_fk_users_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `v_area_outbreaks`;
/*!50001 DROP VIEW IF EXISTS `v_area_outbreaks`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_area_outbreaks` AS SELECT 
 1 AS `disease_id`,
 1 AS `disease_code`,
 1 AS `disease`,
 1 AS `risk`,
 1 AS `upazila`,
 1 AS `district`,
 1 AS `farms_affected`,
 1 AS `hives_affected`,
 1 AS `last_seen`,
 1 AS `alert`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_disease_symptoms`;
/*!50001 DROP VIEW IF EXISTS `v_disease_symptoms`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_disease_symptoms` AS SELECT 
 1 AS `disease_id`,
 1 AS `disease_code`,
 1 AS `disease`,
 1 AS `kind`,
 1 AS `risk`,
 1 AS `symptom_count`,
 1 AS `symptom_codes`,
 1 AS `symptom_names`,
 1 AS `treat_steps`,
 1 AS `prevent_steps`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_farm_summary`;
/*!50001 DROP VIEW IF EXISTS `v_farm_summary`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_farm_summary` AS SELECT 
 1 AS `farm_id`,
 1 AS `owner_id`,
 1 AS `farm_name`,
 1 AS `status`,
 1 AS `farm_type`,
 1 AS `established_on`,
 1 AS `lat`,
 1 AS `lng`,
 1 AS `upazila`,
 1 AS `district`,
 1 AS `hive_count`,
 1 AS `strong_count`,
 1 AS `weak_count`,
 1 AS `queenless_count`,
 1 AS `filled_frames`,
 1 AS `total_honey_kg`,
 1 AS `flora`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_farmer_dashboard`;
/*!50001 DROP VIEW IF EXISTS `v_farmer_dashboard`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_farmer_dashboard` AS SELECT 
 1 AS `owner_id`,
 1 AS `owner_name`,
 1 AS `farms_total`,
 1 AS `farms_active`,
 1 AS `hives_total`,
 1 AS `hives_queenless`,
 1 AS `overdue_inspections`,
 1 AS `honey_total_kg`,
 1 AS `alerts_unread`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_farmer_directory`;
/*!50001 DROP VIEW IF EXISTS `v_farmer_directory`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_farmer_directory` AS SELECT 
 1 AS `user_id`,
 1 AS `name`,
 1 AS `phone`,
 1 AS `created_at`,
 1 AS `farm_name`,
 1 AS `farm_type`,
 1 AS `experience_years`,
 1 AS `rating`,
 1 AS `upazila`,
 1 AS `district`,
 1 AS `lat`,
 1 AS `lng`,
 1 AS `farm_count`,
 1 AS `hive_count`,
 1 AS `active_hives`,
 1 AS `total_honey_kg`,
 1 AS `flora`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_hive_status`;
/*!50001 DROP VIEW IF EXISTS `v_hive_status`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_hive_status` AS SELECT 
 1 AS `hive_id`,
 1 AS `code`,
 1 AS `farm_id`,
 1 AS `farm_name`,
 1 AS `owner_id`,
 1 AS `species`,
 1 AS `frames`,
 1 AS `filled`,
 1 AS `state`,
 1 AS `queen`,
 1 AS `queen_age`,
 1 AS `queen_source`,
 1 AS `queen_color`,
 1 AS `queen_installed_on`,
 1 AS `last_inspection`,
 1 AS `days_since_inspection`,
 1 AS `inspection_overdue`,
 1 AS `total_honey_kg`,
 1 AS `last_harvest`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_monthly_honey`;
/*!50001 DROP VIEW IF EXISTS `v_monthly_honey`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_monthly_honey` AS SELECT 
 1 AS `owner_id`,
 1 AS `yr`,
 1 AS `mn`,
 1 AS `month_name`,
 1 AS `harvest_count`,
 1 AS `hive_count`,
 1 AS `total_kg`,
 1 AS `avg_kg`,
 1 AS `avg_moisture`*/;
SET character_set_client = @saved_cs_client;
DROP TABLE IF EXISTS `v_overdue_hives`;
/*!50001 DROP VIEW IF EXISTS `v_overdue_hives`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `v_overdue_hives` AS SELECT 
 1 AS `hive_id`,
 1 AS `code`,
 1 AS `farm_id`,
 1 AS `farm_name`,
 1 AS `owner_id`,
 1 AS `species`,
 1 AS `frames`,
 1 AS `filled`,
 1 AS `state`,
 1 AS `queen`,
 1 AS `queen_age`,
 1 AS `queen_source`,
 1 AS `queen_color`,
 1 AS `queen_installed_on`,
 1 AS `last_inspection`,
 1 AS `days_since_inspection`,
 1 AS `inspection_overdue`,
 1 AS `total_honey_kg`,
 1 AS `last_harvest`*/;
SET character_set_client = @saved_cs_client;
/*!50106 SET @save_time_zone= @@TIME_ZONE */ ;
/*!50106 DROP EVENT IF EXISTS `ev_cleanup_old_notifications` */;
DELIMITER ;;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;;
/*!50003 SET character_set_client  = utf8mb4 */ ;;
/*!50003 SET character_set_results = utf8mb4 */ ;;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;;
/*!50003 SET @saved_time_zone      = @@time_zone */ ;;
/*!50003 SET time_zone             = 'SYSTEM' */ ;;
/*!50106 CREATE*/ /*!50117 DEFINER=`root`@`localhost`*/ /*!50106 EVENT `ev_cleanup_old_notifications` ON SCHEDULE EVERY 1 WEEK STARTS '2026-11-25 03:00:00' ON COMPLETION PRESERVE ENABLE COMMENT 'পড়া ও ৬০ দিনের পুরনো সতর্কতা মোছা, সপ্তাহে একবার' DO BEGIN
    DELETE FROM notifications
     WHERE unread = 0
       AND created_at < DATE_SUB(NOW(), INTERVAL 60 DAY);
END */ ;;
/*!50003 SET time_zone             = @saved_time_zone */ ;;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;;
/*!50003 SET character_set_client  = @saved_cs_client */ ;;
/*!50003 SET character_set_results = @saved_cs_results */ ;;
/*!50003 SET collation_connection  = @saved_col_connection */ ;;
/*!50106 DROP EVENT IF EXISTS `ev_dearth_season_notice` */;;
DELIMITER ;;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;;
/*!50003 SET character_set_client  = utf8mb4 */ ;;
/*!50003 SET character_set_results = utf8mb4 */ ;;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;;
/*!50003 SET @saved_time_zone      = @@time_zone */ ;;
/*!50003 SET time_zone             = 'SYSTEM' */ ;;
/*!50106 CREATE*/ /*!50117 DEFINER=`root`@`localhost`*/ /*!50106 EVENT `ev_dearth_season_notice` ON SCHEDULE EVERY 1 MONTH STARTS '2026-12-01 08:00:00' ON COMPLETION PRESERVE ENABLE COMMENT 'সামনের মাসে ফুল কম হলে খামারিদের আগাম খবর' DO BEGIN
    DECLARE v_next TINYINT;
    DECLARE v_name VARCHAR(20);

    SET v_next = MONTH(CURDATE() + INTERVAL 1 MONTH);

    IF fn_is_dearth_month(v_next) = 1 THEN
        SELECT name_bn INTO v_name FROM months WHERE month_no = v_next;

        INSERT INTO notifications (recipient_id, kind, title, body,
                                   ref_table, ref_id, unread, created_at)
        SELECT u.id,
               'other',
               CONCAT(v_name, ' মাসে ফুল কম থাকবে'),
               CONCAT('সামনের মাস (', v_name, ') ফুল কম থাকার মৌসুম। ',
                      'কলোনি দুর্বল হওয়া আটকাতে চিনির শিরা দেওয়ার ব্যবস্থা রাখুন।'),
               'months',
               v_next,
               1,
               NOW()
          FROM users u
         WHERE u.role = 'farmer' AND u.is_active = 1;
    END IF;
END */ ;;
/*!50003 SET time_zone             = @saved_time_zone */ ;;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;;
/*!50003 SET character_set_client  = @saved_cs_client */ ;;
/*!50003 SET character_set_results = @saved_cs_results */ ;;
/*!50003 SET collation_connection  = @saved_col_connection */ ;;
/*!50106 DROP EVENT IF EXISTS `ev_nightly_overdue_alerts` */;;
DELIMITER ;;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;;
/*!50003 SET character_set_client  = utf8mb4 */ ;;
/*!50003 SET character_set_results = utf8mb4 */ ;;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;;
/*!50003 SET @saved_time_zone      = @@time_zone */ ;;
/*!50003 SET time_zone             = 'SYSTEM' */ ;;
/*!50106 CREATE*/ /*!50117 DEFINER=`root`@`localhost`*/ /*!50106 EVENT `ev_nightly_overdue_alerts` ON SCHEDULE EVERY 1 DAY STARTS '2026-11-25 21:00:00' ON COMPLETION PRESERVE ENABLE COMMENT 'বাকি পরিদর্শনের সতর্কতা, প্রতি রাত ৯টা' DO BEGIN
    INSERT INTO notifications (recipient_id, kind, title, body,
                               ref_table, ref_id, unread, created_at)
    SELECT v.owner_id,
           'inspection',
           CONCAT('পরিদর্শন বাকি — ', v.code),
           CONCAT(v.farm_name, ' খামারের ', v.code, ' বাক্স ',
                  IF(v.days_since_inspection >= 999,
                     'কখনো পরিদর্শন হয়নি',
                     CONCAT(fn_bn_digits(v.days_since_inspection),
                            ' দিন ধরে দেখা হয়নি')),
                  '। একবার দেখে নিন।'),
           'hives',
           v.hive_id,
           1,
           NOW()
      FROM v_overdue_hives v
     WHERE v.owner_id IS NOT NULL
       AND NOT EXISTS (
               SELECT 1
                 FROM notifications n
                WHERE n.recipient_id = v.owner_id
                  AND n.kind = 'inspection'
                  AND n.ref_table = 'hives'
                  AND n.ref_id = v.hive_id
                  AND n.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY));
END */ ;;
/*!50003 SET time_zone             = @saved_time_zone */ ;;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;;
/*!50003 SET character_set_client  = @saved_cs_client */ ;;
/*!50003 SET character_set_results = @saved_cs_results */ ;;
/*!50003 SET collation_connection  = @saved_col_connection */ ;;
DELIMITER ;
/*!50106 SET TIME_ZONE= @save_time_zone */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_bn_digits` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_bn_digits`(p_text VARCHAR(255)) RETURNS varchar(512) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    DECLARE v_out VARCHAR(512) DEFAULT p_text;
    DECLARE i INT DEFAULT 0;

    IF p_text IS NULL THEN
        RETURN NULL;
    END IF;

    WHILE i <= 9 DO
        SET v_out = REPLACE(v_out, CAST(i AS CHAR),
                            SUBSTRING('০১২৩৪৫৬৭৮৯', i + 1, 1));
        SET i = i + 1;
    END WHILE;

    RETURN v_out;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_days_since_inspection` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_days_since_inspection`(p_hive_id BIGINT) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE v_last DATE;

    SELECT MAX(inspect_date) INTO v_last
      FROM inspections
     WHERE hive_id = p_hive_id;

    IF v_last IS NULL THEN
        RETURN 999;
    END IF;

    RETURN DATEDIFF(CURDATE(), v_last);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_farm_honey_total` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_farm_honey_total`(p_farm_id BIGINT) RETURNS decimal(12,2)
    READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);

    SELECT IFNULL(SUM(hh.kg), 0) INTO v_total
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
     WHERE h.farm_id = p_farm_id;

    RETURN v_total;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_hive_health_score` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_hive_health_score`(p_hive_id BIGINT) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE v_state   VARCHAR(15);
    DECLARE v_frames  SMALLINT UNSIGNED;
    DECLARE v_filled  SMALLINT UNSIGNED;
    DECLARE v_score   INT DEFAULT 0;

    SELECT state, frames, filled INTO v_state, v_frames, v_filled
      FROM hives
     WHERE id = p_hive_id;

    IF v_state IS NULL THEN
        RETURN 0;          -- এমন বাক্স নেই
    END IF;

    SET v_score = CASE v_state
                      WHEN 'সবল'     THEN 60
                      WHEN 'দুর্বল'   THEN 30
                      ELSE 10
                  END;

    IF fn_queen_age_years(p_hive_id) >= 0 THEN
        SET v_score = v_score + 20;
    END IF;

    IF v_frames > 0 THEN
        SET v_score = v_score + ROUND(v_filled / v_frames * 20);
    END IF;

    IF fn_days_since_inspection(p_hive_id) > 14 THEN
        SET v_score = v_score - 15;
    END IF;

    RETURN GREATEST(0, LEAST(100, v_score));
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_hive_honey_total` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_hive_honey_total`(p_hive_id BIGINT) RETURNS decimal(10,2)
    READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(10,2);

    SELECT IFNULL(SUM(kg), 0) INTO v_total
      FROM harvests
     WHERE hive_id = p_hive_id;

    RETURN v_total;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_is_dearth_month` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_is_dearth_month`(p_month TINYINT) RETURNS tinyint
    READS SQL DATA
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count
      FROM flora f
      JOIN flora_blooms fb ON fb.flora_id = f.id
     WHERE fb.month_id = p_month
       AND f.is_dearth = 1;

    RETURN IF(v_count > 0, 1, 0);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_kg_bn` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_kg_bn`(p_kg DECIMAL(10,2)) RETURNS varchar(64) CHARSET utf8mb4
    NO SQL
    DETERMINISTIC
BEGIN
    IF p_kg IS NULL THEN
        RETURN '—';
    END IF;
    RETURN CONCAT(fn_bn_digits(FORMAT(p_kg, 2)), ' কেজি');
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_queen_age_years` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `fn_queen_age_years`(p_hive_id BIGINT) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE v_installed DATE;

    SELECT installed_on INTO v_installed
      FROM queens
     WHERE hive_id = p_hive_id AND removed_on IS NULL
     ORDER BY installed_on DESC
     LIMIT 1;

    IF v_installed IS NULL THEN
        RETURN -1;
    END IF;

    RETURN TIMESTAMPDIFF(YEAR, v_installed, CURDATE());
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_add_harvest` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_add_harvest`(
    IN  p_code         VARCHAR(20),
    IN  p_date         DATE,
    IN  p_kg           DECIMAL(7,2),
    IN  p_moisture     DECIMAL(5,1),
    IN  p_flora_name   VARCHAR(80),
    IN  p_harvester_id BIGINT,
    OUT p_harvest_id   BIGINT
)
BEGIN
    DECLARE v_hive_id  BIGINT DEFAULT NULL;
    DECLARE v_flora_id BIGINT DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id INTO v_hive_id FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    IF p_moisture IS NOT NULL AND p_moisture > 30 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'আর্দ্রতা ৩০%-এর বেশি হলে মধু সংরক্ষণ করা যায় না';
    END IF;

    IF p_kg <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'মধুর পরিমাণ শূন্যের বেশি হতে হবে';
    END IF;

    IF p_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে মধু সংগ্রহ লেখা যায় না';
    END IF;

    IF p_flora_name IS NOT NULL AND p_flora_name <> '' THEN
        SELECT id INTO v_flora_id FROM flora WHERE name = p_flora_name;
    END IF;

    INSERT INTO harvests (hive_id, harvester_id, flora_id, harvest_date,
                          kg, moisture, notes, created_at)
    VALUES (v_hive_id, p_harvester_id, v_flora_id, p_date,
            p_kg, p_moisture, '', NOW());

    SET p_harvest_id = LAST_INSERT_ID();

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_harvester_id, p_date, 'harvest',
            CONCAT('মধু সংগ্রহ ', fn_kg_bn(p_kg)), NOW());

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_move_hive` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_move_hive`(
    IN p_code           VARCHAR(20),
    IN p_target_farm_id BIGINT,
    IN p_actor_id       BIGINT
)
BEGIN
    DECLARE v_hive_id      BIGINT DEFAULT NULL;
    DECLARE v_old_farm_id  BIGINT DEFAULT NULL;
    DECLARE v_old_owner    BIGINT DEFAULT NULL;
    DECLARE v_new_owner    BIGINT DEFAULT NULL;
    DECLARE v_old_name     VARCHAR(120);
    DECLARE v_new_name     VARCHAR(120);

    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT h.id, h.farm_id, f.owner_id, f.name
      INTO v_hive_id, v_old_farm_id, v_old_owner, v_old_name
      FROM hives h
      JOIN farms f ON f.id = h.farm_id
     WHERE h.code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    SELECT owner_id, name INTO v_new_owner, v_new_name
      FROM farms WHERE id = p_target_farm_id;

    IF v_new_owner IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'যে খামারে সরাতে চাইছেন সেটা নেই';
    END IF;

    
    IF v_old_owner <> v_new_owner THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'অন্য খামারির খামারে বাক্স সরানো যায় না';
    END IF;

    IF v_old_farm_id = p_target_farm_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'বাক্সটা আগেই এই খামারে আছে';
    END IF;

    UPDATE hives SET farm_id = p_target_farm_id WHERE id = v_hive_id;

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_actor_id, CURDATE(), 'move',
            CONCAT(v_old_name, ' থেকে ', v_new_name, ' খামারে সরানো হলো'), NOW());

    COMMIT;

    SELECT p_code                AS `বাক্স`,
           v_old_name            AS `আগের খামার`,
           v_new_name            AS `নতুন খামার`,
           'সরানো হয়েছে'        AS `ফল`;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_new_queen` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_new_queen`(
    IN p_code     VARCHAR(20),
    IN p_source   VARCHAR(80),
    IN p_color    VARCHAR(20),
    IN p_actor_id BIGINT
)
BEGIN
    DECLARE v_hive_id BIGINT DEFAULT NULL;
    DECLARE v_state   VARCHAR(15);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT id, state INTO v_hive_id, v_state FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    
    UPDATE queens
       SET removed_on = CURDATE()
     WHERE hive_id = v_hive_id AND removed_on IS NULL;

    
    INSERT INTO queens (hive_id, source, color_mark, installed_on, removed_on, note)
    VALUES (v_hive_id, IFNULL(p_source, ''), IFNULL(p_color, ''), CURDATE(), NULL, '');

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_actor_id, CURDATE(), 'queen',
            CONCAT('নতুন রানী বসানো হলো', IF(p_source IS NULL OR p_source = '',
                                              '', CONCAT(' (', p_source, ')'))), NOW());

    
    IF v_state = 'রানীহীন' THEN
        UPDATE hives SET state = 'দুর্বল' WHERE id = v_hive_id;
    END IF;

    COMMIT;

    SELECT p_code AS `বাক্স`, fn_queen_age_years(v_hive_id) AS `রানীর বয়স`,
           'রানী বসানো হয়েছে' AS `ফল`;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_notify_overdue_inspections` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_notify_overdue_inspections`(
    IN  p_owner_id BIGINT,
    OUT p_sent     INT
)
BEGIN
    DECLARE v_done   TINYINT DEFAULT 0;
    DECLARE v_hive   BIGINT;
    DECLARE v_code   VARCHAR(20);
    DECLARE v_days   INT;
    DECLARE v_farm   VARCHAR(120);
    DECLARE v_owner  BIGINT;

    DECLARE cur_overdue CURSOR FOR
        SELECT hive_id, code, days_since_inspection, farm_name, owner_id
          FROM v_overdue_hives
         WHERE p_owner_id IS NULL OR owner_id = p_owner_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    SET p_sent = 0;

    OPEN cur_overdue;

    read_loop: LOOP
        FETCH cur_overdue INTO v_hive, v_code, v_days, v_farm, v_owner;

        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        INSERT INTO notifications (recipient_id, kind, title, body,
                                   ref_table, ref_id, unread, created_at)
        VALUES (v_owner, 'inspection',
                CONCAT('পরিদর্শন বাকি — ', v_code),
                CONCAT(v_farm, ' খামারের ', v_code, ' বাক্স ',
                       IF(v_days >= 999, 'কখনো পরিদর্শন হয়নি',
                          CONCAT(fn_bn_digits(v_days), ' দিন ধরে দেখা হয়নি')),
                       '। একবার দেখে নিন।'),
                
                
                'hives', v_hive, 1, NOW());

        SET p_sent = p_sent + 1;
    END LOOP;

    CLOSE cur_overdue;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_record_inspection` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_record_inspection`(
    IN p_code          VARCHAR(20),
    IN p_date          DATE,
    IN p_frames_filled TINYINT,
    IN p_state         VARCHAR(15),
    IN p_queen_seen    TINYINT,
    IN p_eggs_seen     TINYINT,
    IN p_disease_codes VARCHAR(255),
    IN p_inspector_id  BIGINT,
    OUT p_inspection_id BIGINT,
    OUT p_diseases_added INT
)
BEGIN
    DECLARE v_hive_id    BIGINT DEFAULT NULL;
    DECLARE v_frames     SMALLINT UNSIGNED;
    DECLARE v_rest       VARCHAR(255);
    DECLARE v_one        VARCHAR(40);
    DECLARE v_disease_id BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_diseases_added = 0;

    START TRANSACTION;

    SELECT id, frames INTO v_hive_id, v_frames FROM hives WHERE code = p_code;

    IF v_hive_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'এই কোডের বাক্স নেই';
    END IF;

    
    IF p_frames_filled > v_frames THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভরা ফ্রেম বাক্সের মোট ফ্রেমের বেশি হতে পারে না';
    END IF;

    IF p_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ভবিষ্যতের তারিখে পরিদর্শন লেখা যায় না';
    END IF;

    INSERT INTO inspections (hive_id, inspector_id, inspect_date, frames_filled,
                             state, queen_seen, eggs_seen, notes, created_at)
    VALUES (v_hive_id, p_inspector_id, p_date, p_frames_filled,
            p_state, p_queen_seen, p_eggs_seen, '', NOW());

    SET p_inspection_id = LAST_INSERT_ID();

    
    SET v_rest = IFNULL(p_disease_codes, '');

    WHILE CHAR_LENGTH(v_rest) > 0 DO
        SET v_one = TRIM(SUBSTRING_INDEX(v_rest, ',', 1));

        IF LOCATE(',', v_rest) > 0 THEN
            SET v_rest = SUBSTRING(v_rest, LOCATE(',', v_rest) + 1);
        ELSE
            SET v_rest = '';
        END IF;

        IF CHAR_LENGTH(v_one) > 0 THEN
            SET v_disease_id = NULL;
            SELECT id INTO v_disease_id FROM diseases WHERE code = v_one;

            
            SAVEPOINT before_disease;
            IF v_disease_id IS NULL THEN
                ROLLBACK TO SAVEPOINT before_disease;
            ELSE
                INSERT IGNORE INTO inspection_diseases (inspection_id, disease_id, severity)
                VALUES (p_inspection_id, v_disease_id, 'mid');
                SET p_diseases_added = p_diseases_added + 1;
            END IF;
        END IF;
    END WHILE;

    
    UPDATE hives
       SET filled = p_frames_filled, state = p_state
     WHERE id = v_hive_id;

    INSERT INTO hive_events (hive_id, actor_id, event_date, kind, note, created_at)
    VALUES (v_hive_id, p_inspector_id, p_date, 'inspect',
            CONCAT('পরিদর্শন — ', p_state, ', ভরা ফ্রেম ',
                   fn_bn_digits(p_frames_filled)), NOW());

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_season_report` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_season_report`(
    IN  p_owner_id      BIGINT,
    IN  p_year          INT,
    OUT p_total_kg      DECIMAL(12,2),
    OUT p_harvest_count INT,
    OUT p_hive_count    INT,
    OUT p_best_hive     VARCHAR(20),
    OUT p_best_kg       DECIMAL(10,2),
    OUT p_avg_moisture  DECIMAL(5,1)
)
BEGIN
    SELECT IFNULL(SUM(hh.kg), 0), COUNT(*), COUNT(DISTINCT hh.hive_id),
           ROUND(AVG(hh.moisture), 1)
      INTO p_total_kg, p_harvest_count, p_hive_count, p_avg_moisture
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
      JOIN farms f ON f.id = h.farm_id
     WHERE f.owner_id = p_owner_id
       AND YEAR(hh.harvest_date) = p_year;

    
    SET p_best_hive = NULL;
    SET p_best_kg = 0;

    SELECT h.code, SUM(hh.kg)
      INTO p_best_hive, p_best_kg
      FROM harvests hh
      JOIN hives h ON h.id = hh.hive_id
      JOIN farms f ON f.id = h.farm_id
     WHERE f.owner_id = p_owner_id
       AND YEAR(hh.harvest_date) = p_year
     GROUP BY h.id, h.code
     ORDER BY SUM(hh.kg) DESC
     LIMIT 1;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_set_fk_action` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES' */ ;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_set_fk_action`(
    IN p_table      VARCHAR(64),
    IN p_column     VARCHAR(64),
    IN p_ref_table  VARCHAR(64),
    IN p_ref_column VARCHAR(64),
    IN p_on_delete  VARCHAR(20)
)
BEGIN
    DECLARE v_name VARCHAR(64) DEFAULT NULL;

    -- আগের FK-র নাম খোঁজা
    SET v_name = NULL;
    SELECT CONSTRAINT_NAME INTO v_name
      FROM information_schema.KEY_COLUMN_USAGE
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = p_table
       AND COLUMN_NAME = p_column
       AND REFERENCED_TABLE_NAME IS NOT NULL
     LIMIT 1;

    -- থাকলে সরানো
    IF v_name IS NOT NULL THEN
        SET @stmt = CONCAT('ALTER TABLE `', p_table, '` DROP FOREIGN KEY `', v_name, '`');
        PREPARE s FROM @stmt;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;

    -- স্পষ্ট নামে, স্পষ্ট নিয়মে আবার বসানো
    SET @stmt = CONCAT(
        'ALTER TABLE `', p_table, '` ADD CONSTRAINT `fk_', p_table, '_', p_column,
        '` FOREIGN KEY (`', p_column, '`) REFERENCES `', p_ref_table, '` (`', p_ref_column,
        '`) ON DELETE ', p_on_delete
    );
    PREPARE s FROM @stmt;
    EXECUTE s;
    DEALLOCATE PREPARE s;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

USE `moukhamar_db`;
/*!50001 DROP VIEW IF EXISTS `v_area_outbreaks`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_area_outbreaks` AS select `d`.`id` AS `disease_id`,`d`.`code` AS `disease_code`,`d`.`name` AS `disease`,`d`.`risk` AS `risk`,`up`.`name` AS `upazila`,`di`.`name` AS `district`,count(distinct `f`.`id`) AS `farms_affected`,count(distinct `h`.`id`) AS `hives_affected`,max(`i`.`inspect_date`) AS `last_seen`,if((count(distinct `f`.`id`) >= 3),1,0) AS `alert` from ((((((`inspection_diseases` `idis` join `inspections` `i` on((`i`.`id` = `idis`.`inspection_id`))) join `hives` `h` on((`h`.`id` = `i`.`hive_id`))) join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) join `upazilas` `up` on((`up`.`id` = `f`.`upazila_id`))) join `districts` `di` on((`di`.`id` = `up`.`district_id`))) join `diseases` `d` on((`d`.`id` = `idis`.`disease_id`))) where (`i`.`inspect_date` >= (curdate() - interval 30 day)) group by `d`.`id`,`d`.`code`,`d`.`name`,`d`.`risk`,`up`.`name`,`di`.`name` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_disease_symptoms`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_disease_symptoms` AS select `d`.`id` AS `disease_id`,`d`.`code` AS `disease_code`,`d`.`name` AS `disease`,`d`.`kind` AS `kind`,`d`.`risk` AS `risk`,count(`s`.`id`) AS `symptom_count`,group_concat(`s`.`code` order by `s`.`code` ASC separator ',') AS `symptom_codes`,group_concat(`s`.`name` order by `s`.`code` ASC separator ' · ') AS `symptom_names`,(select count(0) from `disease_steps` `st` where ((`st`.`disease_id` = `d`.`id`) and (`st`.`kind` = 'treat'))) AS `treat_steps`,(select count(0) from `disease_steps` `st` where ((`st`.`disease_id` = `d`.`id`) and (`st`.`kind` = 'prevent'))) AS `prevent_steps` from ((`diseases` `d` left join `disease_symptoms` `ds` on((`ds`.`disease_id` = `d`.`id`))) left join `symptoms` `s` on((`s`.`id` = `ds`.`symptom_id`))) group by `d`.`id`,`d`.`code`,`d`.`name`,`d`.`kind`,`d`.`risk` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_farm_summary`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_farm_summary` AS select `f`.`id` AS `farm_id`,`f`.`owner_id` AS `owner_id`,`f`.`name` AS `farm_name`,`f`.`status` AS `status`,`f`.`farm_type` AS `farm_type`,`f`.`established_on` AS `established_on`,`f`.`lat` AS `lat`,`f`.`lng` AS `lng`,`up`.`name` AS `upazila`,`di`.`name` AS `district`,count(`h`.`id`) AS `hive_count`,cast(sum((`h`.`state` = 'সবল')) as signed) AS `strong_count`,cast(sum((`h`.`state` = 'দুর্বল')) as signed) AS `weak_count`,cast(sum((`h`.`state` = 'রানীহীন')) as signed) AS `queenless_count`,cast(ifnull(sum(`h`.`filled`),0) as signed) AS `filled_frames`,(select ifnull(sum(`hh`.`kg`),0) from (`harvests` `hh` join `hives` `h2` on((`h2`.`id` = `hh`.`hive_id`))) where (`h2`.`farm_id` = `f`.`id`)) AS `total_honey_kg`,(select group_concat(`fl`.`name` order by `fl`.`name` ASC separator ', ') from (`farm_flora` `ff` join `flora` `fl` on((`fl`.`id` = `ff`.`flora_id`))) where (`ff`.`farm_id` = `f`.`id`)) AS `flora` from (((`farms` `f` join `upazilas` `up` on((`up`.`id` = `f`.`upazila_id`))) join `districts` `di` on((`di`.`id` = `up`.`district_id`))) left join `hives` `h` on((`h`.`farm_id` = `f`.`id`))) group by `f`.`id`,`f`.`owner_id`,`f`.`name`,`f`.`status`,`f`.`farm_type`,`f`.`established_on`,`f`.`lat`,`f`.`lng`,`up`.`name`,`di`.`name` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_farmer_dashboard`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_farmer_dashboard` AS select `us`.`id` AS `owner_id`,`us`.`name` AS `owner_name`,(select count(0) from `farms` `f` where (`f`.`owner_id` = `us`.`id`)) AS `farms_total`,(select count(0) from `farms` `f` where ((`f`.`owner_id` = `us`.`id`) and (`f`.`status` = 'সক্রিয়'))) AS `farms_active`,(select count(0) from `v_hive_status` `v` where (`v`.`owner_id` = `us`.`id`)) AS `hives_total`,(select count(0) from `v_hive_status` `v` where ((`v`.`owner_id` = `us`.`id`) and (`v`.`queen` = 'নেই'))) AS `hives_queenless`,(select count(0) from `v_hive_status` `v` where ((`v`.`owner_id` = `us`.`id`) and (`v`.`inspection_overdue` = 1))) AS `overdue_inspections`,(select ifnull(sum(`v`.`total_honey_kg`),0) from `v_hive_status` `v` where (`v`.`owner_id` = `us`.`id`)) AS `honey_total_kg`,(select count(0) from `notifications` `n` where ((`n`.`recipient_id` = `us`.`id`) and (`n`.`unread` = 1))) AS `alerts_unread` from `users` `us` where (`us`.`role` = 'farmer') */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_farmer_directory`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_farmer_directory` AS select `us`.`id` AS `user_id`,`us`.`name` AS `name`,`us`.`phone` AS `phone`,`us`.`created_at` AS `created_at`,ifnull(nullif(`fp`.`farm_name`,''),concat(`us`.`name`,'-এর খামার')) AS `farm_name`,ifnull(`fp`.`farm_type`,'স্থায়ী') AS `farm_type`,ifnull(`fp`.`experience_years`,0) AS `experience_years`,ifnull(`fp`.`rating`,0) AS `rating`,`up`.`name` AS `upazila`,`di`.`name` AS `district`,coalesce((select `f`.`lat` from `farms` `f` where ((`f`.`owner_id` = `us`.`id`) and (`f`.`lat` is not null)) order by `f`.`id` limit 1),`di`.`lat`) AS `lat`,coalesce((select `f`.`lng` from `farms` `f` where ((`f`.`owner_id` = `us`.`id`) and (`f`.`lng` is not null)) order by `f`.`id` limit 1),`di`.`lng`) AS `lng`,(select count(0) from `farms` `f` where (`f`.`owner_id` = `us`.`id`)) AS `farm_count`,(select count(0) from (`hives` `h` join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) where (`f`.`owner_id` = `us`.`id`)) AS `hive_count`,(select count(0) from (`hives` `h` join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) where ((`f`.`owner_id` = `us`.`id`) and (`h`.`state` <> 'রানীহীন'))) AS `active_hives`,(select ifnull(sum(`hh`.`kg`),0) from ((`harvests` `hh` join `hives` `h` on((`h`.`id` = `hh`.`hive_id`))) join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) where (`f`.`owner_id` = `us`.`id`)) AS `total_honey_kg`,(select group_concat(distinct `fl`.`name` order by `fl`.`name` ASC separator ', ') from ((`farm_flora` `ff` join `flora` `fl` on((`fl`.`id` = `ff`.`flora_id`))) join `farms` `f` on((`f`.`id` = `ff`.`farm_id`))) where (`f`.`owner_id` = `us`.`id`)) AS `flora` from (((`users` `us` left join `farmer_profiles` `fp` on((`fp`.`user_id` = `us`.`id`))) left join `upazilas` `up` on((`up`.`id` = `us`.`upazila_id`))) left join `districts` `di` on((`di`.`id` = `up`.`district_id`))) where ((`us`.`role` = 'farmer') and (`us`.`is_active` = 1)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_hive_status`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_hive_status` AS select `h`.`id` AS `hive_id`,`h`.`code` AS `code`,`h`.`farm_id` AS `farm_id`,`f`.`name` AS `farm_name`,`f`.`owner_id` AS `owner_id`,`bs`.`name` AS `species`,`h`.`frames` AS `frames`,`h`.`filled` AS `filled`,`h`.`state` AS `state`,if((`q`.`id` is null),'নেই','আছে') AS `queen`,ifnull(timestampdiff(YEAR,`q`.`installed_on`,curdate()),0) AS `queen_age`,`q`.`source` AS `queen_source`,`q`.`color_mark` AS `queen_color`,`q`.`installed_on` AS `queen_installed_on`,`li`.`last_inspection` AS `last_inspection`,(to_days(curdate()) - to_days(`li`.`last_inspection`)) AS `days_since_inspection`,(case when (`li`.`last_inspection` is null) then 1 when ((to_days(curdate()) - to_days(`li`.`last_inspection`)) > 14) then 1 else 0 end) AS `inspection_overdue`,ifnull(`hv`.`total_kg`,0) AS `total_honey_kg`,`hv`.`last_harvest` AS `last_harvest` from (((((`hives` `h` join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) join `bee_species` `bs` on((`bs`.`id` = `h`.`species_id`))) left join `queens` `q` on(((`q`.`hive_id` = `h`.`id`) and (`q`.`removed_on` is null)))) left join (select `inspections`.`hive_id` AS `hive_id`,max(`inspections`.`inspect_date`) AS `last_inspection` from `inspections` group by `inspections`.`hive_id`) `li` on((`li`.`hive_id` = `h`.`id`))) left join (select `harvests`.`hive_id` AS `hive_id`,sum(`harvests`.`kg`) AS `total_kg`,max(`harvests`.`harvest_date`) AS `last_harvest` from `harvests` group by `harvests`.`hive_id`) `hv` on((`hv`.`hive_id` = `h`.`id`))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_monthly_honey`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_monthly_honey` AS select `f`.`owner_id` AS `owner_id`,year(`hh`.`harvest_date`) AS `yr`,month(`hh`.`harvest_date`) AS `mn`,`mo`.`name_bn` AS `month_name`,count(0) AS `harvest_count`,count(distinct `hh`.`hive_id`) AS `hive_count`,sum(`hh`.`kg`) AS `total_kg`,round(avg(`hh`.`kg`),2) AS `avg_kg`,round(avg(`hh`.`moisture`),1) AS `avg_moisture` from (((`harvests` `hh` join `hives` `h` on((`h`.`id` = `hh`.`hive_id`))) join `farms` `f` on((`f`.`id` = `h`.`farm_id`))) join `months` `mo` on((`mo`.`month_no` = month(`hh`.`harvest_date`)))) group by `f`.`owner_id`,year(`hh`.`harvest_date`),month(`hh`.`harvest_date`),`mo`.`name_bn` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!50001 DROP VIEW IF EXISTS `v_overdue_hives`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_overdue_hives` AS select `v_hive_status`.`hive_id` AS `hive_id`,`v_hive_status`.`code` AS `code`,`v_hive_status`.`farm_id` AS `farm_id`,`v_hive_status`.`farm_name` AS `farm_name`,`v_hive_status`.`owner_id` AS `owner_id`,`v_hive_status`.`species` AS `species`,`v_hive_status`.`frames` AS `frames`,`v_hive_status`.`filled` AS `filled`,`v_hive_status`.`state` AS `state`,`v_hive_status`.`queen` AS `queen`,`v_hive_status`.`queen_age` AS `queen_age`,`v_hive_status`.`queen_source` AS `queen_source`,`v_hive_status`.`queen_color` AS `queen_color`,`v_hive_status`.`queen_installed_on` AS `queen_installed_on`,`v_hive_status`.`last_inspection` AS `last_inspection`,`v_hive_status`.`days_since_inspection` AS `days_since_inspection`,`v_hive_status`.`inspection_overdue` AS `inspection_overdue`,`v_hive_status`.`total_honey_kg` AS `total_honey_kg`,`v_hive_status`.`last_harvest` AS `last_harvest` from `v_hive_status` where (`v_hive_status`.`inspection_overdue` = 1) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

