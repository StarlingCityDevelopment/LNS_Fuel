local Settings = lib.load('shared.settings')
local st = require('client.cl_state')
local hlpr = require('client.cl_utils')
local fuelStations = Settings.Stations
local cl_ownership = Settings.ownership and Settings.ownership.enabled and require('client.cl_ownership') or nil

local function GetStationId(coords)
    return string.format("station_%.2f_%.2f", coords.x, coords.y)
end

local function getStationName(stationId)
    if cl_ownership then
        return cl_ownership.getStationName(stationId)
    end
    return locale('fuel_station_blip')
end

if Settings.showBlips == 2 then
    for i = 1, #fuelStations do 
        local stationId = GetStationId(fuelStations[i].blip)
        local blip = hlpr.createBlip(fuelStations[i].blip, getStationName(stationId))
        if cl_ownership then
            cl_ownership.activeBlips[stationId] = blip
        end
    end
end

if Settings.ox_target and Settings.showBlips ~= 1 then return end

local function handleStationEntry(pData)
    if Settings.showBlips == 1 and not pData.blip then
        local stationId = GetStationId(pData.coords)
        pData.blip = hlpr.createBlip(pData.coords, getStationName(stationId))
        if cl_ownership then
            cl_ownership.activeBlips[stationId] = pData.blip
        end
    end
end

local function handleStationProximity(pData)
    if pData.currentDistance > 15 then return end

    local availablePumps = pData.pumps
    local distToPump

    for idx = 1, #availablePumps do
        local currentPump = availablePumps[idx]
        distToPump = #(cache.coords - currentPump)

        if distToPump <= 3 then
            st.nearestPump = currentPump
            
            local activeUI = nil

            repeat
                local plyPos = GetEntityCoords(cache.ped)
                distToPump = #(GetEntityCoords(cache.ped) - currentPump)
                
                local nextUI = nil

                if cache.vehicle then
                    nextUI = locale('leave_vehicle')
                elseif not st.isFueling then
                    local isVehicleClose = st.lastVehicle ~= 0 and #(GetEntityCoords(st.lastVehicle) - plyPos) <= 3

                    if isVehicleClose then
                        nextUI = locale('fuel_help')
                    elseif Settings.petrolCan.enabled then
                        nextUI = locale('petrolcan_help')
                    end
                end
                
                if activeUI ~= nextUI then
                    if nextUI then
                        lib.showTextUI(nextUI, { position = 'right-center', icon = 'gas-pump' })
                    else
                        lib.hideTextUI()
                    end
                    activeUI = nextUI
                end

                Wait(0)
            until distToPump > 3
            
            if activeUI then
                lib.hideTextUI()
            end

            st.nearestPump = nil
            return
        end
    end
end

local function handleStationExit(pData)
    if pData.blip then
        pData.blip = RemoveBlip(pData.blip)
        if cl_ownership then
            local stationId = GetStationId(pData.coords)
            cl_ownership.activeBlips[stationId] = nil
        end
    end
end

for i = 1, #fuelStations do
    local station = fuelStations[i]
    lib.points.new({
        coords = station.blip,
        distance = 60,
        onEnter = handleStationEntry,
        onExit = handleStationExit,
        nearby = handleStationProximity,
        pumps = station.pumps,
    })
end
