local Settings = lib.load('shared.settings')
if not Settings or not Settings.Stations then return end

local cl_ownership = Settings.ownership and Settings.ownership.enabled and require('client.cl_ownership') or nil

local spawnedProps = {}
local isPlacing = false

local function despawnStationChargers(stationId)
    if spawnedProps[stationId] then
        for i = 1, #spawnedProps[stationId] do
            local obj = spawnedProps[stationId][i]
            if DoesEntityExist(obj) then
                DeleteObject(obj)
            end
        end
        spawnedProps[stationId] = nil
    end
end

local function spawnStationChargers(stationId, chargers)
    despawnStationChargers(stationId)
    if not chargers or #chargers == 0 then return end

    spawnedProps[stationId] = {}
    local model = `electric_charger`
    if not lib.requestModel(model, 5000) then return end

    for i = 1, #chargers do
        local charger = chargers[i]
        local coords = charger.coords
        local heading = charger.heading or 0.0

        local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
        if obj and obj ~= 0 then
            SetEntityHeading(obj, heading)
            FreezeEntityPosition(obj, true)
            SetEntityInvincible(obj, true)
            table.insert(spawnedProps[stationId], obj)
        end
    end
    SetModelAsNoLongerNeeded(model)
end

local function initDynamicChargers()
    if cl_ownership then
        while not cl_ownership.loaded do
            Wait(100)
        end
        for stationId, data in pairs(cl_ownership.ownedStations) do
            if data and data.electric_chargers then
                spawnStationChargers(stationId, data.electric_chargers)
            end
        end
    end
end

RegisterNetEvent('LNS_Fuel:syncStation', function(stationId, data)
    if data and data.electric_chargers then
        spawnStationChargers(stationId, data.electric_chargers)
    else
        despawnStationChargers(stationId)
    end
end)

local function RotationToDirection(rotation)
    local adjustedRotation = vec3(
        (math.pi / 180.0) * rotation.x,
        (math.pi / 180.0) * rotation.y,
        (math.pi / 180.0) * rotation.z
    )
    return vec3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
end

local function GetCameraRaycast(ignoreEntity, maxDistance)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotationToDirection(camRot)
    local destination = camCoords + (direction * (maxDistance or 15.0))

    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        destination.x, destination.y, destination.z,
        17,
        ignoreEntity,
        4
    )
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit, endCoords
end

function startChargerPlacement(stationId)
    if isPlacing then return end
    isPlacing = true

    local stationConf = nil
    for i = 1, #Settings.Stations do
        local testId = string.format("station_%.2f_%.2f", Settings.Stations[i].blip.x, Settings.Stations[i].blip.y)
        if testId == stationId then
            stationConf = Settings.Stations[i]
            break
        end
    end

    if not stationConf then
        isPlacing = false
        return
    end

    local stationCenter = stationConf.management or stationConf.blip
    local maxRange = Settings.ownership.chargerPlacementRange or 35.0

    local model = `electric_charger`
    if not lib.requestModel(model, 5000) then
        isPlacing = false
        return
    end

    local playerPed = cache.ped
    local startCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 3.0, 0.0)
    local ghostObj = CreateObjectNoOffset(model, startCoords.x, startCoords.y, startCoords.z, false, false, false)
    SetEntityAlpha(ghostObj, 150, false)
    SetEntityCollision(ghostObj, false, false)
    PlaceObjectOnGroundProperly(ghostObj)

    local currentHeading = GetEntityHeading(playerPed)

    lib.showTextUI(locale('textui_place_charger'), { position = 'bottom-center', icon = 'bolt' })

    CreateThread(function()
        local lastUpdate = 0
        local targetPos = startCoords
        local lastInRange = true
        local inRange = true

        while isPlacing do
            Wait(0)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 200, true)

            local now = GetGameTimer()
            if now - lastUpdate > 30 then
                lastUpdate = now

                local hit, endCoords = GetCameraRaycast(ghostObj, 25.0)
                if hit and hit ~= 0 then
                    targetPos = endCoords
                else
                    local camCoords = GetGameplayCamCoord()
                    local camRot = GetGameplayCamRot(2)
                    local direction = RotationToDirection(camRot)
                    targetPos = camCoords + (direction * 8.0)
                end

                local groundExists, groundZ = GetGroundZFor_3dCoord(targetPos.x, targetPos.y, targetPos.z + 2.0, false)
                if groundExists then
                    targetPos = vec3(targetPos.x, targetPos.y, groundZ)
                else
                    local plyCoords = GetEntityCoords(cache.ped)
                    targetPos = vec3(targetPos.x, targetPos.y, plyCoords.z - 1.0)
                end

                local dist = #(targetPos - stationCenter)
                inRange = dist <= maxRange

                if inRange ~= lastInRange then
                    lastInRange = inRange
                    if inRange then
                        lib.showTextUI(locale('textui_place_charger'), { position = 'bottom-center', icon = 'bolt' })
                    else
                        lib.showTextUI(locale('textui_too_far_station'), { position = 'bottom-center', icon = 'triangle-exclamation' })
                    end
                end
            end

            SetEntityCoordsNoOffset(ghostObj, targetPos.x, targetPos.y, targetPos.z, false, false, false)
            SetEntityHeading(ghostObj, currentHeading)

            if IsControlJustPressed(0, 241) then
                currentHeading = (currentHeading - 5.0) % 360.0
            elseif IsControlJustPressed(0, 242) then
                currentHeading = (currentHeading + 5.0) % 360.0
            end

            if inRange then
                DrawMarker(27, targetPos.x, targetPos.y, targetPos.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.5, 0, 200, 0, 100, false, true, 2, nil, nil, false)
            else
                DrawMarker(27, targetPos.x, targetPos.y, targetPos.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.5, 200, 0, 0, 100, false, true, 2, nil, nil, false)
            end

            if inRange and IsDisabledControlJustPressed(0, 38) then
                isPlacing = false
                DeleteObject(ghostObj)
                lib.hideTextUI()
                TriggerServerEvent('LNS_Fuel:addCharger', stationId, targetPos, currentHeading)
                break
            end

            if IsDisabledControlJustPressed(0, 200) or IsControlJustPressed(0, 177) then
                isPlacing = false
                DeleteObject(ghostObj)
                lib.hideTextUI()
                break
            end
        end
        SetModelAsNoLongerNeeded(model)
    end)
end

local function spawnStaticPublicChargers()
    local model = `electric_charger`
    if not lib.requestModel(model, 5000) then return end

    for i = 1, #Settings.Stations do
        local station = Settings.Stations[i]
        local chargers = station.electricpumps or station.electricPumps
        if chargers then
            local stationId = string.format("static_station_%d", i)
            spawnedProps[stationId] = {}
            for j = 1, #chargers do
                local charger = chargers[j]
                local rawCoords = type(charger) == "table" and (charger.coords or charger) or charger
                local coords = type(rawCoords) == "table" and vec3(rawCoords.x or rawCoords[1], rawCoords.y or rawCoords[2], rawCoords.z or rawCoords[3]) or rawCoords
                if type(coords) == "vector4" then
                    coords = vec3(coords.x, coords.y, coords.z)
                end
                
                local heading = type(charger) == "table" and charger.heading or 0.0
                if type(rawCoords) == "vector4" then
                    heading = rawCoords.w
                end

                local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
                if obj and obj ~= 0 then
                    SetEntityHeading(obj, heading)
                    FreezeEntityPosition(obj, true)
                    SetEntityInvincible(obj, true)
                    table.insert(spawnedProps[stationId], obj)
                end
            end
        end
    end
    SetModelAsNoLongerNeeded(model)
end

local function cleanAllChargers()
    for stationId, _ in pairs(spawnedProps) do
        despawnStationChargers(stationId)
    end
end

CreateThread(function()
    initDynamicChargers()
    spawnStaticPublicChargers()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        cleanAllChargers()
    end
end)