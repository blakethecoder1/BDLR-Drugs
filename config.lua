Config = {}

-- Resource name used in events and DB table prefixes
Config.ResourceName = 'bldr-drugs'

-- Debug settings
Config.Debug = {
  enabled = false,         -- Master debug toggle - set to false to disable ALL debug output
  showNPCs = true,        -- Show NPC debug info
  showSales = true,       -- Show sale transactions
  showSpawning = true,    -- Show NPC spawning/despawning
  showInteractions = true,-- Show player-NPC interactions
  showPolice = true,      -- Show police detection
  showXP = true,          -- Show XP calculations
  drawMarkers = true,     -- Draw 3D markers for NPCs
  printToConsole = true,  -- Print debug to server console
  printToChat = false     -- Print debug to player chat
}

-- Money & Reward Configuration
Config.Money = {
  type = 'cash',           -- 'cash', 'bank', 'crypto', 'black_money'
  useMarkedBills = true,   -- Give markedbills instead of direct money
  markedBillsChance = 0.8, -- 80% chance to get markedbills, 20% cash
  markedBillsItem = 'markedbills', -- Item name for marked bills
  
  -- Alternative money types (comment out type above and uncomment one below)
  -- type = 'black_money',  -- ESX black money
  -- type = 'crypto',       -- Crypto currency
  -- type = 'bank',         -- Bank money (clean)
}

-- Police detection radius (units)
Config.PoliceRadius = 200.0

-- Autosave interval (ms)
Config.AutosaveInterval = 300000 -- 5 minutes

-- Sell cooldowns & limits
Config.SellCooldownSeconds = 10
Config.MaxSellsPerMinute = 6

-- Token expiry for trade sessions (ms)
Config.TokenExpiry = 15000 -- 15 seconds

-- Rate limit: minimal ms between trade token requests
Config.MinTokenRequestInterval = 2000

-- NPC Management
Config.NPCs = {
  maxActive = 15,           -- Maximum NPCs active at once
  spawnRadius = 500.0,      -- Radius around player to spawn NPCs
  despawnRadius = 600.0,    -- Radius where NPCs despawn
  spawnChance = 0.3,        -- Chance to spawn NPC when checking (0.0-1.0)
  checkInterval = 5000,     -- How often to check for spawning (ms)
  walkSpeed = 1.0,          -- NPC walking speed
  approachDistance = 2.0,   -- Distance to approach NPC for interaction
  interactionTime = 3000,   -- Time NPC takes to "consider" the deal (ms)
  
  -- NPC behavior
  walkRadius = 50.0,        -- How far NPCs will walk from spawn point
  lifetimeMin = 60000,      -- Minimum NPC lifetime (ms)
  lifetimeMax = 180000,     -- Maximum NPC lifetime (ms)
  
  -- NPC cooldown system
  sellCooldown = 300000,    -- 5 minutes before you can sell to same NPC again (ms)
  showCooldownMarker = true,-- Show visual marker on NPCs you recently dealt with
  cooldownMessage = true,   -- Show notification when trying to sell to cooldown NPC
  
  -- NPC models (will be randomly selected)
  models = {
    'a_m_m_business_01', 'a_m_m_business_02', 'a_f_m_beach_01',
    'a_m_m_bevhills_01', 'a_f_m_bevhills_01', 'a_m_m_eastsa_01',
    'a_f_m_eastsa_01', 'a_m_m_farmer_01', 'a_m_m_genfat_01',
    'a_f_m_genfat_01', 'a_m_m_golfer_01', 'a_f_m_golfer_01',
    'a_m_m_hasjew_01', 'a_f_m_hasjew_01', 'a_m_m_hillbilly_01'
  },
  
  -- Zones where NPCs can spawn (optional - if empty, spawns around player)
  spawnZones = {
    -- { coords = vector3(-1171.36, -1571.65, 4.66), radius = 100.0 },
    -- { coords = vector3(-1045.89, -2736.83, 21.36), radius = 150.0 },
    -- Add more zones as needed
  }
}

-- Sellable items configuration
Config.Items = {
  -- Format: ['item_name'] = { config }
  ['weed'] = {
    label = 'Weed',
    basePrice = 50,           -- Base price per unit
    priceVariation = 0.2,     -- Price can vary +/- 20%
    xpPerUnit = 5,            -- XP gained per unit sold
    minLevel = 0,             -- Minimum level required to sell
    maxAmount = 50,           -- Maximum amount that can be sold at once
    successChance = 0.95,     -- Base success chance (before police modifier)
    policePenalty = 0.05,     -- Success chance reduction per nearby cop
    description = 'High quality street weed'
  },
  
  ['cocaine'] = {
    label = 'Cocaine',
    basePrice = 120,
    priceVariation = 0.25,
    xpPerUnit = 8,
    minLevel = 2,
    maxAmount = 25,
    successChance = 0.85,
    policePenalty = 0.08,
    description = 'Pure Colombian powder'
  },
  
  ['heroin'] = {
    label = 'Heroin',
    basePrice = 200,
    priceVariation = 0.3,
    xpPerUnit = 12,
    minLevel = 4,
    maxAmount = 15,
    successChance = 0.75,
    policePenalty = 0.12,
    description = 'High grade black tar'
  },
  
  ['meth'] = {
    label = 'Meth',
    basePrice = 180,
    priceVariation = 0.25,
    xpPerUnit = 10,
    minLevel = 3,
    maxAmount = 20,
    successChance = 0.80,
    policePenalty = 0.10,
    description = 'Crystal blue persuasion'
  },
  
  ['xtc'] = {
    label = 'Ecstasy',
    basePrice = 80,
    priceVariation = 0.2,
    xpPerUnit = 6,
    minLevel = 1,
    maxAmount = 30,
    successChance = 0.90,
    policePenalty = 0.06,
    description = 'Party pills for the night'
  }
}

-- DB table names
Config.DB = {
  XPTable = 'bldr_drugs',
  LogsTable = 'bldr_drugs_logs'
}

-- XP levels -> multiplier mapping
Config.Levels = {
  { level = 0, xp = 0, multiplier = 1.0, title = 'Street Rookie' },
  { level = 1, xp = 100, multiplier = 1.05, title = 'Corner Dealer' },
  { level = 2, xp = 300, multiplier = 1.12, title = 'Block Runner' },
  { level = 3, xp = 700, multiplier = 1.2, title = 'Neighborhood Pusher' },
  { level = 4, xp = 1500, multiplier = 1.35, title = 'District Supplier' },
  { level = 5, xp = 3000, multiplier = 1.5, title = 'City Kingpin' },
  { level = 6, xp = 6000, multiplier = 1.75, title = 'Regional Boss' },
  { level = 7, xp = 12000, multiplier = 2.0, title = 'Drug Lord' }
}

-- Logging toggle
Config.EnableLogging = true

-- Notification settings
Config.Notifications = {
  position = 'top-right',  -- top-left, top-right, bottom-left, bottom-right
  duration = 4000          -- milliseconds
}

-- Third Eye / Target System Configuration
Config.ThirdEye = {
  enabled = true,              -- Set to true to enable third-eye targeting
  useQBTarget = true,          -- true for qb-target, false for ox_target
  targetIcon = 'fa-solid fa-cannabis', -- icon for third-eye
  targetLabel = 'Sell Drugs',  -- label for third-eye
  targetDistance = 2.5,        -- interaction distance
  targets = {
    peds = true,               -- Allow targeting NPCs
    vehicles = false,          -- Allow targeting vehicles
    objects = false            -- Allow targeting objects
  },
  targetModels = {},           -- add model hashes if using object targeting
  blacklistedZones = {}        -- add zone names if needed
}

