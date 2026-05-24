local currentState = {}

currentState.isFueling = false
currentState.holdingNozzle = false
currentState.holdingElectricNozzle = false
currentState.lastVehicle = cache.vehicle or GetPlayersLastVehicle()

if currentState.lastVehicle == 0 then 
    currentState.lastVehicle = nil 
end

local function handlePetrolCan(itemData)
    if itemData and itemData.name == 'WEAPON_PETROLCAN' then
        currentState.petrolCan = itemData
    else
        currentState.petrolCan = nil
    end
end

handlePetrolCan(exports.ox_inventory:getCurrentWeapon())
AddEventHandler('ox_inventory:currentWeapon', handlePetrolCan)

return currentState
