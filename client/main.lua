local QBCore = exports['qb-core']:GetCoreObject()

local nuiOpen = false
local activeTab = 'give'

local overlayEnabled = false

local initCache = {
    items = nil,
    moneyTypes = nil,
    jobs = nil,
    gangs = nil,
}

local zoneBuilder = {
    mode = 'poly', 
    preview = false,
    points = {},
    center = nil, 
    radius = 3.0,
    length = 3.0,
    width = 3.0,
    minZ = nil,
    maxZ = nil,
    heading = 0.0,
}

local function setNui(open, tab)
    nuiOpen = open and true or false
    activeTab = tab or activeTab
    SetNuiFocus(nuiOpen, nuiOpen)
    SetNuiFocusKeepInput(false)
end

local function notify(msg, ntype)
    if lib and lib.notify then
        lib.notify({
            title = Config.ToolName,
            description = msg,
            type = ntype or 'inform',
        })
        return
    end
    TriggerEvent('QBCore:Notify', msg, ntype or 'primary')
end

local function fmt(num)
    return string.format('%.3f', num + 0.0)
end

local lastCmdAt = 0
local function safeExecuteCommand(cmd)
    if type(cmd) ~= 'string' then return end
    cmd = cmd:gsub('^%s*(.-)%s*$', '%1')
    if cmd == '' then return end
    if #cmd > 256 or cmd:find('[\r\n]') then return end

    local now = GetGameTimer()
    if (now - lastCmdAt) < (Config.SlashlessCooldownMs or 250) then
        return
    end
    lastCmdAt = now
    ExecuteCommand(cmd)
end

local function getCoordsPacket()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rot = GetEntityRotation(ped, 2)

    local streetName = ''
    if Config.EnableCopyStreetName then
        local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local s1 = streetHash and GetStreetNameFromHashKey(streetHash) or ''
        local s2 = crossHash and GetStreetNameFromHashKey(crossHash) or ''
        if s1 ~= '' and s2 ~= '' then
            streetName = ('%s / %s'):format(s1, s2)
        else
            streetName = s1 ~= '' and s1 or s2
        end
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading,
        rx = rot.x,
        ry = rot.y,
        rz = rot.z,
        street = streetName,
    }
end

local function buildCoordString(packet, formatId)
    local x, y, z, h = fmt(packet.x), fmt(packet.y), fmt(packet.z), fmt(packet.h)

    if formatId == 'vector3' then
        return ('vector3(%s, %s, %s)'):format(x, y, z)
    elseif formatId == 'vector4' then
        return ('vector4(%s, %s, %s, %s)'):format(x, y, z, h)
    elseif formatId == 'vec3' then
        return ('vec3(%s, %s, %s)'):format(x, y, z)
    elseif formatId == 'vec4' then
        return ('vec4(%s, %s, %s, %s)'):format(x, y, z, h)
    elseif formatId == 'json' then
        return ('{"x":%s,"y":%s,"z":%s,"h":%s}'):format(x, y, z, h)
    elseif formatId == 'configSnippet' then
        return ('Config.Locations = { vec4(%s, %s, %s, %s) }'):format(x, y, z, h)
    elseif formatId == 'teleportSnippet' then
        return ('SetEntityCoords(PlayerPedId(), %s, %s, %s)'):format(x, y, z)
    elseif formatId == 'street' then
        return packet.street or ''
    end

    return ('vec4(%s, %s, %s, %s)'):format(x, y, z, h)
end

RegisterNetEvent('m7mdtool:client:open', function(tab)
    if nuiOpen then
        SendNUIMessage({ action = 'setTab', tab = tab or 'give' })
        activeTab = tab or activeTab
        return
    end

    local items = lib.callback.await('m7mdtool:getItems', false)
    if not items then
        notify('Not allowed or failed to load items list', 'error')
        return
    end

    initCache.items = items
    initCache.moneyTypes = lib.callback.await('m7mdtool:getMoneyTypes', false) or { 'cash', 'bank' }
    initCache.jobs = lib.callback.await('m7mdtool:getJobs', false) or {}
    initCache.gangs = lib.callback.await('m7mdtool:getGangs', false) or {}

    setNui(true, tab or 'give')

    SendNUIMessage({
        action = 'open',
        tab = tab or 'give',
        items = initCache.items,
        moneyTypes = initCache.moneyTypes,
        jobs = initCache.jobs,
        gangs = initCache.gangs,
        config = {
            maxGiveAmount = Config.MaxGiveAmount,
            maxRemoveAmount = Config.MaxRemoveAmount,
            maxGiveMoney = Config.MaxGiveMoney,
            enableDebugOverlay = Config.EnableDebugOverlay,
            enableCopyStreetName = Config.EnableCopyStreetName,
            enableCopyPlayerInfo = Config.EnableCopyPlayerInfo,
            enableEventTester = Config.EnableEventTester,
        },
    })
end)

local function toggleOverlay(enabled)
    if not Config.EnableDebugOverlay then
        notify('Overlay disabled by config', 'error')
        return
    end

    overlayEnabled = enabled
    notify(overlayEnabled and 'Overlay enabled' or 'Overlay disabled', overlayEnabled and 'success' or 'inform')
end

RegisterNetEvent('m7mdtool:client:quickMenu', function()
    if not lib or not lib.registerContext or not lib.showContext then
        TriggerEvent('m7mdtool:client:open', 'give')
        return
    end

    lib.registerContext({
        id = 'm7mdtool_quickmenu',
        title = 'M7MD-tool',
        options = {
            {
                title = 'Home',
                description = 'Open toolbox home',
                icon = 'house',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'home')
                end,
            },
            {
                title = 'Give Item',
                description = 'Open Give Item UI',
                icon = 'box',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'give')
                end,
            },
            {
                title = 'Copy Coords',
                description = 'Open Copy Coords UI',
                icon = 'location-dot',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'coords')
                end,
            },
            {
                title = 'Inventory Tools',
                description = 'Remove/Clear items',
                icon = 'boxes-stacked',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'inventory')
                end,
            },
            {
                title = 'Player Tools',
                description = 'Goto/Bring/Job/Gang/Money',
                icon = 'user-gear',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'player')
                end,
            },
            {
                title = 'Zones Builder',
                description = 'Build poly/box/circle snippets',
                icon = 'draw-polygon',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'zones')
                end,
            },
            {
                title = 'Debug',
                description = 'Event tester (whitelist only)',
                icon = 'bug',
                disabled = not Config.EnableEventTester,
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'debug')
                end,
            },
            {
                title = 'Snippets',
                description = 'Generate code templates',
                icon = 'code',
                onSelect = function()
                    TriggerEvent('m7mdtool:client:open', 'snippets')
                end,
            },
            {
                title = 'Toggle Debug Overlay',
                description = 'Show x/y/z/h on-screen',
                icon = 'eye',
                disabled = not Config.EnableDebugOverlay,
                onSelect = function()
                    toggleOverlay(not overlayEnabled)
                end,
            },
        },
    })

    lib.showContext('m7mdtool_quickmenu')
end)

RegisterNetEvent('m7mdtool:client:execCommand', function(cmd)
    if nuiOpen then return end
    safeExecuteCommand(cmd)
end)

RegisterNUICallback('m7mdtool_close', function(_, cb)
    setNui(false)
    SendNUIMessage({ action = 'close' })
    cb(true)
end)

RegisterNUICallback('m7mdtool_giveItem', function(data, cb)
    TriggerServerEvent('m7mdtool:server:giveItem', {
        itemName = data and data.itemName or '',
        amount = data and data.amount or 1,
        targetId = data and data.targetId or nil,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_removeItem', function(data, cb)
    TriggerServerEvent('m7mdtool:server:removeItem', {
        itemName = data and data.itemName or '',
        amount = data and data.amount or 1,
        targetId = data and data.targetId or nil,
        slot = data and data.slot or nil,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_clearInventory', function(data, cb)
    TriggerServerEvent('m7mdtool:server:clearInventory', {
        targetId = data and data.targetId or nil,
        confirm = data and data.confirm == true,
        filterItems = data and data.filterItems or nil,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_giveMoney', function(data, cb)
    TriggerServerEvent('m7mdtool:server:giveMoney', {
        targetId = data and data.targetId or nil,
        moneyType = data and data.moneyType or 'cash',
        amount = data and data.amount or 0,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_setJob', function(data, cb)
    TriggerServerEvent('m7mdtool:server:setJob', {
        targetId = data and data.targetId or nil,
        jobName = data and data.jobName or '',
        grade = data and data.grade or 0,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_setGang', function(data, cb)
    TriggerServerEvent('m7mdtool:server:setGang', {
        targetId = data and data.targetId or nil,
        gangName = data and data.gangName or '',
        grade = data and data.grade or 0,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_getPermission', function(data, cb)
    local targetId = data and data.targetId or nil
    local info = lib.callback.await('m7mdtool:getPermissionInfo', false, targetId)
    cb(info or false)
end)

RegisterNUICallback('m7mdtool_removePermission', function(data, cb)
    TriggerServerEvent('m7mdtool:server:removePermission', { targetId = data and data.targetId or nil })
    cb(true)
end)

RegisterNUICallback('m7mdtool_setPermission', function(data, cb)
    TriggerServerEvent('m7mdtool:server:setPermission', {
        targetId = data and data.targetId or nil,
        permission = data and data.permission or nil,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_kickPlayer', function(data, cb)
    TriggerServerEvent('m7mdtool:server:kickPlayer', {
        targetId = data and data.targetId or nil,
        reason = data and data.reason or nil,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_setMetadata', function(data, cb)
    TriggerServerEvent('m7mdtool:server:setMetadata', {
        targetId = data and data.targetId or nil,
        key = data and data.key or '',
        value = data and data.value or '',
        valueIsJson = data and data.valueIsJson == true,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_goto', function(data, cb)
    TriggerServerEvent('m7mdtool:server:gotoPlayer', {
        targetId = data and data.targetId or nil,
        confirm = data and data.confirm == true,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_bring', function(data, cb)
    TriggerServerEvent('m7mdtool:server:bringPlayer', {
        targetId = data and data.targetId or nil,
        confirm = data and data.confirm == true,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_tpCoords', function(data, cb)
    TriggerServerEvent('m7mdtool:server:teleportToCoords', {
        x = data and data.x or nil,
        y = data and data.y or nil,
        z = data and data.z or nil,
        h = data and data.h or 0,
        confirm = data and data.confirm == true,
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_triggerEvent', function(data, cb)
    TriggerServerEvent('m7mdtool:server:triggerWhitelistedEvent', {
        eventName = data and data.eventName or '',
        jsonPayload = data and data.jsonPayload or '',
    })
    cb(true)
end)

RegisterNUICallback('m7mdtool_copy', function(data, cb)
    data = data or {}
    local formatId = tostring(data.format or 'vec4')
    local packet = getCoordsPacket()
    local text = buildCoordString(packet, formatId)

    if text == '' then
        notify('Nothing to copy', 'error')
        cb(false)
        return
    end

    lib.setClipboard(text)
    notify('Copied to clipboard', 'success')
    cb(true)
end)

RegisterNUICallback('m7mdtool_setClipboard', function(data, cb)
    local text = data and tostring(data.text or '') or ''
    if text == '' then
        notify('Nothing to copy', 'error')
        cb(false)
        return
    end

    lib.setClipboard(text)
    notify('Copied to clipboard', 'success')
    cb(true)
end)

RegisterNUICallback('m7mdtool_copyPlayerInfo', function(_, cb)
    if not Config.EnableCopyPlayerInfo then
        notify('Disabled', 'error')
        cb(false)
        return
    end

    local p = getCoordsPacket()
    local info = lib.callback.await('m7mdtool:getPlayerInfo', false)
    if not info then
        notify('Failed to fetch player info', 'error')
        cb(false)
        return
    end

    local text = ('source=%d name=%s citizenid=%s coords=vec4(%s,%s,%s,%s)'):format(
        info.source,
        tostring(info.name or 'unknown'),
        tostring(info.citizenid or 'unknown'),
        fmt(p.x),
        fmt(p.y),
        fmt(p.z),
        fmt(p.h)
    )

    lib.setClipboard(text)
    notify('Copied player info', 'success')
    cb(true)
end)

RegisterNUICallback('m7mdtool_toggleOverlay', function(data, cb)
    if not Config.EnableDebugOverlay then
        notify('Overlay disabled by config', 'error')
        cb(false)
        return
    end

    toggleOverlay(data and data.enabled and true or false)
    cb(true)
end)

RegisterNetEvent('m7mdtool:client:teleport', function(coords)
    coords = coords or {}
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    local h = tonumber(coords.h) or nil

    local ped = PlayerPedId()
    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    if h then
        SetEntityHeading(ped, h + 0.0)
    end
end)

local function addZonePoint()
    local p = getCoordsPacket()
    zoneBuilder.points[#zoneBuilder.points + 1] = { x = p.x, y = p.y, z = p.z }
end

local function clearZonePoints()
    zoneBuilder.points = {}
end

local function undoZonePoint()
    zoneBuilder.points[#zoneBuilder.points] = nil
end

local function setZoneCenterFromPlayer()
    local p = getCoordsPacket()
    zoneBuilder.center = { x = p.x, y = p.y, z = p.z, h = p.h }
    zoneBuilder.heading = p.h
end

local function buildZoneSnippet(snipType)
    local function f(n) return fmt(n) end
    snipType = tostring(snipType or 'qb-polyzone')

    local mode = zoneBuilder.mode
    local c = zoneBuilder.center or getCoordsPacket()
    local length = tonumber(zoneBuilder.length) or 3.0
    local width = tonumber(zoneBuilder.width) or 3.0
    local heading = tonumber(zoneBuilder.heading) or (c.h or 0.0)
    local minZ = zoneBuilder.minZ and tonumber(zoneBuilder.minZ) or (c.z - 1.0)
    local maxZ = zoneBuilder.maxZ and tonumber(zoneBuilder.maxZ) or (c.z + 2.0)
    local r = tonumber(zoneBuilder.radius) or 3.0
    local height = (maxZ - minZ)

    if snipType == 'ox_lib' then
        if mode == 'circle' then
            return ("local zone = lib.zones.sphere({ coords = vec3(%s, %s, %s), radius = %s, debug = false, inside = function(self) end })"):format(
                f(c.x), f(c.y), f(c.z), f(r)
            )
        elseif mode == 'box' then
            return ("local zone = lib.zones.box({ coords = vec3(%s, %s, %s), size = vec3(%s, %s, %s), rotation = %s, debug = false, inside = function(self) end })"):format(
                f(c.x), f(c.y), f(c.z), f(length), f(width), f(height > 0 and height or 3.0), f(heading)
            )
        end

        if #zoneBuilder.points < 3 then
            return '-- Need at least 3 points for poly zone'
        end
        local parts = {}
        for i = 1, #zoneBuilder.points do
            local p = zoneBuilder.points[i]
            parts[#parts + 1] = ("vec3(%s, %s, %s)"):format(f(p.x), f(p.y), f(p.z))
        end
        return ("local zone = lib.zones.poly({ points = { %s }, thickness = %s, debug = false, inside = function(self) end })"):format(
            table.concat(parts, ', '),
            f(height > 0 and height or 4.0)
        )
    end

    if snipType == 'qb-target' then
        if mode == 'circle' then
            return ("exports['qb-target']:AddCircleZone('m7_zone', vector3(%s, %s, %s), %s, { name = 'm7_zone', useZ = true, debugPoly = false }, { options = { { type = 'client', event = 'your:event', icon = 'fa-solid fa-circle', label = 'Interact' } }, distance = 2.0 })"):format(
                f(c.x), f(c.y), f(c.z), f(r)
            )
        elseif mode == 'box' then
            return ("exports['qb-target']:AddBoxZone('m7_zone', vector3(%s, %s, %s), %s, %s, { name = 'm7_zone', heading = %s, minZ = %s, maxZ = %s, debugPoly = false }, { options = { { type = 'client', event = 'your:event', icon = 'fa-solid fa-box', label = 'Interact' } }, distance = 2.0 })"):format(
                f(c.x), f(c.y), f(c.z), f(length), f(width), f(heading), f(minZ), f(maxZ)
            )
        end

        if #zoneBuilder.points < 3 then
            return '-- Need at least 3 points for poly zone'
        end
        local parts = {}
        for i = 1, #zoneBuilder.points do
            local p = zoneBuilder.points[i]
            parts[#parts + 1] = ("vector2(%s, %s)"):format(f(p.x), f(p.y))
        end
        return ("exports['qb-target']:AddPolyZone('m7_zone', { %s }, { name = 'm7_zone', minZ = %s, maxZ = %s, debugPoly = false }, { options = { { type = 'client', event = 'your:event', icon = 'fa-solid fa-draw-polygon', label = 'Interact' } }, distance = 2.0 })"):format(
            table.concat(parts, ', '),
            f(minZ),
            f(maxZ)
        )
    end


    if mode == 'circle' then
        return ("CircleZone:Create(vector3(%s, %s, %s), %s, { name = 'm7_zone', debugPoly = false })"):format(
            f(c.x), f(c.y), f(c.z), f(r)
        )
    elseif mode == 'box' then
        return ("BoxZone:Create(vector3(%s, %s, %s), %s, %s, { name = 'm7_zone', heading = %s, minZ = %s, maxZ = %s, debugPoly = false })"):format(
            f(c.x), f(c.y), f(c.z), f(length), f(width), f(heading), f(minZ), f(maxZ)
        )
    end

    if #zoneBuilder.points < 3 then
        return '-- Need at least 3 points for PolyZone'
    end

    local parts = {}
    for i = 1, #zoneBuilder.points do
        local p = zoneBuilder.points[i]
        parts[#parts + 1] = ("vector2(%s, %s)"):format(f(p.x), f(p.y))
    end

    return ("PolyZone:Create({ %s }, { name = 'm7_zone', debugPoly = false })"):format(table.concat(parts, ', '))
end

RegisterNUICallback('m7mdtool_zones', function(data, cb)
    data = data or {}
    local action = tostring(data.action or '')

    if action == 'setMode' then
        zoneBuilder.mode = tostring(data.mode or 'poly')
        if zoneBuilder.mode ~= 'poly' and zoneBuilder.mode ~= 'circle' and zoneBuilder.mode ~= 'box' then
            zoneBuilder.mode = 'poly'
        end
        if zoneBuilder.mode ~= 'poly' then
            setZoneCenterFromPlayer()
        end
        cb(true)
        return
    elseif action == 'togglePreview' then
        zoneBuilder.preview = data.enabled and true or false
        cb(true)
        return
    elseif action == 'addPoint' then
        addZonePoint()
        cb(true)
        return
    elseif action == 'undoPoint' then
        undoZonePoint()
        cb(true)
        return
    elseif action == 'clearPoints' then
        clearZonePoints()
        cb(true)
        return
    elseif action == 'setParams' then
        if type(data.radius) == 'number' then zoneBuilder.radius = data.radius end
        if type(data.length) == 'number' then zoneBuilder.length = data.length end
        if type(data.width) == 'number' then zoneBuilder.width = data.width end
        if data.minZ ~= nil then zoneBuilder.minZ = data.minZ end
        if data.maxZ ~= nil then zoneBuilder.maxZ = data.maxZ end
        if data.heading ~= nil then zoneBuilder.heading = data.heading end
        cb(true)
        return
    elseif action == 'copySnippet' then
        local text = buildZoneSnippet(data.snipType)
        lib.setClipboard(text)
        notify('Copied zone snippet', 'success')
        cb(true)
        return
    end

    cb(false)
end)

CreateThread(function()
    while true do
        if nuiOpen then
            local packet = getCoordsPacket()
            SendNUIMessage({ action = 'coords', data = packet })
            Wait(250)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if nuiOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)
            DisablePlayerFiring(PlayerId(), true)
            Wait(0)
        else
            Wait(200)
        end
    end
end)

CreateThread(function()
    while true do
        if zoneBuilder.preview then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)

            if zoneBuilder.mode == 'poly' then
                for i = 1, #zoneBuilder.points do
                    local p = zoneBuilder.points[i]
                    DrawMarker(2, p.x, p.y, p.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.22, 0.22, 0.22, 91, 155, 255, 150, false, false, 2, false, nil, nil, false)
                    if i > 1 then
                        local p2 = zoneBuilder.points[i - 1]
                        DrawLine(p2.x, p2.y, p2.z + 0.2, p.x, p.y, p.z + 0.2, 91, 155, 255, 180)
                    end
                end
                if #zoneBuilder.points > 2 then
                    local first = zoneBuilder.points[1]
                    local last = zoneBuilder.points[#zoneBuilder.points]
                    DrawLine(last.x, last.y, last.z + 0.2, first.x, first.y, first.z + 0.2, 91, 155, 255, 120)
                end
            else
                local c = zoneBuilder.center or { x = pcoords.x, y = pcoords.y, z = pcoords.z }
                DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.9, 0.25, 71, 209, 140, 120, false, false, 2, false, nil, nil, false)
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        if overlayEnabled and Config.EnableDebugOverlay then
            local p = getCoordsPacket()
            local txt = ('x=%s y=%s z=%s h=%s'):format(fmt(p.x), fmt(p.y), fmt(p.z), fmt(p.h))

            SetTextFont(4)
            SetTextProportional(0)
            SetTextScale(0.32, 0.32)
            SetTextColour(255, 255, 255, 210)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString(txt)
            DrawText(0.015, 0.72)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if nuiOpen then
        setNui(false)
    end
end)

