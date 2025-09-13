local QBCore = exports['qb-core']:GetCoreObject()
local MySQL = exports['oxmysql']

local playerXP = {} -- in-memory cache: citizenid -> xp
local tokenStore = {} -- token -> {source, expires}
local sellHistory = {} -- source -> {timestamps...} used for rate limiting

local function logDebug(...)
  if Config.Debug then
    print('[bldr-drugs][DEBUG]', ...)
  end
end

-- DB helpers
local function ensureTables()
  local xpTable = Config.DB.XPTable
  local logsTable = Config.DB.LogsTable

  local createXP = ([[
    CREATE TABLE IF NOT EXISTS %s (
      citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
      xp INT NOT NULL DEFAULT 0
    );
  ]]):format(xpTable)

  local createLogs = ([[
    CREATE TABLE IF NOT EXISTS %s (
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
  ]]):format(logsTable)

  MySQL.execute(createXP, {}, function(affected)
    logDebug('ensureTables XP result', affected)
  end)

  MySQL.execute(createLogs, {}, function(affected)
    logDebug('ensureTables Logs result', affected)
  end)
end

-- Load XP for player
local function loadPlayerXP(citizenid, cb)
  MySQL.query('SELECT xp FROM '..Config.DB.XPTable..' WHERE citizenid = ?', {citizenid}, function(result)
    if result and result[1] then
      playerXP[citizenid] = tonumber(result[1].xp) or 0
      logDebug('Loaded XP for', citizenid, playerXP[citizenid])
      if cb then cb(playerXP[citizenid]) end
    else
      -- insert default
      MySQL.execute('INSERT INTO '..Config.DB.XPTable..' (citizenid, xp) VALUES (?, ?)', {citizenid, 0}, function()
        playerXP[citizenid] = 0
        if cb then cb(0) end
      end)
    end
  end)
end

-- Save player XP
local function savePlayerXP(citizenid)
  local xp = playerXP[citizenid] or 0
  MySQL.execute('UPDATE '..Config.DB.XPTable..' SET xp = ? WHERE citizenid = ?', {xp, citizenid}, function(affected)
    logDebug('Saved XP for', citizenid, xp)
  end)
end

-- Log sale
local function logSale(data)
  if not Config.EnableLogging then return end
  MySQL.execute('INSERT INTO '..Config.DB.LogsTable..' (citizenid, item, amount, price, xpEarned, success, reason, x, y, z, nearbyCops) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    {data.citizenid, data.item, data.amount, data.price, data.xpEarned, data.success and 1 or 0, data.reason or '', data.x, data.y, data.z, data.nearbyCops or 0}, function(affected)
      logDebug('Logged sale for', data.citizenid)
    end)
end

-- XP helpers
local function addXP(citizenid, amount)
  playerXP[citizenid] = (playerXP[citizenid] or 0) + amount
  savePlayerXP(citizenid)
end

local function getXP(citizenid)
  return playerXP[citizenid] or 0
end

-- Rate limiting
local function canRequestToken(source)
  local now = os.time()
  sellHistory[source] = sellHistory[source] or {lastTokenRequest = 0, sells = {}}
  if now - sellHistory[source].lastTokenRequest < (Config.MinTokenRequestInterval / 1000) then
    return false, 'token_cooldown'
  end
  sellHistory[source].lastTokenRequest = now
  return true
end

local function canSell(source)
  -- check cooldown and max sells per minute
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
    return false, 'rate_limit'
  end
  -- check last sell cooldown
  if data.lastSell and (now - data.lastSell) < Config.SellCooldownSeconds then
    return false, 'cooldown'
  end
  return true
end

local function registerSell(source)
  sellHistory[source] = sellHistory[source] or {sells = {}}
  table.insert(sellHistory[source].sells, os.time())
  sellHistory[source].lastSell = os.time()
end

-- Token management
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

-- Server callbacks / events

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
end)

-- Server-side sell completion endpoint
QBCore.Functions.CreateCallback(Config.ResourceName..':completeSale', function(source, cb, data)
  -- data: {token, item, amount, coords}
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then cb(false, 'no_player') return end

  -- token validation
  local valid, reason = validateAndConsumeToken(data.token, src)
  if not valid then cb(false, reason) return end

  -- rate limiting
  local can, r = canSell(src)
  if not can then cb(false, r) return end

  -- verify amount and item
  local itemName = tostring(data.item)
  local amount = tonumber(data.amount) or 0
  if amount <= 0 then cb(false, 'invalid_amount') return end

  if not Player.Functions.GetItemByName(itemName) then cb(false, 'no_item') return end
  local itemObj = Player.Functions.GetItemByName(itemName)
  if itemObj.amount < amount then cb(false, 'not_enough') return end

  -- check nearby cops via client callback
  local copsNearby = 0
  local coords = data.coords or {}
  local finished = false
  QBCore.Functions.TriggerCallback(Config.ResourceName..':countNearbyCops', function(count)
    copsNearby = tonumber(count) or 0
    finished = true
  end, coords)

  local waitStart = GetGameTimer()
  while not finished do
    Wait(10)
    if GetGameTimer() - waitStart > 2000 then -- 2s timeout
      finished = true
      copsNearby = 0
      break
    end
  end

  -- compute success chance
  local baseChance = 0.95
  local policePenalty = math.min(copsNearby * 0.08, 0.6)
  local successChance = baseChance - policePenalty

  -- XP multiplier
  local cid = Player.PlayerData.citizenid
  local xp = getXP(cid)
  local multiplier = 1.0
  for i = #Config.Levels, 1, -1 do
    if xp >= Config.Levels[i].xp then multiplier = Config.Levels[i].multiplier break end
  end

  local pricePer = 100 -- placeholder per-item price, replace or expand in config if needed
  local totalPrice = math.floor(pricePer * amount * multiplier)

  -- success roll
  local rand = math.random()
  local success = rand <= successChance
  local reasonFail = nil
  if success then
    -- remove items and give money
    local removed = Player.Functions.RemoveItem(itemName, amount, nil, true)
    if not removed then
      success = false
      reasonFail = 'remove_failed'
    else
      Player.Functions.AddMoney('cash', totalPrice)
      local xpGain = math.floor(5 * amount)
      addXP(cid, xpGain)
      registerSell(src)
    end
  else
    reasonFail = 'deal_failed'
  end

  -- log
  logSale({
    citizenid = cid,
    item = itemName,
    amount = amount,
    price = totalPrice,
    xpEarned = success and math.floor(5 * amount) or 0,
    success = success,
    reason = reasonFail,
    x = coords.x or 0,
    y = coords.y or 0,
    z = coords.z or 0,
    nearbyCops = copsNearby
  })

  cb(success, {price = totalPrice, xp = getXP(cid), reason = reasonFail})
end)

-- Count nearby cops callback (server asks client to perform counting)
QBCore.Functions.CreateCallback(Config.ResourceName..':countNearbyCops', function(source, cb, coords)
  -- We'll request the player's client to count cops nearby using their local player list
  -- Fallback: server side job count (less accurate)
  local src = source
  -- Ask client
  TriggerClientEvent(Config.ResourceName..':countCopsRequest', src, coords, Config.PoliceRadius)

  -- Wait for client response via event
  local responded = false
  local count = 0
  local timeout = 3000
  local start = GetGameTimer()

  local function onResponse(playerSrc, amount)
    if playerSrc ~= src then return end
    count = tonumber(amount) or 0
    responded = true
  end

  RegisterNetEvent(Config.ResourceName..':countCopsResponse_'..src, function(amount)
    onResponse(src, amount)
  end)

  -- Wait loop
  while not responded and (GetGameTimer() - start) < timeout do
    Wait(10)
  end

  cb(count)
end)

-- Player join/leave handling
AddEventHandler('playerDropped', function(reason)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if Player then
    savePlayerXP(Player.PlayerData.citizenid)
  end
  sellHistory[src] = nil
end)

AddEventHandler('onResourceStop', function(name)
  if name ~= GetCurrentResourceName() then return end
  -- save all players
  for cid,xp in pairs(playerXP) do
    savePlayerXP(cid)
  end
end)

-- QBCore playerloaded
RegisterNetEvent('QBCore:PlayerLoaded')
AddEventHandler('QBCore:PlayerLoaded', function(playerId, xPlayer)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if Player then
    loadPlayerXP(Player.PlayerData.citizenid)
  end
end)

-- Admin command sample
QBCore.Commands.Add('adddrugxp', 'Add drug XP to player (admin)', {{name='id', help='player id'},{name='xp', help='xp to add'}}, true, function(source, args)
  local target = tonumber(args[1])
  local xp = tonumber(args[2])
  if not target or not xp then return end
  local Player = QBCore.Functions.GetPlayer(target)
  if not Player then return end
  addXP(Player.PlayerData.citizenid, xp)
  TriggerClientEvent('QBCore:Notify', source, 'Added '..xp..' XP to '..Player.PlayerData.charinfo.firstname, 'success')
end)

-- Initialization
Citizen.CreateThread(function()
  ensureTables()
  math.randomseed(GetGameTimer())
  -- load existing players
  for _, playerId in pairs(GetPlayers()) do
    local ply = tonumber(playerId)
    local Player = QBCore.Functions.GetPlayer(ply)
    if Player then
      loadPlayerXP(Player.PlayerData.citizenid)
    end
  end

  -- autosave loop
  while true do
    Citizen.Wait(Config.AutosaveInterval)
    for cid,xp in pairs(playerXP) do
      savePlayerXP(cid)
    end
  end
end)

