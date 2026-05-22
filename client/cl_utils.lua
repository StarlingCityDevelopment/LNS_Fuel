local Settings = lib.load('shared.settings')
local clientHelpers = {}

function clientHelpers.createBlip(pos, name)
    local newBlip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(newBlip, 361)
    SetBlipDisplay(newBlip, 4)
    SetBlipScale(newBlip, 0.8)
    SetBlipColour(newBlip, 6)
    SetBlipAsShortRange(newBlip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(name or locale('fuel_station_blip'))
    EndTextCommandSetBlipName(newBlip)

    return newBlip
end

function clientHelpers.updateBlipName(blip, name)
    if not blip or not DoesBlipExist(blip) then return end
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
end

function clientHelpers.getVehicleInFront()
    local playerPed = cache.ped
    local plyCoords = GetEntityCoords(playerPed)
    local targetPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.2, -0.25)
    
    local rayHandle = StartShapeTestCapsule(
        plyCoords.x, plyCoords.y, plyCoords.z, 
        targetPos.x, targetPos.y, targetPos.z, 
        2.2, 2, playerPed, 4
    )

    while true do
        Wait(0)
        local result, _, _, _, hitEntity = GetShapeTestResult(rayHandle)

        if result ~= 1 then
            if hitEntity ~= 0 then
                return hitEntity
            end
            return false
        end
    end
end

local vehicleBones = {
    'petrolcap',
    'petroltank',
    'petroltank_l',
    'hub_lr',
    'engine',
}

function clientHelpers.getVehiclePetrolCapBoneIndex(vehId)
    for index = 1, #vehicleBones do
        local bIdx = GetEntityBoneIndexByName(vehId, vehicleBones[index])

        if bIdx ~= -1 then
            return bIdx
        end
    end
    return nil
end

local function checkPlayerFunds()
    return exports.ox_inventory:GetItemCount('money')
end

clientHelpers.getMoney = checkPlayerFunds

function clientHelpers.getLocaleData()
    local localeName = GetConvar("ox:locale", "en")
    local fileContent = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(localeName))
    if not fileContent then
        fileContent = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    end
    if fileContent then
        return json.decode(fileContent)
    end
    return {}
end

function clientHelpers.progress(options)
    local progressType = Settings and Settings.progressType or 'circle'
    if progressType == 'bar' then
        return lib.progressBar(options)
    else
        return lib.progressCircle(options)
    end
end

exports('setMoneyCheck', function(customChecker)
    clientHelpers.getMoney = customChecker or checkPlayerFunds
end)

return clientHelpers
