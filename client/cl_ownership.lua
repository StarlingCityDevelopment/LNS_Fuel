local Settings = lib.load('shared.settings')
if not Settings or not Settings.ownership or not Settings.ownership.enabled then return {} end

local hlpr = require('client.cl_utils')
local cl_ownership = {
    ownedStations = {},
    activeBlips = {},
    loaded = false
}

function GetStationId(coords)
    return string.format("station_%.2f_%.2f", coords.x, coords.y)
end

function cl_ownership.getStationName(stationId, isElectric)
    local station = cl_ownership.ownedStations[stationId]
    if station and station.name then
        return station.name
    end
    return isElectric and (locale('charging_station_blip') or "Public EV Charging Station") or locale('fuel_station_blip')
end

local function isStationElectric(stationId)
    local fuelStations = Settings.Stations
    for i = 1, #fuelStations do
        local station = fuelStations[i]
        local sid = string.format("station_%.2f_%.2f", station.blip.x, station.blip.y)
        if sid == stationId and station.cantBeOwned and (station.electricpumps ~= nil or station.electricPumps ~= nil) then
            return true
        end
    end
    return false
end

RegisterNetEvent('LNS_Fuel:syncStation', function(stationId, data)
    cl_ownership.ownedStations[stationId] = data
    
    local blip = cl_ownership.activeBlips[stationId]
    if blip then
        local isElectric = isStationElectric(stationId)
        local name = data and data.name or (isElectric and locale('charging_station_blip') or locale('fuel_station_blip'))
        hlpr.updateBlipName(blip, name)
    end
    
    SendNUIMessage({
        action = "updateUI",
        station = data
    })
end)

function cl_ownership.openManagement(stationId)
    local data = lib.callback.await('LNS_Fuel:getStationManagement', false, stationId)
    
    if not data then
        return lib.notify({ type = 'error', description = locale('notify_not_station_owner') })
    end

    if not data.id or not data.stock then
        return lib.notify({ type = 'error', description = "Failed to load station data." })
    end

    data.hasElectric = true
    data.electricPumpsCount = 0

    local configToSend = {
        minPrice = Settings.ownership.minPriceTick,
        maxPrice = Settings.ownership.maxPriceTick,
        minElectricPrice = Settings.ownership.minElectricPriceTick or 1,
        maxElectricPrice = Settings.ownership.maxElectricPriceTick or 10,
        stockOrders = Settings.ownership.stockOrders,
        upgrades = Settings.ownership.upgrades,
        theme = Settings.theme,
        aiDispatchFee = Settings.ownership.delivery.aiDispatchFee or 250,
        chargerPrice = Settings.ownership.chargerPrice or 5000,
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openUI",
        station = data,
        config = configToSend,
        locales = hlpr.getLocaleData()
    })
end

function cl_ownership.promptPurchase(stationId)
    local alert = lib.alertDialog({
        header = 'Purchase Gas Station',
        content = ('Are you sure you want to purchase this gas station for $%s?'):format(Settings.ownership.defaultPurchasePrice),
        centered = true,
        cancel = true
    })
    
    if alert == 'confirm' then
        local success, msg = lib.callback.await('LNS_Fuel:buyStation', false, stationId)
        if success then
            lib.notify({ type = 'success', description = msg })
        else
            lib.notify({ type = 'error', description = msg })
        end
    end
end

CreateThread(function()
    cl_ownership.ownedStations = lib.callback.await('LNS_Fuel:getStationsData', false)
    cl_ownership.loaded = true
    
    for stationId, blip in pairs(cl_ownership.activeBlips) do
        local isElectric = isStationElectric(stationId)
        local name = cl_ownership.getStationName(stationId, isElectric)
        hlpr.updateBlipName(blip, name)
    end

    local fuelStations = Settings.Stations
    for i = 1, #fuelStations do
        local station = fuelStations[i]
        if not station.cantBeOwned then
            local stationId = GetStationId(station.blip)
            local managementCoords = station.management or station.blip

            if Settings.ox_target then
                exports.ox_target:addBoxZone({
                    coords = managementCoords,
                    size = vec3(2.5, 2.5, 2.5),
                    rotation = 0.0,
                    debug = false,
                    options = {
                        {
                            name = 'lns_fuel_manage_' .. stationId,
                            icon = 'fas fa-briefcase',
                            label = locale('target_manage_buy'),
                            onSelect = function()
                                local data = cl_ownership.ownedStations[stationId]
                                if data and data.owner then
                                    cl_ownership.openManagement(stationId)
                                else
                                    cl_ownership.promptPurchase(stationId)
                                end
                            end
                        }
                    }
                })
            else
                lib.points.new({
                    coords = managementCoords,
                    distance = 2.0,
                    nearby = function(self)
                        DrawMarker(27, self.coords.x, self.coords.y, self.coords.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.2, 0, 150, 255, 100, false, true, 2, nil, nil, false)
                        
                        local data = cl_ownership.ownedStations[stationId]
                        local text = ""
                        if data and data.owner then
                            text = locale('textui_manage_station', data.name)
                        else
                            text = locale('textui_purchase_station', Settings.ownership.defaultPurchasePrice)
                        end
                        
                        lib.showTextUI(text, { position = 'right-center', icon = 'briefcase' })
                        
                        if IsControlJustPressed(0, 47) then
                            lib.hideTextUI()
                            if data and data.owner then
                                cl_ownership.openManagement(stationId)
                            else
                                cl_ownership.promptPurchase(stationId)
                            end
                        end
                    end,
                    onExit = function()
                        lib.hideTextUI()
                    end
                })
            end
        end
    end
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('renameStation', function(data, cb)
    TriggerServerEvent('LNS_Fuel:renameStation', data.stationId, data.name)
    cb('ok')
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
    TriggerServerEvent('LNS_Fuel:withdrawMoney', data.stationId, data.amount)
    cb('ok')
end)

RegisterNUICallback('depositMoney', function(data, cb)
    TriggerServerEvent('LNS_Fuel:depositMoney', data.stationId, data.amount)
    cb('ok')
end)

RegisterNUICallback('setPrice', function(data, cb)
    TriggerServerEvent('LNS_Fuel:setPrice', data.stationId, data.price)
    cb('ok')
end)

RegisterNUICallback('setElectricPrice', function(data, cb)
    TriggerServerEvent('LNS_Fuel:setElectricPrice', data.stationId, data.electricPrice)
    cb('ok')
end)

RegisterNUICallback('orderStock', function(data, cb)
    TriggerServerEvent('LNS_Fuel:orderStock', data.stationId, data.index, data.isAuto)
    cb('ok')
end)

RegisterNUICallback('buyUpgrade', function(data, cb)
    TriggerServerEvent('LNS_Fuel:buyUpgrade', data.stationId, data.upgradeType)
    cb('ok')
end)

RegisterNUICallback('sellStation', function(data, cb)
    TriggerServerEvent('LNS_Fuel:sellStation', data.stationId)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    TriggerServerEvent('LNS_Fuel:hireEmployee', data.stationId, data.serverId)
    cb('ok')
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    TriggerServerEvent('LNS_Fuel:fireEmployee', data.stationId, data.identifier)
    cb('ok')
end)

RegisterNUICallback('startPlacementMode', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
    if data and data.stationId then
        startChargerPlacement(data.stationId)
    end
end)

RegisterNUICallback('removeCharger', function(data, cb)
    cb('ok')
    if data and data.stationId and data.chargerIndex then
        TriggerServerEvent('LNS_Fuel:removeCharger', data.stationId, data.chargerIndex)
    end
end)

return cl_ownership