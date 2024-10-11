-- Adminer 4.8.1 MySQL 10.9.3-MariaDB dump

SET NAMES utf8;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';

DROP DATABASE IF EXISTS `radius`;
CREATE DATABASE `radius` /*!40100 DEFAULT CHARACTER SET utf8mb3 */;
USE `radius`;

DROP TABLE IF EXISTS `bandwidth`;
CREATE TABLE `bandwidth` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `rate_down` int(11) DEFAULT 0,
  `rate_up` int(11) DEFAULT 0,
  `creation_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;


DROP TABLE IF EXISTS `batch_history`;
CREATE TABLE `batch_history` (
  `id` int(32) NOT NULL AUTO_INCREMENT,
  `batch_name` varchar(64) DEFAULT NULL COMMENT 'an identifier name of the batch instance',
  `batch_description` varchar(256) DEFAULT NULL COMMENT 'general description of the entry',
  `hotspot_id` int(32) DEFAULT 0 COMMENT 'the hotspot business id associated with this batch instance',
  `batch_status` varchar(128) NOT NULL DEFAULT 'Pending' COMMENT 'the batch status',
  `creationdate` datetime DEFAULT '0000-00-00 00:00:00',
  `creationby` varchar(128) DEFAULT NULL,
  `updatedate` datetime DEFAULT '0000-00-00 00:00:00',
  `updateby` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `batch_name` (`batch_name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS `billing_plans`;
CREATE TABLE `billing_plans` (
  `id` int(8) NOT NULL AUTO_INCREMENT,
  `planName` varchar(128) DEFAULT NULL,
  `planId` varchar(128) DEFAULT NULL,
  `planType` varchar(128) DEFAULT NULL,
  `planTimeBank` varchar(128) DEFAULT NULL,
  `planTimeType` varchar(128) DEFAULT NULL,
  `planTimeRefillCost` varchar(128) DEFAULT NULL,
  `planBandwidthUp` varchar(128) DEFAULT NULL,
  `planBandwidthDown` varchar(128) DEFAULT NULL,
  `planTrafficTotal` varchar(128) DEFAULT NULL,
  `planTrafficUp` varchar(128) DEFAULT NULL,
  `planTrafficDown` varchar(128) DEFAULT NULL,
  `planTrafficRefillCost` varchar(128) DEFAULT NULL,
  `planRecurring` varchar(128) DEFAULT NULL,
  `planRecurringPeriod` varchar(128) DEFAULT NULL,
  `planRecurringBillingSchedule` varchar(128) NOT NULL DEFAULT 'Fixed',
  `planCost` varchar(128) DEFAULT NULL,
  `planSetupCost` varchar(128) DEFAULT NULL,
  `planTax` varchar(128) DEFAULT NULL,
  `planCurrency` varchar(128) DEFAULT NULL,
  `planGroup` varchar(128) DEFAULT NULL,
  `planActive` varchar(32) NOT NULL DEFAULT 'yes',
  `creationdate` datetime DEFAULT '0000-00-00 00:00:00',
  `creationby` varchar(128) DEFAULT NULL,
  `updatedate` datetime DEFAULT '0000-00-00 00:00:00',
  `updateby` varchar(128) DEFAULT NULL,
  `planCode` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `planName` (`planName`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS `client`;
CREATE TABLE `client` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `whatsapp_number` varchar(20) DEFAULT NULL,
  `telegram_id` varchar(50) NOT NULL,
  `balance` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;


DROP TABLE IF EXISTS `nas`;
CREATE TABLE `nas` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `nasname` varchar(128) COLLATE utf8mb3_unicode_ci NOT NULL,
  `shortname` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `type` varchar(30) COLLATE utf8mb3_unicode_ci DEFAULT 'other',
  `ports` int(5) DEFAULT NULL,
  `secret` varchar(60) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT 'secret',
  `server` varchar(64) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `community` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `description` varchar(200) COLLATE utf8mb3_unicode_ci DEFAULT 'RADIUS Client',
  PRIMARY KEY (`id`),
  KEY `nasname` (`nasname`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `operators`;
CREATE TABLE `operators` (
  `id` int(32) NOT NULL AUTO_INCREMENT,
  `username` varchar(32) NOT NULL,
  `password` varchar(32) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `username` (`username`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

INSERT INTO `operators` (`id`, `username`, `password`) VALUES
(1,	'root',	'mutiara')
ON DUPLICATE KEY UPDATE `id` = VALUES(`id`), `username` = VALUES(`username`), `password` = VALUES(`password`);

SET NAMES utf8mb4;

DROP TABLE IF EXISTS `otp_requests`;
CREATE TABLE `otp_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `whatsapp_number` varchar(20) DEFAULT NULL,
  `otp_code` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


DROP TABLE IF EXISTS `print_config`;
CREATE TABLE `print_config` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hsname1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hsname2` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hsip` varchar(15) DEFAULT NULL,
  `hsdomain` varchar(255) DEFAULT NULL,
  `hscsn` varchar(20) DEFAULT NULL,
  `hsqrmode` varchar(10) DEFAULT NULL,
  `hsipdomain` varchar(10) DEFAULT NULL,
  `logomode` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb3;

INSERT INTO `print_config` (`id`, `hsname1`, `hsname2`, `hsip`, `hsdomain`, `hscsn`, `hsqrmode`, `hsipdomain`, `logomode`) VALUES
(1,	'𝗠𝗨𝗧𝗜𝗔𝗥𝗔',	'𝗡𝗘𝗧',	'10.10.10.1',	'mutiara.wifi',	'0853-7268-7484',	'code',	'ip',	'text')
ON DUPLICATE KEY UPDATE `id` = VALUES(`id`), `hsname1` = VALUES(`hsname1`), `hsname2` = VALUES(`hsname2`), `hsip` = VALUES(`hsip`), `hsdomain` = VALUES(`hsdomain`), `hscsn` = VALUES(`hscsn`), `hsqrmode` = VALUES(`hsqrmode`), `hsipdomain` = VALUES(`hsipdomain`), `logomode` = VALUES(`logomode`);

DROP TABLE IF EXISTS `radacct`;
CREATE TABLE `radacct` (
  `radacctid` bigint(21) NOT NULL AUTO_INCREMENT,
  `acctsessionid` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `acctuniqueid` varchar(32) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `username` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `groupname` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `realm` varchar(64) COLLATE utf8mb3_unicode_ci DEFAULT '',
  `nasipaddress` varchar(15) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `nasportid` varchar(15) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `nasporttype` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `acctstarttime` datetime DEFAULT NULL,
  `acctupdatetime` datetime DEFAULT NULL,
  `acctstoptime` datetime DEFAULT NULL,
  `acctinterval` int(12) DEFAULT NULL,
  `acctsessiontime` int(12) unsigned DEFAULT NULL,
  `acctauthentic` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `connectinfo_start` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `connectinfo_stop` varchar(50) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `acctinputoctets` bigint(20) DEFAULT NULL,
  `acctoutputoctets` bigint(20) DEFAULT NULL,
  `calledstationid` varchar(50) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `callingstationid` varchar(50) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `acctterminatecause` varchar(32) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `servicetype` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `framedprotocol` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `framedipv6address` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `framedipv6prefix` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `framedinterfaceid` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `delegatedipv6prefix` varchar(32) COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `framedipaddress` varchar(15) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`radacctid`),
  UNIQUE KEY `acctuniqueid` (`acctuniqueid`),
  KEY `username` (`username`),
  KEY `framedipaddress` (`framedipaddress`),
  KEY `acctsessionid` (`acctsessionid`),
  KEY `acctsessiontime` (`acctsessiontime`),
  KEY `acctstarttime` (`acctstarttime`),
  KEY `acctinterval` (`acctinterval`),
  KEY `acctstoptime` (`acctstoptime`),
  KEY `nasipaddress` (`nasipaddress`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radcheck`;
CREATE TABLE `radcheck` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `attribute` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` char(2) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '==',
  `value` varchar(253) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `username` (`username`(32))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radgroupbw`;
CREATE TABLE `radgroupbw` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `groupname` varchar(255) NOT NULL,
  `bw_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `bw_id` (`bw_id`),
  CONSTRAINT `radgroupbw_ibfk_1` FOREIGN KEY (`bw_id`) REFERENCES `bandwidth` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;


DROP TABLE IF EXISTS `radgroupcheck`;
CREATE TABLE `radgroupcheck` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `groupname` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `attribute` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` char(2) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '==',
  `value` varchar(253) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `groupname` (`groupname`(32))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radgroupreply`;
CREATE TABLE `radgroupreply` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `groupname` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `attribute` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` char(2) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '=',
  `value` varchar(253) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `groupname` (`groupname`(32))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radpostauth`;
CREATE TABLE `radpostauth` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `pass` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `reply` varchar(32) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `authdate` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radreply`;
CREATE TABLE `radreply` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `attribute` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `op` char(2) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '=',
  `value` varchar(253) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `username` (`username`(32))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `radusergroup`;
CREATE TABLE `radusergroup` (
  `username` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `groupname` varchar(64) COLLATE utf8mb3_unicode_ci NOT NULL DEFAULT '',
  `priority` int(11) NOT NULL DEFAULT 1,
  KEY `username` (`username`(32))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;


DROP TABLE IF EXISTS `topup`;
CREATE TABLE `topup` (
  `id` varchar(10) NOT NULL,
  `user_id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `amount` int(11) NOT NULL,
  `status` enum('Accept','Reject','Pending') NOT NULL,
  `date` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;


DELIMITER ;;

CREATE TRIGGER `before_insert_topup` BEFORE INSERT ON `topup` FOR EACH ROW
BEGIN
    SET NEW.id = CONCAT('TRX', LPAD(FLOOR(RAND() * 999), 3, '0'));
END;;

DELIMITER ;

DROP TABLE IF EXISTS `userbillinfo`;
CREATE TABLE `userbillinfo` (
  `id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(128) DEFAULT NULL,
  `planName` varchar(128) DEFAULT NULL,
  `hotspot_id` int(32) DEFAULT NULL,
  `hotspotlocation` varchar(32) DEFAULT NULL,
  `contactperson` varchar(200) DEFAULT NULL,
  `company` varchar(200) DEFAULT NULL,
  `email` varchar(200) DEFAULT NULL,
  `phone` varchar(200) DEFAULT NULL,
  `address` varchar(200) DEFAULT NULL,
  `city` varchar(200) DEFAULT NULL,
  `state` varchar(200) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `zip` varchar(200) DEFAULT NULL,
  `paymentmethod` varchar(200) DEFAULT NULL,
  `cash` varchar(200) DEFAULT NULL,
  `creditcardname` varchar(200) DEFAULT NULL,
  `creditcardnumber` varchar(200) DEFAULT NULL,
  `creditcardverification` varchar(200) DEFAULT NULL,
  `creditcardtype` varchar(200) DEFAULT NULL,
  `creditcardexp` varchar(200) DEFAULT NULL,
  `notes` varchar(200) DEFAULT NULL,
  `changeuserbillinfo` varchar(128) DEFAULT NULL,
  `lead` varchar(200) DEFAULT NULL,
  `coupon` varchar(200) DEFAULT NULL,
  `ordertaker` varchar(200) DEFAULT NULL,
  `billstatus` varchar(200) DEFAULT NULL,
  `lastbill` date NOT NULL DEFAULT '0000-00-00',
  `nextbill` date NOT NULL DEFAULT '0000-00-00',
  `nextinvoicedue` int(32) DEFAULT NULL,
  `billdue` int(32) DEFAULT NULL,
  `postalinvoice` varchar(8) DEFAULT NULL,
  `faxinvoice` varchar(8) DEFAULT NULL,
  `emailinvoice` varchar(8) DEFAULT NULL,
  `batch_id` int(32) DEFAULT NULL,
  `creationdate` datetime DEFAULT '0000-00-00 00:00:00',
  `creationby` varchar(128) DEFAULT NULL,
  `updatedate` datetime DEFAULT '0000-00-00 00:00:00',
  `updateby` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `username` (`username`),
  KEY `planname` (`planName`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


DROP TABLE IF EXISTS `userinfo`;
CREATE TABLE `userinfo` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(128) DEFAULT NULL,
  `firstname` varchar(200) DEFAULT NULL,
  `lastname` varchar(200) DEFAULT NULL,
  `email` varchar(200) DEFAULT NULL,
  `department` varchar(200) DEFAULT NULL,
  `company` varchar(200) DEFAULT NULL,
  `workphone` varchar(200) DEFAULT NULL,
  `homephone` varchar(200) DEFAULT NULL,
  `mobilephone` varchar(200) DEFAULT NULL,
  `address` varchar(200) DEFAULT NULL,
  `city` varchar(200) DEFAULT NULL,
  `state` varchar(200) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `zip` varchar(200) DEFAULT NULL,
  `notes` varchar(200) DEFAULT NULL,
  `changeuserinfo` varchar(128) DEFAULT NULL,
  `portalloginpassword` varchar(128) DEFAULT '',
  `enableportallogin` int(32) DEFAULT 0,
  `creationdate` datetime DEFAULT '0000-00-00 00:00:00',
  `creationby` varchar(128) DEFAULT NULL,
  `updatedate` datetime DEFAULT '0000-00-00 00:00:00',
  `updateby` varchar(128) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `username` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


-- 2024-10-11 12:53:21
