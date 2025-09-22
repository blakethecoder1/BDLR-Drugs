local QBCore = exports['qb-core']:GetCoreObject()
local MySQL = exports['oxmysql']

local playerXP = {} -- in-memory cache: citizenid -> xp
local tokenStore = {} -- token -> {source, expires}
local sellHistory = {} -- source -> {timestamps...} used for rate limiting

-- Debug logging function
local function debugPrint(category, ...)
  if Config.Debug.enabled then
    local categoryEnabled = false
    
    if category == 'sales' and Config.Debug.showSales then categoryEnabled = true
    elseif category == 'police' and Config.Debug.showPolice then categoryEnabled = true
    elseif category == 'xp' and Config.Debug.showXP then categoryEnabled = true
    elseif category == 'general' then categoryEnabled = true
    end
    
    if categoryEnabled and Config.Debug.printToConsole then
      print('[bldr-drugs][' .. string.upper(category) .. ']', ...)
    end
  end
end

-- Enhanced DB helpers
local function ensureTables()
  local xpTable = Config.DB.XPTable
  local logsTable = Config.DB.LogsTable

  local createXP = ([[
    CREATE TABLE IF NOT EXISTS %s (
      citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
      xp INT NOT NULL DEFAULT 0,
      total_sales INT DEFAULT 0,
      total_earned INT DEFAULT 0,
      last_sale TIMESTAMP NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    );
  ]]):format(xpTable)

  local createLogs = ([[
    CREATE TABLE IF NOT EXISTS %s (
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
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  ]]):format(logsTable)

  MySQL.execute(createXP, {}, function(affected)
    debugPrint('general', 'ensureTables XP result', affected)
  end)

  MySQL.execute(createLogs, {}, function(affected)
    debugPrint('general', 'ensureTables Logs result', affected)
  end)
end

-- Player XP management
local function loadPlayerXP(citizenid, cb)
  MySQL.query('SELECT * FROM '..Config.DB.XPTable..' WHERE citizenid = ?', {citizenid}, function(result)
    if result and result[1] then
      playerXP[citizenid] = {
        xp = tonumber(result[1].xp) or 0,
        totalSales = tonumber(result[1].total_sales) or 0,
        totalEarned = tonumber(result[1].total_earned) or 0
      }
      debugPrint('xp', 'Loaded XP for', citizenid, playerXP[citizenid].xp)
      if cb then cb(playerXP[citizenid].xp) end
    else
      -- insert default
      MySQL.execute('INSERT INTO '..Config.DB.XPTable..' (citizenid, xp) VALUES (?, ?)', {citizenid, 0}, function()
        playerXP[citizenid] = { xp = 0, totalSales = 0, totalEarned = 0 }
        if cb then cb(0) end
      end)
    end
  end)
end

local function savePlayerXP(citizenid)
  local data = playerXP[citizenid] or { xp = 0, totalSales = 0, totalEarned = 0 }
  MySQL.execute('UPDATE '..Config.DB.XPTable..' SET xp = ?, total_sales = ?, total_earned = ?, last_sale = NOW() WHERE citizenid = ?', 
    {data.xp, data.totalSales, data.totalEarned, citizenid}, function(affected)
      debugPrint('xp', 'Saved XP for', citizenid, data.xp)
    end)
end

-- Enhanced logging
local function logSale(data)
  if not Config.EnableLogging then return end
  
  MySQL.execute([[
    INSERT INTO ]] .. Config.DB.LogsTable .. [[ 
    (citizenid, item, amount, base_price, final_price, xpEarned, level_before, level_after, success, reason, x, y, z, nearbyCops, success_chance) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ]], {
    data.citizenid, data.item, data.amount, data.basePrice or 0, data.finalPrice or 0, 
    data.xpEarned or 0, data.levelBefore or 0, data.levelAfter or 0, data.success and 1 or 0, 
    data.reason or '', data.x or 0, data.y or 0, data.z or 0, data.nearbyCops or 0, data.successChance or 0
  }, function(affected)
    debugPrint('sales', 'Logged sale for', data.citizenid)
  end)
end

-- Item validation and pricing
local function getItemConfig(itemName)
  return Config.Items[itemName]
end

local function calculatePrice(itemConfig, amount, level, multiplier)
  local basePrice = itemConfig.basePrice * amount
  local variation = itemConfig.priceVariation or 0.2
  local variationMultiplier = 1 + (math.random() * variation * 2 - variation) -- +/- variation
  local finalPrice = math.floor(basePrice * variationMultiplier * multiplier)
  
  debugPrint('sales', 'Price calculation:', 'base=', basePrice, 'variation=', variationMultiplier, 'multiplier=', multiplier, 'final=', finalPrice)
  return finalPrice, basePrice
end

-- XP and level helpers
local function addXP(citizenid, amount)
  if not playerXP[citizenid] then
    playerXP[citizenid] = { xp = 0, totalSales = 0, totalEarned = 0 }
  end
  
  local oldXP = playerXP[citizenid].xp
  playerXP[citizenid].xp = playerXP[citizenid].xp + amount
  playerXP[citizenid].totalSales = playerXP[citizenid].totalSales + 1
  
  debugPrint('xp', 'Added', amount, 'XP to', citizenid, '- Total:', playerXP[citizenid].xp)
  savePlayerXP(citizenid)
  
  return oldXP, playerXP[citizenid].xp
end

local function addEarnings(citizenid, amount)
  if not playerXP[citizenid] then
    playerXP[citizenid] = { xp = 0, totalSales = 0, totalEarned = 0 }
  end
  playerXP[citizenid].totalEarned = playerXP[citizenid].totalEarned + amount
end

local function getXP(citizenid)
  return playerXP[citizenid] and playerXP[citizenid].xp or 0
end

local function getPlayerLevel(xp)
  local level = 0
  local multiplier = 1.0
  for i = #Config.Levels, 1, -1 do
    if xp >= Config.Levels[i].xp then
      level = Config.Levels[i].level
      multiplier = Config.Levels[i].multiplier
      break
    end
  end
  return level, multiplier
end

-- Rate limiting (unchanged but with debug)
local function canRequestToken(source)
  local now = os.time()
  sellHistory[source] = sellHistory[source] or {lastTokenRequest = 0, sells = {}}
  if now - sellHistory[source].lastTokenRequest < (Config.MinTokenRequestInterval / 1000) then
    debugPrint('general', 'Token request blocked - cooldown for source', source)
    return false, 'token_cooldown'
  end
  sellHistory[source].lastTokenRequest = now
  return true
end

local function canSell(source)
  local data = sellHistory[source] or {sells = {}}
  data.sells = data.sells or {}
  local now = os.time()
  
  -- remove old timestamps (>60s)
  local newSells = {}
  for _,ts in pairs(data.sells) do
    if now - ts <= 60 then table.insert(newSells, ts) end
  end
  data.sells = newSells
  
  if #data.sells >= Config.MaxSellsPerMinute then
    debugPrint('sales', 'Sell blocked - rate limit for source', source)
    return false, 'rate_limit'
  end
  
  if data.lastSell and (now - data.lastSell) < Config.SellCooldownSeconds then
    debugPrint('sales', 'Sell blocked - cooldown for source', source)
    return false, 'cooldown'
  end
  return true
end

local function registerSell(source)
  sellHistory[source] = sellHistory[source] or {sells = {}}
  table.insert(sellHistory[source].sells, os.time())
  sellHistory[source].lastSell = os.time()
end

-- Token management (unchanged)
local function generateToken()
  local token = tostring(math.random(100000, 999999)) .. tostring(os.time())
  return token
end

local function createTokenForSource(source)
  local token = generateToken()
  tokenStore[token] = {source = source, expires = GetGameTimer() + Config.TokenExpiry}
  return token
end

local function validateAndConsumeToken(token, source)
  local t = tokenStore[token]
  if not t then return false, 'invalid' end
  if t.source ~= source then return false, 'mismatch' end
  if GetGameTimer() > t.expires then tokenStore[token] = nil return false, 'expired' end
  tokenStore[token] = nil
  return true
end

-- Third-eye selling event
RegisterServerEvent('bdlr-drugs:server:sellWithThirdEye')
AddEventHandler('bdlr-drugs:server:sellWithThirdEye', function(targetEntity)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local citizenId = Player.PlayerData.citizenid
    
    debugPrint("SYSTEM", string.format("Player %s attempting third-eye sale to entity %s", GetPlayerName(source), targetEntity))
    
    -- Check if player has any sellable drugs
    local hasDrugs = false
    for _, itemData in pairs(Config.Items) do
        local item = Player.Functions.GetItemByName(itemData.name)
        if item and item.amount > 0 then
            hasDrugs = true
            break
        end
    end
    
    if not hasDrugs then
        TriggerClientEvent('QBCore:Notify', source, 'You have no drugs to sell', 'error')
        return
    end
    
    -- Generate token for this transaction using existing system
    local token = createTokenForSource(source)
    
    debugPrint("SYSTEM", string.format("Generated third-eye token for player %s", GetPlayerName(source)))
    
    -- Send token to client with player data
    loadPlayerXP(citizenId, function(xpData)
        local level = getPlayerLevel(xpData.xp)
        local nextLevelXP = 0
        
        if level < #Config.XP.levels then
            nextLevelXP = Config.XP.levels[level + 1].minXP
        end
        
        TriggerClientEvent('bdlr-drugs:client:receiveToken', source, token, GetGameTimer() + Config.TokenExpiry)
        TriggerClientEvent('bdlr-drugs:client:updatePlayerData', source, {
            level = level,
            title = Config.XP.levels[level].title,
            xp = xpData.xp,
            nextLevelXP = nextLevelXP
        })
    end)
end)

-- Server Events
RegisterServerEvent(Config.ResourceName..':requestToken')
AddEventHandler(Config.ResourceName..':requestToken', function()
  local src = source
  local ok, reason = canRequestToken(src)
  if not ok then
    TriggerClientEvent(Config.ResourceName..':tokenResponse', src, false, reason)
    return
  end
  local token = createTokenForSource(src)
  TriggerClientEvent(Config.ResourceName..':tokenResponse', src, true, token, Config.TokenExpiry)
  debugPrint('general', 'Token created for source', src)
end)

-- Enhanced sell completion
QBCore.Functions.CreateCallback(Config.ResourceName..':completeSale', function(source, cb, data)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then cb(false, {reason = 'no_player'}) return end

  -- Token validation
  local valid, reason = validateAndConsumeToken(data.token, src)
  if not valid then 
    debugPrint('sales', 'Token validation failed for', src, reason)
    cb(false, {reason = reason}) 
    return 
  end

  -- Rate limiting
  local can, r = canSell(src)
  if not can then 
    debugPrint('sales', 'Rate limit hit for', src, r)
    cb(false, {reason = r}) 
    return 
  end

  -- Item validation
  local itemName = tostring(data.item)
  local amount = tonumber(data.amount) or 0
  local itemConfig = getItemConfig(itemName)
  
  if not itemConfig then 
    debugPrint('sales', 'Invalid item', itemName, 'for', src)
    cb(false, {reason = 'invalid_item'}) 
    return 
  end
  
  if amount <= 0 or amount > itemConfig.maxAmount then
    debugPrint('sales', 'Invalid amount', amount, 'for', itemName, 'by', src)
    cb(false, {reason = 'invalid_amount'}) 
    return 
  end

  -- Check player has item
  local itemObj = Player.Functions.GetItemByName(itemName)
  if not itemObj or itemObj.amount < amount then
    debugPrint('sales', 'Player', src, 'does not have enough', itemName)
    cb(false, {reason = 'not_enough'}) 
    return 
  end

  -- Level requirement check
  local cid = Player.PlayerData.citizenid
  local xp = getXP(cid)
  local level, multiplier = getPlayerLevel(xp)
  
  if level < itemConfig.minLevel then
    debugPrint('sales', 'Player', src, 'level', level, 'too low for', itemName, 'requires', itemConfig.minLevel)
    cb(false, {reason = 'level_too_low'}) 
    return 
  end

  -- Police detection
  local copsNearby = 0
  local coords = data.coords or {}
  local players = QBCore.Functions.GetQBPlayers()
  
  for playerId, PolicePlayer in pairs(players) do
    if PolicePlayer and PolicePlayer.PlayerData and PolicePlayer.PlayerData.job and PolicePlayer.PlayerData.job.name == 'police' then
      local targetPed = GetPlayerPed(playerId)
      if targetPed and targetPed ~= 0 then
        local pedCoords = GetEntityCoords(targetPed)
        local dist = #(vector3(coords.x or 0, coords.y or 0, coords.z or 0) - pedCoords)
        if dist <= Config.PoliceRadius then
          copsNearby = copsNearby + 1
        end
      end
    end
  end
  
  debugPrint('police', 'Found', copsNearby, 'cops nearby for sale by', src)

  -- Calculate success chance
  local baseChance = itemConfig.successChance or 0.95
  local policePenalty = copsNearby * (itemConfig.policePenalty or 0.05)
  local successChance = math.max(0.1, baseChance - policePenalty) -- Minimum 10% chance
  
  -- Price calculation
  local finalPrice, basePrice = calculatePrice(itemConfig, amount, level, multiplier)
  
  -- Success roll
  local rand = math.random()
  local success = rand <= successChance
  local reasonFail = nil
  local xpGain = 0
  
  debugPrint('sales', 'Sale attempt:', 'item=', itemName, 'amount=', amount, 'chance=', successChance, 'roll=', rand, 'success=', success)
  
  if success then
    -- Remove items and give money
    local removed = Player.Functions.RemoveItem(itemName, amount, nil, true)
    if not removed then
      success = false
      reasonFail = 'remove_failed'
      debugPrint('sales', 'Failed to remove items for', src)
    else
      Player.Functions.AddMoney('cash', finalPrice)
      xpGain = (itemConfig.xpPerUnit or 5) * amount
      local oldXP, newXP = addXP(cid, xpGain)
      addEarnings(cid, finalPrice)
      registerSell(src)
      
      -- Update client stats
      TriggerClientEvent(Config.ResourceName..':updatePlayerStats', src, newXP)
      
      debugPrint('sales', 'Successful sale:', 'player=', src, 'item=', itemName, 'amount=', amount, 'price=', finalPrice, 'xp=', xpGain)
    end
  else
    reasonFail = 'deal_failed'
    debugPrint('sales', 'Sale failed due to chance roll for', src)
  end

  -- Enhanced logging
  logSale({
    citizenid = cid,
    item = itemName,
    amount = amount,
    basePrice = basePrice,
    finalPrice = finalPrice,
    xpEarned = xpGain,
    levelBefore = level,
    levelAfter = getPlayerLevel(getXP(cid)),
    success = success,
    reason = reasonFail,
    x = coords.x or 0,
    y = coords.y or 0,
    z = coords.z or 0,
    nearbyCops = copsNearby,
    successChance = successChance
  })

  cb(success, {
    price = finalPrice,
    xp = getXP(cid),
    level = getPlayerLevel(getXP(cid)),
    reason = reasonFail,
    xpGained = xpGain
  })
end)

-- Player management events
AddEventHandler('playerDropped', function(reason)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if Player then
    savePlayerXP(Player.PlayerData.citizenid)
  end
  sellHistory[src] = nil
  debugPrint('general', 'Player', src, 'dropped, saved data')
end)

AddEventHandler('onResourceStop', function(name)
  if name ~= GetCurrentResourceName() then return end
  -- save all players
  for cid,data in pairs(playerXP) do
    savePlayerXP(cid)
  end
  debugPrint('general', 'Resource stopping, saved all player data')
end)

-- QBCore playerloaded
RegisterNetEvent('QBCore:PlayerLoaded')
AddEventHandler('QBCore:PlayerLoaded', function(playerId, xPlayer)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if Player then
    loadPlayerXP(Player.PlayerData.citizenid, function(xp)
      TriggerClientEvent(Config.ResourceName..':updatePlayerStats', src, xp)
    end)
  end
end)

-- Admin commands
QBCore.Commands.Add('adddrugxp', 'Add drug XP to player (admin)', {{name='id', help='player id'},{name='xp', help='xp to add'}}, true, function(source, args)
  local target = tonumber(args[1])
  local xp = tonumber(args[2])
  if not target or not xp then return end
  local Player = QBCore.Functions.GetPlayer(target)
  if not Player then return end
  
  local oldXP, newXP = addXP(Player.PlayerData.citizenid, xp)
  local level, multiplier = getPlayerLevel(newXP)
  
  TriggerClientEvent('QBCore:Notify', source, 'Added '..xp..' XP to '..Player.PlayerData.charinfo.firstname..' (Level '..level..')', 'success')
  TriggerClientEvent(Config.ResourceName..':updatePlayerStats', target, newXP)
end, 'admin')

QBCore.Commands.Add('checkdrugstats', 'Check drug dealing stats (admin)', {{name='id', help='player id'}}, true, function(source, args)
  local target = tonumber(args[1]) or source
  local Player = QBCore.Functions.GetPlayer(target)
  if not Player then return end
  
  local cid = Player.PlayerData.citizenid
  local data = playerXP[cid] or { xp = 0, totalSales = 0, totalEarned = 0 }
  local level, multiplier = getPlayerLevel(data.xp)
  local levelInfo = Config.Levels[level + 1] or Config.Levels[#Config.Levels]
  
  TriggerClientEvent('chat:addMessage', source, {
    color = {0, 255, 0},
    multiline = true,
    args = {"[DRUG STATS]", 
      Player.PlayerData.charinfo.firstname..' '..Player.PlayerData.charinfo.lastname..
      '\\nLevel: '..level..' ('..levelInfo.title..')'..
      '\\nXP: '..data.xp..
      '\\nMultiplier: x'..multiplier..
      '\\nTotal Sales: '..data.totalSales..
      '\\nTotal Earned: $'..data.totalEarned
    }
  })
end, 'admin')

QBCore.Commands.Add('drugdebug', 'Toggle drug debug mode (admin)', {}, false, function(source, args)
  Config.Debug.enabled = not Config.Debug.enabled
  TriggerClientEvent('QBCore:Notify', source, 'Drug debug mode: '..(Config.Debug.enabled and 'ON' or 'OFF'), 'primary')
end, 'admin')

-- Initialization
Citizen.CreateThread(function()
  ensureTables()
  math.randomseed(GetGameTimer())
  debugPrint('general', 'Drug dealing system initialized')
  
  -- load existing players
  for _, playerId in pairs(GetPlayers()) do
    local ply = tonumber(playerId)
    local Player = QBCore.Functions.GetPlayer(ply)
    if Player then
      loadPlayerXP(Player.PlayerData.citizenid, function(xp)
        TriggerClientEvent(Config.ResourceName..':updatePlayerStats', ply, xp)
      end)
    end
  end

  -- autosave loop
  while true do
    Citizen.Wait(Config.AutosaveInterval)
    local count = 0
    for cid,data in pairs(playerXP) do
      savePlayerXP(cid)
      count = count + 1
    end
    if count > 0 then
      debugPrint('general', 'Autosaved', count, 'player records')
    end
  end
end)

