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

-- Verify the table structure
DESCRIBE bldr_drugs;