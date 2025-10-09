-- BLDR-DRUGS evolution progression (integrated)
CREATE TABLE IF NOT EXISTS `drug_evolution_progress` (
  `citizenid` varchar(50) NOT NULL,
  `total_revenue` int NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
);

CREATE TABLE IF NOT EXISTS `drug_evolution_unlocks` (
  `citizenid` varchar(50) NOT NULL,
  `key_name` varchar(64) NOT NULL,
  `unlocked` tinyint(1) NOT NULL DEFAULT 0,
  `meta` json DEFAULT NULL,
  PRIMARY KEY (`citizenid`, `key_name`)
);