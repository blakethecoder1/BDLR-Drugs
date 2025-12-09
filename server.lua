local QBCore = exports['qb-core']:GetCoreObject()

-- ESX support for black money (if ESX is available)
local ESX = nil
if GetResourceState('es_extended') == 'started' then
  ESX = exports['es_extended']:getSharedObject()
end

local playerXP = {} -- in-memory cache: citizenid -> xp
local tokenStore = {} -- token -> {source, expires}
local sellHistory = {} -- source -> {timestamps...} used for rate limiting

-- Evolution system table
local BLDR_Evolution = {}

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

  -- First, create tables if they don't exist
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

  exports.oxmysql:execute(createXP, function(affected)
    debugPrint('general', 'ensureTables XP result', affected)
    
    -- After creating table, add missing columns if they don't exist
    local alterQueries = {
      ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS total_sales INT DEFAULT 0;"):format(xpTable),
      ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS total_earned INT DEFAULT 0;"):format(xpTable),
      ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS last_sale TIMESTAMP NULL;"):format(xpTable),
      ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;"):format(xpTable),
      ("ALTER TABLE %s ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;"):format(xpTable)
    }
    
    for _, query in pairs(alterQueries) do
      exports.oxmysql:execute(query, function(result)
        debugPrint('general', 'ALTER TABLE result:', result)
      end)
    end
  end)

  exports.oxmysql:execute(createLogs, function(affected)
    debugPrint('general', 'ensureTables Logs result', affected)
  end)
end

-- Player XP management
local function loadPlayerXP(citizenid, cb)
  exports.oxmysql:query('SELECT * FROM '..Config.DB.XPTable..' WHERE citizenid = ?', {citizenid}, function(result)
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
      exports.oxmysql:execute('INSERT INTO '..Config.DB.XPTable..' (citizenid, xp) VALUES (?, ?)', {citizenid, 0}, function()
        playerXP[citizenid] = { xp = 0, totalSales = 0, totalEarned = 0 }
        if cb then cb(0) end
      end)
    end
  end)
end

local function savePlayerXP(citizenid)
  local data = playerXP[citizenid] or { xp = 0, totalSales = 0, totalEarned = 0 }
  exports.oxmysql:execute('UPDATE '..Config.DB.XPTable..' SET xp = ?, total_sales = ?, total_earned = ?, last_sale = NOW() WHERE citizenid = ?', 
    {data.xp, data.totalSales, data.totalEarned, citizenid}, function(affected)
      debugPrint('xp', 'Saved XP for', citizenid, data.xp)
    end)
end

-- Enhanced logging
local function logSale(data)
  if not Config.EnableLogging then return end
  
  exports.oxmysql:execute([[
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
    loadPlayerXP(citizenId, function(xp)
        local level, multiplier = getPlayerLevel(xp)
        local nextLevelXP = 0
        
        -- Find next level XP requirement
        for i = 1, #Config.Levels do
            if Config.Levels[i].level > level then
                nextLevelXP = Config.Levels[i].xp
                break
            end
        end
        
        -- Get level title
        local title = "Street Rookie"
        for i = 1, #Config.Levels do
            if Config.Levels[i].level == level then
                title = Config.Levels[i].title
                break
            end
        end
        
        TriggerClientEvent('bdlr-drugs:client:receiveToken', source, token, GetGameTimer() + Config.TokenExpiry)
        TriggerClientEvent('bdlr-drugs:client:updatePlayerData', source, {
            level = level,
            title = title,
            xp = xp,
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

RegisterServerEvent(Config.ResourceName..':requestPlayerStats')
AddEventHandler(Config.ResourceName..':requestPlayerStats', function()
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  loadPlayerXP(Player.PlayerData.citizenid, function(xp)
    TriggerClientEvent(Config.ResourceName..':updatePlayerStats', src, xp)
    debugPrint('general', 'Player stats sent to', src, 'XP:', xp)
  end)
end)

-- [NEW] Robbery dispatch system
local lastDispatchTime = 0
RegisterServerEvent(Config.ResourceName..':server:robberyDispatch')
AddEventHandler(Config.ResourceName..':server:robberyDispatch', function(source, coords)
  local currentTime = GetGameTimer()
  
  -- Check dispatch cooldown
  if currentTime - lastDispatchTime < Config.Robbery.dispatchCooldown then
    debugPrint('general', 'Robbery dispatch on cooldown, skipping')
    return
  end
  
  lastDispatchTime = currentTime
  
  -- Send dispatch to all police players
  local players = QBCore.Functions.GetQBPlayers()
  for playerId, PolicePlayer in pairs(players) do
    if PolicePlayer and PolicePlayer.PlayerData and PolicePlayer.PlayerData.job and PolicePlayer.PlayerData.job.name == 'police' then
      -- Use your server's dispatch system - examples below:
      
      -- Example 1: cd_dispatch
      -- exports['cd_dispatch']:GetPlayerInfo(playerId)
      -- exports['cd_dispatch']:AddNotification({
      --   job_table = {'police'},
      --   coords = coords,
      --   title = Config.Robbery.dispatchCode .. ' - ' .. Config.Robbery.dispatchMessage,
      --   message = 'Robbery in progress at drug deal',
      --   flash = 0,
      --   unique_id = tostring(math.random(0000000,9999999)),
      --   blip = {sprite = 458, scale = 1.0, colour = 1, flashes = false, text = 'Robbery', time = (5*60*1000), sound = 1}
      -- })
      
      -- Example 2: ps-dispatch
      -- exports['ps-dispatch']:DrugSale(coords)
      
      -- Example 3: Simple notification (fallback)
      TriggerClientEvent('QBCore:Notify', playerId, Config.Robbery.dispatchCode .. ': ' .. Config.Robbery.dispatchMessage, 'error', 10000)
      
      debugPrint('general', 'Robbery dispatch sent to police player', playerId)
    end
  end
end)

-- Enhanced sell completion
QBCore.Functions.CreateCallback(Config.ResourceName..':completeSale', function(source, cb, data)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then 
    debugPrint('sales', 'No player found for source', src)
    cb(false, {reason = 'no_player'}) 
    return 
  end

  debugPrint('sales', 'Starting sale for player', src, 'with data:', json.encode(data))

  -- Token validation
  local valid, reason = validateAndConsumeToken(data.token, src)
  if not valid then 
    debugPrint('sales', 'Token validation failed for', src, 'reason:', reason)
    cb(false, {reason = reason}) 
    return 
  end

  debugPrint('sales', 'Token validation passed for', src)

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
  
  -- [NEW] Robbery chance system start
  local robberyTriggered = false
  if Config.Robbery.enabled and success then
    local robberyRoll = math.random(1, 100)
    if robberyRoll <= Config.Robbery.chance then
      robberyTriggered = true
      debugPrint('sales', 'ROBBERY TRIGGERED for player', src, 'roll=', robberyRoll, 'chance=', Config.Robbery.chance)
      
      -- Trigger client-side robbery sequence
      TriggerClientEvent(Config.ResourceName..':startRobbery', src, {
        coords = coords,
        playerPed = GetPlayerPed(src)
      })
      
      -- Handle stolen cash (server-side)
      if Config.Robbery.canStealCash then
        local playerCash = Player.Functions.GetMoney('cash')
        local maxSteal = math.min(
          Config.Robbery.maxCashStolen.max,
          math.floor(playerCash * (Config.Robbery.maxCashStolen.percent / 100))
        )
        local stolenCash = math.random(Config.Robbery.maxCashStolen.min, math.max(Config.Robbery.maxCashStolen.min, maxSteal))
        
        if playerCash >= stolenCash then
          Player.Functions.RemoveMoney('cash', stolenCash, "robbed-during-deal")
          debugPrint('sales', 'Robber stole', stolenCash, 'cash from player', src)
          
          -- Notify player about cash loss
          TriggerClientEvent(Config.ResourceName..':robberyStoleCash', src, stolenCash)
        end
      end
      
      -- Handle stolen items (server-side)
      if Config.Robbery.canStealItems then
        -- Items are already being sold, so we just don't give them back if sale is canceled
        debugPrint('sales', 'Robber attempting to steal items:', itemName, 'x', amount)
        TriggerClientEvent(Config.ResourceName..':robberyStoleItems', src, itemName, amount)
      end
      
      -- Send police dispatch if enabled
      if Config.Robbery.dispatchEnabled then
        TriggerEvent(Config.ResourceName..':server:robberyDispatch', src, coords)
      end
      
      -- If configured to cancel sale on robbery, mark as failed
      if Config.Robbery.cancelSaleOnRobbery then
        success = false
        reasonFail = 'robbed'
        debugPrint('sales', 'Sale canceled due to robbery for player', src)
      end
    end
  end
  -- [NEW] Robbery chance system end
  
  if success and not robberyTriggered then
    -- Remove items and give money
    debugPrint('sales', 'Attempting to remove item:', 'item=', itemName, 'amount=', amount, 'player=', src)
    local removed = Player.Functions.RemoveItem(itemName, amount, nil, "drug-sale")
    debugPrint('sales', 'Remove item result:', removed)
    if not removed then
      success = false
      reasonFail = 'remove_failed'
      debugPrint('sales', 'Failed to remove items for', src)
    else
      -- Handle money/reward based on config
      local rewardGiven = false
      
      if Config.Money.useMarkedBills and math.random() <= Config.Money.markedBillsChance then
        -- Give markedbills instead of direct money
        local markedBillsGiven = Player.Functions.AddItem(Config.Money.markedBillsItem, finalPrice, nil, "drug-sale")
        if markedBillsGiven then
          rewardGiven = true
          debugPrint('sales', 'Gave markedbills:', finalPrice, 'to player', src)
        end
      end
      
      -- If markedbills failed or not configured, give money directly
      if not rewardGiven then
        if Config.Money.type == 'black_money' then
          -- ESX black money support
          local xPlayer = ESX.GetPlayerFromId(src)
          if xPlayer then
            xPlayer.addAccountMoney('black_money', finalPrice)
            rewardGiven = true
            debugPrint('sales', 'Gave black money:', finalPrice, 'to player', src)
          end
        elseif Config.Money.type == 'crypto' then
          -- Crypto currency (if supported by your server)
          Player.Functions.AddMoney('crypto', finalPrice, "drug-sale")
          rewardGiven = true
          debugPrint('sales', 'Gave crypto:', finalPrice, 'to player', src)
        else
          -- Standard QBCore money types: 'cash', 'bank'
          Player.Functions.AddMoney(Config.Money.type, finalPrice, "drug-sale")
          rewardGiven = true
          debugPrint('sales', 'Gave', Config.Money.type..':', finalPrice, 'to player', src)
        end
      end
      
      if not rewardGiven then
        -- Fallback to cash if everything else failed
        Player.Functions.AddMoney('cash', finalPrice, "drug-sale")
        debugPrint('sales', 'Fallback: gave cash:', finalPrice, 'to player', src)
end
      
      xpGain = (itemConfig.xpPerUnit or 5) * amount
      local oldXP, newXP = addXP(cid, xpGain)
      addEarnings(cid, finalPrice)
      registerSell(src)
      
      -- Update client stats
      TriggerClientEvent(Config.ResourceName..':updatePlayerStats', src, newXP)
      
      -- Record sale for evolution system (safely)
      local ok, err = pcall(function()
        BLDR_Evolution.RecordSale(src, cid, itemName, amount, finalPrice)
      end)
      if not ok then
        debugPrint('sales', 'Evolution record sale error:', err)
      end
      
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

  -- Prepare reward information for client notification
  local rewardInfo = {
    type = 'none',
    amount = finalPrice
  }
  
  if success then
    if Config.Money.useMarkedBills and math.random() <= Config.Money.markedBillsChance then
      rewardInfo.type = 'markedbills'
    elseif Config.Money.type == 'black_money' then
      rewardInfo.type = 'black_money'
    elseif Config.Money.type == 'crypto' then
      rewardInfo.type = 'crypto'
    else
      rewardInfo.type = Config.Money.type
    end
  end

  debugPrint('sales', 'Preparing callback response for', src, 'success:', success, 'reason:', reasonFail)

  cb(success, {
    price = finalPrice,
    xp = getXP(cid),
    level = getPlayerLevel(getXP(cid)),
    reason = reasonFail,
    xpGained = xpGain,
    moneyEarned = success and finalPrice or 0,
    reward = rewardInfo
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
  
  -- Find the level info
  local levelInfo = nil
  for i = 1, #Config.Levels do
    if Config.Levels[i].level == level then
      levelInfo = Config.Levels[i]
      break
    end
  end
  levelInfo = levelInfo or Config.Levels[1] -- fallback to first level
  
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

-- Admin command to manually record a drug sale for testing evolution system
QBCore.Commands.Add('testevorecord', 'Manually record a drug sale for evolution testing (admin)', {
  {name='playerid', help='player id'}, 
  {name='item', help='drug item name (weed, cocaine, meth, etc)'}, 
  {name='amount', help='amount sold'}, 
  {name='revenue', help='revenue earned'}
}, true, function(source, args)
  local playerId = tonumber(args[1])
  local itemName = args[2]
  local amount = tonumber(args[3]) or 1
  local revenue = tonumber(args[4]) or 100
  
  if not playerId or not itemName then
    TriggerClientEvent('QBCore:Notify', source, 'Usage: /testevorecord [playerid] [item] [amount] [revenue]', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  -- Record the sale in evolution system
  local ok, err = pcall(function()
    BLDR_Evolution.RecordSale(playerId, citizenId, itemName, amount, revenue)
  end)
  
  if ok then
    TriggerClientEvent('QBCore:Notify', source, string.format('✅ Test sale recorded: %dx %s for $%d revenue (Player: %s)', 
      amount, itemName, revenue, Player.PlayerData.charinfo.firstname), 'success')
    debugPrint('sales', 'Admin test sale recorded:', 'player=', playerId, 'item=', itemName, 'amount=', amount, 'revenue=', revenue)
  else
    TriggerClientEvent('QBCore:Notify', source, 'Error recording test sale: ' .. tostring(err), 'error')
    debugPrint('sales', 'Admin test sale error:', err)
  end
end, 'admin')

-- Admin command to quickly test evolution unlocks
QBCore.Commands.Add('testevounlock', 'Test evolution unlock by giving revenue/count (admin)', {
  {name='playerid', help='player id'}, 
  {name='type', help='revenue or count'}, 
  {name='item', help='item name (for count type)'}, 
  {name='amount', help='amount to add'}
}, true, function(source, args)
  local playerId = tonumber(args[1])
  local unlockType = args[2] -- 'revenue' or 'count'
  local itemName = args[3] -- only needed for count type
  local amount = tonumber(args[4]) or 1000
  
  if not playerId or not unlockType then
    TriggerClientEvent('QBCore:Notify', source, 'Usage: /testevounlock [playerid] [revenue|count] [item] [amount]', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  if unlockType == 'revenue' then
    -- Add revenue directly
    local ok, err = pcall(function()
      BLDR_Evolution.RecordSale(playerId, citizenId, 'test_item', 1, amount)
    end)
    
    if ok then
      TriggerClientEvent('QBCore:Notify', source, string.format('✅ Added $%d revenue for testing (Player: %s)', 
        amount, Player.PlayerData.charinfo.firstname), 'success')
    else
      TriggerClientEvent('QBCore:Notify', source, 'Error adding revenue: ' .. tostring(err), 'error')
    end
    
  elseif unlockType == 'count' then
    if not itemName then
      TriggerClientEvent('QBCore:Notify', source, 'Item name required for count type', 'error')
      return
    end
    
    -- Add item count
    local ok, err = pcall(function()
      BLDR_Evolution.RecordSale(playerId, citizenId, itemName, amount, 1)
    end)
    
    if ok then
      TriggerClientEvent('QBCore:Notify', source, string.format('✅ Added %d %s sales for testing (Player: %s)', 
        amount, itemName, Player.PlayerData.charinfo.firstname), 'success')
    else
      TriggerClientEvent('QBCore:Notify', source, 'Error adding item count: ' .. tostring(err), 'error')
    end
  else
    TriggerClientEvent('QBCore:Notify', source, 'Type must be "revenue" or "count"', 'error')
  end
end, 'admin')

-- Admin command to test evolution crafting
QBCore.Commands.Add('testevocraft', 'Test evolution crafting (admin)', {
  {name='playerid', help='player id'}, 
  {name='recipe', help='recipe key (recipe_evo_weed_lvl1, recipe_evo_cocaine_lvl1, recipe_evo_meth_lvl1)'}
}, true, function(source, args)
  local playerId = tonumber(args[1])
  local recipeKey = args[2]
  
  if not playerId or not recipeKey then
    TriggerClientEvent('QBCore:Notify', source, 'Usage: /testevocraft [playerid] [recipe_key]', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  -- Trigger the crafting event for the target player
  TriggerClientEvent('bldr-drugs:triggerCraft', playerId, recipeKey)
  TriggerClientEvent('QBCore:Notify', source, string.format('Triggered crafting: %s for player %s (items will now have purity metadata)', recipeKey, Player.PlayerData.charinfo.firstname), 'success')
end, 'admin')

-- Debug command to check what's actually unlocked in database
QBCore.Commands.Add('debugunlocks', 'Debug evolution unlocks (admin)', {
  {name='playerid', help='player id'}
}, true, function(source, args)
  local playerId = tonumber(args[1]) or source
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  -- Check all possible unlock keys
  local unlockKeys = {'recipe_evo_weed_lvl1', 'recipe_evo_cocaine_lvl1', 'recipe_evo_meth_lvl1', 'evo_weed_lvl1', 'evo_cocaine_lvl1', 'evo_meth_lvl1'}
  
  for _, key in ipairs(unlockKeys) do
    exports.oxmysql:single('SELECT unlocked FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenId, key }, function(row)
      -- Use the same logic as evoIsUnlocked function
      local unlocked = row and (row.unlocked == 1 or row.unlocked == true)
      print(string.format('[DEBUG] Player %s (%s) - Key: %s - Unlocked: %s - Raw value: %s', Player.PlayerData.charinfo.firstname, citizenId, key, tostring(unlocked), tostring(row and row.unlocked)))
      TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = false,
        args = {"[DEBUG]", string.format('%s: %s', key, unlocked and 'UNLOCKED' or 'LOCKED')}
      })
    end)
  end
end, 'admin')

-- Test the exact same syntax as evoSetUnlocked
QBCore.Commands.Add('testexactsyntax', 'Test exact evoSetUnlocked syntax (admin)', {}, true, function(source, args)
  local testCitizenId = "SYNTAX_TEST_" .. os.time()
  local testKey = "test_recipe_key"
  
  print("[DEBUG testexactsyntax] Testing exact syntax with citizenid:", testCitizenId)
  TriggerClientEvent('chat:addMessage', source, {
    color = {255, 255, 0},
    args = {"[SYNTAXTEST]", "Testing exact evoSetUnlocked syntax..."}
  })
  
  -- Use the EXACT same query as evoSetUnlocked
  exports.oxmysql:insert([[
    INSERT INTO drug_evolution_unlocks (citizenid, key_name, unlocked, meta)
    VALUES (?, ?, 1, NULL)
    ON DUPLICATE KEY UPDATE unlocked = 1
  ]], { testCitizenId, testKey }, function(result, error)
    if error then
      print("[DEBUG testexactsyntax] ERROR:", error)
      TriggerClientEvent('chat:addMessage', source, {
        color = {255, 0, 0},
        args = {"[SYNTAXTEST]", "ERROR: " .. tostring(error)}
      })
    else
      print("[DEBUG testexactsyntax] SUCCESS - insertId:", result and result.insertId, "affectedRows:", result and result.affectedRows)
      TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 0},
        args = {"[SYNTAXTEST]", "SUCCESS! insertId: " .. tostring(result and result.insertId)}
      })
    end
  end)
end, 'admin')

-- Simple database test
QBCore.Commands.Add('simpledbtest', 'Simple database test (admin)', {}, true, function(source, args)
  print("[DEBUG simpledbtest] Starting simple database test...")
  TriggerClientEvent('chat:addMessage', source, {
    color = {255, 255, 0},
    args = {"[SIMPLEDBTEST]", "Starting test..."}
  })
  
  -- Test 1: Simple SELECT from existing table
  exports.oxmysql:query('SELECT COUNT(*) as count FROM bldr_drugs LIMIT 1', {}, function(rows)
    print("[DEBUG simpledbtest] Test 1 - bldr_drugs count:", rows and rows[1] and rows[1].count or "ERROR")
    TriggerClientEvent('chat:addMessage', source, {
      color = {0, 255, 255},
      args = {"[SIMPLEDBTEST]", "Test 1 passed - bldr_drugs accessible"}
    })
    
    -- Test 2: Check evolution unlocks table structure
    exports.oxmysql:query('DESCRIBE drug_evolution_unlocks', {}, function(rows2)
      print("[DEBUG simpledbtest] Test 2 - table structure rows:", rows2 and #rows2 or "ERROR")
      TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 255},
        args = {"[SIMPLEDBTEST]", "Test 2 passed - table structure OK"}
      })
      
      -- Test 3: Simple insert without ON DUPLICATE KEY
      local testData = {
        citizenid = "DBTEST_" .. os.time(),
        key_name = "test_key_" .. os.time(),
        unlocked = 1
      }
      
      exports.oxmysql:insert('INSERT INTO drug_evolution_unlocks (citizenid, key_name, unlocked) VALUES (?, ?, ?)', 
        { testData.citizenid, testData.key_name, testData.unlocked }, function(result)
        print("[DEBUG simpledbtest] Test 3 - Insert result:", result and result.insertId or "ERROR")
        TriggerClientEvent('chat:addMessage', source, {
          color = {0, 255, 0},
          args = {"[SIMPLEDBTEST]", "Test 3 passed - Insert worked! ID: " .. (result and result.insertId or "unknown")}
        })
      end)
    end)
  end)
end, 'admin')

-- Test database connection and table
QBCore.Commands.Add('dbtest', 'Test database connection (admin)', {}, true, function(source, args)
  print("[DEBUG dbtest] Testing database connection...")
  
  -- First check if table exists
  exports.oxmysql:query('SHOW TABLES LIKE "drug_evolution_unlocks"', {}, function(rows, error)
    if error then
      print("[DEBUG dbtest] Error checking table existence:", error)
      TriggerClientEvent('chat:addMessage', source, {
        color = {255, 0, 0},
        args = {"[DBTEST]", "Error checking table: " .. tostring(error)}
      })
      return
    end
    
    print("[DEBUG dbtest] Table check result:", json.encode(rows))
    if #rows == 0 then
      print("[DEBUG dbtest] Table drug_evolution_unlocks does NOT exist!")
      TriggerClientEvent('chat:addMessage', source, {
        color = {255, 0, 0},
        args = {"[DBTEST]", "Table drug_evolution_unlocks does NOT exist!"}
      })
      return
    end
    
    TriggerClientEvent('chat:addMessage', source, {
      color = {0, 255, 0},
      args = {"[DBTEST]", "Table exists! Trying manual insert..."}
    })
    
    -- Try a simple manual insert
    local testCitizenId = "TEST123"
    local testKey = "test_key"
    
    exports.oxmysql:insert('INSERT INTO drug_evolution_unlocks (citizenid, key_name, unlocked) VALUES (?, ?, 1)', 
      { testCitizenId, testKey }, function(result, error)
      if error then
        print("[DEBUG dbtest] Manual insert error:", error)
        TriggerClientEvent('chat:addMessage', source, {
          color = {255, 0, 0},
          args = {"[DBTEST]", "Insert error: " .. tostring(error)}
        })
      else
        print("[DEBUG dbtest] Manual insert success:", json.encode(result))
        TriggerClientEvent('chat:addMessage', source, {
          color = {0, 255, 0},
          args = {"[DBTEST]", "Insert success! insertId: " .. tostring(result.insertId)}
        })
      end
    end)
  end)
end, 'admin')

-- Direct database check command
QBCore.Commands.Add('dbcheck', 'Check database directly (admin)', {
  {name='playerid', help='player id'}
}, true, function(source, args)
  local playerId = tonumber(args[1]) or source
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  -- Check if drug_evolution_unlocks table exists and what's in it
  exports.oxmysql:query('SELECT * FROM drug_evolution_unlocks WHERE citizenid = ?', { citizenId }, function(rows)
    print("[DEBUG dbcheck] Total rows for citizenid " .. citizenId .. ": " .. #rows)
    TriggerClientEvent('chat:addMessage', source, {
      color = {255, 0, 255},
      multiline = false,
      args = {"[DBCHECK]", "Total rows: " .. #rows}
    })
    
    for i, row in ipairs(rows) do
      print(string.format("[DEBUG dbcheck] Row %d: key=%s, unlocked=%s, meta=%s", i, row.key_name, tostring(row.unlocked), tostring(row.meta)))
      TriggerClientEvent('chat:addMessage', source, {
        color = {255, 0, 255},
        multiline = false,
        args = {"[DBCHECK]", string.format("Row %d: %s = %s", i, row.key_name, row.unlocked == 1 and "UNLOCKED" or "LOCKED")}
      })
    end
  end)
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


-- === BLDR-DRUGS Evolution (Progression) ===

local function evoNotify(src, msg, typ)
  typ = typ or 'success'
  local brand = (Config.Evolution and Config.Evolution.brand) and (Config.Evolution.brand .. ': ') or ''
  if Config.Evolution and Config.Evolution.notify == 'ox' and GetResourceState('ox_lib') == 'started' then
    -- Use ox_lib with enhanced styling for better visibility
    local notifyData = {
      title = brand:gsub(': $', ''), -- Remove trailing colon for title
      description = msg,
      type = typ,
      position = 'top-right',
      style = {
        backgroundColor = 'rgba(0, 0, 0, 0.9)',
        color = '#ffffff',
        border = '1px solid #00ff88'
      }
    }
    TriggerClientEvent('ox_lib:notify', src, notifyData)
  elseif Config.Evolution and Config.Evolution.notify == 'qb' then
    TriggerClientEvent('QBCore:Notify', src, brand .. msg, typ)
  else
    TriggerClientEvent('chat:addMessage', src, { args = {'System', brand .. msg} })
  end
end

local function evoEnsureRow(citizenid)
  exports.oxmysql:insert('INSERT IGNORE INTO drug_evolution_progress (citizenid, total_revenue) VALUES (?, 0)', { citizenid })
end

local function evoAddRevenue(citizenid, delta)
  evoEnsureRow(citizenid)
  exports.oxmysql:update('UPDATE drug_evolution_progress SET total_revenue = total_revenue + ? WHERE citizenid = ?', { delta, citizenid })
end

local function evoGetRevenue(citizenid, cb)
  exports.oxmysql:single('SELECT total_revenue FROM drug_evolution_progress WHERE citizenid = ?', { citizenid }, function(row)
    cb(row and (row.total_revenue or 0) or 0)
  end)
end

local function evoSetUnlocked(citizenid, key)
  exports.oxmysql:insert([[
    INSERT INTO drug_evolution_unlocks (citizenid, key_name, unlocked, meta)
    VALUES (?, ?, 1, NULL)
    ON DUPLICATE KEY UPDATE unlocked = 1
  ]], { citizenid, key })
end

local function evoIsUnlocked(citizenid, key, cb)
  exports.oxmysql:single('SELECT unlocked FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenid, key }, function(row)
    -- Handle both boolean true and integer 1
    local isUnlocked = row and (row.unlocked == 1 or row.unlocked == true)
    cb(isUnlocked)
  end)
end

local function evoAddCount(citizenid, item, delta)
  exports.oxmysql:single('SELECT meta FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenid, 'count_'..item }, function(row)
    local count = 0
    if row and row.meta then
      local ok, data = pcall(json.decode, row.meta)
      if ok and data and data.count then count = tonumber(data.count) or 0 end
    end
    count = count + (tonumber(delta) or 0)
    local meta = json.encode({ count = count })
    exports.oxmysql:insert([[
      INSERT INTO drug_evolution_unlocks (citizenid, key_name, unlocked, meta)
      VALUES (?, ?, 0, ?)
      ON DUPLICATE KEY UPDATE meta = VALUES(meta)
    ]], { citizenid, 'count_'..item, meta })
  end)
end

-- Try unlocks when progress changes
local function evoTryUnlocks(src, citizenid, lastSale)
  if not (Config.Evolution and Config.Evolution.enabled) then return end
  print("[DEBUG evoTryUnlocks] Starting for citizenid:", citizenid, "item:", lastSale and lastSale.item, "amount:", lastSale and lastSale.amount)
  
  evoGetRevenue(citizenid, function(totalRevenue)
    print("[DEBUG evoTryUnlocks] Total revenue:", totalRevenue)
    local newly = 0
    local nearUnlocks = {}
    local notifySettings = Config.Evolution.notifications or {}
    print("[DEBUG evoTryUnlocks] Notifications enabled:", notifySettings.enabled)
    
    for _, th in ipairs(Config.Evolution.thresholds or {}) do
      print("[DEBUG evoTryUnlocks] Checking threshold:", th.key, "by:", th.by, "item:", th.item, "amount:", th.amount)
      exports.oxmysql:single('SELECT unlocked FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenid, th.key }, function(row)
        local already = row and (row.unlocked == 1 or row.unlocked == true)
        print("[DEBUG evoTryUnlocks] Threshold", th.key, "already unlocked:", already)
        if not already then
          local met = false
          local progress = 0
          
          if th.by == 'revenue' then
            met = totalRevenue >= (th.amount or 0)
            progress = (totalRevenue / (th.amount or 1)) * 100
            
            -- Check for progress notifications based on config
            if not met and notifySettings.enabled then
              local milestones = notifySettings.milestones or {75, 90, 95}
              local nearThreshold = notifySettings.nearUnlockThreshold or 95
              
              if progress >= nearThreshold then
                table.insert(nearUnlocks, {
                  key = th.key,
                  progress = progress,
                  remaining = (th.amount or 0) - totalRevenue,
                  type = 'revenue'
                })
              else
                -- Check other milestones
                for _, milestone in ipairs(milestones) do
                  if milestone < nearThreshold and progress >= milestone and progress < milestone + 5 then
                    local remaining = (th.amount or 0) - totalRevenue
                    evoNotify(src, string.format('Evolution Progress: %s is %d%% complete! $%d more revenue needed.', th.key, milestone, remaining), 'primary')
                    break
                  end
                end
              end
            end
            
          elseif th.by == 'count' and th.item then
            print("[DEBUG evoTryUnlocks] Count-based check for", th.item)
            exports.oxmysql:single('SELECT meta FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenid, 'count_'..th.item }, function(r2)
              local cnt = 0
              if r2 and r2.meta then
                local ok, data = pcall(json.decode, r2.meta)
                if ok and data and data.count then cnt = tonumber(data.count) or 0 end
              end
              print("[DEBUG evoTryUnlocks] Current", th.item, "count:", cnt, "required:", th.amount)
              
              progress = (cnt / (th.amount or 1)) * 100
              print("[DEBUG evoTryUnlocks] Progress:", progress .. "%")
              
              if cnt >= (th.amount or 0) then
                print("[DEBUG evoTryUnlocks] UNLOCKING", th.key)
                -- unlock
                evoSetUnlocked(citizenid, th.key)
                for _, rkey in ipairs(th.unlocks or {}) do evoSetUnlocked(citizenid, rkey) end
                newly = newly + 1
                evoNotify(src, string.format('🎉 Evolution unlocked! You can now craft %s!', th.key), 'success')
              else
                -- Check for progress notifications based on config
                if notifySettings.enabled then
                  print("[DEBUG evoTryUnlocks] Checking notifications for progress:", progress)
                  local milestones = notifySettings.milestones or {75, 90, 95}
                  local nearThreshold = notifySettings.nearUnlockThreshold or 95
                  
                  if progress >= nearThreshold then
                    local remaining = (th.amount or 0) - cnt
                    table.insert(nearUnlocks, {
                      key = th.key,
                      progress = progress,
                      remaining = remaining,
                      type = 'count',
                      item = th.item
                    })
                  else
                    -- Check other milestones
                    for _, milestone in ipairs(milestones) do
                      if milestone <= progress and progress < milestone + 10 then  -- Wider range for testing
                        local remaining = (th.amount or 0) - cnt
                        print("[DEBUG evoTryUnlocks] Sending milestone notification:", milestone, "% for", th.key)
                        evoNotify(src, string.format('🔥 Evolution Progress: %s is %d%% complete! %d more %s sales needed.', th.key, math.floor(progress), remaining, th.item), 'info')
                        break
                      end
                    end
                  end
                end
              end
            end)
            return -- async path returns here
          end
          
          if met then
            evoSetUnlocked(citizenid, th.key)
            for _, rkey in ipairs(th.unlocks or {}) do evoSetUnlocked(citizenid, rkey) end
            newly = newly + 1
          end
        end
      end)
    end
    
    -- Handle near-unlock notifications for revenue-based unlocks
    if notifySettings.enabled then
      for _, unlock in ipairs(nearUnlocks) do
        if unlock.type == 'revenue' then
          evoNotify(src, string.format('🔥 ALMOST THERE! %s is %.1f%% complete! Only $%d more revenue needed!', unlock.key, unlock.progress, unlock.remaining), 'warning')
        elseif unlock.type == 'count' then
          evoNotify(src, string.format('🔥 ALMOST THERE! %s is %.1f%% complete! Only %d more %s sales needed!', unlock.key, unlock.progress, unlock.remaining, unlock.item), 'warning')
        end
      end
    end
    
    if newly > 0 then
      local commandText = (Config.Evolution.notifications and Config.Evolution.notifications.showProgressCommand) and ' Check progress with /checkevolution' or ''
      evoNotify(src, ('🎉 Unlocked %d evolution tier(s)! New recipes available!%s'):format(newly, commandText), 'success')
      for _, grant in ipairs((Config.Evolution.autoGrantItems or {})) do
        local count = grant.count or 1
        if GetResourceState('ox_inventory') == 'started' then
          exports.ox_inventory:AddItem(src, grant.item, count)
        else
          local Player = QBCore.Functions.GetPlayer(src)
          if Player then Player.Functions.AddItem(grant.item, count) end
        end
      end
    end
  end)
end

-- Public: record a sale into evolution
function BLDR_Evolution.RecordSale(src, citizenid, itemSold, amountSold, grossRevenue)
  if not (Config.Evolution and Config.Evolution.enabled) then return end
  if not citizenid then
    local Player = QBCore.Functions.GetPlayer(src)
    citizenid = Player and Player.PlayerData.citizenid
  end
  if not citizenid then return end
  evoAddRevenue(citizenid, tonumber(grossRevenue or 0))
  if itemSold and amountSold then evoAddCount(citizenid, itemSold, tonumber(amountSold or 0)) end
  evoTryUnlocks(src, citizenid, { item=itemSold, amount=amountSold, revenue=grossRevenue })
end

-- Check if a recipe is unlocked (sync via callback)
QBCore.Functions.CreateCallback('bldr-drugs:isUnlocked', function(src, cb, recipe_key)
  local Player = QBCore.Functions.GetPlayer(src); if not Player then cb(false) return end
  evoIsUnlocked(Player.PlayerData.citizenid, recipe_key, cb)
end)

-- Get available recipes for crafting menu
QBCore.Functions.CreateCallback('bldr-drugs:getAvailableRecipes', function(src, cb)
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then cb({}) return end
  if not (Config.Evolution and Config.Evolution.enabled) then cb({}) return end
  
  local citizenId = Player.PlayerData.citizenid
  local availableRecipes = {}
  local recipeCount = 0
  local totalRecipes = 0
  
  -- Count total recipes
  for _, _ in pairs(Config.Evolution.recipes or {}) do
    totalRecipes = totalRecipes + 1
  end
  
  if totalRecipes == 0 then
    cb({})
    return
  end
  
  -- Check each recipe
  for recipeKey, recipe in pairs(Config.Evolution.recipes or {}) do
    evoIsUnlocked(citizenId, recipe.unlock_key, function(unlocked)
      recipeCount = recipeCount + 1
      
      if unlocked then
        table.insert(availableRecipes, {
          key = recipeKey,
          label = recipe.label,
          requires = recipe.requires,
          result = recipe.result,
          time_ms = recipe.time_ms
        })
      end
      
      -- Return results when all recipes have been checked
      if recipeCount >= totalRecipes then
        cb(availableRecipes)
      end
    end)
  end
end)

-- Craft evolution recipes
RegisterNetEvent('bldr-drugs:craftEvolution', function(recipe_key)
  local src = source
  if not (Config.Evolution and Config.Evolution.enabled) then return end
  local rec = Config.Evolution.recipes and Config.Evolution.recipes[recipe_key]
  if not rec then return end
  local Player = QBCore.Functions.GetPlayer(src); if not Player then return end
  evoIsUnlocked(Player.PlayerData.citizenid, rec.unlock_key, function(ok)
    if not ok then evoNotify(src, 'You have not unlocked this recipe yet.', 'error'); return end

    -- Inventory wrappers
    local function hasItem(item, count)
      if GetResourceState('ox_inventory') == 'started' then
        return (exports.ox_inventory:Search(src, 'count', item) or 0) >= count
      else
        local it = Player.Functions.GetItemByName(item)
        return it and (it.amount or 0) >= count
      end
    end
    local function removeItem(item, count)
      if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:RemoveItem(src, item, count)
      else
        return Player.Functions.RemoveItem(item, count)
      end
    end
    local function addItem(item, count, info)
      if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:AddItem(src, item, count, info)
      else
        return Player.Functions.AddItem(item, count, nil, info)
      end
    end

    -- Requirements
    for _, req in ipairs(rec.requires or {}) do
      if not hasItem(req.item, req.count or 1) then
        evoNotify(src, ('Missing %sx %s'):format(req.count or 1, req.item), 'error'); return
      end
    end
    for _, req in ipairs(rec.requires or {}) do removeItem(req.item, req.count or 1) end
    
    -- Generate purity for the evolved drug
    local itemConfig = Config.Items[rec.result.item]
    local purity = generatePurity(rec.result.item, nil)
    local purityLevel, purityData = getPurityLevel(purity)
    
    -- Create item info with purity metadata (minimal for clean display)
    local itemInfo = {
      _purity = purity, -- Hidden field for gameplay mechanics (underscore prefix)
      description = (itemConfig and itemConfig.description or "") .. " | " .. purityData.label
    }
    
    addItem(rec.result.item, rec.result.count or 1, itemInfo)
    evoNotify(src, ('Crafted %s with %s quality!'):format(rec.label or recipe_key, purityData.label), 'success')
  end)
end)

-- New command to check evolution progress and unlock status
QBCore.Commands.Add('checkevolution', 'Check evolution progress towards unlocking evolved drugs', {{name='id', help='player id (optional)'}}, false, function(source, args)
  local target = tonumber(args[1]) or source
  local Player = QBCore.Functions.GetPlayer(target)
  if not Player then 
    evoNotify(source, 'Player not found', 'error')
    return 
  end
  
  local cid = Player.PlayerData.citizenid
  local isAdmin = QBCore.Functions.HasPermission(source, 'admin')
  
  -- Only allow checking own stats unless admin
  if target ~= source and not isAdmin then
    evoNotify(source, 'You can only check your own evolution progress', 'error')
    return
  end
  
  if not (Config.Evolution and Config.Evolution.enabled) then
    evoNotify(source, 'Evolution system is disabled', 'error')
    return
  end
  
  -- Check if command is available to non-admins
  local allowCommand = (Config.Evolution.notifications and Config.Evolution.notifications.showProgressCommand) or isAdmin
  if not allowCommand then
    evoNotify(source, 'Evolution progress command is disabled', 'error')
    return
  end
  
  evoGetRevenue(cid, function(totalRevenue)
    -- Show header notification
    evoNotify(source, string.format('💰 Evolution Progress - Total Revenue: $%d', totalRevenue), 'primary')
    
    local hasUnlocks = false
    local unlockCount = 0
    local totalUnlocks = #(Config.Evolution.thresholds or {})
    
    for _, th in ipairs(Config.Evolution.thresholds or {}) do
      exports.oxmysql:single('SELECT unlocked FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { cid, th.key }, function(row)
        local isUnlocked = row and row.unlocked == 1
        unlockCount = unlockCount + 1
        
        if th.by == 'revenue' then
          local progress = math.min(100, (totalRevenue / (th.amount or 1)) * 100)
          if isUnlocked then
            evoNotify(source, string.format('✅ %s: UNLOCKED', th.key), 'success')
          else
            local remaining = (th.amount or 0) - totalRevenue
            evoNotify(source, string.format('⏳ %s: %.1f%% ($%d needed)', th.key, progress, remaining), 'primary')
          end
          hasUnlocks = true
          
        elseif th.by == 'count' and th.item then
          exports.oxmysql:single('SELECT meta FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { cid, 'count_'..th.item }, function(r2)
            local cnt = 0
            if r2 and r2.meta then
              local ok, data = pcall(json.decode, r2.meta)
              if ok and data and data.count then cnt = tonumber(data.count) or 0 end
            end
            
            local progress = math.min(100, (cnt / (th.amount or 1)) * 100)
            if isUnlocked then
              evoNotify(source, string.format('✅ %s: UNLOCKED', th.key), 'success')
            else
              local remaining = (th.amount or 0) - cnt
              evoNotify(source, string.format('⏳ %s: %.1f%% (%d %s needed)', th.key, progress, remaining, th.item), 'primary')
            end
          end)
          hasUnlocks = true
        end
        
        -- Show summary notification when all unlocks have been processed
        if unlockCount >= totalUnlocks then
          if not hasUnlocks then
            evoNotify(source, 'No evolution thresholds configured', 'error')
          else
            evoNotify(source, '📋 Evolution progress check complete!', 'success')
          end
        end
      end)
    end
    
    -- Handle case where no thresholds exist
    if totalUnlocks == 0 then
      evoNotify(source, 'No evolution thresholds configured', 'error')
    end
  end)
end)

-- Clear evolution data for testing
QBCore.Commands.Add('clearevodata', 'Clear evolution data for testing (admin)', {
  {name='playerid', help='player id'}, 
  {name='item', help='item to clear (weed/cocaine/meth) or "all"'}
}, true, function(source, args)
  local playerId = tonumber(args[1]) or source
  local itemToClear = args[2] or 'all'
  
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  if itemToClear == 'all' then
    -- Clear all evolution data
    exports.oxmysql:execute('DELETE FROM drug_evolution_progress WHERE citizenid = ?', { citizenId })
    exports.oxmysql:execute('DELETE FROM drug_evolution_unlocks WHERE citizenid = ?', { citizenId })
    TriggerClientEvent('QBCore:Notify', source, string.format('Cleared ALL evolution data for %s', Player.PlayerData.charinfo.firstname), 'success')
  else
    -- Clear specific item data
    local keysToDelete = {}
    if itemToClear == 'meth' then
      keysToDelete = {'count_meth', 'evo_meth_lvl1', 'recipe_evo_meth_lvl1'}
    elseif itemToClear == 'weed' then
      keysToDelete = {'count_weed', 'evo_weed_lvl1', 'recipe_evo_weed_lvl1'}
    elseif itemToClear == 'cocaine' then
      keysToDelete = {'count_cocaine', 'evo_cocaine_lvl1', 'recipe_evo_cocaine_lvl1'}
    else
      TriggerClientEvent('QBCore:Notify', source, 'Invalid item. Use: weed, cocaine, meth, or all', 'error')
      return
    end
    
    -- Delete specific unlock entries
    for _, key in ipairs(keysToDelete) do
      exports.oxmysql:execute('DELETE FROM drug_evolution_unlocks WHERE citizenid = ? AND key_name = ?', { citizenId, key })
    end
    
    TriggerClientEvent('QBCore:Notify', source, string.format('Cleared %s evolution data for %s', itemToClear, Player.PlayerData.charinfo.firstname), 'success')
  end
end, 'admin')

-- Manual unlock command for testing (placed after evolution functions are defined)
QBCore.Commands.Add('forceunlock', 'Force unlock evolution recipe (admin)', {
  {name='playerid', help='player id'}, 
  {name='recipe_key', help='recipe key to unlock'}
}, true, function(source, args)
  local playerId = tonumber(args[1])
  local recipeKey = args[2]
  
  if not playerId or not recipeKey then
    TriggerClientEvent('QBCore:Notify', source, 'Usage: /forceunlock [playerid] [recipe_key]', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(playerId)
  if not Player then
    TriggerClientEvent('QBCore:Notify', source, 'Player not found', 'error')
    return
  end
  
  local citizenId = Player.PlayerData.citizenid
  
  -- Force unlock the recipe
  evoSetUnlocked(citizenId, recipeKey)
  
  TriggerClientEvent('QBCore:Notify', source, string.format('Force unlocked %s for %s', recipeKey, Player.PlayerData.charinfo.firstname), 'success')
  TriggerClientEvent('QBCore:Notify', playerId, string.format('Recipe unlocked: %s', recipeKey), 'success')
end, 'admin')
