local QBCore = exports['qb-core']:GetCoreObject()
local playerData = { xp = 0 }
local lastSell = 0
local buyers = {}

-- Load player data
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        TriggerServerEvent('bldr-drugs:loadPlayer')
    end
end)

RegisterNetEvent('bldr-drugs:sendPlayerData', function(data)
    playerData = data or { xp = 0 }
end)

local function getMultiplier()
    local mult = 1.0
    for i = #Config.Levels, 1, -1 do
        if playerData.xp >= Config.Levels[i].xp then mult = Config.Levels[i].multiplier break end
    end
    return mult
end

-- NUI
local uiOpen = false

RegisterNUICallback('sell', function(data, cb)
    if GetGameTimer() - lastSell < (Config.SellCooldown * 1000) then
        SendNUIMessage({ action = 'error', text = 'Please wait before selling again' })
        cb(false)
        return
    end

    lib.callback('bldr-drugs:canSellItem', false, function(can)
        if not can then
            SendNUIMessage({ action = 'error', text = 'You do not have that item' })
            cb(false)
            return
        end
        TriggerServerEvent('bldr-drugs:sellItem', { item = data.item, amount = tonumber(data.amount) })
        lastSell = GetGameTimer()
        cb(true)
    end, data.item)
end)

function openNui()
    if uiOpen then return end
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', drugs = Config.Drugs, xp = playerData.xp })
end

function closeNui()
    if not uiOpen then return end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(data, cb) closeNui() cb(true) end)

-- keybind
RegisterCommand('sellmenu', function() openNui() end)

-- world prompt
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for _, loc in pairs(Config.SellLocations) do
            local dist = #(pos - loc.coords)
            if dist < loc.radius then
                sleep = 200
                lib.showTextUI('[E] - Open seller (NUI)', { position = 'top-center' })
                if IsControlJustReleased(0, 38) then openNui() end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then lib.hideTextUI() SetNuiFocus(false, false) end end)
