-- Add missing columns to existing bldr_drugs table
-- This script will add the missing columns without losing existing data

ALTER TABLE bldr_drugs 
ADD COLUMN IF NOT EXISTS total_sales INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_earned INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_sale TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Add indexes for better performance
ALTER TABLE bldr_drugs 
ADD INDEX IF NOT EXISTS idx_xp (xp),
ADD INDEX IF NOT EXISTS idx_last_sale (last_sale);

-- Add telemetry columns for sale logs (v1 balancing/hardening update)
ALTER TABLE bldr_drugs_logs
ADD COLUMN IF NOT EXISTS reward_type VARCHAR(32),
ADD COLUMN IF NOT EXISTS unit_price INT,
ADD COLUMN IF NOT EXISTS variation_multiplier DOUBLE,
ADD COLUMN IF NOT EXISTS level_multiplier DOUBLE,
ADD COLUMN IF NOT EXISTS robbery_triggered TINYINT(1) DEFAULT 0;

-- Verify the table structure
DESCRIBE bldr_drugs;