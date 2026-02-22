-- Admin Creator Tables for BLDR-Drugs
CREATE TABLE IF NOT EXISTS bldr_drug_items (
  name VARCHAR(100) NOT NULL PRIMARY KEY,
  label VARCHAR(100),
  base_price INT DEFAULT 0,
  price_variation DOUBLE DEFAULT 0.2,
  xp_per_unit INT DEFAULT 0,
  min_level INT DEFAULT 0,
  max_amount INT DEFAULT 1,
  success_chance DOUBLE DEFAULT 1,
  police_penalty DOUBLE DEFAULT 0,
  description TEXT,
  image VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bldr_drug_recipes (
  key_name VARCHAR(100) NOT NULL PRIMARY KEY,
  label VARCHAR(100),
  result_item VARCHAR(100),
  result_count INT DEFAULT 1,
  requires_json LONGTEXT,
  unlock_key VARCHAR(100),
  time_ms INT DEFAULT 5000,
  image VARCHAR(255),
  enabled TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bldr_drug_tables (
  id INT AUTO_INCREMENT PRIMARY KEY,
  label VARCHAR(100),
  x DOUBLE,
  y DOUBLE,
  z DOUBLE,
  heading DOUBLE DEFAULT 0,
  prop_model VARCHAR(100),
  enabled TINYINT(1) DEFAULT 1,
  meta_json LONGTEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
