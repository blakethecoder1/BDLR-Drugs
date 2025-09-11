local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

local function ensurePlayer(cid)
    PlayerData[cid] = PlayerData[cid] or { xp = 0 }
end

-- Database load/save
if Config.UseDatabase then
    MySQL.ready(function()
        print('bldr-drugs: MySQL ready')
    end)
end

RegisterServerEvent('bldr-drugs:loadPlayer')
AddEventHandler('bldr-drugs:loadPlayer', function()
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if not ply then return end
    local cid = ply.PlayerData.citizenid
    ensurePlayer(cid)

    if Config.UseDatabase then
        MySQL.Async.fetchScalar('SELECT xp FROM ' .. Config.TableName .. ' WHERE citizenid = @cid', {['@cid'] = cid}, function(xp)
            if xp then
                PlayerData[cid].xp = tonumber(xp)
            else
                -- insert
                MySQL.Async.execute('INSERT INTO '..Config.TableName..' (citizenid, xp) VALUES (@cid, @xp)', {['@cid']=cid, ['@xp']=0})
            end
            TriggerClientEvent('bldr-drugs:sendPlayerData', src, PlayerData[cid])
        end)
    else
        TriggerClientEvent('bldr-drugs:sendPlayerData', src, PlayerData[cid])
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if not ply then return end
    local cid = ply.PlayerData.citizenid
    if Config.UseDatabase and PlayerData[cid] then
        MySQL.Async.execute('UPDATE '..Config.TableName..' SET xp = @xp WHERE citizenid = @cid', {['@xp']=PlayerData[cid].xp, ['@cid']=cid})
    end
end)

QBCore.Functions.CreateCallback('bldr-drugs:canSellItem', function(source, cb, item)
    local ply = QBCore.Functions.GetPlayer(source)
    if not ply then cb(false) return end
    local has = ply.Functions.GetItemByName(item)
    if has and has.amount > 0 then cb(true) else cb(false) end
end)

local function getMultiplierFor(cid)
    local pdata = PlayerData[cid] or { xp = 0 }
    local mult = 1.0
    for i = #Config.Levels, 1, -1 do
        if pdata.xp >= Config.Levels[i].xp then
            mult = Config.Levels[i].multiplier
            break
        end
    end
    return mult
end

local function countCopsNearby(coords)
    local players = QBCore.Functions.GetPlayers()
    local count = 0
    for _, pid in pairs(players) do
        local p = QBCore.Functions.GetPlayer(tonumber(pid))
        if p and p.PlayerData.job.name == 'police' then
            -- ideally get player coords via client callback, simplified here: count as police
            count = count + 1
        end
    end
    return count
end

RegisterServerEvent('bldr-drugs:sellItem')
AddEventHandler('bldr-drugs:sellItem', function(data)
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if not ply then return end
    local cid = ply.PlayerData.citizenid
    ensurePlayer(cid)

    local item = data.item
    local amount = tonumber(data.amount) or 1
    if amount <= 0 then TriggerClientEvent('QBCore:Notify', src, 'Invalid amount', 'error') return end

    local has = ply.Functions.GetItemByName(item)
    if not has or has.amount < amount then TriggerClientEvent('QBCore:Notify', src, 'Not enough items', 'error') return end

    local basePrice = 50
    for _, d in pairs(Config.Drugs) do if d.item == item then basePrice = d.basePrice end end

    -- compute multiplier & police penalty
    local mult = getMultiplierFor(cid)
    local policeNearby = countCopsNearby(nil)
    local sellChance = Config.SellChance
    if policeNearby > 0 then
        sellChance = math.max(5, sellChance - Config.PolicePenalty)
    end

    local roll = math.random(1,100)
    if roll > sellChance then
        -- fail
        local lost = math.max(1, math.ceil(amount/2))
        ply.Functions.RemoveItem(item, lost)
        PlayerData[cid].xp = PlayerData[cid].xp + 5
        TriggerClientEvent('QBCore:Notify', src, 'Buyer ran off with some product!', 'error')
        TriggerClientEvent('bldr-drugs:sendPlayerData', src, PlayerData[cid])
        return
    end

    -- success: spawn buyer npc and handle immersive sale (client will request payment after animation)
    -- we calculate tentative pay and XP
    local total = math.floor(basePrice * amount * mult)
    local gainedXp = 10 * amount

    -- remove items now to prevent dupes
    ply.Functions.RemoveItem(item, amount)
    PlayerData[cid].xp = PlayerData[cid].xp + gainedXp

    -- give money
    ply.Functions.AddMoney('cash', total)
    TriggerClientEvent('QBCore:Notify', src, 'Sold x'..amount..' for $'..total, 'success')
    TriggerClientEvent('bldr-drugs:sendPlayerData', src, PlayerData[cid])

    -- persist
    if Config.UseDatabase then
        MySQL.Async.execute('UPDATE '..Config.TableName..' SET xp = @xp WHERE citizenid = @cid', {['@xp']=PlayerData[cid].xp, ['@cid']=cid})
    end
end)

-- Admin
QBCore.Commands.Add('adddrugxp', 'Add drug XP', {{name='id', help='player id'},{name='xp', help='amount'}}, true, function(src, args)
    local target = tonumber(args[1])
    local xp = tonumber(args[2]) or 0
    local tply = QBCore.Functions.GetPlayer(target)
    if not tply then TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error') return end
    local cid = tply.PlayerData.citizenid
    ensurePlayer(cid)
    PlayerData[cid].xp = PlayerData[cid].xp + xp
    TriggerClientEvent('bldr-drugs:sendPlayerData', target, PlayerData[cid])
    TriggerClientEvent('QBCore:Notify', src, 'Added XP', 'success')
end, 'admin')
