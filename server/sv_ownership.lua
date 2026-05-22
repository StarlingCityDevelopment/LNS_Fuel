local Settings = lib.load('shared.settings')
ownedStations = {}
if not Settings or not Settings.ownership or not Settings.ownership.enabled then return end
local activeDeliveries = {}

local function reportSecurityCheck(src, message)
    print(message)
    if Settings and Settings.exploitdrop then
        DropPlayer(src, "Security violation detected (LNS_Fuel)")
    end
end

local function validateNumber(val)
    local num = tonumber(val)
    if not num or num ~= num or num == math.huge or num == -math.huge then
        return nil
    end
    return num
end

local function validateInteger(val)
    local num = validateNumber(val)
    if not num then return nil end
    return math.floor(num)
end

function GetStationId(coords)
    return string.format("station_%.2f_%.2f", coords.x, coords.y)
end

local function GetStationIndex(stationId)
    if type(stationId) ~= "string" then return nil end
    for i = 1, #Settings.Stations do
        if GetStationId(Settings.Stations[i].blip) == stationId then
            return i
        end
    end
    return nil
end

local function getPlayerIdentifier(source)
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player then return Player.PlayerData.citizenid end
    end

    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then return xPlayer.identifier end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if string.find(identifier, "license:") then
            return identifier
        end
    end
    return nil
end

local function getPlayerName(source)
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(source)
        if Player then return Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname end
    end

    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then return xPlayer.getName() end
    end

    return GetPlayerName(source)
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `lns_fuel_stations` (
            `station_id` VARCHAR(50) NOT NULL,
            `owner` VARCHAR(50) DEFAULT NULL,
            `name` VARCHAR(100) DEFAULT 'Gas Station',
            `balance` INT NOT NULL DEFAULT 0,
            `stock` INT NOT NULL DEFAULT 1000,
            `capacity` INT NOT NULL DEFAULT 2000,
            `price` INT NOT NULL DEFAULT 5,
            `upgrades` TEXT DEFAULT '{}',
            `statistics` TEXT DEFAULT '{}',
            PRIMARY KEY (`station_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `lns_fuel_employees` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `station_id` VARCHAR(50) NOT NULL,
            `identifier` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `role` VARCHAR(50) DEFAULT 'employee',
            UNIQUE KEY `station_emp` (`station_id`, `identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local results = MySQL.query.await("SELECT * FROM lns_fuel_stations")
    if results then
        for _, row in ipairs(results) do
            local upgrades = { capacity = 0, shippingDiscount = 0, hiredDriver = 0 }
            local stats = { totalSales = 0, totalRevenue = 0, lifetimeClients = 0 }
            
            if row.upgrades and row.upgrades ~= "" then
                pcall(function() upgrades = json.decode(row.upgrades) or upgrades end)
            end
            if row.statistics and row.statistics ~= "" then
                pcall(function() stats = json.decode(row.statistics) or stats end)
            end

            local emps = {}
            local empResults = MySQL.query.await("SELECT identifier, name, role FROM lns_fuel_employees WHERE station_id = ?", {row.station_id})
            if empResults then
                for _, empRow in ipairs(empResults) do
                    table.insert(emps, {
                        identifier = empRow.identifier,
                        name = empRow.name,
                        role = empRow.role
                    })
                end
            end

            local idx = GetStationIndex(row.station_id)
            ownedStations[row.station_id] = {
                id = row.station_id,
                prettyId = idx and ("#" .. idx) or row.station_id,
                owner = row.owner,
                name = row.name,
                balance = row.balance,
                stock = row.stock,
                capacity = row.capacity,
                price = row.price,
                upgrades = upgrades,
                statistics = stats,
                employees = emps
            }
        end
    end
end)

local function syncStation(stationId)
    TriggerClientEvent('LNS_Fuel:syncStation', -1, stationId, ownedStations[stationId])
end

lib.callback.register('LNS_Fuel:getStationsData', function(source)
    return ownedStations
end)

local function isOwner(source, stationId)
    if type(stationId) ~= "string" then return false end
    local plyId = getPlayerIdentifier(source)
    local station = ownedStations[stationId]
    return station and station.owner == plyId
end

local function saveStation(stationId)
    if type(stationId) ~= "string" then return end
    local station = ownedStations[stationId]
    if not station or station.pending then return end
    
    MySQL.query.await([[
        UPDATE lns_fuel_stations 
        SET name = ?, balance = ?, stock = ?, capacity = ?, price = ?, upgrades = ?, statistics = ?
        WHERE station_id = ?
    ]], {
        station.name,
        station.balance,
        station.stock,
        station.capacity,
        station.price,
        json.encode(station.upgrades),
        json.encode(station.statistics),
        stationId
    })
end

lib.callback.register('LNS_Fuel:buyStation', function(source, stationId)
    if type(stationId) ~= "string" then
        return false, locale('notify_invalid_station_id_type')
    end

    local plyId = getPlayerIdentifier(source)
    if not plyId then return false, locale('notify_cannot_identify_player') end

    local idx = GetStationIndex(stationId)
    if not idx then
        reportSecurityCheck(source, ("[Security Check] Player %s attempted to buy invalid stationId %s"):format(source, stationId))
        return false, locale('notify_failed_load_station')
    end

    if ownedStations[stationId] then
        if ownedStations[stationId].owner then
            return false, locale('notify_already_owned')
        elseif ownedStations[stationId].pending then
            return false, locale('notify_purchase_in_progress')
        end
    end

    if not ownedStations[stationId] then
        ownedStations[stationId] = { pending = true }
    else
        ownedStations[stationId].pending = true
    end

    local limit = Settings.ownership.stationsPerPlayer
    if limit and limit > 0 then
        local owned = 0
        for _, station in pairs(ownedStations) do
            if station.owner == plyId then
                owned = owned + 1
            end
        end
        if owned >= limit then
            ownedStations[stationId] = nil
            return false, locale('notify_station_limit'):format(limit)
        end
    end

    local cost = Settings.ownership.defaultPurchasePrice
    local playerCash = exports.ox_inventory:GetItemCount(source, 'money')

    if playerCash < cost then
        ownedStations[stationId] = nil
        return false, locale('notify_insufficient_player_cash')
    end

    local removed = exports.ox_inventory:RemoveItem(source, 'money', cost)
    if not removed then
        ownedStations[stationId] = nil
        return false, locale('notify_payment_failed')
    end

    local newStation = {
        id = stationId,
        prettyId = idx and ("#" .. idx) or stationId,
        owner = plyId,
        name = "Gas Station",
        balance = 0,
        stock = Settings.ownership.defaultCapacity,
        capacity = Settings.ownership.defaultCapacity,
        price = Settings.priceTick,
        upgrades = { capacity = 0, shippingDiscount = 0, hiredDriver = 0 },
        statistics = { totalSales = 0, totalRevenue = 0, lifetimeClients = 0 },
        employees = {}
    }

    MySQL.query.await([[
        INSERT INTO lns_fuel_stations (station_id, owner, name, balance, stock, capacity, price, upgrades, statistics) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        newStation.id,
        newStation.owner,
        newStation.name,
        newStation.balance,
        newStation.stock,
        newStation.capacity,
        newStation.price,
        json.encode(newStation.upgrades),
        json.encode(newStation.statistics)
    })

    ownedStations[stationId] = newStation
    syncStation(stationId)

    return true, locale('notify_purchase_success')
end)

lib.callback.register('LNS_Fuel:getStationManagement', function(source, stationId)
    if type(stationId) ~= "string" then return nil end
    local plyId = getPlayerIdentifier(source)
    local station = ownedStations[stationId]
    if not station or station.pending then return nil end

    local isOwner = (station.owner == plyId)
    local isEmp = false
    if not isOwner and station.employees then
        for _, emp in ipairs(station.employees) do
            if emp.identifier == plyId then
                isEmp = true
                break
            end
        end
    end

    if not isOwner and not isEmp then return nil end

    local stationData = {}
    for k, v in pairs(station) do
        stationData[k] = v
    end
    stationData.role = isOwner and "owner" or "employee"
    return stationData
end)

RegisterNetEvent('LNS_Fuel:renameStation', function(stationId, newName)
    local src = source
    if type(stationId) ~= "string" or type(newName) ~= "string" then
        return
    end
    if not isOwner(src, stationId) then return end

    if #newName < 3 or #newName > 30 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_name_length') })
    end

    local cleanName = newName:lower():gsub("%s+", ""):gsub("%p+", "")
    for _, word in ipairs(Settings.ownership.blacklistWords) do
        if string.find(cleanName, word:lower()) then
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_blacklisted_word') })
        end
    end

    ownedStations[stationId].name = newName
    saveStation(stationId)
    syncStation(stationId)

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_station_renamed') })
end)

RegisterNetEvent('LNS_Fuel:withdrawMoney', function(stationId, amount)
    local src = source
    if type(stationId) ~= "string" then return end
    if not isOwner(src, stationId) then return end

    local validatedAmount = validateInteger(amount)
    if not validatedAmount or validatedAmount <= 0 then return end

    local station = ownedStations[stationId]
    if station.balance < validatedAmount then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_not_enough_funds') })
    end

    station.balance = station.balance - validatedAmount
    saveStation(stationId)
    syncStation(stationId)

    exports.ox_inventory:AddItem(src, 'money', validatedAmount)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_withdraw_success'):format(validatedAmount) })
end)

RegisterNetEvent('LNS_Fuel:depositMoney', function(stationId, amount)
    local src = source
    if type(stationId) ~= "string" then return end
    if not isOwner(src, stationId) then return end

    local validatedAmount = validateInteger(amount)
    if not validatedAmount or validatedAmount <= 0 then return end

    local playerCash = exports.ox_inventory:GetItemCount(src, 'money')
    if playerCash < validatedAmount then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_not_enough_cash') })
    end

    local removed = exports.ox_inventory:RemoveItem(src, 'money', validatedAmount)
    if not removed then return end

    local station = ownedStations[stationId]
    station.balance = station.balance + validatedAmount
    saveStation(stationId)
    syncStation(stationId)

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_deposit_success'):format(validatedAmount) })
end)

RegisterNetEvent('LNS_Fuel:setPrice', function(stationId, price)
    local src = source
    if type(stationId) ~= "string" then return end
    if not isOwner(src, stationId) then return end

    local validatedPrice = validateInteger(price)
    if not validatedPrice then return end
    
    local minPrice = Settings.ownership.minPriceTick
    local maxPrice = Settings.ownership.maxPriceTick

    if validatedPrice < minPrice or validatedPrice > maxPrice then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_price_range'):format(minPrice, maxPrice) })
    end

    ownedStations[stationId].price = validatedPrice
    saveStation(stationId)
    syncStation(stationId)

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_price_set_success'):format(validatedPrice) })
end)

RegisterNetEvent('LNS_Fuel:orderStock', function(stationId, orderIndex, isAuto)
    local src = source
    if type(stationId) ~= "string" then return end
    
    local plyId = getPlayerIdentifier(src)
    local station = ownedStations[stationId]
    if not station or station.pending then return end

    local allowed = (station.owner == plyId)
    if not allowed and station.employees then
        for _, emp in ipairs(station.employees) do
            if emp.identifier == plyId then
                allowed = true
                break
            end
        end
    end
    if not allowed then return end

    if activeDeliveries[stationId] or station.activeDelivery then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_delivery_in_progress') })
    end

    local validatedIndex = validateInteger(orderIndex)
    if not validatedIndex then return end
    
    local orderData = Settings.ownership.stockOrders[validatedIndex]
    if not orderData then return end

    if station.stock + orderData.amount > station.capacity then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_stock_exceeds_capacity') })
    end

    local discount = 0.0
    local discountLevel = station.upgrades.shippingDiscount or 0
    if discountLevel > 0 then
        local discountConf = Settings.ownership.upgrades.shippingDiscount.levels[discountLevel]
        if discountConf then
            discount = discountConf.value
        end
    end

    local baseCost = math.floor(orderData.price * (1 - discount))
    local totalCost = baseCost

    if isAuto then
        local hiredDriverUpgrade = Settings.ownership.upgrades.hiredDriver
        if not hiredDriverUpgrade or not hiredDriverUpgrade.enabled then
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_upgrade_disabled') or "Hired drivers are disabled." })
        end

        local hiredDriverLvl = station.upgrades.hiredDriver or 0
        if hiredDriverLvl == 0 then
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_requires_dispatch_upgrade') })
        end

        local dispatchFee = Settings.ownership.delivery.aiDispatchFee or 250
        totalCost = baseCost + dispatchFee
    end

    if station.balance < totalCost then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_not_enough_balance_delivery') })
    end

    local stationCoords = nil
    for i = 1, #Settings.Stations do
        local sCoords = Settings.Stations[i].blip
        if GetStationId(sCoords) == stationId then
            stationCoords = Settings.Stations[i].delivery or sCoords
            break
        end
    end

    if not stationCoords then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_coords_not_found') })
    end

    station.balance = station.balance - totalCost

    if isAuto then
        local hiredDriverLvl = station.upgrades.hiredDriver or 0
        local levelConf = Settings.ownership.upgrades.hiredDriver.levels[hiredDriverLvl]
        local duration = levelConf and levelConf.value or 600

        local deliveryObj = {
            amount = orderData.amount,
            stationId = stationId,
            source = src,
            startTime = os.time(),
            endTime = os.time() + duration,
            isAuto = true,
            label = orderData.label
        }
        activeDeliveries[stationId] = deliveryObj
        station.activeDelivery = deliveryObj

        saveStation(stationId)
        syncStation(stationId)

        TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = locale('notify_ai_delivery_dispatched') })

        SetTimeout(duration * 1000, function()
            local currentDelivery = activeDeliveries[stationId]
            if currentDelivery and currentDelivery.isAuto and currentDelivery.startTime == deliveryObj.startTime then
                local currentStation = ownedStations[stationId]
                if currentStation then
                    local finalAmount = currentDelivery.amount
                    if currentStation.stock + finalAmount > currentStation.capacity then
                        finalAmount = currentStation.capacity - currentStation.stock
                        if finalAmount < 0 then finalAmount = 0 end
                    end

                    currentStation.stock = currentStation.stock + finalAmount
                    currentStation.activeDelivery = nil
                    activeDeliveries[stationId] = nil

                    saveStation(stationId)
                    syncStation(stationId)

                    if GetPlayerPing(currentDelivery.source) > 0 then
                        TriggerClientEvent('ox_lib:notify', currentDelivery.source, { type = 'success', description = locale('notify_ai_delivery_completed'):format(finalAmount) })
                    end
                end
            end
        end)
    else
        local deliveryObj = {
            amount = orderData.amount,
            stationId = stationId,
            source = src,
            startTime = os.time(),
            isAuto = false,
            label = orderData.label
        }
        activeDeliveries[stationId] = deliveryObj
        station.activeDelivery = deliveryObj

        saveStation(stationId)
        syncStation(stationId)

        TriggerClientEvent('LNS_Fuel:startDelivery', src, stationId, orderData.amount, stationCoords)
        TriggerClientEvent('ox_lib:notify', src, { type = 'info', description = locale('notify_delivery_ordered') })
    end
end)

RegisterNetEvent('LNS_Fuel:completeDelivery', function(stationId)
    local src = source
    if type(stationId) ~= "string" then return end
    
    local delivery = activeDeliveries[stationId]
    if not delivery or delivery.source ~= src then
        return
    end

    local elapsed = os.time() - (delivery.startTime or 0)
    if elapsed < 10 then
        reportSecurityCheck(src, ("[Security Check] Player %s attempted LNS_Fuel:completeDelivery too fast! Elapsed: %d seconds. Action blocked."):format(src, elapsed))
        return
    end

    local stationCoords = nil
    for i = 1, #Settings.Stations do
        local sCoords = Settings.Stations[i].blip
        if GetStationId(sCoords) == stationId then
            stationCoords = Settings.Stations[i].delivery or Settings.Stations[i].management or sCoords
            break
        end
    end

    if stationCoords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local dist = #(playerCoords - stationCoords)
        if dist > 35.0 then
            reportSecurityCheck(src, ("[Security Check] Player %s attempted LNS_Fuel:completeDelivery for station %s from a distance of %0.2f meters! Action blocked."):format(src, stationId, dist))
            return
        end

        if delivery.trailerNetId then
            local trailer = NetworkGetEntityFromNetworkId(delivery.trailerNetId)
            if DoesEntityExist(trailer) then
                local trailerCoords = GetEntityCoords(trailer)
                local distTrailer = #(trailerCoords - stationCoords)
                if distTrailer > 35.0 then
                    reportSecurityCheck(src, ("[Security Check] Player %s attempted LNS_Fuel:completeDelivery but trailer is too far from station! Distance: %0.2f meters"):format(src, distTrailer))
                    return
                end
                DeleteEntity(trailer)
            else
                if Settings.spawnType == 'server' then
                    reportSecurityCheck(src, ("[Security Check] Player %s attempted LNS_Fuel:completeDelivery but trailer entity does not exist on server!"):format(src))
                    return
                end
            end
        end
    end

    local station = ownedStations[stationId]
    if station and not station.pending then
        local finalAmount = delivery.amount
        if station.stock + finalAmount > station.capacity then
            finalAmount = station.capacity - station.stock
            if finalAmount < 0 then finalAmount = 0 end
        end

        station.stock = station.stock + finalAmount
        station.activeDelivery = nil
        saveStation(stationId)
        syncStation(stationId)

        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_delivery_completed'):format(finalAmount) })
    end

    activeDeliveries[stationId] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    for stationId, delivery in pairs(activeDeliveries) do
        if delivery.source == src and not delivery.isAuto then
            activeDeliveries[stationId] = nil
            local station = ownedStations[stationId]
            if station then
                station.activeDelivery = nil
                syncStation(stationId)
            end
            break
        end
    end
end)

RegisterNetEvent('LNS_Fuel:abortDelivery', function()
    local src = source
    for stationId, delivery in pairs(activeDeliveries) do
        if delivery.source == src then
            activeDeliveries[stationId] = nil
            local station = ownedStations[stationId]
            if station then
                station.activeDelivery = nil
                syncStation(stationId)
            end
            break
        end
    end
end)


RegisterNetEvent('LNS_Fuel:buyUpgrade', function(stationId, upgradeType)
    local src = source
    if type(stationId) ~= "string" or type(upgradeType) ~= "string" then
        return
    end
    if not isOwner(src, stationId) then return end

    local station = ownedStations[stationId]
    local upgradeConf = Settings.ownership.upgrades[upgradeType]
    if not upgradeConf then return end

    if upgradeType == "hiredDriver" and not upgradeConf.enabled then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_upgrade_disabled') or "This upgrade is currently disabled." })
    end

    local currentLevel = station.upgrades[upgradeType] or 0
    local nextLevel = currentLevel + 1
    local levelData = upgradeConf.levels[nextLevel]

    if not levelData then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_max_upgrade') })
    end

    if station.balance < levelData.price then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_not_enough_balance_upgrade') })
    end

    station.balance = station.balance - levelData.price
    station.upgrades[upgradeType] = nextLevel

    if upgradeType == "capacity" then
        station.capacity = levelData.value
    end

    saveStation(stationId)
    syncStation(stationId)

    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_upgrade_success'):format(upgradeConf.title, nextLevel) })
end)

RegisterNetEvent('LNS_Fuel:sellStation', function(stationId)
    local src = source
    if type(stationId) ~= "string" then return end
    if not isOwner(src, stationId) then return end

    local station = ownedStations[stationId]
    ownedStations[stationId] = nil

    local refund = Settings.ownership.defaultPurchasePrice * Settings.ownership.sellRefundRate

    local upgradeRefund = 0
    for upgradeType, level in pairs(station.upgrades) do
        local upgradeConf = Settings.ownership.upgrades[upgradeType]
        if upgradeConf then
            for lvl = 1, level do
                local lvlData = upgradeConf.levels[lvl]
                if lvlData then
                    upgradeRefund = upgradeRefund + (lvlData.price * Settings.ownership.upgradeRefundRate)
                end
            end
        end
    end

    local totalRefund = math.floor(refund + upgradeRefund)
    
    MySQL.query.await("DELETE FROM lns_fuel_stations WHERE station_id = ?", {stationId})
    MySQL.query.await("DELETE FROM lns_fuel_employees WHERE station_id = ?", {stationId})

    TriggerClientEvent('LNS_Fuel:syncStation', -1, stationId, nil)

    exports.ox_inventory:AddItem(src, 'money', totalRefund)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_station_sold'):format(totalRefund) })
end)

function GetStationAtCoords(coords)
    for stationId, data in pairs(ownedStations) do
        local stationConf = nil
        for i = 1, #Settings.Stations do
            local testId = GetStationId(Settings.Stations[i].blip)
            if testId == stationId then
                stationConf = Settings.Stations[i]
                break
            end
        end

        if stationConf then
            for _, pump in ipairs(stationConf.pumps) do
                if #(coords - pump) < 5.0 then
                    return stationId, data
                end
            end
        end
    end
    return nil, nil
end

lib.callback.register('LNS_Fuel:spawnDeliveryVehicles', function(source)
    local src = source

    local activeDelivery = nil
    local activeStationId = nil
    for stationId, delivery in pairs(activeDeliveries) do
        if delivery.source == src then
            activeDelivery = delivery
            activeStationId = stationId
            break
        end
    end

    if not activeDelivery then
        reportSecurityCheck(src, ("[Security Check] Player %s requested server-side vehicle spawn via LNS_Fuel:spawnDeliveryVehicles without an active delivery run!"):format(src))
        return nil
    end

    if activeDelivery.truckNetId or activeDelivery.trailerNetId then
        reportSecurityCheck(src, ("[Security Check] Player %s requested LNS_Fuel:spawnDeliveryVehicles but vehicles are already spawned!"):format(src))
        return nil
    end

    local deliveryConf = Settings.ownership.delivery
    local truckModel = deliveryConf.truckModel
    local trailerModel = deliveryConf.trailerModel
    local truckPos = deliveryConf.truckSpawn
    local trailerPos = deliveryConf.trailerSpawn

    local truck = CreateVehicleServerSetter(truckModel, 'automobile', truckPos.x, truckPos.y, truckPos.z, truckPos.w)
    local trailer = CreateVehicleServerSetter(trailerModel, 'trailer', trailerPos.x, trailerPos.y, trailerPos.z, trailerPos.w)

    local timeout = 100
    while (not DoesEntityExist(truck) or not DoesEntityExist(trailer)) and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end

    if not DoesEntityExist(truck) or not DoesEntityExist(trailer) then
        return nil
    end

    local truckNetId = NetworkGetNetworkIdFromEntity(truck)
    local trailerNetId = NetworkGetNetworkIdFromEntity(trailer)
    timeout = 100
    while (truckNetId == 0 or trailerNetId == 0) and timeout > 0 do
        Wait(50)
        truckNetId = NetworkGetNetworkIdFromEntity(truck)
        trailerNetId = NetworkGetNetworkIdFromEntity(trailer)
        timeout = timeout - 1
    end

    if truckNetId == 0 or trailerNetId == 0 then
        return nil
    end

    activeDelivery.truckNetId = truckNetId
    activeDelivery.trailerNetId = trailerNetId

    local bucket = GetPlayerRoutingBucket(src)
    if bucket ~= 0 then
        SetEntityRoutingBucket(truck, bucket)
        SetEntityRoutingBucket(trailer, bucket)
    end

    exports.qbx_vehiclekeys:GiveKeys(src, truck)

    return {
        truckNetId = truckNetId,
        trailerNetId = trailerNetId
    }
end)

RegisterNetEvent('LNS_Fuel:giveDeliveryKeys', function(plate, vehNetId)
    local src = source
    if type(plate) ~= "string" then return end
    
    local validatedNetId = validateInteger(vehNetId)
    if not validatedNetId then return end

    if Settings.spawnType == 'server' then
        reportSecurityCheck(src, ("[Security Check] Player %s requested delivery keys via client event but spawnType is server!"):format(src))
        return
    end

    local activeDelivery = nil
    for _, delivery in pairs(activeDeliveries) do
        if delivery.source == src then
            activeDelivery = delivery
            break
        end
    end

    if not activeDelivery then
        reportSecurityCheck(src, ("[Security Check] Player %s requested delivery keys via LNS_Fuel:giveDeliveryKeys without an active delivery run!"):format(src))
        return
    end

    if activeDelivery.truckNetId then
        reportSecurityCheck(src, ("[Security Check] Player %s requested delivery keys but already has spawned truck/keys!"):format(src))
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(validatedNetId)
    local timeout = 100
    while not DoesEntityExist(vehicle) and timeout > 0 do
        Wait(10)
        vehicle = NetworkGetEntityFromNetworkId(validatedNetId)
        timeout = timeout - 1
    end

    if DoesEntityExist(vehicle) then
        local model = GetEntityModel(vehicle)
        local expectedModel = Settings.ownership.delivery.truckModel
        if model ~= expectedModel then
            reportSecurityCheck(src, ("[Security Check] Player %s requested delivery keys for non-delivery vehicle model! Model: %s, Expected: %s"):format(src, model, expectedModel))
            return
        end
        activeDelivery.truckNetId = validatedNetId
        exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
    else
        reportSecurityCheck(src, ("[Security Check] Player %s requested delivery keys for a vehicle that does not exist on the server!"):format(src))
    end
end)

RegisterNetEvent('LNS_Fuel:hireEmployee', function(stationId, targetServerId)
    local src = source
    if type(stationId) ~= "string" then return end
    
    local validatedTarget = validateInteger(targetServerId)
    if not validatedTarget then return end
    
    if not isOwner(src, stationId) then return end

    local targetPed = GetPlayerPed(validatedTarget)
    if not targetPed or targetPed == 0 then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_player_not_found') })
    end

    local targetId = getPlayerIdentifier(validatedTarget)
    if not targetId then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_cannot_identify_player') })
    end

    local station = ownedStations[stationId]
    if not station or station.pending then return end

    if station.owner == targetId then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_cannot_hire_self') })
    end

    if not station.employees then
        station.employees = {}
    end

    for _, emp in ipairs(station.employees) do
        if emp.identifier == targetId then
            return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_player_already_employed') })
        end
    end

    local targetName = getPlayerName(validatedTarget)
    
    table.insert(station.employees, {
        identifier = targetId,
        name = targetName,
        role = 'employee'
    })

    MySQL.query.await([[
        INSERT INTO lns_fuel_employees (station_id, identifier, name, role)
        VALUES (?, ?, ?, 'employee')
        ON DUPLICATE KEY UPDATE name = VALUES(name)
    ]], {stationId, targetId, targetName})

    syncStation(stationId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_employee_hired'):format(targetName) })
    TriggerClientEvent('ox_lib:notify', validatedTarget, { type = 'info', description = locale('notify_hired_by_station'):format(station.name) })
end)

RegisterNetEvent('LNS_Fuel:fireEmployee', function(stationId, employeeIdentifier)
    local src = source
    if type(stationId) ~= "string" or type(employeeIdentifier) ~= "string" then return end
    if not isOwner(src, stationId) then return end

    local station = ownedStations[stationId]
    if not station or not station.employees or station.pending then return end

    local foundIndex = nil
    local employeeName = ""
    for i, emp in ipairs(station.employees) do
        if emp.identifier == employeeIdentifier then
            foundIndex = i
            employeeName = emp.name
            break
        end
    end

    if not foundIndex then
        return TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = locale('notify_employee_not_found') })
    end

    table.remove(station.employees, foundIndex)

    MySQL.query.await("DELETE FROM lns_fuel_employees WHERE station_id = ? AND identifier = ?", {stationId, employeeIdentifier})

    syncStation(stationId)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = locale('notify_employee_fired'):format(employeeName) })
    
    if GetResourceState('qbx_core') == 'started' then
        local tPlayer = exports.qbx_core:GetPlayerByCitizenId(employeeIdentifier)
        if tPlayer then
            TriggerClientEvent('ox_lib:notify', tPlayer.PlayerData.source, { type = 'warning', description = locale('notify_employee_let_go'):format(station.name) })
        end
    elseif GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        local tPlayer = ESX.GetPlayerFromIdentifier(employeeIdentifier)
        if tPlayer then
            TriggerClientEvent('ox_lib:notify', tPlayer.source, { type = 'warning', description = locale('notify_employee_let_go'):format(station.name) })
        end
    end
end)