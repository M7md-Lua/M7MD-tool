local QBCore = exports['qb-core']:GetCoreObject()

local lastGiveAt = {}
local lastRemoveAt = {}
local lastClearAt = {}
local lastMoneyAt = {}
local lastTeleportAt = {}
local lastSlashlessAt = {}

local commandSet = {}
local slashlessAllow = {}

local function refreshCommandSet()
    commandSet = {}
    local cmds = GetRegisteredCommands()
    if type(cmds) ~= 'table' then return end
    for i = 1, #cmds do
        local name = cmds[i] and cmds[i].name
        if type(name) == 'string' and name ~= '' then
            commandSet[name:lower()] = true
        end
    end
end

local function refreshSlashlessAllow()
    slashlessAllow = {}
    if type(Config.SlashlessCommands) ~= 'table' then return end
    for i = 1, #Config.SlashlessCommands do
        local name = Config.SlashlessCommands[i]
        if type(name) == 'string' and name ~= '' then
            slashlessAllow[name:lower()] = true
        end
    end
end

local function audit(channel, title, color, message)
    TriggerEvent('qb-log:server:CreateLog', channel, title, color, message, false)
end

local function trim(s)
    return (s:gsub('^%s*(.-)%s*$', '%1'))
end

local function isAllowed(src)
    if src == 0 then
        return true
    end

    if Config.RequireQBCorePermission then
        return QBCore.Functions.HasPermission(src, Config.QBCorePerms)
    end

    if Config.AllowAceCommand and IsPlayerAceAllowed(src, 'command.m7tool') then
        return true
    end

    if QBCore.Functions.HasPermission(src, Config.QBCorePerms) then
        return true
    end

    return false
end

local function deny(src)
    if src == 0 then
        print(('[%s] denied (console)'):format(Config.ToolName))
        return
    end

    TriggerClientEvent('QBCore:Notify', src, ('%s: not allowed'):format(Config.ToolName), 'error')
end

local function openTool(src, tab)
    TriggerClientEvent('m7mdtool:client:open', src, tab or 'give')
end

RegisterCommand('m7tool', function(source)
    local src = source
    if not isAllowed(src) then return deny(src) end
    openTool(src, 'give')
end, false)

RegisterCommand('m7give', function(source)
    local src = source
    if not isAllowed(src) then return deny(src) end
    openTool(src, 'give')
end, false)

RegisterCommand('m7coords', function(source)
    local src = source
    if not isAllowed(src) then return deny(src) end
    openTool(src, 'coords')
end, false)

RegisterCommand('dt', function(source)
    local src = source
    if not isAllowed(src) then return deny(src) end
    TriggerClientEvent('m7mdtool:client:quickMenu', src)
end, false)

AddEventHandler('chatMessage', function(source, _, message)
    local src = source
    if type(message) ~= 'string' then return end

    local msg = trim(message)
    if msg == '' then return end

    local lower = msg:lower()
    local first = lower:match('^(%S+)')
    if not first then return end

    if first ~= 'dt' and first ~= 'm7tool' and first ~= 'm7give' and first ~= 'm7coords' then
        return
    end

    CancelEvent()

    if not isAllowed(src) then
        return deny(src)
    end

    if first == 'dt' then
        local tab = lower:match('^dt%s+(%S+)')
        if tab and tab ~= '' then
            return openTool(src, tab)
        end
        return TriggerClientEvent('m7mdtool:client:quickMenu', src)
    end

    if first == 'm7give' then return openTool(src, 'give') end
    if first == 'm7coords' then return openTool(src, 'coords') end
    return openTool(src, 'home')
end)

CreateThread(function()
    refreshCommandSet()
    refreshSlashlessAllow()
    while true do
        Wait(10000)
        refreshCommandSet()
        refreshSlashlessAllow()
    end
end)

AddEventHandler('chatMessage', function(source, _, message)
    if not Config.EnableSlashlessCommands then return end

    local src = source
    if type(message) ~= 'string' then return end

    local msg = trim(message)
    if msg == '' then return end
    if msg:sub(1, 1) == '/' then return end

    local lower = msg:lower()
    local first = lower:match('^(%S+)')
    if not first or first == '' then return end

    if first == 'dt' or first == 'm7tool' or first == 'm7give' or first == 'm7coords' then
        return
    end

    if not slashlessAllow[first] then
        return
    end

    if not commandSet[first] then
        return
    end

    local now = GetGameTimer()
    if lastSlashlessAt[src] and (now - lastSlashlessAt[src]) < (Config.SlashlessCooldownMs or 250) then
        CancelEvent()
        return
    end
    lastSlashlessAt[src] = now

    CancelEvent()
    TriggerClientEvent('m7mdtool:client:execCommand', src, msg)
end)

lib.callback.register('m7mdtool:getItems', function(source)
    local src = source
    if not isAllowed(src) then return false end

    local list = {}
    for name, item in pairs(QBCore.Shared.Items) do
        list[#list + 1] = {
            name = name,
            label = item.label or name,
        }
    end

    table.sort(list, function(a, b)
        return a.name < b.name
    end)

    return list
end)

lib.callback.register('m7mdtool:isAllowed', function(source)
    return isAllowed(source)
end)

lib.callback.register('m7mdtool:getMoneyTypes', function(source)
    local src = source
    if not isAllowed(src) then return false end

    local out = {}
    for k in pairs(QBCore.Config.Money.MoneyTypes) do
        out[#out + 1] = k
    end
    table.sort(out)
    return out
end)

lib.callback.register('m7mdtool:getPermissionInfo', function(source, targetId)
    local src = source
    if not isAllowed(src) then return false end

    targetId = tonumber(targetId)
    if not targetId or targetId < 1 or not GetPlayerName(targetId) then
        return false
    end

    local list = {}

    list[#list + 1] = 'user'
    if type(QBCore.Config.Server.Permissions) == 'table' then
        for _, v in ipairs(QBCore.Config.Server.Permissions) do
            if type(v) == 'string' and v ~= 'user' then
                list[#list + 1] = v
            end
        end
    end


    local seen = {}
    local out = {}
    for i = 1, #list do
        local v = tostring(list[i])
        if not seen[v] then
            seen[v] = true
            out[#out + 1] = v
        end
    end

    table.sort(out)

    return {
        current = QBCore.Functions.GetPermission(targetId),
        all = out,
    }
end)

lib.callback.register('m7mdtool:getJobs', function(source)
    local src = source
    if not isAllowed(src) then return false end

    local out = {}
    for name, job in pairs(QBCore.Shared.Jobs) do
        out[#out + 1] = { name = name, label = job.label or name }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end)

lib.callback.register('m7mdtool:getGangs', function(source)
    local src = source
    if not isAllowed(src) then return false end

    local out = {}
    for name, gang in pairs(QBCore.Shared.Gangs) do
        out[#out + 1] = { name = name, label = gang.label or name }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end)

lib.callback.register('m7mdtool:getPlayerPermission', function(source, targetId)
    local src = source
    if not isAllowed(src) then return false end

    targetId = tonumber(targetId)
    if not targetId or targetId < 1 or not GetPlayerName(targetId) then
        return false
    end

    return QBCore.Functions.GetPermission(targetId)
end)

lib.callback.register('m7mdtool:getPlayerInfo', function(source)
    local src = source
    if not isAllowed(src) then return false end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    return {
        source = src,
        citizenid = Player.PlayerData.citizenid,
        name = GetPlayerName(src),
    }
end)

local function ratelimit(bucket, src, cooldownMs)
    local now = GetGameTimer()
    if bucket[src] and (now - bucket[src]) < cooldownMs then
        return false
    end
    bucket[src] = now
    return true
end

RegisterNetEvent('m7mdtool:server:giveItem', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    if not ratelimit(lastGiveAt, src, Config.GiveCooldownMs) then
        TriggerClientEvent('QBCore:Notify', src, ('%s: slow down'):format(Config.ToolName), 'error')
        return
    end

    payload = payload or {}

    local itemName = trim(tostring(payload.itemName or '')):lower()
    if itemName == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Item name is required', 'error')
        return
    end

    local itemData = QBCore.Shared.Items[itemName]
    if not itemData then
        TriggerClientEvent('QBCore:Notify', src, ('Item does not exist: %s'):format(itemName), 'error')
        return
    end

    local amount = tonumber(payload.amount) or 1
    amount = math.floor(amount)
    if amount < 1 or amount > Config.MaxGiveAmount then
        TriggerClientEvent('QBCore:Notify', src, ('Amount must be 1-%d'):format(Config.MaxGiveAmount), 'error')
        return
    end

    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, ('Target not online: %s'):format(tostring(payload.targetId)), 'error')
        return
    end

    local ok = exports['qb-inventory']:AddItem(target, itemName, amount, nil, {})
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, 'Failed to give item (inventory full?)', 'error')
        return
    end

    TriggerClientEvent('inventory:client:ItemBox', target, itemData, 'add', amount)
    audit('m7mdtool', 'GiveItem', 'green', ('**%s** gave **%dx %s** to **ID %d**'):format(GetPlayerName(src), amount, itemName, target))

    if target == src then
        TriggerClientEvent('QBCore:Notify', src, ('Gave yourself %dx %s'):format(amount, itemData.label or itemName), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, ('Gave %dx %s to ID %d'):format(amount, itemData.label or itemName, target), 'success')
        TriggerClientEvent('QBCore:Notify', target, ('Received %dx %s'):format(amount, itemData.label or itemName), 'success')
    end
end)

RegisterNetEvent('m7mdtool:server:removeItem', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    if not ratelimit(lastRemoveAt, src, Config.RemoveCooldownMs) then
        TriggerClientEvent('QBCore:Notify', src, ('%s: slow down'):format(Config.ToolName), 'error')
        return
    end

    payload = payload or {}
    local itemName = trim(tostring(payload.itemName or '')):lower()
    if itemName == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Item name is required', 'error')
        return
    end

    local itemData = QBCore.Shared.Items[itemName]
    if not itemData then
        TriggerClientEvent('QBCore:Notify', src, ('Item does not exist: %s'):format(itemName), 'error')
        return
    end

    local amount = tonumber(payload.amount) or 1
    amount = math.floor(amount)
    if amount < 1 or amount > Config.MaxRemoveAmount then
        TriggerClientEvent('QBCore:Notify', src, ('Amount must be 1-%d'):format(Config.MaxRemoveAmount), 'error')
        return
    end

    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, ('Target not online: %s'):format(tostring(payload.targetId)), 'error')
        return
    end

    local ok = exports['qb-inventory']:RemoveItem(target, itemName, amount, payload.slot and tonumber(payload.slot) or nil)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, 'Failed to remove item', 'error')
        return
    end

    TriggerClientEvent('inventory:client:ItemBox', target, itemData, 'remove', amount)
    audit('m7mdtool', 'RemoveItem', 'red', ('**%s** removed **%dx %s** from **ID %d**'):format(GetPlayerName(src), amount, itemName, target))
    TriggerClientEvent('QBCore:Notify', src, ('Removed %dx %s from ID %d'):format(amount, itemData.label or itemName, target), 'success')
end)

RegisterNetEvent('m7mdtool:server:clearInventory', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    if not ratelimit(lastClearAt, src, Config.ClearInventoryCooldownMs) then
        TriggerClientEvent('QBCore:Notify', src, ('%s: slow down'):format(Config.ToolName), 'error')
        return
    end

    payload = payload or {}
    if payload.confirm ~= true then
        TriggerClientEvent('QBCore:Notify', src, 'Confirmation required', 'error')
        return
    end

    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, ('Target not online: %s'):format(tostring(payload.targetId)), 'error')
        return
    end

    exports['qb-inventory']:ClearInventory(target, payload.filterItems)
    audit('m7mdtool', 'ClearInventory', 'red', ('**%s** cleared inventory of **ID %d**'):format(GetPlayerName(src), target))
    TriggerClientEvent('QBCore:Notify', src, ('Cleared inventory for ID %d'):format(target), 'success')
    if target ~= src then
        TriggerClientEvent('QBCore:Notify', target, 'Your inventory was cleared by an admin', 'error')
    end
end)

RegisterNetEvent('m7mdtool:server:giveMoney', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    if not ratelimit(lastMoneyAt, src, Config.GiveMoneyCooldownMs) then
        TriggerClientEvent('QBCore:Notify', src, ('%s: slow down'):format(Config.ToolName), 'error')
        return
    end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    local moneyType = trim(tostring(payload.moneyType or '')):lower()
    if moneyType == '' or not QBCore.Config.Money.MoneyTypes[moneyType] then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid money type', 'error')
        return
    end

    local amount = tonumber(payload.amount) or 0
    amount = math.floor(amount)
    if amount < 1 or amount > Config.MaxGiveMoney then
        TriggerClientEvent('QBCore:Notify', src, ('Amount must be 1-%d'):format(Config.MaxGiveMoney), 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('QBCore:Notify', src, ('Target not online: %s'):format(tostring(payload.targetId)), 'error')
        return
    end

    Player.Functions.AddMoney(moneyType, amount, 'M7MD-tool')
    audit('m7mdtool', 'GiveMoney', 'green', ('**%s** gave **%d %s** to **ID %d**'):format(GetPlayerName(src), amount, moneyType, target))
    TriggerClientEvent('QBCore:Notify', src, ('Gave %d %s to ID %d'):format(amount, moneyType, target), 'success')
    if target ~= src then
        TriggerClientEvent('QBCore:Notify', target, ('You received %d %s'):format(amount, moneyType), 'success')
    end
end)

RegisterNetEvent('m7mdtool:server:setJob', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    local jobName = trim(tostring(payload.jobName or '')):lower()
    if jobName == '' or not QBCore.Shared.Jobs[jobName] then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid job name', 'error')
        return
    end

    local grade = tonumber(payload.grade) or 0
    grade = math.floor(grade)
    if grade < 0 then grade = 0 end

    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    Player.Functions.SetJob(jobName, grade)
    audit('m7mdtool', 'SetJob', 'yellow', ('**%s** set job **%s:%d** for **ID %d**'):format(GetPlayerName(src), jobName, grade, target))
    TriggerClientEvent('QBCore:Notify', src, ('Set job for ID %d -> %s (%d)'):format(target, jobName, grade), 'success')
end)

RegisterNetEvent('m7mdtool:server:setGang', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    local gangName = trim(tostring(payload.gangName or '')):lower()
    if gangName == '' or not QBCore.Shared.Gangs[gangName] then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid gang name', 'error')
        return
    end

    local grade = tonumber(payload.grade) or 0
    grade = math.floor(grade)
    if grade < 0 then grade = 0 end

    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    Player.Functions.SetGang(gangName, grade)
    audit('m7mdtool', 'SetGang', 'yellow', ('**%s** set gang **%s:%d** for **ID %d**'):format(GetPlayerName(src), gangName, grade, target))
    TriggerClientEvent('QBCore:Notify', src, ('Set gang for ID %d -> %s (%d)'):format(target, gangName, grade), 'success')
end)

RegisterNetEvent('m7mdtool:server:removePermission', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        TriggerClientEvent('QBCore:Notify', src, 'Target id required', 'error')
        return
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    QBCore.Functions.RemovePermission(target)
    audit('m7mdtool', 'RemovePermission', 'red', ('**%s** removed permission for **ID %d**'):format(GetPlayerName(src), target))
    TriggerClientEvent('QBCore:Notify', src, ('Removed permission for ID %d'):format(target), 'success')
    TriggerClientEvent('QBCore:Notify', target, 'Your permission was removed', 'error')
end)

RegisterNetEvent('m7mdtool:server:setPermission', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    local perm = tostring(payload.permission or ''):lower()

    if not target or target < 1 then
        TriggerClientEvent('QBCore:Notify', src, 'Target id required', 'error')
        return
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    if perm == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Permission required', 'error')
        return
    end

    if perm == 'user' then
        QBCore.Functions.RemovePermission(target)
        audit('m7mdtool', 'SetPermission', 'yellow', ('**%s** set permission user for **ID %d**'):format(GetPlayerName(src), target))
        TriggerClientEvent('QBCore:Notify', src, ('Set permission for ID %d -> user'):format(target), 'success')
        return
    end

    local allowed = false
    if type(QBCore.Config.Server.Permissions) == 'table' then
        for _, v in ipairs(QBCore.Config.Server.Permissions) do
            if tostring(v):lower() == perm then
                allowed = true
                break
            end
        end
    end

    if not allowed then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid permission', 'error')
        return
    end

    QBCore.Functions.AddPermission(target, perm)
    audit('m7mdtool', 'SetPermission', 'red', ('**%s** set permission **%s** for **ID %d**'):format(GetPlayerName(src), perm, target))
    TriggerClientEvent('QBCore:Notify', src, ('Set permission for ID %d -> %s'):format(target, perm), 'success')
    TriggerClientEvent('QBCore:Notify', target, ('Your permission was set to %s'):format(perm), 'error')
end)

RegisterNetEvent('m7mdtool:server:kickPlayer', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    local reason = tostring(payload.reason or 'Kicked by admin')

    if not target or target < 1 then
        TriggerClientEvent('QBCore:Notify', src, 'Target id required', 'error')
        return
    end

    if not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    QBCore.Functions.Kick(target, reason, nil, nil)
    audit('m7mdtool', 'Kick', 'red', ('**%s** kicked **ID %d** (%s)'):format(GetPlayerName(src), target, reason))
    TriggerClientEvent('QBCore:Notify', src, ('Kicked ID %d'):format(target), 'success')
end)

RegisterNetEvent('m7mdtool:server:setMetadata', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    payload = payload or {}
    local target = tonumber(payload.targetId)
    if not target or target < 1 then
        target = src
    end

    local key = trim(tostring(payload.key or ''))
    if key == '' or #key > 48 then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid metadata key', 'error')
        return
    end

    if Config.MetadataAllowedKeys and #Config.MetadataAllowedKeys > 0 then
        local okKey = false
        for _, v in ipairs(Config.MetadataAllowedKeys) do
            if v == key then okKey = true break end
        end
        if not okKey then
            TriggerClientEvent('QBCore:Notify', src, 'Metadata key not allowed', 'error')
            return
        end
    end

    local raw = tostring(payload.value or '')
    if #raw > 2048 then
        TriggerClientEvent('QBCore:Notify', src, 'Value too large', 'error')
        return
    end

    local value = raw
    if payload.valueIsJson == true and raw ~= '' then
        local ok, decoded = pcall(function() return json.decode(raw) end)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, 'Invalid JSON value', 'error')
            return
        end
        value = decoded
    end

    local Player = QBCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    Player.Functions.SetMetaData(key, value)
    audit('m7mdtool', 'SetMetaData', 'yellow', ('**%s** set metadata **%s** for **ID %d**'):format(GetPlayerName(src), key, target))
    TriggerClientEvent('QBCore:Notify', src, ('Set metadata %s for ID %d'):format(key, target), 'success')
end)

RegisterNetEvent('m7mdtool:server:gotoPlayer', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end
    if not ratelimit(lastTeleportAt, src, Config.TeleportCooldownMs) then return end

    payload = payload or {}
    if payload.confirm ~= true then
        TriggerClientEvent('QBCore:Notify', src, 'Confirmation required', 'error')
        return
    end

    local target = tonumber(payload.targetId)
    if not target or target < 1 or not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    local ped = GetPlayerPed(target)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerClientEvent('m7mdtool:client:teleport', src, { x = coords.x, y = coords.y, z = coords.z, h = heading })
    audit('m7mdtool', 'Goto', 'blue', ('**%s** goto **ID %d**'):format(GetPlayerName(src), target))
end)

RegisterNetEvent('m7mdtool:server:bringPlayer', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end
    if not ratelimit(lastTeleportAt, src, Config.TeleportCooldownMs) then return end

    payload = payload or {}
    if payload.confirm ~= true then
        TriggerClientEvent('QBCore:Notify', src, 'Confirmation required', 'error')
        return
    end

    local target = tonumber(payload.targetId)
    if not target or target < 1 or not GetPlayerName(target) then
        TriggerClientEvent('QBCore:Notify', src, 'Target not online', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    TriggerClientEvent('m7mdtool:client:teleport', target, { x = coords.x, y = coords.y, z = coords.z, h = heading })
    audit('m7mdtool', 'Bring', 'blue', ('**%s** bring **ID %d**'):format(GetPlayerName(src), target))
end)

RegisterNetEvent('m7mdtool:server:teleportToCoords', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end
    if not ratelimit(lastTeleportAt, src, Config.TeleportCooldownMs) then return end

    payload = payload or {}
    if payload.confirm ~= true then
        TriggerClientEvent('QBCore:Notify', src, 'Confirmation required', 'error')
        return
    end

    local x, y, z = tonumber(payload.x), tonumber(payload.y), tonumber(payload.z)
    if not x or not y or not z then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid coords', 'error')
        return
    end

    local h = tonumber(payload.h) or 0.0
    TriggerClientEvent('m7mdtool:client:teleport', src, { x = x, y = y, z = z, h = h })
    audit('m7mdtool', 'Teleport', 'blue', ('**%s** teleported to coords'):format(GetPlayerName(src)))
end)

RegisterNetEvent('m7mdtool:server:triggerWhitelistedEvent', function(payload)
    local src = source
    if not isAllowed(src) then return deny(src) end

    if not Config.EnableEventTester then
        TriggerClientEvent('QBCore:Notify', src, 'Event tester disabled', 'error')
        return
    end

    payload = payload or {}
    local eventName = trim(tostring(payload.eventName or ''))
    if eventName == '' then
        TriggerClientEvent('QBCore:Notify', src, 'Event name required', 'error')
        return
    end

    local allowed = false
    for _, v in ipairs(Config.EventTesterAllowedEvents) do
        if v == eventName then
            allowed = true
            break
        end
    end

    if not allowed then
        TriggerClientEvent('QBCore:Notify', src, 'Event not allowed', 'error')
        return
    end

    local jsonPayload = tostring(payload.jsonPayload or '')
    if #jsonPayload > Config.EventTesterMaxPayloadBytes then
        TriggerClientEvent('QBCore:Notify', src, 'Payload too large', 'error')
        return
    end

    local decoded
    if jsonPayload ~= '' then
        local ok, res = pcall(function() return json.decode(jsonPayload) end)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, 'Invalid JSON payload', 'error')
            return
        end
        decoded = res
    end

    TriggerEvent(eventName, decoded, src)
    audit('m7mdtool', 'EventTester', 'orange', ('**%s** triggered event **%s**'):format(GetPlayerName(src), eventName))
    TriggerClientEvent('QBCore:Notify', src, 'Event triggered', 'success')
end)

