local Settings = lib.load("shared.settings")
local st = require("client.cl_state")
local hlpr = require("client.cl_utils")
local fuelMod = require("client.cl_fuel")

local function DoesVehicleUseFuelSafe(veh)
	if not veh or veh == 0 or not DoesEntityExist(veh) then
		return false
	end
	return DoesVehicleUseFuel(veh)
end

exports.ox_target:addModel(Settings.pumpModels, {
	{
		distance = 2,
		icon = "fas fa-gas-pump",
		label = locale("grab_hose") or "Grab Hose",
		onSelect = function(data)
			fuelMod.grabNozzle(data.entity, false)
		end,
		canInteract = function(entity)
			return not cache.vehicle and not st.holdingNozzle and not st.holdingElectricNozzle and not st.isFueling
		end,
	},
	{
		distance = 2,
		icon = "fas fa-hand",
		label = locale("return_hose") or "Return Hose",
		onSelect = function()
			fuelMod.returnNozzle()
		end,
		canInteract = function(entity)
			return st.holdingNozzle and not st.isFueling
		end,
	},
	{
		distance = 2,
		icon = "fas fa-faucet",
		label = locale("petrolcan_buy_or_refill"),
		onSelect = function(targetData)
			local hasJerryCan = Settings.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			fuelMod.getPetrolCan(targetData.coords, hasJerryCan)
		end,
		canInteract = function(entity)
			return Settings.petrolCan.enabled
				and not st.holdingNozzle
				and not st.holdingElectricNozzle
				and not st.isFueling
		end,
	},
})

if Settings.petrolCan.enabled then
	exports.ox_target:addGlobalVehicle({
		{
			distance = 2,
			icon = "fas fa-gas-pump",
			label = locale("start_fueling"),
			onSelect = function(targetData)
				if not st.petrolCan then
					lib.notify({ type = "error", description = locale("petrolcan_not_equipped") })
					return
				end

				if st.petrolCan.metadata.ammo <= Settings.durabilityTick then
					lib.notify({
						type = "error",
						description = locale("petrolcan_not_enough_fuel"),
					})
					return
				end

				fuelMod.startFueling(targetData.entity, false)
			end,
			canInteract = function(entity)
				if st.isFueling or cache.vehicle or lib.progressActive() or not DoesVehicleUseFuelSafe(entity) then
					return false
				end
				return st.petrolCan and Settings.petrolCan.enabled
			end,
		},
	})
end

exports.ox_target:addGlobalVehicle({
	{
		distance = 2,
		icon = "fas fa-gas-pump",
		label = locale("insert_hose") or "Insert Hose",
		onSelect = function(targetData)
			if GetVehicleFuelLevel(targetData.entity) >= 100 then
				lib.notify({ type = "error", description = locale("vehicle_full") })
				return
			end
			fuelMod.startFueling(targetData.entity, true)
		end,
		canInteract = function(entity)
			return st.holdingNozzle and not st.isFueling and not cache.vehicle and DoesVehicleUseFuelSafe(entity)
		end,
	},
	{
		distance = 2,
		icon = "fas fa-bolt",
		label = locale("insert_charger_cable") or "Insert Charger Cable",
		onSelect = function(targetData)
			if GetVehicleFuelLevel(targetData.entity) >= 100 then
				lib.notify({
					type = "error",
					description = locale("battery_full") or "The battery of this vehicle is already fully charged!",
				})
				return
			end
			fuelMod.startFueling(targetData.entity, true)
		end,
		canInteract = function(entity)
			return st.holdingElectricNozzle
				and not st.isFueling
				and not cache.vehicle
				and DoesVehicleUseFuelSafe(entity)
		end,
	},
})

exports.ox_target:addModel(Settings.electricPumpModels or { `electric_charger` }, {
	{
		distance = 2,
		icon = "fas fa-bolt",
		label = locale("grab_charger_cable") or "Grab Charger Cable",
		onSelect = function(data)
			fuelMod.grabNozzle(data.entity, true)
		end,
		canInteract = function(entity)
			return not cache.vehicle and not st.holdingNozzle and not st.holdingElectricNozzle and not st.isFueling
		end,
	},
	{
		distance = 2,
		icon = "fas fa-hand",
		label = locale("return_charger_cable") or "Return Charger Cable",
		onSelect = function()
			fuelMod.returnNozzle()
		end,
		canInteract = function(entity)
			return st.holdingElectricNozzle and not st.isFueling
		end,
	},
})
