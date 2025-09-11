Config = {}

Config.Drugs = {
    { item = 'weed', label = 'Weed', basePrice = 100 },
    { item = 'coke', label = 'Cocaine', basePrice = 300 },
    { item = 'meth', label = 'Meth', basePrice = 250 },
}

Config.SellLocations = {
    { coords = vector3(1391.0, 3605.0, 35.0), radius = 50.0 },
    { coords = vector3(55.0, -1392.0, 29.0), radius = 40.0 },
}

Config.Levels = {
    { xp = 0, multiplier = 1.0 },
    { xp = 100, multiplier = 1.1 },
    { xp = 300, multiplier = 1.25 },
    { xp = 700, multiplier = 1.5 },
    { xp = 1500, multiplier = 1.75 },
}

Config.SellCooldown = 5 -- seconds
Config.MaxPeds = 6
Config.SellChance = 85 -- base
Config.UI = { timeout = 10000 }

-- Database
Config.UseDatabase = true
Config.TableName = 'bldr_drugs' -- columns: citizenid VARCHAR(50), xp INT

-- Buyer NPC settings
Config.SpawnDistance = 5.0
Config.BuyerModel = 'a_m_m_skater_01'
Config.BuyerTimeout = 20000 -- ms before buyer leaves

-- Police detection: if number of cops nearby > this, reduce success chance
Config.PoliceCheckRadius = 80.0
Config.PolicePenalty = 30 -- percent penalty when cops nearby

return Config
