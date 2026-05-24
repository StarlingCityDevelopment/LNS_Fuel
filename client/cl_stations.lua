local Settings = lib.load('shared.settings')
local st = require('client.cl_state')
local hlpr = require('client.cl_utils')
local fuelStations = Settings.Stations
local cl_ownership = Settings.ownership and Settings.ownership.enabled and require('client.cl_ownership') or nil

local function GetStationId(coords)
    return string.format("station_%.2f_%.2f", coords.x, coords.y)
end

local function getStationName(stationId, station)
    if station.electricpumps or station.electricPumps then
        return locale('charging_station_blip')
    end
    if cl_ownership then
        local name = cl_ownership.getStationName(stationId)
        if name and name ~= locale('fuel_station_blip') then
            return name
        end
    end
    return locale('fuel_station_blip')
end

if Settings.showBlips == 2 then
    for i = 1, #fuelStations do 
        local station = fuelStations[i]
        local stationId = GetStationId(station.blip)
        local isElectric = station.cantBeOwned and (station.electricpumps ~= nil or station.electricPumps ~= nil)
        local sprite = isElectric and 354 or 361
        local color = isElectric and 3 or 6
        local blip = hlpr.createBlip(station.blip, getStationName(stationId, station), sprite, color)
        if cl_ownership then
            cl_ownership.activeBlips[stationId] = blip
        end
    end
end

if Settings.ox_target and Settings.showBlips ~= 1 then return end

local function handleStationEntry(pData)
    if Settings.showBlips == 1 and not pData.blip then
        local stationId = GetStationId(pData.coords)
        local isElectric = pData.cantBeOwned and (pData.electricpumps ~= nil or pData.electricPumps ~= nil)
        local sprite = isElectric and 354 or 361
        local color = isElectric and 3 or 6
        pData.blip = hlpr.createBlip(pData.coords, getStationName(stationId, pData), sprite, color)
        if cl_ownership then
            cl_ownership.activeBlips[stationId] = pData.blip
        end
    end
end

local function handleStationProximity(pData)
    if pData.currentDistance > 15 then return end

    local availablePumps = pData.pumps or {}
    local electricPumps = pData.electricpumps or {}

    local allPumps = {}
    for i = 1, #availablePumps do allPumps[#allPumps+1] = availablePumps[i] end
    for i = 1, #electricPumps do
        local coords = type(electricPumps[i]) == "table" and electricPumps[i].coords or electricPumps[i]
        local vec3Coords = type(coords) == "table" and vec3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]) or coords
        if type(vec3Coords) == "vector4" then
            vec3Coords = vec3(vec3Coords.x, vec3Coords.y, vec3Coords.z)
        end
        allPumps[#allPumps+1] = vec3Coords
    end

    if cl_ownership then
        local stationId = GetStationId(pData.coords)
        local sData = cl_ownership.ownedStations[stationId]
        if sData and sData.electric_chargers then
            for _, charger in ipairs(sData.electric_chargers) do
                local coords = charger.coords
                local vec3Coords = type(coords) == "table" and vec3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3]) or coords
                if type(vec3Coords) == "vector4" then
                    vec3Coords = vec3(vec3Coords.x, vec3Coords.y, vec3Coords.z)
                end
                allPumps[#allPumps+1] = vec3Coords
            end
        end
    end

    local distToPump

    for idx = 1, #allPumps do
        local currentPump = allPumps[idx]
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
        electricpumps = station.electricpumps or station.electricPumps,
        cantBeOwned = station.cantBeOwned,
    })
end