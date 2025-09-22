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
local thirdEyeTargets = {}

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

-- Zone checking function
local function IsInBlacklistedZone(coords)
  if not Config.ThirdEye.blacklistedZones then return false end
  
  for _, zone in pairs(Config.ThirdEye.blacklistedZones) do
    local distance = #(coords - zone.coords)
    if distance <= zone.radius then
      debugPrint("Player in blacklisted zone:", zone.name)
      return true, zone.name
    end
  end
  return false
end

-- Third-Eye Integration Functions
local function OpenDrugSelling(data)
  local playerCoords = GetEntityCoords(PlayerPedId())
  local isBlacklisted, zoneName = IsInBlacklistedZone(playerCoords)
  
  if isBlacklisted then
    QBCore.Functions.Notify('You cannot sell drugs in this area: ' .. zoneName, 'error')
    return
  end
  
  if currentToken then
    -- Already have a token, open UI directly
    SetNuiFocus(true, true)
    SendNUIMessage({ 
      action = 'open', 
      playerLevel = playerLevel,
      playerTitle = playerTitle or 'Street Rookie',
      playerXP = playerXP,
      nextLevelXP = nextLevelXP or 0
    })
  else
    -- Request token first
    RequestTradeToken()
    -- Small delay then open UI
    SetTimeout(1000, function()
      if currentToken then
        SetNuiFocus(true, true)
        SendNUIMessage({ 
          action = 'open', 
          playerLevel = playerLevel,
          playerTitle = playerTitle or 'Street Rookie',
          playerXP = playerXP,
          nextLevelXP = nextLevelXP or 0
        })
      end
    end)
  end
end

local function SetupThirdEyeTargets()
  if not Config.ThirdEye.enabled then return end
  
  local targetSystem = Config.ThirdEye.useQBTarget and 'qb-target' or 'ox_target'
  debugPrint("Setting up third-eye targets using", targetSystem)
  
  -- Target for peds (NPCs)
  if Config.ThirdEye.targets.peds then
    if Config.ThirdEye.useQBTarget then
      exports['qb-target']:AddGlobalPed({
        options = {
          {
            type = "client",
            event = "bldr-drugs:openSelling",
            icon = Config.ThirdEye.targetIcon,
            label = Config.ThirdEye.targetLabel,
            canInteract = function(entity)
              return not IsPedAPlayer(entity)
            end
          }
        },
        distance = Config.ThirdEye.targetDistance
      })
    end
  end
  
  -- Target for vehicles
  if Config.ThirdEye.targets.vehicles then
    if Config.ThirdEye.useQBTarget then
      exports['qb-target']:AddGlobalVehicle({
        options = {
          {
            type = "client",
            event = "bldr-drugs:openSelling",
            icon = Config.ThirdEye.targetIcon,
            label = Config.ThirdEye.targetLabel,
          }
        },
        distance = Config.ThirdEye.targetDistance
      })
    end
  end
  
  -- Target for specific object models
  if Config.ThirdEye.targets.objects and Config.ThirdEye.targetModels then
    if Config.ThirdEye.useQBTarget then
      exports['qb-target']:AddTargetModel(Config.ThirdEye.targetModels, {
        options = {
          {
            type = "client",
            event = "bldr-drugs:openSelling",
            icon = Config.ThirdEye.targetIcon,
            label = Config.ThirdEye.targetLabel,
          }
        },
        distance = Config.ThirdEye.targetDistance
      })
    end
  end
  
  -- Freeaim targeting (sell anywhere)
  if Config.ThirdEye.targets.freeaim then
    if Config.ThirdEye.useQBTarget then
      exports['qb-target']:AddGlobalPlayer({
        options = {
          {
            type = "client",
            event = "bldr-drugs:openSelling",
            icon = Config.ThirdEye.targetIcon,
            label = Config.ThirdEye.targetLabel .. " (Freeaim)",
            canInteract = function(entity)
              -- Only allow on self for freeaim selling
              return entity == PlayerPedId()
            end
          }
        },
        distance = Config.ThirdEye.targetDistance
      })
    end
  end
end

local function RemoveThirdEyeTargets()
  if not Config.ThirdEye.enabled then return end
  
  if Config.ThirdEye.useQBTarget then
    exports['qb-target']:RemoveGlobalPed("Sell Drugs")
    exports['qb-target']:RemoveGlobalVehicle("Sell Drugs")
    exports['qb-target']:RemoveGlobalPlayer("Sell Drugs")
    if Config.ThirdEye.targetModels then
      exports['qb-target']:RemoveTargetModel(Config.ThirdEye.targetModels, Config.ThirdEye.targetLabel)
    end
  end
end

-- Event handlers for third-eye
RegisterNetEvent('bldr-drugs:openSelling', function(data)
  OpenDrugSelling(data)
end)

-- NPC Management (Keep existing system as backup/additional option)
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
  -- Only spawn NPCs if third-eye is disabled or as additional option
  if Config.ThirdEye.enabled and Config.ThirdEye.sellAnywhere then
    -- Reduce NPC spawning when third-eye is available
    if #activeNPCs >= math.floor(Config.NPCs.maxActive / 3) then
      return
    end
  elseif #activeNPCs >= Config.NPCs.maxActive then
    return
  end
  
  local playerCoords = GetEntityCoords(PlayerPedId())
  local spawnAttempts = 0
  local maxAttempts = 5  -- Reduced attempts when third-eye available
  
  while #activeNPCs < (Config.ThirdEye.enabled and math.floor(Config.NPCs.maxActive / 3) or Config.NPCs.maxActive) and spawnAttempts < maxAttempts do
    spawnAttempts = spawnAttempts + 1
    
    if math.random() < Config.NPCs.spawnChance then
      local angle = math.random() * 2 * math.pi
      local distance = math.random(Config.NPCs.spawnRadius * 0.5, Config.NPCs.spawnRadius)
      local spawnCoords = {
        x = playerCoords.x + math.cos(angle) * distance,
        y = playerCoords.y + math.sin(angle) * distance,
        z = playerCoords.z
      }
      
      local foundGround, groundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 50.0, false)
      if foundGround then
        spawnCoords.z = groundZ
        
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
            debugPrint("Spawned NPC", #activeNPCs, "/", (Config.ThirdEye.enabled and math.floor(Config.NPCs.maxActive / 3) or Config.NPCs.maxActive))
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

-- Main interaction thread (modified for third-eye compatibility)
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    
    -- Only show traditional NPC interactions if third-eye is disabled or as backup
    if not Config.ThirdEye.enabled and not isInteracting then
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
          OpenDrugSelling()
        end
      end
    end
  end
end)

-- NPC management thread (reduced frequency when third-eye enabled)
Citizen.CreateThread(function()
  while true do
    local interval = Config.ThirdEye.enabled and Config.NPCs.checkInterval * 2 or Config.NPCs.checkInterval
    Citizen.Wait(interval)
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

-- Third-eye initialization
Citizen.CreateThread(function()
  Wait(2000) -- Wait for dependencies to load
  if Config.ThirdEye.enabled then
    SetupThirdEyeTargets()
    debugPrint("Third-eye drug selling system initialized")
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
  
  -- Remove third-eye targets
  RemoveThirdEyeTargets()
  
  -- Cleanup NPCs
  for _, npcData in pairs(activeNPCs) do
    if DoesEntityExist(npcData.entity) then
      DeleteEntity(npcData.entity)
    end
  end
  
  activeNPCs = {}
  debugPrint("Cleaned up all NPCs and targets on resource stop")
end)
