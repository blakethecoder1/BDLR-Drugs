-- Migration for bldr-drugs XP and logs tables

CREATE TABLE IF NOT EXISTS bldr_drugs (
  citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
  xp INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS bldr_drugs_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(50),
  item VARCHAR(100),
  amount INT,
  price INT,
  xpEarned INT,
  success TINYINT(1),
  reason VARCHAR(250),
  x DOUBLE,
  y DOUBLE,
  z DOUBLE,
  nearbyCops INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
