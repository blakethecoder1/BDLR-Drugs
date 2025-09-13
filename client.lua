local QBCore = exports['qb-core']:GetCoreObject()

local currentToken = nil
local tokenExpiry = 0
local lastTokenRequest = 0

local function debugPrint(...) if Config.Debug then print('[bldr-drugs][CLIENT]', ...) end end

-- NUI open
RegisterNUICallback('requestSell', function(data, cb)
  -- data: {item, amount, coords}
  if not currentToken then cb({ success = false, reason = 'no_token' }) return end
  local payload = { token = currentToken, item = data.item, amount = tonumber(data.amount) or 0, coords = data.coords }
  QBCore.Functions.TriggerCallback(Config.ResourceName..':completeSale', function(success, resp)
    cb({ success = success, resp = resp })
    if success then
      currentToken = nil
    end
  end, payload)
end)

-- Token response
RegisterNetEvent(Config.ResourceName..':tokenResponse')
AddEventHandler(Config.ResourceName..':tokenResponse', function(ok, tokenOrReason, expiry)
  if not ok then
    QBCore.Functions.Notify('Failed to get trade token: '..tostring(tokenOrReason), 'error')
    return
  end
  currentToken = tokenOrReason
  tokenExpiry = GetGameTimer() + (expiry or Config.TokenExpiry)
  QBCore.Functions.Notify('Trade session ready', 'success')
end)

-- Request token helper
function RequestTradeToken()
  local now = GetGameTimer()
  if now - lastTokenRequest < Config.MinTokenRequestInterval then
    QBCore.Functions.Notify('Please wait before requesting another session', 'error')
    return
  end
  lastTokenRequest = now
  TriggerServerEvent(Config.ResourceName..':requestToken')
end

-- Count cops request from server
RegisterNetEvent(Config.ResourceName..':countCopsRequest')
AddEventHandler(Config.ResourceName..':countCopsRequest', function(coords, radius)
  local count = 0
  local players = QBCore.Functions.GetPlayers()
  for _, pid in ipairs(players) do
    local psrc = tonumber(pid)
    local ped = GetPlayerPed(psrc)
    if ped and ped ~= 0 then
      local pedCoords = GetEntityCoords(ped)
      local dist = #(vector3(coords.x, coords.y, coords.z) - pedCoords)
      if dist <= radius then
        local player = QBCore.Functions.GetPlayer(psrc)
        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == 'police' then
          count = count + 1
        end
      end
    end
  end
  -- respond via server event channel specific to source
  local mySrc = GetPlayerServerId(PlayerId())
  TriggerServerEvent(Config.ResourceName..':countCopsResponse_'..mySrc, count)
end)

-- Simple NUI toggles for testing
RegisterCommand('bldr_request_token', function()
  RequestTradeToken()
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resName)
  if resName ~= GetCurrentResourceName() then return end
  -- any cleanup such as deleting peds would go here
end)

-- Example: open NUI at sell location (very simple)
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _,v in pairs(Config.SellPoints) do
      if #(coords - v) < 2.0 then
        -- show hint
        DrawText3D(v.x, v.y, v.z+0.2, '[E] Sell Drugs')
        if IsControlJustReleased(0, 38) then
          -- request token then open NUI
          RequestTradeToken()
          SetNuiFocus(true, true)
          SendNUIMessage({ action = 'open', xp = 0 })
        end
      end
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

-- Basic thread to clear expired token
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(1000)
    if currentToken and GetGameTimer() > tokenExpiry then
      currentToken = nil
      QBCore.Functions.Notify('Trade session expired', 'error')
    end
  end
end)
