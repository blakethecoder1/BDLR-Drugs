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
local npcCooldowns = {} -- Track NPCs we've recently dealt with: {entityId: expireTime}

-- Custom notification function with improved visibility
local function CustomNotify(text, type, duration)
  local notifyType = type or 'info'
  local notifyDuration = duration or 4000
  
  -- Convert type to ensure compatibility
  if notifyType == 'primary' then notifyType = 'info' end
  
  -- Use ox_lib notifications for better styling if available
  if GetResourceState('ox_lib') == 'started' then
    local notifyData = {
      title = 'BLDR-DRUGS',
      description = text,
      type = notifyType,
      position = 'top-right',
      duration = notifyDuration,
      style = {
        backgroundColor = 'rgba(0, 0, 0, 0.95)',
        color = '#ffffff',
        border = '2px solid #00ff88'
      }
    }
    
    -- Adjust colors based on type
    if notifyType == 'error' then
      notifyData.style.border = '2px solid #ff4444'
      notifyData.style.color = '#ff4444'
    elseif notifyType == 'success' then
      notifyData.style.border = '2px solid #00ff88'
      notifyData.style.color = '#00ff88'
    elseif notifyType == 'warning' then
      notifyData.style.border = '2px solid #ffaa00'
      notifyData.style.color = '#ffaa00'
    end
    
    exports.ox_lib:notify(notifyData)
  else
    -- Fallback to QBCore notification
    QBCore.Functions.Notify(text, notifyType, notifyDuration)
  end
end

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

-- NPC Filtering System
local function IsNPCAllowed(entity)
  if not Config.NPCs.filteringEnabled then
    return true -- No filtering enabled
  end
  
  if not DoesEntityExist(entity) or IsPedAPlayer(entity) then
    return false
  end
  
  local model = GetEntityModel(entity)
  local modelName = GetHashKey(model) -- Get hash for comparison
  
  -- Convert model hashes to strings for comparison
  local function modelInList(modelList)
    for _, checkModel in pairs(modelList) do
      if GetHashKey(checkModel) == model then
        return true
      end
    end
    return false
  end
  
  -- Check vehicle restriction
  if Config.NPCs.blockVehicleNPCs and IsPedInAnyVehicle(entity, false) then
    return false
  end
  
  -- Check mission NPC restriction (using safe alternative)
  if Config.NPCs.blockMissionNPCs then
    -- Check if NPC has specific mission-related flags or is invincible
    if not CanPedRagdoll(entity) or GetEntityHealth(entity) <= 0 then
      return false
    end
  end
  
  -- Check distance from shops if configured
  if Config.NPCs.minDistanceFromShops > 0.0 then
    local pedCoords = GetEntityCoords(entity)
    -- Add shop locations that you want to avoid (customize as needed)
    local shopLocations = {
      vector3(25.7, -1347.3, 29.49),     -- LTD Downtown
      vector3(-3038.71, 585.9, 7.9),     -- LTD Inseno Road
      vector3(-3241.91, 1001.46, 12.83), -- LTD Barbareno Road
      vector3(1728.66, 6414.16, 35.04),  -- LTD Senora Freeway
      vector3(1697.99, 4924.4, 42.06),   -- LTD Grapeseed Main St
      vector3(1961.48, 3739.96, 32.34),  -- LTD Sandy Shores
      vector3(547.79, 2671.79, 42.16),   -- LTD Route 68
      vector3(2679.25, 3280.12, 55.24),  -- LTD Senora Freeway
      vector3(2557.94, 382.05, 108.62),  -- LTD Palomino Freeway
      vector3(373.55, 325.56, 103.56),   -- 24/7 Supermarket Clinton Ave
      vector3(811.24, -775.0, 26.17),    -- Ammunation
      vector3(842.44, -1033.42, 28.19),  -- Ammunation La Mesa
      -- Add more shop coordinates as needed
    }
    
    for _, shopCoords in pairs(shopLocations) do
      if #(pedCoords - shopCoords) < Config.NPCs.minDistanceFromShops then
        return false
      end
    end
  end
  
  -- Apply filtering based on mode
  if Config.NPCs.filterMode == 'blacklist' then
    -- Blacklist mode: allow all except blacklisted
    if modelInList(Config.NPCs.blacklistedModels) then
      return false
    end
    return true
  elseif Config.NPCs.filterMode == 'whitelist' then
    -- Whitelist mode: only allow whitelisted
    if #Config.NPCs.whitelistedModels == 0 then
      return true -- Empty whitelist means allow all
    end
    return modelInList(Config.NPCs.whitelistedModels)
  end
  
  return true -- Default: allow
end

-- NPC Cooldown Management
local function IsNPCOnCooldown(entity)
  if not DoesEntityExist(entity) then return false end
  
  local entityId = NetworkGetNetworkIdFromEntity(entity)
  local currentTime = GetGameTimer()
  
  -- Clean up expired cooldowns
  for id, expireTime in pairs(npcCooldowns) do
    if currentTime > expireTime then
      npcCooldowns[id] = nil
    end
  end
  
  return npcCooldowns[entityId] and currentTime < npcCooldowns[entityId]
end

local function SetNPCCooldown(entity)
  if not DoesEntityExist(entity) then return end
  
  local entityId = NetworkGetNetworkIdFromEntity(entity)
  local expireTime = GetGameTimer() + Config.NPCs.sellCooldown
  npcCooldowns[entityId] = expireTime
  
  debugPrint("Set cooldown for NPC", entityId, "expires in", Config.NPCs.sellCooldown, "ms")
end

local function GetNPCCooldownTimeLeft(entity)
  if not DoesEntityExist(entity) then return 0 end
  
  local entityId = NetworkGetNetworkIdFromEntity(entity)
  local currentTime = GetGameTimer()
  
  if npcCooldowns[entityId] and currentTime < npcCooldowns[entityId] then
    return math.ceil((npcCooldowns[entityId] - currentTime) / 1000) -- Return seconds
  end
  
  return 0
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
      
      -- Find next level XP requirement
      for j = 1, #Config.Levels do
        if Config.Levels[j].level > level then
          nextLevelXP = Config.Levels[j].xp
          break
        end
      end
      if nextLevelXP == 0 then
        nextLevelXP = xp -- Max level
      end
      break
    end
  end
  
  return level, title, multiplier, nextLevelXP
end

local function GetAvailableItems()
  local availableItems = {}
  local currentLevel = playerLevel or 0 -- Fallback to 0 if playerLevel is nil
  
  debugPrint("Getting available items for level:", currentLevel)
  
  for itemName, itemConfig in pairs(Config.Items) do
    if currentLevel >= itemConfig.minLevel then
      table.insert(availableItems, {
        name = itemName,
        label = itemConfig.label,
        basePrice = itemConfig.basePrice,
        maxAmount = itemConfig.maxAmount,
        description = itemConfig.description
      })
    end
  end
  
  debugPrint("Found", #availableItems, "available items")
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
    CustomNotify('You cannot sell drugs in this area: ' .. zoneName, 'error')
    return
  end
  
  if currentToken then
    -- Already have a token, open UI directly
    debugPrint("Opening UI with existing token")
    SetNuiFocus(true, true)  -- Enable both keyboard and mouse
    SendNUIMessage({ 
      action = 'open', 
      playerLevel = playerLevel,
      playerTitle = playerTitle or 'Street Rookie',
      playerXP = playerXP,
      nextLevelXP = nextLevelXP or 0
    })
  else
    -- Request token first
    debugPrint("Requesting token before opening UI")
    RequestTradeToken()
    -- Small delay then open UI
    SetTimeout(1000, function()
      if currentToken then
        debugPrint("Opening UI after token received")
        SetNuiFocus(true, true)  -- Enable both keyboard and mouse
        SendNUIMessage({ 
          action = 'open', 
          playerLevel = playerLevel,
          playerTitle = playerTitle or 'Street Rookie',
          playerXP = playerXP,
          nextLevelXP = nextLevelXP or 0
        })
      else
        debugPrint("Failed to get token, not opening UI")
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
              return IsNPCAllowed(entity)
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
  -- If we have entity data (third-eye interaction), make NPC face player
  if data and data.entity and DoesEntityExist(data.entity) and not IsPedAPlayer(data.entity) then
    -- Check if this NPC is allowed for selling
    if not IsNPCAllowed(data.entity) then
      CustomNotify('This person is not interested in your business', 'error', 3000)
      return
    end
    
    -- Check if this NPC is on cooldown
    if IsNPCOnCooldown(data.entity) then
      local timeLeft = GetNPCCooldownTimeLeft(data.entity)
      if Config.NPCs.cooldownMessage then
        CustomNotify('This person isn\'t interested right now. Try again in ' .. timeLeft .. ' seconds.', 'error', 3000)
      end
      return -- Don't proceed with opening the selling UI
    end
    
    -- Clear NPC tasks and make them face the player
    ClearPedTasks(data.entity)
    TaskTurnPedToFaceEntity(data.entity, PlayerPedId(), -1)
    
    -- Set them as the nearby NPC for selling interaction
    nearbyNPC = {
      entity = data.entity,
      isInteracting = false,
      spawnCoords = GetEntityCoords(data.entity)
    }
    
    -- Add a brief conversation animation
    SetTimeout(800, function()
      if DoesEntityExist(data.entity) then
        TaskStartScenarioInPlace(data.entity, "WORLD_HUMAN_STAND_MOBILE", 0, true)
      end
    end)
  end
  
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
  debugPrint("Sell request received:", json.encode(data))
  
  if not currentToken then 
    debugPrint("No token available")
    cb({ success = false, reason = 'no_token' }) 
    return 
  end
  
  if not nearbyNPC then
    debugPrint("No nearby NPC")
    cb({ success = false, reason = 'no_buyer' })
    return
  end
  
  -- Check if NPC is on cooldown
  if IsNPCOnCooldown(nearbyNPC.entity) then
    local timeLeft = GetNPCCooldownTimeLeft(nearbyNPC.entity)
    debugPrint("NPC is on cooldown for", timeLeft, "more seconds")
    
    if Config.NPCs.cooldownMessage then
      CustomNotify('This person isn\'t interested right now. Try again in ' .. timeLeft .. ' seconds.', 'error', 3000)
    end
    
    cb({ success = false, reason = 'npc_cooldown', timeLeft = timeLeft })
    return
  end
  
  local playerCoords = GetEntityCoords(PlayerPedId())
  local payload = { 
    token = currentToken, 
    item = data.item, 
    amount = tonumber(data.amount) or 1, 
    coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z}
  }
  
  debugPrint("Sending sell request with payload:", json.encode(payload))
  
  -- Mark NPC as interacting and stop them
  nearbyNPC.isInteracting = true
  isInteracting = true
  
  -- Enhanced NPC interaction behavior
  if DoesEntityExist(nearbyNPC.entity) then
    -- Clear any existing tasks
    ClearPedTasks(nearbyNPC.entity)
    
    -- Make NPC look at player immediately
    TaskTurnPedToFaceEntity(nearbyNPC.entity, PlayerPedId(), -1)
    
    -- Add a brief delay then make them do a conversation gesture
    SetTimeout(500, function()
      if DoesEntityExist(nearbyNPC.entity) and nearbyNPC.isInteracting then
        -- Play talking animation
        TaskStartScenarioInPlace(nearbyNPC.entity, "WORLD_HUMAN_STAND_MOBILE_UPRIGHT", 0, true)
        
        -- Make sure they keep looking at player during conversation
        SetTimeout(1000, function()
          if DoesEntityExist(nearbyNPC.entity) and nearbyNPC.isInteracting then
            TaskLookAtEntity(nearbyNPC.entity, PlayerPedId(), Config.NPCs.interactionTime * 1000, 0, 2)
          end
        end)
      end
    end)
  end
  
  QBCore.Functions.TriggerCallback(Config.ResourceName..':completeSale', function(success, result)
    debugPrint("Sell callback result:", success, json.encode(result or {}))
    
    -- Always send a proper response to prevent JSON errors
    local response = {
      success = success or false,
      reason = (result and result.reason) or 'unknown error',
      xpGained = (result and result.xpGained) or 0,
      moneyEarned = (result and result.moneyEarned) or 0
    }
    
    cb(response)
    
    if success then
      currentToken = nil
      
      -- Enhanced success notification with reward info
      local rewardText = ""
      if result and result.reward then
        local rewardType = result.reward.type
        local amount = result.reward.amount
        
        if rewardType == 'markedbills' then
          rewardText = " | Received $" .. amount .. " in marked bills 💰"
        elseif rewardType == 'black_money' then
          rewardText = " | Received $" .. amount .. " dirty money 🖤"
        elseif rewardType == 'crypto' then
          rewardText = " | Received $" .. amount .. " in crypto 💎"
        elseif rewardType == 'bank' then
          rewardText = " | Received $" .. amount .. " (banked) 🏦"
        elseif rewardType == 'cash' then
          rewardText = " | Received $" .. amount .. " cash 💵"
        end
      end
      
      local xpText = ""
      if result and result.xpGained and result.xpGained > 0 then
        xpText = " | +" .. result.xpGained .. " XP 📈"
      end
      
      CustomNotify('Deal completed successfully!' .. rewardText .. xpText, 'success', 5000)
      
      -- Set cooldown on this NPC
      if nearbyNPC and DoesEntityExist(nearbyNPC.entity) then
        SetNPCCooldown(nearbyNPC.entity)
      end
      
      -- Update player stats if provided
      if result and result.xp then
        playerXP = result.xp
        playerLevel, playerTitle, playerMultiplier, nextLevelXP = GetPlayerLevelInfo(playerXP)
      end
    else
      CustomNotify('Deal failed: ' .. (response.reason or 'unknown'), 'error')
    end
    
    -- Reset interaction state after a delay
    Citizen.SetTimeout(2000, function()
      isInteracting = false
      if nearbyNPC and DoesEntityExist(nearbyNPC.entity) then
        nearbyNPC.isInteracting = false
        
        -- Clear any conversation animations/tasks
        ClearPedTasks(nearbyNPC.entity)
        
        if success then
          -- If deal was successful, make NPC walk away casually
          SetTimeout(500, function()
            if DoesEntityExist(nearbyNPC.entity) then
              -- Give them a small wave animation first
              TaskPlayAnim(nearbyNPC.entity, "gestures@m@standing@casual", "gesture_bye_soft", 3.0, 3.0, 2000, 48, 0.0, 0, 0, 0)
              
              -- After wave, make them walk away
              SetTimeout(2500, function()
                if DoesEntityExist(nearbyNPC.entity) then
                  -- Walk away from player
                  local playerCoords = GetEntityCoords(PlayerPedId())
                  local npcCoords = GetEntityCoords(nearbyNPC.entity)
                  local direction = npcCoords - playerCoords
                  direction = direction / #direction -- normalize
                  local walkAwayCoords = npcCoords + direction * 10.0
                  
                  TaskGoToCoordAnyMeans(nearbyNPC.entity, walkAwayCoords.x, walkAwayCoords.y, walkAwayCoords.z, 1.0, 0, 0, 786603, 0xbf800000)
                end
              end)
            end
          end)
        else
          -- If deal failed, make NPC look disappointed and resume normal behavior
          SetTimeout(500, function()
            if DoesEntityExist(nearbyNPC.entity) then
              -- Shrug animation
              TaskPlayAnim(nearbyNPC.entity, "gestures@m@standing@casual", "gesture_shrug_hard", 2.0, 2.0, 2000, 48, 0.0, 0, 0, 0)
              
              -- After shrug, resume wandering
              SetTimeout(3000, function()
                if DoesEntityExist(nearbyNPC.entity) then
                  TaskWanderInArea(nearbyNPC.entity, nearbyNPC.spawnCoords.x, nearbyNPC.spawnCoords.y, nearbyNPC.spawnCoords.z, Config.NPCs.walkRadius, 1.0, 120.0)
                end
              end)
            end
          end)
        end
      end
    end)
  end, payload)
end)

-- Server Events
RegisterNetEvent(Config.ResourceName..':tokenResponse')
AddEventHandler(Config.ResourceName..':tokenResponse', function(ok, tokenOrReason, expiry)
  if not ok then
    CustomNotify('Failed to get trade token: '..tostring(tokenOrReason), 'error')
    return
  end
  currentToken = tokenOrReason
  tokenExpiry = GetGameTimer() + (expiry or Config.TokenExpiry)
  CustomNotify('Trade session ready - Find a buyer!', 'success')
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
    CustomNotify('Please wait before requesting another session', 'error')
    return
  end
  lastTokenRequest = now
  TriggerServerEvent(Config.ResourceName..':requestToken')
end

-- Initialize player stats when resource starts
Citizen.CreateThread(function()
  Wait(2000) -- Wait for core to be ready
  debugPrint("Initializing bldr-drugs client...")
  TriggerServerEvent(Config.ResourceName..':requestPlayerStats')
end)

-- Load animations for NPC interactions
Citizen.CreateThread(function()
  RequestAnimDict("gestures@m@standing@casual")
  while not HasAnimDictLoaded("gestures@m@standing@casual") do
    Wait(100)
  end
  debugPrint("Gesture animations loaded")
end)

-- Event to handle when player spawns/loads
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
  Wait(1000)
  debugPrint("Player loaded, requesting stats...")
  TriggerServerEvent(Config.ResourceName..':requestPlayerStats')
end)

-- NUI Callbacks (registered early to ensure availability)
RegisterNUICallback('getAvailableItems', function(data, cb)
  debugPrint("NUI callback: getAvailableItems requested")
  local items = GetAvailableItems()
  debugPrint("Available items count:", #items)
  
  -- Log the response for debugging
  if Config.Debug.enabled then
    for i, item in pairs(items) do
      debugPrint("Item", i..":", item.name, item.label, "Level req:", item.minLevel or 0)
    end
  end
  
  cb({ items = items })
end)

-- Test callback to verify NUI communication
RegisterNUICallback('test', function(data, cb)
  debugPrint("NUI test callback working!")
  cb({ success = true, message = "NUI communication working" })
end)

-- Request player stats callback
RegisterNUICallback('requestPlayerStats', function(data, cb)
  debugPrint("NUI requesting player stats, current level:", playerLevel)
  TriggerServerEvent(Config.ResourceName..':requestPlayerStats')
  cb({ success = true })
end)

-- Ready callback for when NUI loads
RegisterNUICallback('ready', function(data, cb)
  debugPrint("NUI ready callback received")
  cb({ success = true })
end)

-- Add throttling to prevent spam
local lastCloseTime = 0

RegisterNUICallback('close', function(data, cb)
  local currentTime = GetGameTimer()
  
  -- Prevent spam by throttling close calls
  if currentTime - lastCloseTime < 100 then -- 100ms throttle
    cb('ok')
    return
  end
  
  lastCloseTime = currentTime
  debugPrint("NUI close callback called")
  
  -- Immediately release focus
  SetNuiFocus(false, false)
  
  -- Send close message
  SendNUIMessage({ action = 'close' })
  
  -- Reset interaction state
  isInteracting = false
  
  cb('ok')
end)

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

-- Emergency command to fix stuck NUI focus
RegisterCommand('bldr_fix_ui', function()
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
  isInteracting = false
  
  -- Force enable movement
  DisableControlAction(0, 1, false) -- LookLeftRight
  DisableControlAction(0, 2, false) -- LookUpDown
  DisableControlAction(0, 30, false) -- MoveLeftRight
  DisableControlAction(0, 31, false) -- MoveUpDown
  
  print("[BLDR-DRUGS] UI focus manually released - you should be able to move now")
end)

-- Add a thread to monitor for stuck UI focus (disabled for now to allow proper UI interaction)
--[[ This was interfering with normal UI operation
Citizen.CreateThread(function()
  while true do
    Wait(1000)
    
    -- Check if NUI focus is active but UI should be closed
    if not isInteracting then
      -- Release any lingering focus
      SetNuiFocus(false, false)
    end
  end
end)
--]]

-- Debug resource name
RegisterCommand('bldr_debug_resource', function()
  print("[BLDR-DRUGS] Resource name should be: " .. GetCurrentResourceName())
  print("[BLDR-DRUGS] Config resource name: " .. Config.ResourceName)
end)

-- Test NUI communication
RegisterCommand('bldr_test_nui', function()
  print("[BLDR-DRUGS] Testing NUI communication...")
  SetNuiFocus(true, true)
  SendNUIMessage({ 
    action = 'open', 
    playerLevel = playerLevel or 0,
    playerTitle = playerTitle or 'Street Rookie',
    playerXP = playerXP or 0,
    nextLevelXP = 100
  })
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
        local npcCoords = GetEntityCoords(nearbyNPC.entity)
        local npcOnCooldown = IsNPCOnCooldown(nearbyNPC.entity)
        
        if Config.Debug.enabled and Config.Debug.drawMarkers then
          -- Green marker for available NPCs, red for cooldown NPCs
          local r, g, b = npcOnCooldown and 255 or 0, npcOnCooldown and 0 or 255, 0
          DrawMarker(1, npcCoords.x, npcCoords.y, npcCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, r, g, b, 100, false, true, 2, nil, nil, false)
        end
        
        -- Show cooldown markers even when debug is off
        if npcOnCooldown and Config.NPCs.showCooldownMarker then
          DrawMarker(1, npcCoords.x, npcCoords.y, npcCoords.z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 0, 0, 150, false, true, 2, nil, nil, false)
        end
        
        -- Show interaction prompt
        if npcOnCooldown then
          local timeLeft = GetNPCCooldownTimeLeft(nearbyNPC.entity)
          DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.2, '⏰ Not interested (' .. timeLeft .. 's)')
        else
          DrawText3D(npcCoords.x, npcCoords.y, npcCoords.z + 1.2, '[E] Approach Buyer')
          
          if IsControlJustReleased(0, 38) then -- E key
            OpenDrugSelling()
          end
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
      CustomNotify('Trade session expired', 'error')
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

-- Custom notification event handler
RegisterNetEvent('bldr-drugs:notify', function(text, type, duration)
  CustomNotify(text, type, duration)
end)

-- Debug command to identify NPC models (for adding to blacklist)
RegisterCommand('checknpc', function()
  local playerPed = PlayerPedId()
  local coords = GetEntityCoords(playerPed)
  local closestPed = nil
  local closestDistance = 10.0
  
  local handle, ped = FindFirstPed()
  local success = true
  
  while success do
    if ped ~= playerPed and not IsPedAPlayer(ped) then
      local pedCoords = GetEntityCoords(ped)
      local distance = #(coords - pedCoords)
      if distance < closestDistance then
        closestDistance = distance
        closestPed = ped
      end
    end
    success, ped = FindNextPed(handle)
  end
  
  EndFindPed(handle)
  
  if closestPed then
    local model = GetEntityModel(closestPed)
    local modelName = GetHashKey(model)
    local allowed = IsNPCAllowed(closestPed)
    local inVehicle = IsPedInAnyVehicle(closestPed, false)
    local isMission = not CanPedRagdoll(closestPed) -- Safe alternative for mission check
    
    CustomNotify(string.format('NPC Info: Model=%s | Allowed=%s | InVehicle=%s | Mission=%s', 
      modelName, tostring(allowed), tostring(inVehicle), tostring(isMission)), 'info', 8000)
    
    print('[bldr-drugs] NPC Model Hash:', model)
    print('[bldr-drugs] NPC Model Name (for config):', modelName)
  else
    CustomNotify('No NPC found nearby', 'error', 3000)
  end
end, false)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  
  -- Remove third-eye targets
  RemoveThirdEyeTargets()
  
  -- Remove crafting table targets
  RemoveCraftingTables()
  
  -- Cleanup NPCs
  for _, npcData in pairs(activeNPCs) do
    if DoesEntityExist(npcData.entity) then
      DeleteEntity(npcData.entity)
    end
  end
  
  activeNPCs = {}
  debugPrint("Cleaned up all NPCs and targets on resource stop")
end)

-- === EVOLUTION CRAFTING TABLE SYSTEM ===

-- Crafting table locations (you can add more)
local craftingTables = {
  {
    coords = vector3(1375.8, 3602.01, 34.88), -- Updated location
    label = "Drug Lab Table",
    prop = "bkr_prop_meth_table01a" -- Optional prop to spawn
  }
  -- Add more locations here:
  -- { coords = vector3(x, y, z), label = "Another Lab", prop = "prop_name" }
}

-- Initialize crafting tables
Citizen.CreateThread(function()
  if not Config.Evolution or not Config.Evolution.enabled then return end
  
  for i, table in ipairs(craftingTables) do
    -- Optionally spawn a prop
    if table.prop then
      local prop = CreateObject(GetHashKey(table.prop), table.coords.x, table.coords.y, table.coords.z - 1.0, false, false, false)
      SetEntityHeading(prop, 0.0)
      FreezeEntityPosition(prop, true)
      debugPrint("Spawned crafting table prop at", table.coords)
    end
    
    -- Add qb-target interaction
    if Config.ThirdEye.enabled and Config.ThirdEye.useQBTarget then
      exports['qb-target']:AddBoxZone("crafting_table_" .. i, table.coords, 2.0, 2.0, {
        name = "crafting_table_" .. i,
        heading = 0,
        minZ = table.coords.z - 1,
        maxZ = table.coords.z + 1,
      }, {
        options = {
          {
            type = "client",
            event = "bldr-drugs:openCraftingMenu",
            icon = "fas fa-flask",
            label = table.label,
          }
        },
        distance = 2.0
      })
      debugPrint("Added crafting table target zone", i)
    end
  end
end)

-- Remove crafting table targets
function RemoveCraftingTables()
  if not Config.ThirdEye.enabled or not Config.ThirdEye.useQBTarget then return end
  
  for i, _ in ipairs(craftingTables) do
    exports['qb-target']:RemoveZone("crafting_table_" .. i)
  end
  debugPrint("Removed all crafting table targets")
end

-- Open crafting menu event
RegisterNetEvent('bldr-drugs:openCraftingMenu', function()
  if not Config.Evolution or not Config.Evolution.enabled then 
    CustomNotify("Evolution system is disabled", "error")
    return 
  end
  
  -- Get available recipes
  QBCore.Functions.TriggerCallback('bldr-drugs:getAvailableRecipes', function(recipes)
    if not recipes or #recipes == 0 then
      CustomNotify("No recipes available. Sell more drugs to unlock recipes!", "error")
      return
    end
    
    -- Create menu options
    local menuOptions = {}
    for _, recipe in ipairs(recipes) do
      local requirementText = ""
      for i, req in ipairs(recipe.requires or {}) do
        if i > 1 then requirementText = requirementText .. ", " end
        requirementText = requirementText .. (req.count or 1) .. "x " .. req.item
      end
      
      table.insert(menuOptions, {
        header = recipe.label,
        txt = "Requires: " .. requirementText .. "<br/>Crafting time: " .. ((recipe.time_ms or 5000) / 1000) .. " seconds",
        params = {
          event = "bldr-drugs:startCrafting",
          args = {
            recipeKey = recipe.key
          }
        }
      })
    end
    
    -- Add close option
    table.insert(menuOptions, {
      header = "Close",
      txt = "",
      params = {
        event = "qb-menu:closeMenu"
      }
    })
    
    -- Open menu
    exports['qb-menu']:openMenu(menuOptions)
  end)
end)

-- Start crafting event
RegisterNetEvent('bldr-drugs:startCrafting', function(data)
  local recipeKey = data.recipeKey
  if not recipeKey then return end
  
  -- Get recipe details for progress bar
  local recipe = Config.Evolution.recipes[recipeKey]
  if not recipe then return end
  
  -- Close menu
  exports['qb-menu']:closeMenu()
  
  -- Show progress bar
  QBCore.Functions.Progressbar("drug_crafting", "Crafting " .. (recipe.label or "evolved drug") .. "...", recipe.time_ms or 5000, false, true, {
    disableMovement = true,
    disableCarMovement = true,
    disableMouse = false,
    disableCombat = true,
  }, {
    animDict = "mini@repair",
    anim = "fixing_a_ped",
    flags = 49,
  }, {}, {}, function() -- Done
    -- Trigger server-side crafting
    TriggerServerEvent('bldr-drugs:craftEvolution', recipeKey)
  end, function() -- Cancel
    CustomNotify("Crafting cancelled", "error")
  end)
end)

-- Client event to trigger crafting (for admin testing)
RegisterNetEvent('bldr-drugs:triggerCraft', function(recipeKey)
  TriggerServerEvent('bldr-drugs:craftEvolution', recipeKey)
end)
