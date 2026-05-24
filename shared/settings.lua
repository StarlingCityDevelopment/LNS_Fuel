if not lib.checkDependency('ox_lib', '3.22.0', true) then return end
if not lib.checkDependency('ox_inventory', '2.30.0', true) then return end

return {
    -- Set to true to drop players who trigger security checks (exploiting attempts)
    exploitdrop = true,

    -- Set to true if you are using ox_target
    ox_target = true,

    -- Progress indicator type: 'bar' or 'circle'
    progressType = 'bar',

    -- Spawn type for job/delivery vehicles:
    -- 'client': Spawns vehicles client-side
    -- 'server': Spawns vehicles server-side (required if routing bucket entity lockdown is strict or relaxed)
    spawnType = 'server',

    -- Blip visibility settings
    -- 0: Hidden
    -- 1: Show closest (Updates every 5s)
    -- 2: Always visible
    showBlips = 2,

    -- Amount of fuel added per tick
    refillValue = 0.50,

    -- How often the fuel amount increments (in milliseconds)
    refillTick = 250,

    -- Price charged to the player every refill tick
    priceTick = 5,

    -- Price charged to the player every electric charging tick (public stations)
    electricPriceTick = 2,

    -- Degradation amount applied to the jerry can per tick
    durabilityTick = 1.3,

    -- Settings for the Jerry Can
    petrolCan = {
        enabled = true,
        duration = 5000,
        price = 1000,
        refillPrice = 800,
    },

    -- Adjusts the global fuel usage rate for all vehicles
    globalFuelConsumptionRate = 10.0,

    -- Multiplier rate for singular vehicle models (key can be model string or hash)
    -- This overrides the class and global rate.
    vehicleModelFuelRates = {
        ['adder'] = 15.0,    -- Adder consumes fuel faster
        ['panto'] = 5.0,     -- Panto consumes fuel slower
    },

    -- Multiplier rate per vehicle class (0-22)
    -- This overrides the global rate but is overridden by model-specific rates.
    -- Vehicle Class IDs:
    -- 0: Compacts, 1: Sedans, 2: SUVs, 3: Coupes, 4: Muscle, 5: Sports Classics,
    -- 6: Sports, 7: Super, 8: Motorcycles, 9: Off-road, 10: Industrial, 11: Utility,
    -- 12: Vans, 13: Cycles, 14: Boats, 15: Helicopters, 16: Planes, 17: Service,
    -- 18: Emergency, 19: Military, 20: Commercial, 21: Trains, 22: Open Wheel
    vehicleClassFuelRates = {
        [0] = 7.0,  -- Compacts
        [7] = 15.0, -- Super cars
        [8] = 5.0,  -- Motorcycles
        [13] = 0.0, -- Cycles (pedal bikes usually don't use fuel, but class rate can be set)
    },

    -- List of recognized gas pump models
    pumpModels = {
        `prop_gas_pump_old2`,
        `prop_gas_pump_1a`,
        `prop_vintage_pump`,
        `prop_gas_pump_old3`,
        `prop_gas_pump_1c`,
        `prop_gas_pump_1b`,
        `prop_gas_pump_1d`,
    },

    -- List of recognized electric charging station pump models
    electricPumpModels = {
        `electric_charger`,
    },

    -- Physics-based hose/cable settings
    pumpHose = true,
    nozzleLength = 7.5,
    ropeType = {
        fuel = 3,       -- 3: Very Thick Black Rope
        electric = 4,   -- 4: Very Thin Black Rope
    },

    -- List of electric vehicles (key is model name in lowercase, value is true)
    electricVehicles = {
        ['tesla'] = true,
        ['neon'] = true,
        ['raiden'] = true,
        ['cyclone'] = true,
        ['tezeract'] = true,
        ['imorgon'] = true,
        ['voltic'] = true,
        ['surge'] = true,
        ['dilettante'] = true,
        ['khamelion'] = true,
        ['iwagen'] = true,
        ['omnisegt'] = true,
        ['virtue'] = true,
        ['buffalo4'] = true,
        ['corsita'] = true,
    },

	-- UI Accent Colors
	theme = {
        primary = '#6fd2f3',    -- Light Blue accent color
        primaryDark = '#4fb9dd', -- Darker variant for hovers
        primaryText = '#0f0f10'  -- Dark text for better visibility on light blue
    },

	-- Ownership Settings
    ownership = {
        enabled = true,
        defaultPurchasePrice = 75000, -- Default purchase price
        stationsPerPlayer = 1,         -- Maximum number of stations a single player can own (0 = unlimited)
        minPriceTick = 1,              -- Minimum fuel price tick owners can set
        maxPriceTick = 25,             -- Maximum fuel price tick owners can set
        minElectricPriceTick = 1,      -- Minimum electric price tick owners can set
        maxElectricPriceTick = 10,     -- Maximum electric price tick owners can set
        defaultElectricPrice = 2,      -- Default electric price tick
        defaultCapacity = 2000,
        chargerPrice = 5000,
        chargerPlacementRange = 35.0,
        
        -- Fuel Stock delivery orders
        stockOrders = {
            { label = "Small delivery (500L)", amount = 500, price = 1000 },
            { label = "Medium delivery (1000L)", amount = 1000, price = 1800 },
            { label = "Large delivery (2000L)", amount = 2000, price = 3200 },
        },
        
        -- Station Upgrades
        upgrades = {
            capacity = {
                title = "Fuel Tank Capacity Upgrade",
                description = "Increase maximum stock storage for fuel.",
                levels = {
                    { level = 1, value = 5000, price = 15000 },
                    { level = 2, value = 10000, price = 30000 },
                    { level = 3, value = 20000, price = 50000 },
                }
            },
            shippingDiscount = {
                title = "Supplier Partnership Upgrade",
                description = "Negotiate bulk shipping rates to get a discount on stock orders.",
                levels = {
                    { level = 1, value = 0.10, price = 10000 }, -- 10% discount
                    { level = 2, value = 0.20, price = 20000 }, -- 20% discount
                    { level = 3, value = 0.35, price = 35000 }, -- 35% discount
                }
            },
            hiredDriver = {
                enabled = true, -- Toggle to completely enable/disable the hired drivers feature
                title = "Logistics Dispatch Contract",
                description = "Contract professional truck drivers to automatically fetch and deliver your stock orders over time.",
                levels = {
                    { level = 1, value = 600, price = 15000 }, -- Level 1: 10 mins (600 seconds)
                    { level = 2, value = 420, price = 25000 }, -- Level 2: 7 mins (420 seconds)
                    { level = 3, value = 300, price = 40000 }, -- Level 3: 5 mins (300 seconds)
                }
            },
            chargerLimit = {
                title = "Power Grid Expansion",
                description = "Expand your station's power grid to allow placing more electric chargers.",
                levels = {
                    { level = 1, value = 3, price = 10000 },
                    { level = 2, value = 4, price = 20000 },
                    { level = 3, value = 6, price = 35000 },
                }
            }
        },

        -- Blacklisted words for station names
        blacklistWords = {
            "nigger", "kike", "retard", "faggot", "dyke", "tranny", "chink", "cunt", 
            "fuck", "shit", "bitch", "asshole", "niggerish", "nigga", "fag", "cunts"
        },
        
        -- Sell refund rate (e.g. 60% of initial price + 50% of upgrade costs)
        sellRefundRate = 0.60,
        upgradeRefundRate = 0.50,

        -- Fuel Delivery Job Settings
        delivery = {
            depotCoords = vec3(934.33, -3138.5, 5.90),      -- Depot marker / pickup point
            truckSpawn = vec4(929.33, -3135.5, 5.90, 270.0), -- Truck spawn position
            trailerSpawn = vec4(1699.57, -1620.51, 111.48, 195.43), -- Trailer spawn position
            returnCoords = vec3(938.33, -3142.5, 5.90),      -- Truck return marker
            truckModel = `phantom`,
            trailerModel = `tanker`,
            
            aiDispatchFee = 250, -- Extra cost to hire an AI driver per order
        },
    },

    -- Locations and coordinates of all gas stations
    Stations = {
		-- Los Santos
		{
			blip = vec3(-71.28, -1761.16, 29.48),
			management = vec3(-44.18, -1749.36, 28.42),
			delivery = vec3(-70.22, -1772.89, 27.85),
			pumps = {
				vec3(-63.61373901367187, -1767.937744140625, 28.26160812377929),
				vec3(-61.03425216674805, -1760.8505859375, 28.30055999755859),
				vec3(-69.45481872558594, -1758.018798828125, 28.54180145263672),
				vec3(-72.0343017578125, -1765.10595703125, 28.52847290039062),
				vec3(-80.17231750488281, -1762.143798828125, 28.79890060424804),
				vec3(-77.5927505493164, -1755.056884765625, 28.80794906616211)
			}
		},

		{
			blip = vec3(264.74, -1260.98, 29.18),
			management = vec3(264.74, -1260.98, 29.18),
			delivery = vec3(264.74, -1260.98, 29.18),
			pumps = {
				vec3(256.4333801269531, -1253.46142578125, 28.2867317199707),
				vec3(256.4333801269531, -1261.29833984375, 28.29153060913086),
				vec3(256.4333801269531, -1268.6396484375, 28.29116821289062),
				vec3(265.0627136230469, -1268.6396484375, 28.29112243652343),
				vec3(265.0627136230469, -1261.29833984375, 28.29272079467773),
				vec3(265.0627136230469, -1253.46142578125, 28.28998565673828),
				vec3(273.8385925292969, -1253.46142578125, 28.29183197021484),
				vec3(273.8385925292969, -1261.29833984375, 28.2861328125),
				vec3(273.8385925292969, -1268.6396484375, 28.29059982299804)
			}
		},

		{
			blip = vec3(1208.66, -1402.64, 35.22),
			management = vec3(1208.66, -1402.64, 35.22),
			delivery = vec3(1208.66, -1402.64, 35.22),
			pumps = {
				vec3(1212.937255859375, -1404.030029296875, 34.38496017456055),
				vec3(1210.064697265625, -1406.903076171875, 34.38496017456055),
				vec3(1204.1953125, -1401.03369140625, 34.38496017456055),
				vec3(1207.068115234375, -1398.160888671875, 34.38496017456055)
			}
		},

		{
			blip = vec3(818.83, -1029.89, 26.17),
			management = vec3(818.83, -1029.89, 26.17),
			delivery = vec3(818.83, -1029.89, 26.17),
			pumps = {
				vec3(810.698974609375, -1026.247802734375, 25.43555450439453),
				vec3(810.698974609375, -1030.94140625, 25.43555450439453),
				vec3(818.986083984375, -1030.94140625, 25.43555450439453),
				vec3(818.986083984375, -1026.247802734375, 25.43555450439453),
				vec3(827.2933349609375, -1026.247802734375, 25.63511276245117),
				vec3(827.2933349609375, -1030.94140625, 25.63511276245117)
			}
		},

		{
			blip = vec3(1181.27, -329.57, 69.18),
			management = vec3(1181.27, -329.57, 69.18),
			delivery = vec3(1181.27, -329.57, 69.18),
			pumps = {
				vec3(1186.3909912109376, -338.2332458496094, 68.35638427734375),
				vec3(1178.9632568359376, -339.5430603027344, 68.3656005859375),
				vec3(1177.4598388671876, -331.0143737792969, 68.3187255859375),
				vec3(1184.8870849609376, -329.7048034667969, 68.30953979492188),
				vec3(1183.1292724609376, -320.9965515136719, 68.35069274902344),
				vec3(1175.7015380859376, -322.3061218261719, 68.35877990722656)
			}
		},

		{
			blip = vec3(621.07, 269.52, 103.04),
			management = vec3(621.07, 269.52, 103.04),
			delivery = vec3(621.07, 269.52, 103.04),
			pumps = {
				vec3(612.4210205078125, 273.9571533203125, 102.26951599121094),
				vec3(612.4322509765625, 263.83575439453127, 102.26951599121094),
				vec3(620.9901123046875, 263.8359375, 102.26951599121094),
				vec3(620.986083984375, 273.96978759765627, 102.26951599121094),
				vec3(629.630615234375, 273.9698486328125, 102.26951599121094),
				vec3(629.634521484375, 263.835693359375, 102.26951599121094)
			}
		},

		{
			blip = vec3(-1437.58, -276.38, 46.21),
			management = vec3(-1437.58, -276.38, 46.21),
			delivery = vec3(-1437.58, -276.38, 46.21),
			pumps = {
				vec3(-1429.075927734375, -279.15185546875, 45.40259552001953),
				vec3(-1438.072021484375, -268.69781494140627, 45.40358734130859),
				vec3(-1444.5035400390626, -274.23236083984377, 45.40358734130859),
				vec3(-1435.5074462890626, -284.6864013671875, 45.40259552001953)
			}
		},

		{
			blip = vec3(-2096.6, -318.15, 13.02),
			management = vec3(-2096.6, -318.15, 13.02),
			delivery = vec3(-2096.6, -318.15, 13.02),
			pumps = {
				vec3(-2088.755615234375, -327.3988037109375, 12.1609182357788),
				vec3(-2088.086669921875, -321.0352478027344, 12.1609182357788),
				vec3(-2087.21533203125, -312.8184814453125, 12.1609182357788),
				vec3(-2096.096435546875, -311.9068908691406, 12.1609182357788),
				vec3(-2096.814453125, -320.1178894042969, 12.1609182357788),
				vec3(-2097.4833984375, -326.48150634765627, 12.1609182357788),
				vec3(-2106.065673828125, -325.5794677734375, 12.1609182357788),
				vec3(-2105.396728515625, -319.2159118652344, 12.1609182357788),
				vec3(-2104.53515625, -311.01983642578127, 12.1609182357788)
			}
		},

		{
			blip = vec3(-1799.03, 803.11, 138.4),
			management = vec3(-1799.03, 803.11, 138.4),
			delivery = vec3(-1799.03, 803.11, 138.4),
			pumps = {
				vec3(-1795.9344482421876, 811.963623046875, 137.69021606445313),
				vec3(-1790.8387451171876, 806.4029541015625, 137.69512939453126),
				vec3(-1797.2239990234376, 800.5526123046875, 137.65481567382813),
				vec3(-1802.3189697265626, 806.1129150390625, 137.65170288085938),
				vec3(-1808.7191162109376, 799.951416015625, 137.68540954589845),
				vec3(-1803.6236572265626, 794.3907470703125, 137.68983459472657)
			}
		},

		{
			blip = vec3(-524.84, -1211.02, 18.18),
			management = vec3(-524.84, -1211.02, 18.18),
			delivery = vec3(-524.84, -1211.02, 18.18),
			pumps = {
				vec3(-522.2349853515625, -1217.422119140625, 17.32516098022461),
				vec3(-524.9267578125, -1216.152099609375, 17.32538604736328),
				vec3(-529.51708984375, -1213.962646484375, 17.32538604736328),
				vec3(-532.2852783203125, -1212.71875, 17.32538604736328),
				vec3(-528.5758056640625, -1204.80126953125, 17.32538604736328),
				vec3(-525.8076171875, -1206.044921875, 17.32538604736328),
				vec3(-521.21728515625, -1208.234375, 17.32538604736328),
				vec3(-518.525634765625, -1209.50439453125, 17.32516098022461)
			}
		},

		{
			blip = vec3(2581.56, 361.65, 108.46),
			management = vec3(2581.56, 361.65, 108.46),
			delivery = vec3(2581.56, 361.65, 108.46),
			pumps = {
				vec3(2588.406005859375, 358.5595703125, 107.65083312988281),
				vec3(2588.645751953125, 364.0592041015625, 107.65049743652344),
				vec3(2581.173583984375, 364.3847351074219, 107.65000915527344),
				vec3(2580.93408203125, 358.88507080078127, 107.6507797241211),
				vec3(2573.544677734375, 359.20697021484377, 107.65115356445313),
				vec3(2573.7841796875, 364.7066650390625, 107.65056610107422)
			}
		},

		{
			blip = vec3(-319.84, -1471.77, 30.55),
			management = vec3(-319.84, -1471.77, 30.55),
			delivery = vec3(-319.84, -1471.77, 30.55),
			pumps = {
				vec3(-329.8195495605469, -1471.6396484375, 29.72901153564453),
				vec3(-324.7491149902344, -1480.4140625, 29.7288589477539),
				vec3(-317.2628479003906, -1476.091796875, 29.72502899169922),
				vec3(-322.3332214355469, -1467.317626953125, 29.72066497802734),
				vec3(-314.9219665527344, -1463.03857421875, 29.72624969482422),
				vec3(-309.8515319824219, -1471.79833984375, 29.72341156005859)
			}
		},

		{
			blip = vec3(175.31, -1561.73, 29.26),
			management = vec3(175.31, -1561.73, 29.26),
			delivery = vec3(175.31, -1561.73, 29.26),
			pumps = {
				vec3(181.8067169189453, -1561.9698486328126, 28.32902526855468),
				vec3(174.9801483154297, -1568.4442138671876, 28.32902526855468),
				vec3(169.29725646972657, -1562.2669677734376, 28.32902526855468),
				vec3(176.02076721191407, -1555.9114990234376, 28.32838058471679)
			}
		},

		{
			blip = vec3(-723.72, -935.51, 19.21),
			management = vec3(-723.72, -935.51, 19.21),
			delivery = vec3(-723.72, -935.51, 19.21),
			pumps = {
				vec3(-732.6458129882813, -932.5162353515625, 18.211669921875),
				vec3(-732.6458129882813, -939.3216552734375, 18.211669921875),
				vec3(-724.0073852539063, -939.3216552734375, 18.211669921875),
				vec3(-724.0073852539063, -932.5162353515625, 18.211669921875),
				vec3(-715.4374389648438, -932.5162353515625, 18.211669921875),
				vec3(-715.4374389648438, -939.3216552734375, 18.211669921875)
			}
		},

		-- Blaine County
		{
			blip = vec3(-2555.31, 2334.01, 33.06),
			management = vec3(-2555.31, 2334.01, 33.06),
			delivery = vec3(-2555.31, 2334.01, 33.06),
			pumps = {
				vec3(-2551.396240234375, 2327.115478515625, 32.24691772460937),
				vec3(-2558.021484375, 2326.704345703125, 32.25613403320312),
				vec3(-2558.484619140625, 2334.1337890625, 32.2554702758789),
				vec3(-2552.607177734375, 2334.467529296875, 32.254150390625),
				vec3(-2552.3984375, 2341.8916015625, 32.21600341796875),
				vec3(-2558.7724609375, 2341.48779296875, 32.2252197265625)
			}
		},

		{
			blip = vec3(49.69, 2778.33, 57.88),
			management = vec3(49.69, 2778.33, 57.88),
			delivery = vec3(49.69, 2778.33, 57.88),
			pumps = {
				vec3(50.30570602416992, 2778.53466796875, 57.04140090942383),
				vec3(48.9130973815918, 2779.58544921875, 57.04140090942383)
			}
		},

		{
			blip = vec3(264.15, 2607.05, 44.95),
			management = vec3(264.15, 2607.05, 44.95),
			delivery = vec3(264.15, 2607.05, 44.95),
			pumps = {
				vec3(264.976318359375, 2607.177734375, 43.98323059082031),
				vec3(263.08258056640627, 2606.794677734375, 43.98323059082031)
			}
		},

		{
			blip = vec3(1207.56, 2660.2, 37.81),
			management = vec3(1207.56, 2660.2, 37.81),
			delivery = vec3(1207.56, 2660.2, 37.81),
			pumps = {
				vec3(1208.509765625, 2659.427978515625, 36.89814758300781),
				vec3(1209.58154296875, 2658.3515625, 36.89955139160156),
				vec3(1205.8997802734376, 2662.048583984375, 36.89674377441406)
			}
		},

		{
			blip = vec3(2538.0, 2593.83, 37.94),
			management = vec3(2538.0, 2593.83, 37.94),
			delivery = vec3(2538.0, 2593.83, 37.94),
			pumps = {
				vec3(2539.79443359375, 2594.807861328125, 36.95571899414062)
			}
		},

		{
			blip = vec3(2680.01, 3265.0, 55.24),
			management = vec3(2680.01, 3265.0, 55.24),
			delivery = vec3(2680.01, 3265.0, 55.24),
			pumps = {
				vec3(2680.90234375, 3266.40771484375, 54.39086151123047),
				vec3(2678.512939453125, 3262.3369140625, 54.39086151123047)
			}
		},

		{
			blip = vec3(2005.07, 3774.33, 32.18),
			management = vec3(2005.07, 3774.33, 32.18),
			delivery = vec3(2005.07, 3774.33, 32.18),
			pumps = {
				vec3(2009.25439453125, 3776.7734375, 31.39846420288086),
				vec3(2006.205078125, 3774.95654296875, 31.39846420288086),
				vec3(2003.913818359375, 3773.47607421875, 31.39846420288086),
				vec3(2001.546875, 3772.20166015625, 31.39846420288086)
			}
		},

		{
			blip = vec3(1688.42, 4930.85, 42.08),
			management = vec3(1688.42, 4930.85, 42.08),
			delivery = vec3(1688.42, 4930.85, 42.08),
			pumps = {
				vec3(1684.5911865234376, 4931.6552734375, 41.22716522216797),
				vec3(1690.0948486328126, 4927.8017578125, 41.22769546508789)
			}
		},

		{
			blip = vec3(1039.34, 2671.78, 39.55),
			management = vec3(1039.34, 2671.78, 39.55),
			delivery = vec3(1039.34, 2671.78, 39.55),
			pumps = {
				vec3(1043.2193603515626, 2674.445556640625, 38.70339202880859),
				vec3(1035.4425048828126, 2674.435791015625, 38.70319366455078),
				vec3(1035.4423828125, 2667.904052734375, 38.70318984985351),
				vec3(1043.2196044921876, 2667.913818359375, 38.70345306396484)
			}
		},

		{
			blip = vec3(1785.58, 3330.47, 41.38),
			management = vec3(1785.58, 3330.47, 41.38),
			delivery = vec3(1785.58, 3330.47, 41.38),
			pumps = {
				vec3(1785.032470703125, 3331.47607421875, 40.34383392333984),
				vec3(1786.079833984375, 3329.853515625, 40.41194534301758)
			}
		},

		-- Paleto bay stations
		{
			blip = vec3(1702.79, 6416.86, 33.64),
			management = vec3(1702.79, 6416.86, 33.64),
			delivery = vec3(1702.79, 6416.86, 33.64),
			pumps = {
				vec3(1697.756591796875, 6418.34423828125, 31.760009765625),
				vec3(1701.724365234375, 6416.48291015625, 31.760009765625),
				vec3(1705.737060546875, 6414.60009765625, 31.760009765625)
			}
		},

		{
			blip = vec3(179.94, 6602.6, 31.85),
			management = vec3(179.94, 6602.6, 31.85),
			delivery = vec3(179.94, 6602.6, 31.85),
			pumps = {
				vec3(186.97091674804688, 6606.2177734375, 31.0625),
				vec3(179.67465209960938, 6604.9306640625, 31.0625),
				vec3(172.33335876464845, 6603.6357421875, 31.0625)
			}
		},

		{
			blip = vec3(-93.98, 6420.1, 31.48),
			management = vec3(-93.98, 6420.1, 31.48),
			delivery = vec3(-93.98, 6420.1, 31.48),
			pumps = {
				vec3(-97.06086730957031, 6416.7666015625, 30.64349365234375),
				vec3(-91.29045104980469, 6422.537109375, 30.64349365234375)
			}
		},

		{
			blip = vec3(-326.77, -938.38, 30.61),
			cantBeOwned = true,
			electricpumps = {
				vec4(-322.6, -936.04, 30.08, 342.13),
				vec4(-323.89, -939.51, 30.08, 342.67),
				vec4(-325.14, -943.0, 30.08, 349.69)
			}
		}
	}
}