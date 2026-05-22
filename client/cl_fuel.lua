local Settings = lib.load('shared.settings')
local st = require('client.cl_state')
local hlpr = require('client.cl_utils')

local fuelModule = {}

function fuelModule.setFuel(stateBag, veh, amt, sync)
    if not DoesEntityExist(veh) then return end
    
    local safeAmt = math.clamp(amt, 0, 100)
    SetVehicleFuelLevel(veh, safeAmt)
    stateBag:set('fuel', safeAmt, sync)
end

local cl_ownership = Settings.ownership and Settings.ownership.enabled and require('client.cl_ownership') or nil

local function GetStationId(coords)
    return string.format("station_%.2f_%.2f", coords.x, coords.y)
end

function fuelModule.getPetrolCan(pos, isRefilling)
    local playerPed = cache.ped
    TaskTurnPedToFaceCoord(playerPed, pos.x, pos.y, pos.z, Settings.petrolCan.duration)
    Wait(500)

    local success = hlpr.progress({
        duration = Settings.petrolCan.duration,
        label = locale('petrolcan_buy_or_refill'),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'timetable@gardener@filling_can',
            clip = 'gar_ig_5_filling_can',
            flags = 49,
        }
    })

    local stationId = nil
    if cl_ownership then
        local plyCoords = GetEntityCoords(playerPed)
        for sId, data in pairs(cl_ownership.ownedStations) do
            local sConf = nil
            for i = 1, #Settings.Stations do
                if GetStationId(Settings.Stations[i].blip) == sId then
                    sConf = Settings.Stations[i]
                    break
                end
            end

            if sConf then
                for _, pump in ipairs(sConf.pumps) do
                    if #(plyCoords - pump) < 5.0 then
                        stationId = sId
                        break
                    end
                end
            end
            if stationId then break end
        end
    end

    if success then
        if isRefilling and exports.ox_inventory:GetItemCount('WEAPON_PETROLCAN') > 0 then
            TriggerServerEvent('LNS_Fuel:fuelCan', true, Settings.petrolCan.refillPrice, stationId)
        else
            TriggerServerEvent('LNS_Fuel:fuelCan', false, Settings.petrolCan.price, stationId)
        end
    end

    ClearPedTasks(playerPed)
end

function fuelModule.startFueling(veh, usingPump)
    local vState = Entity(veh).state
    local currentLevel = vState.fuel or GetVehicleFuelLevel(veh)
    
    local missing = 100.0 - currentLevel
    if missing < Settings.refillValue then
        lib.notify({ type = 'error', description = locale('tank_full') })
        return
    end

    local stationId = nil
    local isStationOwned = false
    local stationData = nil
    local pricePerTick = Settings.priceTick
    local stationName = "Public Gas Station"

    if usingPump and cl_ownership then
        local plyCoords = GetEntityCoords(cache.ped)
        for sId, data in pairs(cl_ownership.ownedStations) do
            local sConf = nil
            for i = 1, #Settings.Stations do
                if GetStationId(Settings.Stations[i].blip) == sId then
                    sConf = Settings.Stations[i]
                    break
                end
            end

            if sConf then
                for _, pump in ipairs(sConf.pumps) do
                    if #(plyCoords - pump) < 5.0 then
                        stationId = sId
                        stationData = data
                        break
                    end
                end
            end
            if stationId then break end
        end

        if stationId and stationData and stationData.owner then
            isStationOwned = true
            pricePerTick = stationData.price or Settings.priceTick
            stationName = stationData.name or "Gas Station"

            if stationData.stock <= 0 then
                lib.notify({ type = 'error', description = locale('notify_station_out_of_fuel') })
                return
            end
        end
    end

    if usingPump then
        local playerMoney = hlpr.getMoney()
        local costPerLiter = 0
        if isStationOwned then
            costPerLiter = pricePerTick
        else
            costPerLiter = pricePerTick / Settings.refillValue
        end
        
        local model = GetEntityModel(veh)
        local displayModel = GetDisplayNameFromVehicleModel(model)
        local vehicleLabel = GetLabelText(displayModel)
        if vehicleLabel == "CARNOTFOUND" then
            vehicleLabel = displayModel
        end

        local p = promise.new()
        st.activePumpPromise = p

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "openPumpUI",
            data = {
                stationName = stationName,
                pricePerLiter = costPerLiter,
                currentFuel = math.floor(currentLevel),
                playerMoney = playerMoney,
                stockLeft = isStationOwned and stationData.stock or 99999,
                vehicleName = vehicleLabel,
                isOwned = isStationOwned,
                theme = Settings.theme
            },
            locales = hlpr.getLocaleData()
        })

        local selectedLiters = Citizen.Await(p)
        st.activePumpPromise = nil

        if not selectedLiters or selectedLiters <= 0 then
            return
        end

        local maxAffordable = playerMoney / costPerLiter
        local maxNeeded = 100.0 - currentLevel
        local maxAvailable = isStationOwned and stationData.stock or 99999

        local litersToPump = math.min(selectedLiters, maxAffordable, maxNeeded, maxAvailable)
        if litersToPump <= 0 then return end

        local fillDuration = math.ceil(litersToPump / Settings.refillValue) * Settings.refillTick
        local costTotal = litersToPump * costPerLiter

        st.isFueling = true
        local playerPed = cache.ped

        TaskTurnPedToFaceEntity(playerPed, veh, fillDuration)
        Wait(500)

        CreateThread(function()
            local animDict = 'timetable@gardener@filling_can'
            local animClip = 'gar_ig_5_filling_can'
            local propData = {
                model = 'prop_cs_fuel_nozle',
                bone = 18905,
                pos = vec3(0.1, 0.02, 0.02),
                rot = vec3(90.0, 40.0, 170.0),
                rotOrder = 1,
            }

            hlpr.progress({
                duration = fillDuration,
                label = locale('progress_refueling'),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = true,
                    car = true,
                    combat = true,
                },
                anim = {
                    dict = animDict,
                    clip = animClip,
                },
                prop = propData,
            })

            st.isFueling = false
        end)

        local currentPumped = 0
        while st.isFueling do
            currentPumped = currentPumped + Settings.refillValue
            if currentPumped >= litersToPump and lib.progressActive() then
                lib.cancelProgress()
                break
            end
            Wait(Settings.refillTick)
        end

        ClearPedTasks(playerPed)

        local actualLiters = math.min(currentPumped, litersToPump)
        local finalLevel = math.min(100.0, currentLevel + actualLiters)
        local finalCost = math.ceil(actualLiters * costPerLiter)

        if actualLiters > 0 then
            local vehNetId = NetworkGetNetworkIdFromEntity(veh)
            TriggerServerEvent('LNS_Fuel:pay', finalCost, finalLevel, vehNetId, stationId, actualLiters)
        end
    else
        if not st.petrolCan then
            lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
            return
        end
        if st.petrolCan.metadata.ammo <= Settings.durabilityTick then
            lib.notify({
                type = 'error',
                description = locale('petrolcan_not_enough_fuel')
            })
            return
        end

        st.isFueling = true
        local playerPed = cache.ped

        local fillDuration = math.ceil(missing / Settings.refillValue) * Settings.refillTick
        TaskTurnPedToFaceEntity(playerPed, veh, fillDuration)
        Wait(500)

        CreateThread(function()
            hlpr.progress({
                duration = fillDuration,
                label = locale('progress_refueling'),
                useWhileDead = false,
                canCancel = true,
                disable = {
                    move = true,
                    car = true,
                    combat = true,
                },
                anim = {
                    dict = 'weapon@w_sp_jerrycan',
                    clip = 'fire',
                },
            })

            st.isFueling = false
        end)

        local canDegradation = 0
        while st.isFueling do
            canDegradation = canDegradation + Settings.durabilityTick

            if canDegradation >= st.petrolCan.metadata.ammo then
                lib.cancelProgress()
                canDegradation = st.petrolCan.metadata.ammo
                break
            end

            currentLevel = currentLevel + Settings.refillValue

            if currentLevel >= 100.0 then
                st.isFueling = false
                currentLevel = 100.0
            end

            Wait(Settings.refillTick)
        end

        ClearPedTasks(playerPed)

        local vehNetId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent('LNS_Fuel:updateFuelCan', canDegradation, vehNetId, currentLevel)
    end
end

RegisterNUICallback('startRefueling', function(data, cb)
    SetNuiFocus(false, false)
    if st.activePumpPromise then
        st.activePumpPromise:resolve(data.liters)
    end
    cb('ok')
end)

RegisterNUICallback('closePumpUI', function(data, cb)
    SetNuiFocus(false, false)
    if st.activePumpPromise then
        st.activePumpPromise:resolve(nil)
    end
    cb('ok')
end)

return fuelModule