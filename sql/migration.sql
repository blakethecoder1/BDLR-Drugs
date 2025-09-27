-- Enhanced Migration for bldr-drugs XP and logs tables

CREATE TABLE IF NOT EXISTS bldr_drugs (
  citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
  xp INT NOT NULL DEFAULT 0,
  total_sales INT DEFAULT 0,
  total_earned INT DEFAULT 0,
  last_sale TIMESTAMP NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_xp (xp),
  INDEX idx_last_sale (last_sale)
);

CREATE TABLE IF NOT EXISTS bldr_drugs_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(50),
  item VARCHAR(100),
  amount INT,
  base_price INT,
  final_price INT,
  xpEarned INT,
  level_before INT,
  level_after INT,
  success TINYINT(1),
  reason VARCHAR(250),
  x DOUBLE,
  y DOUBLE,
  z DOUBLE,
  nearbyCops INT,
  success_chance DOUBLE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_citizenid (citizenid),
  INDEX idx_item (item),
  INDEX idx_success (success),
  INDEX idx_created_at (created_at)
);

-- Add sample data for testing (optional - remove in production)
-- INSERT IGNORE INTO bldr_drugs (citizenid, xp, total_sales, total_earned) 
-- VALUES ('test123', 500, 25, 5000);
