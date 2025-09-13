Config = {}

-- Resource name used in events and DB table prefixes
Config.ResourceName = 'bldr-drugs'

-- Police detection radius (units)
Config.PoliceRadius = 200.0

-- Autosave interval (ms)
Config.AutosaveInterval = 300000 -- 5 minutes

-- Sell cooldowns & limits
Config.SellCooldownSeconds = 10
Config.MaxSellsPerMinute = 6

-- Token expiry for trade sessions (ms)
Config.TokenExpiry = 15000 -- 15 seconds

-- DB table names
Config.DB = {
  XPTable = 'bldr_drugs',
  LogsTable = 'bldr_drugs_logs'
}

-- Default buyer configuration (used by client for spawning)
Config.Buyer = {
  Models = { 'a_m_m_business_01', 'a_m_m_business_02', 'a_f_m_beach_01' },
  SpawnDistanceMin = 18.0,
  SpawnDistanceMax = 26.0,
  ApproachDistance = 1.5,
  WalkSpeed = 1.0
}

-- Sell locations (example)
Config.SellPoints = {
  vector3(-1171.36, -1571.65, 4.6644), -- example spot
}

-- XP levels -> multiplier mapping
Config.Levels = {
  { level = 0, xp = 0, multiplier = 1.0 },
  { level = 1, xp = 100, multiplier = 1.05 },
  { level = 2, xp = 300, multiplier = 1.12 },
  { level = 3, xp = 700, multiplier = 1.2 },
  { level = 4, xp = 1500, multiplier = 1.35 },
  { level = 5, xp = 3000, multiplier = 1.5 },
}

-- Logging toggle
Config.EnableLogging = true

-- Rate limit: minimal ms between trade token requests
Config.MinTokenRequestInterval = 2000

-- Debug
Config.Debug = false

