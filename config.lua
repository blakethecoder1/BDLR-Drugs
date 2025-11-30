Config = {}

-- Resource name used in events and DB table prefixes
Config.ResourceName = 'bldr-drugs'

-- Debug settings
Config.Debug = {
  enabled = false,          -- Master debug toggle - set to true to enable debug output
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
  
  -- NPC Filtering System
  filteringEnabled = true,  -- Enable NPC filtering (recommended)
  filterMode = 'blacklist', -- 'blacklist' = block specific NPCs, 'whitelist' = only allow specific NPCs
  
  -- Blacklist: NPCs you CANNOT sell to (shop keepers, essential NPCs, etc.)
  blacklistedModels = {
    -- Shop keepers and store NPCs
    'mp_m_shopkeep_01', 'cs_old_man1a', 'cs_old_man2', 's_m_m_shopkeeper_01',
    's_f_m_shop_high', 's_f_y_shop_low', 's_f_y_shop_mid', 's_m_y_shop_mask',
    
    -- Gas station attendants
    'mp_m_freemode_01', 'ig_manuel', 'cs_manuel',
    
    -- Ammunation clerks
    'cs_hunter', 's_m_y_ammucity_01',
    
    -- Car dealership
    'cs_carbuyer', 'ig_car3guy1', 'ig_car3guy2',
    
    -- Add more as needed - check model names in-game
  },
  
  -- Whitelist: ONLY these NPCs can be sold to (leave empty if using blacklist)
  whitelistedModels = {
    -- Only enable this if you want to restrict to specific models
    -- 'a_m_m_business_01', 'a_f_m_business_02', etc.
  },
  
  -- Additional filtering options
  blockVehicleNPCs = true,  -- Don't allow selling to NPCs in vehicles
  blockMissionNPCs = true,  -- Don't allow selling to mission-critical NPCs
  minDistanceFromShops = 50.0, -- Minimum distance from shops/stores to sell (0.0 to disable)
  
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
  },

  -- EVOLVED DRUGS (Higher tier, better prices) - Premium purity by default
  ['evo_weed_chronic'] = {
    label = 'Chronic Kush',
    basePrice = 85,           -- 70% more than regular weed
    priceVariation = 0.15,    -- Less variation (premium product)
    xpPerUnit = 8,            -- 60% more XP
    minLevel = 1,             -- Requires some experience
    maxAmount = 40,
    successChance = 0.96,     -- Higher success rate
    policePenalty = 0.04,     -- Less police attention
    description = 'Premium evolved cannabis strain'
  },

  ['evo_cocaine_pure'] = {
    label = 'Pure Colombian',
    basePrice = 200,          -- 67% more than regular cocaine
    priceVariation = 0.2,
    xpPerUnit = 12,           -- 50% more XP
    minLevel = 3,             -- Higher level requirement
    maxAmount = 20,
    successChance = 0.88,     -- Slightly better success
    policePenalty = 0.07,     -- Slightly less police penalty
    description = 'Pharmaceutical grade cocaine'
  },

  ['evo_meth_l1'] = {
    label = 'Blue Crystal',
    basePrice = 300,          -- 67% more than regular meth
    priceVariation = 0.2,
    xpPerUnit = 15,           -- 50% more XP
    minLevel = 4,             -- High level requirement
    maxAmount = 15,
    successChance = 0.83,     -- Better success rate
    policePenalty = 0.08,     -- Slightly less police attention
    description = 'Laboratory grade methamphetamine'
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
  position = 'center-right',   -- ox_lib supports: top-left, top-right, top-center, center-left, center-right, bottom-left, bottom-right, bottom-center
  duration = 6500,             -- 6.5 seconds - slower so people can read
  useCustom = true,            -- Use custom bright notifications instead of default QBCore green
  customColors = {
    success = '#00ffaa',       -- Bright mint green - easier to read
    error = '#ff4444',         -- Bright red with good contrast
    info = '#4da6ff',          -- Bright blue that pops
    warning = '#ffaa00'        -- Orange for warnings
  }
}

-- UI Color Customization
Config.UI = {
  colors = {
    primary = '#00ff88',       -- Main accent color (borders, highlights)
    secondary = '#0f3460',     -- Secondary color (backgrounds)
    background = 'rgba(26, 26, 46, 0.85)',  -- Main background color
    backgroundAlt = 'rgba(22, 33, 62, 0.85)', -- Alternative background
    text = '#ffffff',          -- Primary text color
    textMuted = '#cccccc',     -- Muted text color
    success = '#00ff88',       -- Success color (level, XP bar)
    warning = '#ffd700',       -- Warning/highlight color (title)
    error = '#ff4444'          -- Error color
  },
  -- Gradient backgrounds (format: 'linear-gradient(angle, color1, color2)')
  gradients = {
    panel = 'linear-gradient(145deg, rgba(26, 26, 46, 0.85), rgba(22, 33, 62, 0.85))',
    header = 'linear-gradient(90deg, #0f3460, #16213e)',
    xpBar = 'linear-gradient(90deg, #00ff88, #00cc6a)'
  }
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

-- === BLDR-DRUGS: Evolution (progression) ===
Config.Evolution = {
  enabled = true,
  brand = 'BLDR-DRUGS',         -- prefix for player-facing toasts
  notify = 'ox',                -- 'qb' | 'ox' | 'chat' (ox_lib has better styling)
  inventory = 'auto',           -- 'auto' | 'ox' | 'qb' | 'core'
  
  -- Progress notification settings
  notifications = {
    enabled = true,             -- Enable progress notifications
    milestones = {75, 90, 95},  -- Notify at these progress percentages
    nearUnlockThreshold = 95,   -- Show special "almost there" message at this %
    showProgressCommand = true  -- Allow /checkevolution command for all players
  },
  
  thresholds = {
    -- Unlocks by count sold of specific items (simplified for testing)
    { key = 'evo_weed_lvl1',    by = 'count', item = 'weed',    amount = 25, unlocks = {'recipe_evo_weed_lvl1'} },
    { key = 'evo_cocaine_lvl1', by = 'count', item = 'cocaine', amount = 20, unlocks = {'recipe_evo_cocaine_lvl1'} },
    { key = 'evo_meth_lvl1',    by = 'count', item = 'meth',    amount = 15, unlocks = {'recipe_evo_meth_lvl1'} },
  },
  autoGrantItems = {
    -- Auto-give crafting materials when unlocks happen (optional)
    -- { item = 'thc_extract', count = 1 },
    -- { item = 'purification_kit', count = 1 },
    -- { item = 'lithium', count = 1 }
  },
  recipes = {
    -- Evolved Weed Recipe (25 weed sales required)
    recipe_evo_weed_lvl1 = {
      label = 'Chronic Weed',
      result = { item = 'evo_weed_chronic', count = 2 },
      requires = {
        { item = 'weed', count = 3 },
        { item = 'thc_extract', count = 1 },
        { item = 'rolling_papers', count = 1 },
      },
      unlock_key = 'recipe_evo_weed_lvl1',
      time_ms = 5000
    },
    
    -- Evolved Cocaine Recipe (20 cocaine sales required)
    recipe_evo_cocaine_lvl1 = {
      label = 'Pure Cocaine',
      result = { item = 'evo_cocaine_pure', count = 1 },
      requires = {
        { item = 'cocaine', count = 2 },
        { item = 'purification_kit', count = 1 },
        { item = 'acetone', count = 1 },
      },
      unlock_key = 'recipe_evo_cocaine_lvl1',
      time_ms = 7000
    },
    
    -- Evolved Meth Recipe (15 meth sales required)
    recipe_evo_meth_lvl1 = {
      label = 'Blue Meth',
      result = { item = 'evo_meth_l1', count = 1 },
      requires = {
        { item = 'meth', count = 2 },
        { item = 'lithium', count = 1 },
        { item = 'pseudoephedrine', count = 1 },
      },
      unlock_key = 'recipe_evo_meth_lvl1',
      time_ms = 8000
    }
  }
}
