local Settings = lib.load('shared.settings')
local st  = require('client.cl_state')
local hlpr  = require('client.cl_utils')
local fuelMod   = require('client.cl_fuel')

if Settings.petrolCan.enabled then
    exports.ox_target:addModel(Settings.pumpModels, {
        {
            distance = 2,
            icon = "fas fa-gas-pump",
            label = locale('start_fueling'),
            onSelect = function()
                fuelMod.startFueling(st.lastVehicle, true)
            end,
            canInteract = function(entity)
                if st.isFueling or cache.vehicle or lib.progressActive() then
                    return false
                end
                if not st.lastVehicle then return false end
                
                local dist = #(GetEntityCoords(st.lastVehicle) - GetEntityCoords(cache.ped))
                return dist <= 3
            end
        },
        {
            distance = 2,
            icon = "fas fa-faucet",
            label = locale('petrolcan_buy_or_refill'),
            onSelect = function(targetData)
                local hasJerryCan = Settings.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
                fuelMod.getPetrolCan(targetData.coords, hasJerryCan)
            end,
        },
    })
else
    exports.ox_target:addModel(Settings.pumpModels, {
        {
            distance = 2,
            icon = "fas fa-gas-pump",
            label = locale('start_fueling'),
            onSelect = function()
                if GetVehicleFuelLevel(st.lastVehicle) >= 100 then
                    lib.notify({ type = 'error', description = locale('vehicle_full') })
                    return 
                end
                fuelMod.startFueling(st.lastVehicle, true)
            end,
            canInteract = function(entity)
                if st.isFueling or cache.vehicle or not DoesVehicleUseFuel(st.lastVehicle) then
                    return false
                end
                
                if not st.lastVehicle then return false end
                local distToVeh = #(GetEntityCoords(st.lastVehicle) - GetEntityCoords(cache.ped))
                return distToVeh <= 3
            end
        },
    })
end

if Settings.petrolCan.enabled then
    exports.ox_target:addGlobalVehicle({
        {
            distance = 2,
            icon = "fas fa-gas-pump",
            label = locale('start_fueling'),
            onSelect = function(targetData)
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

                fuelMod.startFueling(targetData.entity, false)
            end,
            canInteract = function(entity)
                if st.isFueling or cache.vehicle or lib.progressActive() or not DoesVehicleUseFuel(entity) then
                    return false
                end
                return st.petrolCan and Settings.petrolCan.enabled
            end
        }
    })
end
