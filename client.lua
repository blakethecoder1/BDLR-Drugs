local QBCore = exports['qb-core']:GetCoreObject()

-- State management
local currentToken = nil
local tokenExpiry = 0
local lastTokenRequest = 0
local activeNPCs = {}
local playerLevel = 0
local playerXP = 0
local nearbyNPC = nil
local isInteracting = false

-- Debug function
local function debugPrint(...)
  if Config.Debug.enabled and Config.Debug.printToConsole then
    print('[bldr-drugs][CLIENT]', ...)
  end
  if Config.Debug.enabled and Config.Debug.printToChat then
    local args = {...}
    local message = table.concat(args, ' ')
    TriggerEvent('chat:addMessage', {
      color = {255, 255, 0},
      multiline = true,
      args = {"[DEBUG]", message}
    })
  end
end

-- Helper functions
local function GetPlayerLevelInfo(xp)
  local level = 0
  local title = 'Street Rookie'
  local multiplier = 1.0
  local nextLevelXP = 0
  
  for i = #Config.Levels, 1, -1 do
    if xp >= Config.Levels[i].xp then
      level = Config.Levels[i].level
      title = Config.Levels[i].title
      multiplier = Config.Levels[i].multiplier
      if Config.Levels[i + 1] then
        nextLevelXP = Config.Levels[i + 1].xp
      else
        nextLevelXP = xp -- Max level
      end
      break
    end
  end
  
  return level, title, multiplier, nextLevelXP
end

local function GetAvailableItems()
  local availableItems = {}
  for itemName, itemConfig in pairs(Config.Items) do
    if playerLevel >= itemConfig.minLevel then
      table.insert(availableItems, {
        name = itemName,
        label = itemConfig.label,
        basePrice = itemConfig.basePrice,
        maxAmount = itemConfig.maxAmount,
        description = itemConfig.description
      })
    end
  end
  return availableItems
end

-- NPC Management
local function CreateDrugNPC(coords, model)
  local hash = GetHashKey(model)
  
  RequestModel(hash)
  while not HasModelLoaded(hash) do
    Wait(100)
  end
  
  local npc = CreatePed(4, hash, coords.x, coords.y, coords.z, math.random(0, 360), false, true)
  
  SetEntityCanBeDamaged(npc, false)
  SetPedCanRagdollFromPlayerImpact(npc, false)
  SetBlockingOfNonTemporaryEvents(npc, true)
  SetPedFleeAttributes(npc, 0, 0)
  SetPedCombatAttributes(npc, 17, 1)
  
  -- Give the NPC a random task
  local taskType = math.random(1, 3)
  if taskType == 1 then
    TaskWanderStandard(npc, 10.0, 10)
  elseif taskType == 2 then
    TaskStartScenarioInPlace(npc, "WORLD_HUMAN_SMOKING", 0, true)
  else
    TaskStartScenarioInPlace(npc, "WORLD_HUMAN_STAND_MOBILE", 0, true)
  end
  
  SetModelAsNoLongerNeeded(hash)
  
  debugPrint("Created NPC", model, "at", coords)
  
  return npc
end

local function SpawnNPCsAroundPlayer()
  if #activeNPCs >= Config.NPCs.maxActive then
    return
  end
  
  local playerCoords = GetEntityCoords(PlayerPedId())
  local spawnAttempts = 0
  local maxAttempts = 10
  
  while #activeNPCs < Config.NPCs.maxActive and spawnAttempts < maxAttempts do
    spawnAttempts = spawnAttempts + 1
    
    if math.random() < Config.NPCs.spawnChance then
      -- Generate random spawn position
      local angle = math.random() * 2 * math.pi
      local distance = math.random(Config.NPCs.spawnRadius * 0.5, Config.NPCs.spawnRadius)
      local spawnCoords = {
        x = playerCoords.x + math.cos(angle) * distance,
        y = playerCoords.y + math.sin(angle) * distance,
        z = playerCoords.z
      }
      
      -- Find ground Z coordinate
      local foundGround, groundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 50.0, false)
      if foundGround then
        spawnCoords.z = groundZ
        
        -- Check if spawn location is clear
        local _, isPositionClear = GetClosestVehicle(spawnCoords.x, spawnCoords.y, spawnCoords.z, 5.0, 0, 71)
        if isPositionClear == 0 then
          local model = Config.NPCs.models[math.random(1, #Config.NPCs.models)]
          local npc = CreateDrugNPC(spawnCoords, model)
          
          if npc and npc ~= 0 then
            local npcData = {
              entity = npc,
              spawnCoords = spawnCoords,
              spawnTime = GetGameTimer(),
              lifetime = math.random(Config.NPCs.lifetimeMin, Config.NPCs.lifetimeMax),
              isInteracting = false,
              model = model
            }
            
            table.insert(activeNPCs, npcData)
            debugPrint("Spawned NPC", #activeNPCs, "/", Config.NPCs.maxActive)
          end
        end
      end
    end
  end
end

local function CleanupNPCs()
  local playerCoords = GetEntityCoords(PlayerPedId())
  local currentTime = GetGameTimer()
  
  for i = #activeNPCs, 1, -1 do
    local npcData = activeNPCs[i]
    local npcCoords = GetEntityCoords(npcData.entity)
    local distance = #(playerCoords - npcCoords)
    local age = currentTime - npcData.spawnTime
    
    -- Remove if too far, too old, or dead
    if distance > Config.NPCs.despawnRadius or age > npcData.lifetime or not DoesEntityExist(npcData.entity) then
      if DoesEntityExist(npcData.entity) then
        DeleteEntity(npcData.entity)
      end
      table.remove(activeNPCs, i)
      debugPrint("Removed NPC", i, "- Distance:", math.floor(distance), "Age:", math.floor(age/1000), "s")
    end
  end
end

local function FindNearestNPC()
  local playerCoords = GetEntityCoords(PlayerPedId())
  local closestNPC = nil
  local closestDistance = Config.NPCs.approachDistance
  
  for _, npcData in pairs(activeNPCs) do
    if DoesEntityExist(npcData.entity) and not npcData.isInteracting then
      local npcCoords = GetEntityCoords(npcData.entity)
      local distance = #(playerCoords - npcCoords)
      
      if distance < closestDistance then
        closestDistance = distance
        closestNPC = npcData
      end
    end
  end
  
  return closestNPC, closestDistance
end

-- NUI Callbacks
RegisterNUICallback('requestSell', function(data, cb)
  if not currentToken then 
    cb({ success = false, reason = 'no_token' }) 
    return 
  end
  
  if not nearbyNPC then
    cb({ success = false, reason = 'no_buyer' })
    return
  end
  
  local playerCoords = GetEntityCoords(PlayerPedId())
  local payload = { 
    token = currentToken, 
    item = data.item, 
    amount = tonumber(data.amount) or 0, 
    coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z}
  }
  
  -- Mark NPC as interacting
  nearbyNPC.isInteracting = true
  isInteracting = true
  
  -- Make NPC look at player
  TaskTurnPedToFaceEntity(nearbyNPC.entity, PlayerPedId(), Config.NPCs.interactionTime)
  
  QBCore.Functions.TriggerCallback(Config.ResourceName..':completeSale', function(success, resp)
    cb({ success = success, resp = resp })
    if success then
      currentToken = nil
      QBCore.Functions.Notify('Deal completed successfully!', 'success')
    else
      QBCore.Functions.Notify('Deal failed: ' .. (resp.reason or 'unknown'), 'error')
    end
    
    -- Reset interaction state
    isInteracting = false
    if nearbyNPC then
      nearbyNPC.isInteracting = false
    end
  end, payload)
end)

RegisterNUICallback('close', function(data, cb)
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  cb('ok')
end)

RegisterNUICallback('getAvailableItems', function(data, cb)
  cb({ items = GetAvailableItems() })
end)

-- Server Events
RegisterNetEvent(Config.ResourceName..':tokenResponse')
AddEventHandler(Config.ResourceName..':tokenResponse', function(ok, tokenOrReason, expiry)
  if not ok then
    QBCore.Functions.Notify('Failed to get trade token: '..tostring(tokenOrReason), 'error')
    return
  end
  currentToken = tokenOrReason
  tokenExpiry = GetGameTimer() + (expiry or Config.TokenExpiry)
  QBCore.Functions.Notify('Trade session ready - Find a buyer!', 'success')
end)

RegisterNetEvent(Config.ResourceName..':updatePlayerStats')
AddEventHandler(Config.ResourceName..':updatePlayerStats', function(xp)
  playerXP = xp
  playerLevel, playerTitle, playerMultiplier, nextLevelXP = GetPlayerLevelInfo(xp)
  
  if Config.Debug.enabled and Config.Debug.showXP then
    debugPrint("XP Updated:", xp, "Level:", playerLevel, "Title:", playerTitle)
  end
end)

-- Helper functions
function RequestTradeToken()
  local now = GetGameTimer()
  if now - lastTokenRequest < Config.MinTokenRequestInterval then
    QBCore.Functions.Notify('Please wait before requesting another session', 'error')
    return
  end
  lastTokenRequest = now
  TriggerServerEvent(Config.ResourceName..':requestToken')
end

-- Commands for testing
RegisterCommand('bldr_request_token', function()
  RequestTradeToken()
end)

RegisterCommand('bldr_debug_npcs', function()
  if Config.Debug.enabled then
    print("=== Active NPCs ===")
    for i, npcData in pairs(activeNPCs) do
      local coords = GetEntityCoords(npcData.entity)
      print(i, npcData.model, coords, "Interacting:", npcData.isInteracting)
    end
  end
end)

-- Main interaction thread
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    
    if not isInteracting then
      local foundNPC, distance = FindNearestNPC()
      nearbyNPC = foundNPC
      
      if nearbyNPC then
        if Config.Debug.enabled and Config.Debug.drawMarkers then
          local npcCoords = GetEntityCoords(nearbyNPC.entity)
          DrawMarker(1, npcCoords.x, npcCoords.y, npcCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 255, 0, 100, false, true, 2, nil, nil, false)
        end
        
        -- Show interaction prompt
        local npcCoords = GetEntityCoords(nearbyNPC.entity)
        DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.2, '[E] Approach Buyer')
        
        if IsControlJustReleased(0, 38) then -- E key
          if currentToken then
            SetNuiFocus(true, true)
            SendNUIMessage({ 
              action = 'open', 
              playerLevel = playerLevel,
              playerTitle = playerTitle or 'Street Rookie',
              playerXP = playerXP,
              nextLevelXP = nextLevelXP or 0
            })
          else
            RequestTradeToken()
          end
        end
      end
    end
  end
end)

-- NPC management thread
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(Config.NPCs.checkInterval)
    SpawnNPCsAroundPlayer()
    CleanupNPCs()
  end
end)

-- Token expiry thread
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    if currentToken and GetGameTimer() > tokenExpiry then
      currentToken = nil
      QBCore.Functions.Notify('Trade session expired', 'error')
    end
  end
end)

-- Helper: draw 3d text
function DrawText3D(x, y, z, text)
  SetTextScale(0.35, 0.35)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255, 255, 255, 215)
  SetTextEntry('STRING')
  SetTextCentre(true)
  AddTextComponentString(text)
  SetDrawOrigin(x, y, z, 0)
  DrawText(0.0, 0.0)
  ClearDrawOrigin()
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  
  for _, npcData in pairs(activeNPCs) do
    if DoesEntityExist(npcData.entity) then
      DeleteEntity(npcData.entity)
    end
  end
  
  activeNPCs = {}
  debugPrint("Cleaned up all NPCs on resource stop")
end)
