package.path = package.path .. ";data/scripts/lib/?.lua"

include("weapontype")
include("relations")
include("defaultscripts")

local ShipUtility = include ("shiputility")
local MissionUT = include("missionutility")
local PirateGenerator = include("pirategenerator")
local SectorFighterGenerator = include("sectorfightergenerator")
local CaptainGenerator = include("captaingenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")

local VbmnUtil = {}
local self = VbmnUtil

VbmnUtil._Debug = 0

--region #FACTION GENERATION / INTERACTION

function VbmnUtil.getFriendlyFaction()
    local methodName = "Get Friendly Faction"
    self.Log(methodName, "Getting friendly faction.")

    local name = "Spears of Adrasteia"

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 230, 0) --Averaged mindist + maxdist, then averaged mindist + result of previous calc. This puts the faction in deep Trinium.
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToAll = true
        faction.staticRelationsToPlayers = true
        faction.homeSectorUnknown = true
    end

    return faction
end

function VbmnUtil.addFriendlyFactionRep(_player, amount)
    local methodName = "Add Friendly Faction Rep"
    local _faction = self.getFriendlyFaction()

    if not _faction then
        self.Log(methodName, "Could not find friendly faction.")
        return
    end

    local _Galaxy = Galaxy()
    local _Rel = _Galaxy:getFactionRelations(_faction, _player)
    _Galaxy:setFactionRelations(_faction, _player, _Rel + amount)
end

function VbmnUtil.setFriendlyFactionRep(_player, amount)
    local methodName = "Set Friendly Faction Rep"
    local _faction = self.getFriendlyFaction()

    if not _faction then
        self.Log(methodName, "Could not find friendly faction.")
        return
    end

    Galaxy():setFactionRelations(_faction, _player, amount)
end

--endregion

--region #DIALOG / CHAT MSG UTIL

function VbmnUtil.getDialogAllisonTalkerColor()
    return self.getDialogAllisonTextColor()
end

function VbmnUtil.getDialogAllisonTextColor()
    return ColorRGB(1.0, 0.0, 0.0)
end

function VbmnUtil.allisonChatter(_sector, chatter)
    local methodName = "Allison Chatter"
    _sector = _sector or Sector()
    local allisons = { _sector:getEntitiesByScriptValue("is_allison") }
    if #allisons > 0 then
        _sector:broadcastChatMessage(allisons[1], ChatMessageType.Chatter, chatter)
    end
end

--endregion

--region #SHIP GENERATION

--========================
--FRIENDLY SHIPS
--========================
function VbmnUtil.spawnAllison(deleteOnLeft, showAsUnknown)
    local methodName = "Spawn Allison"
    self.Log(methodName, "Running.")

    local useShipTitle = "Allison's Ship"
    if showAsUnknown then
        useShipTitle = "Unknown Ship"
    end

    local allisonData = {
        planFile = "data/plans/vengeance/vengeancenyiroro.xml",
        shipTitle = useShipTitle,
        shipName = "Erinyes",
        shipIcon = "data/textures/icons/pixel/flagship.png",
        scriptValues = { "is_allison" },
        armamentFunction = function(ship)
            ShipUtility.addSpecificScalableWeapon(ship, { WeaponType.Bolter }, 1.0, 1, nil)
            ShipUtility.addSpecificScalableWeapon(ship, { WeaponType.PlasmaGun }, 1.0, 0, nil)
            ShipUtility.addBossAntiTorpedoEquipment(ship)
        end,
        withdrawFunction = function(ship)
            --This can sometimes result in schrodinger's Allison with two of her showing up but trust me when I say that's better than the alternative.
            local withdrawMessages = {
                "I'll be back...",
                "I will return.",
                "I'm not finished yet...",
                "Tch. Withdrawing for now...",
                "Run while you can."
            }

            local withdrawData = {
                _Threshold = 0.10,
                _Invincibility = 0.02,
                _MinTime = 1,
                _MaxTime = 3,
                _WithdrawMessage = randomEntry(withdrawMessages),
                _SetValueOnWithdraw = "allison_withdrawing"
            }
    
            ship:addScript("ai/withdrawatlowhealth.lua", withdrawData)
        end
    }

    return VbmnUtil.spawnAdrasteiaShip(allisonData, deleteOnLeft)
end

function VbmnUtil.spawnAdrasteiaWarship(deleteOnLeft)
    local methodName = "Spawn Adrasteia Warship"
    self.Log(methodName, "Running.")

    local possiblePlans = {
        "data/plans/vengeance/vengeancecruiser1.xml",
        "data/plans/vengeance/vengeancecruiser2.xml"
    }

    shuffle(random(), possiblePlans)

    local warshipData = {
        planFile = possiblePlans[1],
        scriptValues = { "is_adrasteia_warship", "is_adrasteia_cruiser" },
        armamentFunction = function(ship)
            ShipUtility.addMilitaryEquipment(ship, 1.5, 1)
        end
    }

    return VbmnUtil.spawnAdrasteiaShip(warshipData, deleteOnLeft)
end

function VbmnUtil.spawnAdrasteiaMissileShip(deleteOnLeft)
    local methodName = "Spawn Adrasteia Missile Ship"
    self.Log(methodName, "Running.")

    local warshipData = {
        planFile = "data/plans/vengeance/vengeancemissilecruiser.xml",
        shipIcon = "data/textures/icons/pixel/torpedoboatex.png",
        scriptValues = { "is_adrasteia_warship", "is_adrasteia_missile_ship" },
        armamentFunction = function(ship)
            ShipUtility.addArtilleryEquipment(ship)

            local torpSlammerValues = {
                _TimeToActive = 10,
                _ROF = 4,
                _UpAdjust = false,
                _ForwardAdjustFactor = 1.5,
                _PreferWarheadType = 2, --Neutron
                _TargetPriority = 6 --Random pirate or xsotan
            }

            ship:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        end
    }

    return VbmnUtil.spawnAdrasteiaShip(warshipData, deleteOnLeft)
end

function VbmnUtil.spawnAdrasteiaHijackingShip(deleteOnLeft)
    local methodName = "Spawn Adrasteia Hijacking Ship"
    self.Log(methodName, "Running.")

    local shipData = {
        planFile = "data/plans/vengeance/vengeancehijacker.xml",
        shipTitle = "Hijacking Ship",
        shipIcon = "data/textures/icons/pixel/carrier.png",
        scriptValues = { "is_adrasteia_hijack_ship" },
        armamentFunction = function(ship)
            ShipUtility.addMilitaryEquipment(ship, 0.5, 1)
        end,
        preCrewFunction = function(ship)
            local hangar = Hangar(ship.index)

            local x, y = Sector():getCoordinates()

            for squadIdx = 1, 4 do
                local squad = hangar:addSquad("Boarder Squad")
                local fighter = SectorFighterGenerator():generateCrewShuttle(x, y)
                fighter.diameter = 1

                hangar:setBlueprint(squad, fighter)

                for i = hangar:getSquadFighters(squad), hangar:getSquadMaxFighters(squad) - 1 do
                    if hangar.freeSpace >= fighter.volume then 
                        hangar:addFighter(squad, fighter)
                    end
                end
            end
        end,
        postCrewFunction = function(ship)
            ship:addCrew(10000, CrewMan(CrewProfessionType.Attacker)) --Lucky us the AI doesn't have to worry about morale lmaooo
            ship:setCaptain(CaptainGenerator():generate()) --I dunno if boarding requires a captain but I'm not taking any chances here.

            ship:addMultiplyableBias(StatsBonuses.FighterSquads, 12) --Same with this - not sure if it's needed but not taking chances.
        end
    }

    return VbmnUtil.spawnAdrasteiaShip(shipData, deleteOnLeft)
end

function VbmnUtil.spawnAdrasteiaShip(shipData, deleteOnLeft)
    local methodName = "Spawn Adrasteia Ship"
    self.Log(methodName, "Running.")

    local faction = self.getFriendlyFaction()
    if not faction then
        self.Log(methodName, "Could not find faction.")
        return
    end

    local planName = shipData.planFile
    self.Log(methodName, "Spawning from plan " .. tostring(planName))
    local plan = LoadPlanFromFile(planName)
    local scale = 1.0

    plan:scale(vec3(scale, scale, scale))

    local ship = Sector():createShip(faction, "", plan, PirateGenerator.getGenericPosition())

    if shipData.armamentFunction then
        shipData.armamentFunction(ship)
    end

    ship:setDropsAttachedTurrets(false)

    if shipData.shipName then
        ship.name = shipData.shipName
    end
    if shipData.shipTitle then
        ship.title = shipData.shipTitle
    end

    --Add crew and run preCrew / postCrew functions if they exist. Mostly for the hijacking ship.
    if shipData.preCrewFunction then
        shipData.preCrewFunction(ship)
    end
    ship.crew = ship.idealCrew
    if shipData.postCrewFunction then
        shipData.postCrewFunction(ship)
    end

    if shipData.shipIcon then
        ship:addScript("icon.lua", shipData.shipIcon)
    end

    if shipData.withdrawFunction then
        shipData.withdrawFunction(ship)
    end

    ship:setValue("is_adrasteia", true)
    ship:setValue("is_adrasteia_ship", true)
    ship:setValue("_ESCC_bypass_hazard", true)
    ship:setValue("bDisableXAI", true)
    ship:setValue("SDKEDSDisabled", true)
    for _, value in pairs(shipData.scriptValues) do
        ship:setValue(value, true)
    end

    Boarding(ship).boardable = false
    ship.dockable = false

    if deleteOnLeft then
        self.Log(methodName, "Deleting entity on player leaving...")
        MissionUT.deleteOnPlayersLeft(ship)
    else
        self.Log(methodName, "Entity will not be deleted on player leaving.")
    end

    return ship
end

--========================
--ENEMY SHIPS
--========================
function VbmnUtil.spawnGruznier(faction, enhanced, lootFuncId, timesKilled)
    local methodName = "Spawn Brute Gruznier"
    self.Log(methodName, "Running.")

    local _sector = Sector()
    local _random = random()

    local planName = "data/plans/vengeance/gruznier.xml"
    self.Log(methodName, "Spawning from plan " .. tostring(planName))
    local plan = LoadPlanFromFile(planName)
    local scale = 1.0

    plan:scale(vec3(scale, scale, scale))

    local ship = _sector:createShip(faction, "", plan, PirateGenerator.getGenericPosition())

    ShipUtility.addMilitaryEquipment(ship, 2, 0)
    ShipUtility.addMilitaryEquipment(ship, 1.5, 0)

    ship:setDropsAttachedTurrets(false)

    local timesKilledToNumerals = timesKilled + 1

    ship.name = "Da Gruzier"
    if timesKilledToNumerals > 1 then
        ship.title = "Brute Gruznier ${num}" % { num = toRomanLiterals(timesKilledToNumerals) }
    else
        ship.title = "Brute Gruznier"
    end
    ship.crew = ship.idealCrew

    --Upgrade Gruznier thrusters
    self.Log(methodName, "Upgrading thrusters.")
    local _thrusters = Thrusters(ship)
    local thrustFactor = 2
    if enhanced then
        thrustFactor = 5 --Give him better thrusters if he is enhanced - this way he spends less time maneuvering and more time charging.
    end
    _thrusters.baseYaw = _thrusters.baseYaw * thrustFactor
    _thrusters.basePitch = _thrusters.basePitch * thrustFactor
    _thrusters.baseRoll = _thrusters.baseRoll * thrustFactor
    _thrusters.fixedStats = true

    self.Log(methodName, "Modfiying physics.")
    local _physics = Physics(ship)
    _physics.driftDecrease = 0.2 --So he doesn't drift quite as much. Makes him better able to ram.

    --Replace icon script
    self.Log(methodName, "Setting icon.lua")
    local safetyBreakout = 0
    while ship:hasScript("icon.lua") and safetyBreakout < 15 do
        ship:removeScript("icon.lua")
        safetyBreakout = safetyBreakout + 1
    end
    ship:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")

    self.Log(methodName, "Setting script values.")
    ship:setValue("is_pirate", true)
    ship:setValue("is_gruznier", true)
    ship:setValue("is_boss_gruznier", true)
    ship:setValue("_ESCC_bypass_hazard", true)
    ship:setValue("bDisableXAI", true) --Gruznier gets his own AI script.
    ship:setValue("SDKEDSDisabled", true)
    ship:setValue("IW_nuclear_m", 0.125)

    Boarding(ship).boardable = false
    ship.dockable = false

    self.Log(methodName, "Adding Loot")
    local shipLoot = Loot(ship)
    local x, y = _sector:getCoordinates()

    local lootFuncs = {
        function() --1 / good loot
            local turretGen = SectorTurretGenerator()

            --The velocity bypass / engine booster are kind of bad and not as useful as say, a m-tcs. Add 2 good turrets with an offset to compensate for this.
            shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, Rarity(RarityType.Exceptional))))
            shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, Rarity(RarityType.Exotic))))
            if random():test(0.5) then
                shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/enginebooster.lua", Rarity(RarityType.Exceptional), Seed(_random:getInt(1, 20000))))
                shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/velocitybypass.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))
            else
                shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/enginebooster.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))
                shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/velocitybypass.lua", Rarity(RarityType.Exceptional), Seed(_random:getInt(1, 20000))))
            end

            ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
        end,
        function() --2 / bad loot for mission 6 (in case of abandon after boss kill => retake)
            local turretGen = SectorTurretGenerator()
            local upgradeGen = UpgradeGenerator()

            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/enginebooster.lua", Rarity(RarityType.Rare), Seed(_random:getInt(1, 20000))))
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/velocitybypass.lua", Rarity(RarityType.Rare), Seed(_random:getInt(1, 20000))))
            
            for _ = 1, 4 do
                if _random:test(0.25) then
                    shipLoot:insert(upgradeGen:generateSectorSystem(x, y, nil, nil))
                else
                    shipLoot:insert(InventoryTurret(turretGen:generate(x, y, 0, nil, nil, nil)))
                end
            end
        end,
        function() --3 / loot for side mission
            local turretGen = SectorTurretGenerator()
            local upgradeGen = UpgradeGenerator()

            for _ = 1, 2 do
                --The velocity bypass / engine booster are kind of bad and not as useful as say, a m-tcs. Add 2 exotic turrets with an offset to compensate for this.
                shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -10, Rarity(RarityType.Exotic))))
            end

            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/enginebooster.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/velocitybypass.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))

            local _random = random()

            local rarityTable = {
                Rarity(RarityType.Common),
                Rarity(RarityType.Uncommon),
                Rarity(RarityType.Rare),
                Rarity(RarityType.Exceptional)
            }

            for _, useRarity in pairs(rarityTable) do
                for _ = 1, 2 do
                    if _random:test(0.5) then
                        shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, useRarity)))
                    else
                        shipLoot:insert(upgradeGen:generateSectorSystem(x, y, useRarity, nil))
                    end
                end
            end

            ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
        end
    }

    lootFuncs[lootFuncId]()

    return ship
end

function VbmnUtil.setGruznierAttack(gruznier, useEnhanced, personality)
    local gruzAI = ShipAI(gruznier)
    gruzAI:clearFriendFactions()
    gruzAI:clearFriendEntities()
    gruzAI:setIdle()
    gruzAI:setPassiveShooting(true)

    gruznier:addScriptOnce("player/missions/vengeance/story6/vengeance6gruznier.lua", useEnhanced, personality)
    gruznier:addScriptOnce("avenger.lua")
    gruznier:addScriptOnce("secondaryweapons.lua")
end

function VbmnUtil.spawnXinull(faction, lootFuncId, timesKilled)
    local methodName = "Spawn Boss Xinull"
    self.Log(methodName, "Running.")

    local _sector = Sector()
    local _random = random()

    local planName = "data/plans/vengeance/xinull.xml"
    self.Log(methodName, "Spawning from plan " .. tostring(planName))
    local plan = LoadPlanFromFile(planName)
    local scale = 1.0

    plan:scale(vec3(scale, scale, scale))

    local ship = _sector:createShip(faction, "", plan, PirateGenerator.getGenericPosition())

    ShipUtility.addSpecificScalableWeapon(ship, { WeaponType.ChainGun }, 3.0, 0, 800)
    ShipUtility.addBossAntiTorpedoEquipment(ship, nil, nil, 800)

    ship:setDropsAttachedTurrets(false)

    local timesKilledToNumerals = timesKilled + 1

    ship.damageMultiplier = (ship.damageMultiplier or 1) * 1.5

    if timesKilledToNumerals > 1 then
        ship.title = "Boss Xinull ${num}" % { num = toRomanLiterals(timesKilledToNumerals) }
    else
        ship.title = "Boss Xinull"
    end
    ship.crew = ship.idealCrew

    --Replace icon script
    self.Log(methodName, "Setting icon.lua")
    local safetyBreakout = 0
    while ship:hasScript("icon.lua") and safetyBreakout < 15 do
        ship:removeScript("icon.lua")
        safetyBreakout = safetyBreakout + 1
    end
    ship:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")

    self.Log(methodName, "Setting script values.")
    ship:setValue("is_pirate", true)
    ship:setValue("is_xinull", true)
    ship:setValue("is_boss_xinull", true)
    ship:setValue("_ESCC_bypass_hazard", true)
    ship:setValue("bDisableXAI", true)
    ship:setValue("SDKEDSDisabled", true)
    ship:setValue("IW_nuclear_m", 0.125)

    Boarding(ship).boardable = false
    ship.dockable = false

    self.Log(methodName, "Adding Loot")
    local shipLoot = Loot(ship)
    local x, y = _sector:getCoordinates()

    local lootFuncs = {
        function()
            local turretGen = SectorTurretGenerator()

            for _ = 1, 2 do
                shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, Rarity(RarityType.Exceptional))))
            end
            shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, Rarity(RarityType.Exotic))))

            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/shieldbooster.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))
            
            ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
        end,
        function()
            local turretGen = SectorTurretGenerator()
            local upgradeGen = UpgradeGenerator()

            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/shieldbooster.lua", Rarity(RarityType.Rare), Seed(_random:getInt(1, 20000))))
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Rare), Seed(_random:getInt(1, 20000))))
            
            for _ = 1, 4 do
                if _random:test(0.25) then
                    shipLoot:insert(upgradeGen:generateSectorSystem(x, y, nil, nil))
                else
                    shipLoot:insert(InventoryTurret(turretGen:generate(x, y, 0, nil, nil, nil)))
                end
            end
        end,
        function()
            local turretGen = SectorTurretGenerator()
            local upgradeGen = UpgradeGenerator()

            for _ = 1, 2 do
                shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -10, Rarity(RarityType.Exotic))))
            end

            local _random = random()

            local mtcsRarity = Rarity(RarityType.Exotic)
            if _random:test(0.125) then
                mtcsRarity = Rarity(RarityType.Legendary)
            end
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/shieldbooster.lua", mtcsRarity, Seed(_random:getInt(1, 20000))))
            shipLoot:insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))

            local rarityTable = {
                Rarity(RarityType.Common),
                Rarity(RarityType.Uncommon),
                Rarity(RarityType.Rare),
                Rarity(RarityType.Exceptional)
            }

            for _, useRarity in pairs(rarityTable) do
                for _ = 1, 3 do
                    if _random:test(0.5) then
                        shipLoot:insert(InventoryTurret(turretGen:generate(x, y, -5, useRarity)))
                    else
                        shipLoot:insert(upgradeGen:generateSectorSystem(x, y, useRarity, nil))
                    end
                end
            end

            ship:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
        end
    }

    lootFuncs[lootFuncId]()

    return ship
end

function VbmnUtil.setXinullAttack(xinull, useEnhanced, personality)
    local xinullAI = ShipAI(xinull)
    xinullAI:clearFriendFactions()
    xinullAI:clearFriendEntities()
    xinullAI:setAggressive()

    local torpSlammerValues = {
        _TimeToActivate = 45,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = 1, --normal damage for now - subject to balancing pass.
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 2,
        _PreferSecondaryWarheadType = 3,
        _TargetPriority = 8, --Target tag > Player
        _TargetTag = "is_allison",
        _RangeFactor = 3,
        _AccelFactor = 4,
        _VelocityFactor = 4,
        _TurningSpeedFactor = 4,
        _DrunkMode = true, --Randomizes accel / velocity / turning speed.
        _AntiAiDurabilityFactor = 9999 --Multiplies torpedo durability when target is NOT owned by player or alliance.
    }

    xinull:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
    xinull:addScriptOnce("avenger.lua", { _Multiplier = 1.05 })
    xinull:addScriptOnce("frenzy.lua", { _DamageThreshold = 1.1, _UpdateCycle = 5, _IncreasePerUpdate = 0.75 })
    xinull:addScriptOnce("player/missions/vengeance/story9/vengeance9xinull.lua", useEnhanced, personality)
end

--endregion

--region #LOGGING

function VbmnUtil.Log(methodName, msg)
    if VbmnUtil._Debug == 1 then
        print("[Vbmn Utility] - [" .. methodName .. "] - " .. msg)
    end
end

--endregion

return VbmnUtil