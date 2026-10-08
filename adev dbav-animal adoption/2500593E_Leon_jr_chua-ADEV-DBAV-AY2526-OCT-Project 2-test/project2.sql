CREATE DATABASE  IF NOT EXISTS `animal_adoption` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
USE `animal_adoption`;
-- MySQL dump 10.13  Distrib 8.0.38, for Win64 (x86_64)
--
-- Host: localhost    Database: animal_adoption
-- ------------------------------------------------------
-- Server version	8.0.39

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `animal_images`
--

DROP TABLE IF EXISTS `animal_images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `animal_images` (
  `id` int NOT NULL AUTO_INCREMENT,
  `animal_id` int NOT NULL,
  `image_url` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_animal_images_animals_idx` (`animal_id`),
  CONSTRAINT `fk_animal_images_animals` FOREIGN KEY (`animal_id`) REFERENCES `animals` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=108 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `animal_images`
--

LOCK TABLES `animal_images` WRITE;
/*!40000 ALTER TABLE `animal_images` DISABLE KEYS */;
INSERT INTO `animal_images` VALUES (4,1,'images/kurt.jpg',1),(5,2,'images/choom.jpg',1),(7,4,'images/thunk.jpg',1),(20,12,'https://s.telegraph.co.uk/graphics/projects/peanuts-movie/media/peanuts-15-mr.jpg',0),(22,12,'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSWahuQ0jlwh70-S-BZ3wPWy6jSibw8X9MC4w&s',0),(23,12,'https://mediaproxy.tvtropes.org/width/1200/https://static.tvtropes.org/pmwiki/pub/images/peanuts_movie_disneyscreencapscom_7713.jpg',1),(25,12,'https://avi-8.com/cdn/shop/articles/snoopy-1f5571532ca54022b5eae307ab3381d6_e087a64c-b9f0-4f37-8df6-66bc3f32d8a0.webp?v=1764646295',0),(26,12,'https://m.media-amazon.com/images/S/pv-target-images/b0098104b1297c728250de553d325222ae03a6848d05df5dc21dca8465d0626e.jpg',0),(36,12,'https://static.wikia.nocookie.net/peanuts/images/7/7c/Snoopy_2014.jpg/revision/latest?cb=20240928013922',0),(38,12,'https://media.desenio.com/site_images/685d896597bfddc5cb9daba4_1685032353_18824-5.jpg?auto=compress%2Cformat&fit=max&w=3840',0),(39,12,'https://www.infobae.com/resizer/v2/3ADN22QBQVBOFHIBUSV7SRZ2G4.jpg?auth=6bd4c26929b2085422538014861298895cb140504d4950adac31ac92af489b10&smart=true&width=1200&height=1200&quality=85',0),(41,15,'https://thumbs.dreamstime.com/b/business-man-praying-using-prayer-gesture-eyes-ope-10468013.jpg',1),(42,15,'https://media.istockphoto.com/id/147912835/photo/business-man-praying-with-eyes-closed.jpg?s=612x612&w=0&k=20&c=kanhsKc6FFJUdmUpgvy7DVZzVMPq6q-MGFUJHwwSePQ=',0),(43,15,'https://thumbs.dreamstime.com/b/business-man-praying-eyes-closed-10468059.jpg',0),(44,15,'https://i.pinimg.com/736x/14/9f/b4/149fb44b10ec0890560247d8af58db29.jpg',0),(46,15,'https://thumbs.dreamstime.com/b/business-man-his-knees-holding-bible-10467996.jpg',0),(51,21,'https://media.tenor.com/AXdHhyF7pyoAAAAe/tiktok-hamster-reading-hamster.png',1),(52,21,'https://i.pinimg.com/236x/18/53/8f/18538f185e3b2f2b05140e8f27d852e5.jpg',0),(53,21,'https://i.pinimg.com/236x/b9/cc/4f/b9cc4f8d9f21fcb49b31973b05ca29c9.jpg',0),(54,21,'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcS1nITi0X41Hw19DU8vL7F__P1ifr3kwW2dHg&s',0),(55,21,'https://media.tenor.com/3In54SsKPIQAAAAM/hamster-hamster-meme.gif',0),(57,23,'https://tails.com/blog/wp-content/uploads/2021/09/4-1.png',1),(58,23,'https://heronscrossing.vet/wp-content/uploads/Golden-Retriever-1024x683.jpg',0),(59,23,'https://www.blogwoufwouf.com/wp-content/uploads/2018/11/%C2%A9stieberszabolcs.jpg',0),(60,23,'https://www.superpet.pe/blog/wp-content/uploads/2021/08/Golden-Retriever-La-gui%CC%81a-completa-de-esta-raza-1-750x450.jpg',0),(61,23,'https://www.petairuk.com/wp-content/uploads/2025/05/10-great-facts-about-golden-retrievers-petair-wp-768x493.png',0),(62,24,'https://scampsandchamps.co.uk/wp-content/uploads/2025/02/pexels-lichtblick800-29750372.jpg',1),(63,24,'https://closerpets.co.uk/cdn/shop/articles/boris-debusscher-8hj_0KqePuk-unsplash_0c035ae6-50f6-42b8-8959-14530e0958f5.jpg?v=1758717954',0),(64,24,'https://headsupfortails.com/cdn/shop/articles/British_Shorthair_Cat.jpg?v=1759992877',0),(65,25,'https://content.lyka.com.au/f/1016262/1104x676/e36872ce32/beagle.png/m/640x427/smart/filters:format(webp)',1),(66,25,'https://www.petcare.com.au/wp-content/uploads/2017/09/Beagle_PetCare-5.jpg',0),(86,4,'https://preview.redd.it/monkey-thinking-v0-fcdjkrqqjxrf1.jpeg?width=720&format=pjpg&auto=webp&s=918abd8a888b980d17ef32c41640dd3df4ca2bc7',0),(87,4,'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSDQlAAYmLMoOfipLgKNOL9oAreguUwaHOAlA&s',0),(88,4,'https://preview.redd.it/the-original-image-of-the-monkey-thinking-meme-v0-u2k4yuv3zbqf1.jpeg?width=640&format=pjpg&auto=webp&s=4869f2cc94cf37891587a014246d6294c6ab74cc',0),(89,40,'https://preview.redd.it/random-question-but-does-anyone-have-versions-of-this-cat-v0-ya8qikz9kn0f1.png?auto=webp&s=c2fdba9a3904ab3bec9e7367e380f66343c2929a',1),(90,1,'https://i.pinimg.com/originals/d1/30/77/d1307726079aa3c22191e6280e8d6ad5.jpg',0),(92,40,'https://preview.redd.it/zazu-soldier-cat-two-thousand-yard-stare-meme-restoration-v0-elx0vyxdhgpd1.png?width=1080&crop=smart&auto=webp&s=90fb482d202d04af3fd163498ae47fd80dca9560',0),(103,44,'https://www.sanesveterinari.it/wp-content/themes/yootheme/cache/eb/istockphoto-1015300986-612x612-1-ebafcfe4.jpeg',0),(104,44,'https://wildearth.com/cdn/shop/articles/maine-coon-cat_55188294-45b4-49d5-91f1-39a003f863b5.jpg?v=1767883207',1),(106,44,'https://cdn.hswstatic.com/gif/shutterstock-1897319095.jpg',0);
/*!40000 ALTER TABLE `animal_images` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `animals`
--

DROP TABLE IF EXISTS `animals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `animals` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `age_year` int NOT NULL,
  `age_month` int NOT NULL,
  `gender` enum('Male','Female') COLLATE utf8mb4_unicode_ci NOT NULL,
  `temperament` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `adoption_status` enum('Available','Reserved','Adopted') COLLATE utf8mb4_unicode_ci NOT NULL,
  `species_id` int NOT NULL,
  `breed_id` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_animals_species` (`species_id`),
  KEY `fk_animals_breed` (`breed_id`),
  CONSTRAINT `fk_animals_breed` FOREIGN KEY (`breed_id`) REFERENCES `breeds` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_animals_species` FOREIGN KEY (`species_id`) REFERENCES `species` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=46 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `animals`
--

LOCK TABLES `animals` WRITE;
/*!40000 ALTER TABLE `animals` DISABLE KEYS */;
INSERT INTO `animals` VALUES (1,'Kurt',6,7,'Male','Calm','Available',1,1),(2,'Choombus',3,7,'Male','Playful and Energetic','Reserved',2,2),(4,'Thunk',10,4,'Male','Apples fruits prata monkey fellow cool tree nice eat green stare food please','Adopted',3,3),(12,'Snoopy',75,3,'Male','jolly','Available',1,5),(15,'Please A star',66,4,'Male','11111111111111111111111322222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222','Available',3,3),(21,'hamster',1,1,'Male','studious fellow','Available',6,14),(23,'Goldengo',5,11,'Male','Happy playful, loves to run','Adopted',1,13),(24,'Sesame',3,6,'Female','lazy','Available',2,9),(25,'Chop',5,9,'Male','Chill ','Available',1,5),(40,'Dude',3,1,'Male','relaxed, likes to stare into empty space','Available',2,9),(44,'Simba',6,9,'Male','Bright and playful','Available',2,10);
/*!40000 ALTER TABLE `animals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `breeds`
--

DROP TABLE IF EXISTS `breeds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `breeds` (
  `id` int NOT NULL AUTO_INCREMENT,
  `species_id` int NOT NULL,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `species_id` (`species_id`,`name`),
  CONSTRAINT `fk_breeds_species` FOREIGN KEY (`species_id`) REFERENCES `species` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `breeds`
--

LOCK TABLES `breeds` WRITE;
/*!40000 ALTER TABLE `breeds` DISABLE KEYS */;
INSERT INTO `breeds` VALUES (5,1,'Beagle'),(13,1,'Golden Retriever'),(1,1,'Vizsla'),(9,2,'British Shorthair'),(2,2,'Domestic shorthair'),(10,2,'Maine Coon'),(3,3,'Barbary Macaque'),(12,3,'Capuchin Monkey'),(11,3,'Rhesus Macaque'),(14,6,'Chinese Hamster'),(8,6,'Roborovski Dwarf'),(7,6,'Syrian Hamster');
/*!40000 ALTER TABLE `breeds` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `species`
--

DROP TABLE IF EXISTS `species`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `species` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `species`
--

LOCK TABLES `species` WRITE;
/*!40000 ALTER TABLE `species` DISABLE KEYS */;
INSERT INTO `species` VALUES (2,'Cat'),(1,'Dog'),(6,'Hamster'),(3,'Monkey');
/*!40000 ALTER TABLE `species` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-02-09  1:14:59
