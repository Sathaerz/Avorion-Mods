--[[
    RAID PIRATE SHIPMENT
    NOTES:
        - Wanted to make a mission where you could fight to collect goods for turrets rather than trading.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - N/A
    ROUGH OUTLINE
        - 1 wave of transports per 2 danger levels show up (max of 5)
        - Transports / escort loosely based on Chasing Shadows (Horizon Story 3)
        - Mission ends after 5th wave destroyed or time runs out, whatever happens first. Player rewarded based on # of transports blown up.
        - Pick a turret before the mission. Transports are filled with random components for that turret.
        - Waves show up every 5 minutes. Player has 30 minutes to complete whole mission. Fails if *no* transport waves are blown up.
        - Ramp up difficulty quickly per wave spawned.
        - Ships get ~50% stronger per wave. You get a +25% bonus for each transport group killed after the first.
    DANGER LEVEL
        1+ - Spawn table. Maybe they get stronger faster - +15% per wave @ level 1 and +25% per wave @ level 10
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include("goodsindex")
include("weapontype")

ESCCUtil = include("esccutil")

local Balancing = include ("galaxy")
local ShipGenerator = include("shipgenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local ShipUtility = include("shiputility")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")
local TurretIngredients = include("turretingredients")

mission._Debug = 0
mission._Name = "Raid Pirate Shipment"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy transport groups", bulletPoint = true, visible = false, fulfilled = false },
    { text = "${_KILLED}/5 Destroyed", bulletPoint = true, visible = false, fulfilled = false },
    { text = "Destroy at least two groups", bulletPoint = true, visible = false, fulfilled = false }
}
mission.data.timeLimit = 10 * 60 --Player has 10 minutes to head to the sector. Take the time limit off when the player arrives.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "Good work on raiding that convoy. Here's your reward. Remember - you can keep any turret parts you found."
mission.data.failMessage = "You couldn't even destroy a single group of transports? We're not looking forward to facing those new weapons..."

mission.data.custom.objectiveScriptValue = "_raidpirateshipment_objective"
mission.data.custom.backgroundPirateScriptValue = "_raidpirateshipment_background_pirate"
mission.data.custom.danger9CustomMultiplier = 1.1
mission.data.custom.danger10CustomMultiplier = 1.25

local RRaidPirateShipment_init = initialize
function initialize(_Data_in, bulletin)
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(methodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

        local _sector = Sector()
        local _Giver = Entity(_Data_in.giver)

        local _X, _Y = _Data_in.location.x, _Data_in.location.y

        --Emergency breakout just in case the player somehow got this from a player faction.
        if _Giver.playerOrAllianceOwned then
            print("ERROR: Mission from player faction - aborting.")
            terminate()
            return
        end
        --[[=====================================================
            CUSTOM MISSION DATA SETUP:
        =========================================================]]
        mission.data.custom.dangerLevel = _Data_in.dangerLevel
        mission.data.custom.inBarrier = _Data_in.inBarrier
        mission.data.custom.weaponType = _Data_in.weaponType
        mission.data.custom.weaponTypeName = _Data_in.weaponTypeName
        local transportDefenders = 4
        local backgroundRespawnTime = 90
        local transportDespawnTime = 120
        local destroyedGroupRequirement = 1
        local maxBackgroundPirates = 6
        local backgroundPirateWaveCount = 4
        if mission.data.custom.dangerLevel > 5 then
            transportDefenders = transportDefenders + 1
            maxBackgroundPirates = maxBackgroundPirates + 2
        end
        if mission.data.custom.dangerLevel == 10 then
            transportDefenders = transportDefenders + 1
            backgroundRespawnTime = backgroundRespawnTime - 30
            transportDespawnTime = transportDespawnTime - 30
            maxBackgroundPirates = maxBackgroundPirates + 4
            backgroundPirateWaveCount = backgroundPirateWaveCount + 1
            destroyedGroupRequirement = 2
            mission.data.failMessage = "You didn't destroy enough of the transports. We're not looking forward to facing those new weapons..."
        end
        mission.data.custom.transportDefenders = transportDefenders
        mission.data.custom.backgroundRespawnTime = backgroundRespawnTime
        mission.data.custom.transportDespawnTime = transportDespawnTime
        mission.data.custom.spawnedTransportGroups = 0
        mission.data.custom.destroyedTransportGroups = 0
        mission.data.custom.checkForNoTransports = false --Turn this to true after spawning a wave.
        mission.data.custom.startTransportEscapeSequence = false
        mission.data.custom.spawnedEarlyTransportGroup = false
        mission.data.custom.spawnedEarlyBackgroundWave = false
        mission.data.custom.phase2BackgroundTimer = 0
        mission.data.custom.phase2TransportTimer = 0
        mission.data.custom.destroyedGroupRequirement = destroyedGroupRequirement
        mission.data.custom.maxBackgroundPirates = maxBackgroundPirates
        mission.data.custom.backgroundPirateWaveCount = backgroundPirateWaveCount

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { _X = _X, _Y = _Y, _WEAPONTYPE = mission.data.custom.weaponTypeName }
        mission.data.description[3].arguments = { _X = _X, _Y = _Y }
        mission.data.description[5].arguments = { _KILLED = mission.data.custom.destroyedTransportGroups }
    end

    --Run vanilla init. Managers _restoring on its own.
    RRaidPirateShipment_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS

mission.globalPhase.onAbandon = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
    end
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
    end
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
    end
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
    if mission.data.custom.dangerLevel == 10 then
        mission.data.description[6].visible = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(x, y) --Set the pirate level based on the target location.
    mission.data.custom.cleanUpSector = true
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].onBegin = function()
    mission.data.timeLimit = mission.internals.timePassed + (30 * 60) --Player has 30 minutes to blow up 5 groups. They only need to blow up 1 group to win.
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 2 Update Target Location Server"
    --Increment timer variables.
    mission.data.custom.phase2BackgroundTimer = mission.data.custom.phase2BackgroundTimer + timeStep
    mission.data.custom.phase2TransportTimer = mission.data.custom.phase2TransportTimer + timeStep

    --Manage background pirates.
    if mission.data.custom.phase2BackgroundTimer >= mission.data.custom.backgroundRespawnTime then
        raidPirateShipment_spawnBackgroundPirates()
        mission.data.custom.phase2BackgroundTimer = 0
    end

    --Check to see if the player has destroyed the entire transport group.
    local freighterCt = ESCCUtil.countEntitiesByValue(mission.data.custom.objectiveScriptValue)
    if mission.data.custom.checkForNoTransports and freighterCt == 0 then
        --All destroyed.
        mission.data.custom.destroyedTransportGroups = mission.data.custom.destroyedTransportGroups + 1

        mission.Log(methodName, "Destroyed groups: " .. tostring(mission.data.custom.destroyedTransportGroups) .. " Required: " .. tostring(mission.data.custom.destroyedGroupRequirement))
        if mission.data.custom.destroyedTransportGroups >= mission.data.custom.destroyedGroupRequirement then
            if mission.data.custom.dangerLevel == 10 then
                mission.data.description[6].fulfilled = true
            end
            mission.internals.fulfilled = true
        end

        mission.data.custom.checkForNoTransports = false
        mission.data.description[5].arguments = { _KILLED = mission.data.custom.destroyedTransportGroups }
        sync()
    end

    --Last, check to see if the player has taken too long to destroy the transport group.
    if mission.data.custom.phase2TransportTimer >= mission.data.custom.transportDespawnTime and not mission.data.custom.startTransportEscapeSequence then
        local freighters = { Sector():getEntitiesByScriptValue(mission.data.custom.objectiveScriptValue) }
        for _, freighter in pairs(freighters) do
            local jumpTime = random():getFloat(4, 5)
            freighter:addScript("utility/delayeddelete.lua", jumpTime)
        end
        deferredCallback(3.75, "raidPirateShipment_freighterEscaped") --line 382
        mission.data.custom.startTransportEscapeSequence = true
    end
end

mission.phases[2].onAccomplish = function()
    local _MethodName = "Phase 2 On Accomplish"
    mission.Log(_MethodName, "Running win condition.")

    --Player is given a 25% bonus per freighter group killed after the first
    local bonusMultiplier = math.max(0, mission.data.custom.destroyedTransportGroups - 1)
    local bonusFactor = 1 + (0.25 * bonusMultiplier)

    mission.Log(_MethodName, "Bonus factor is " .. tostring(bonusFactor))

    mission.data.reward.credits = mission.data.reward.credits * bonusFactor

    reward()
end

mission.phases[2].onFail = function()
    punish()
end

mission.phases[2].onPreRenderHud = function()
    if atTargetLocation() then
        raidPirateShipment_onMarkDroppedGoods()
    end
end

--region #PHASE 2 TIMER CALLS

if onServer() then

mission.phases[2].timers[1] = {
    time = 30,
    callback = function()
        --Should always be the first group to spawn buuuuut...
        if atTargetLocation() and mission.data.custom.spawnedTransportGroups < 5 and not mission.data.custom.spawnedEarlyTransportGroup then
            raidPirateShipment_spawnTransports()
            raidPirateShipment_spawnTransportDefenders()
            mission.data.custom.spawnedEarlyTransportGroup = true
        end
    end,
    repeating = true
}

mission.phases[2].timers[2] = {
    time = 15,
    callback = function()
        if atTargetLocation() and not mission.data.custom.spawnedEarlyBackgroundWave then
            raidPirateShipment_spawnBackgroundPirates()
            mission.data.custom.spawnedEarlyBackgroundWave = true
        end
    end,
    repeating = true
}

mission.phases[2].timers[3] = {
    time = 240,
    callback = function()
        if atTargetLocation() and mission.data.custom.spawnedTransportGroups < 5 then
            raidPirateShipment_spawnTransports()
            raidPirateShipment_spawnTransportDefenders()
        end
    end,
    repeating = true
}

mission.phases[2].timers[4] = {
    time = 15,
    callback = function()
        if mission.data.custom.destroyedTransportGroups >= 5 then
            accomplish()
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function raidPirateShipment_spawnTransportDefenders()
    local _MethodName = "Spawn Shipment Escort"
    mission.Log(_MethodName, "Spawning escorts at danger level " .. tostring(mission.data.custom.dangerLevel))

    local _random = random()

    --Pick a random transport and use that as the centerpiece in our formation. Spawn the pirates in a rough sphere around it.
    local _Freighters = { Sector():getEntitiesByScriptValue(mission.data.custom.objectiveScriptValue) }
    shuffle(_random, _Freighters)
    local _Centerpos = _Freighters[1].translationf

    local useTable = "Standard"
    if _random:test(0.025 * mission.data.custom.dangerLevel) then
        useTable = "High"
    end

    local _PirateGenerator = AsyncPirateGenerator(nil, raidPirateShipment_onTransportDefendersFinished)
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, mission.data.custom.transportDefenders, useTable)

    _PirateGenerator:startBatch()
    _PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    local _GetEscortPosition = function(_cpos)
        local vec = ESCCUtil.getVectorAtDistance(_cpos, 1000, false)
        local look = vec3(math.random(), math.random(), math.random())
        local up = vec3(math.random(), math.random(), math.random())

        return MatrixLookUpPosition(look, up, vec)
    end

    for _, _Pirate in pairs(_PirateTable) do
        _PirateGenerator:createPirateByName(_Pirate, _GetEscortPosition(_Centerpos))
    end

    _PirateGenerator:endBatch()
end

function raidPirateShipment_onTransportDefendersFinished(generated)
    for _, ship in pairs(generated) do
        raidPirateShipment_applyDurabilityAndDamageBuff(ship, 0.5)
    end

    SpawnUtility.addEnemyBuffs(generated)

    Placer.resolveIntersections()

    --We set it here so that the buffs are set appropriately. (i.e. transport defender wave 1 doesn't get buffed since it is spawned after the transports)
    mission.data.custom.spawnedTransportGroups = mission.data.custom.spawnedTransportGroups + 1
end

function raidPirateShipment_spawnBackgroundPirates()
    local methodName = "Spawn Background Pirates"
    mission.Log(methodName, "Running.")

    local backgroundPirateCt = ESCCUtil.countEntitiesByValue(mission.data.custom.backgroundPirateScriptValue)
    if backgroundPirateCt < mission.data.custom.maxBackgroundPirates then
        local piratesToSpawn = mission.data.custom.maxBackgroundPirates - backgroundPirateCt
        piratesToSpawn = math.min(piratesToSpawn, mission.data.custom.backgroundPirateWaveCount) --cap at mission value. max is 5 @ danger 10.

        mission.Log(methodName, "Spawning " .. tostring(piratesToSpawn) .. " pirates.")

        local spawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, piratesToSpawn, "Low", false)

        local generator = AsyncPirateGenerator(nil, raidPirateShipment_onBackgroundPiratesFinished)
    
        generator:startBatch()
    
        local distance = 250 --_#DistAdj
        local pirate_positions = generator:getStandardPositions(piratesToSpawn, distance)
        for idx, p in pairs(spawnTable) do
            generator:createScaledPirateByName(p, pirate_positions[idx])
        end
    
        generator:endBatch()
    end
end

function raidPirateShipment_onBackgroundPiratesFinished(generated)
    for _, ship in pairs(generated) do
        ship:setValue(mission.data.custom.backgroundPirateScriptValue, true)
        raidPirateShipment_applyDurabilityAndDamageBuff(ship, 0.5)
        ship:setDropsLoot(false)
    end

    SpawnUtility.addEnemyBuffs(generated)
end

function raidPirateShipment_spawnTransports()
    local methodName = "Spawn Pirate Transports"
    mission.Log(methodName, "Running.")

    --Reset mission / timer variables before we do anything.
    mission.data.custom.phase2TransportTimer = 0
    mission.data.custom.startTransportEscapeSequence = false
    mission.data.custom.checkForNoTransports = true

    local _sector = Sector()
    local _random = random()

    local x, y = _sector:getCoordinates()
    local sectorVolume = Balancing_GetSectorShipVolume(x, y)
    local _Vol1 = sectorVolume * 4
    local _Vol2 = sectorVolume * 6
    local _Vol3 = sectorVolume * 8
    local pirateFaction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)

    local look = _random:getVector(-100, 100)
    local up = _random:getVector(-100, 100)
    local pos = vec3(0, 0, 0)

    local _basepos = ESCCUtil.getVectorAtDistance(pos, 4000, true)
    local _unit = 150
    local _p1 = vec3(_basepos.x + (_unit*2), _basepos.y + (_unit*1), _basepos.z + (_unit*1))
    local _p2 = vec3(_basepos.x, _basepos.y + (_unit*-1), _basepos.z)
    local _p3 = vec3(_basepos.x + (_unit*-2), _basepos.y + (_unit*-1), _basepos.z + (_unit*-1))
    local _p4 = vec3(_basepos.x + (_unit*-4), _basepos.y + (_unit*1), _basepos.z + (_unit*-1))
    local _p5 = vec3(_basepos.x + (_unit*-6), _basepos.y + (_unit*-1), _basepos.z + (_unit*1))

    local _Freighters = {}

    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p1), _Vol1))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p2), _Vol1))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p3), _Vol3))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p4), _Vol2))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p5), _Vol2))

    for _, _ship in pairs(_Freighters) do
        _ship:setValue("is_pirate", true)
        _ship:setValue("bDisableXAI", true) --Disable any Xavorion AI
        _ship:setValue(mission.data.custom.objectiveScriptValue, true)
        ESCCUtil.removeCivilScripts(_ship)
        Boarding(_ship).boardable = false

        --add cargo here
        local possibleIngredients = TurretIngredients[mission.data.custom.weaponType]
        local chosenIngredient = getRandomEntry(possibleIngredients)

        --Pick an amount.
        local lowAmount = 50
        local highAmount = 50 + (10 * mission.data.custom.dangerLevel)
        local waveCargoBonus = 1.0 + (mission.data.custom.spawnedTransportGroups * 0.05)
        local regionalBonus = raidPirateShipment_getRegionalLootBonus()
        if mission.data.custom.dangerLevel == 9 then
            waveCargoBonus = waveCargoBonus * mission.data.custom.danger9CustomMultiplier
        end
        if mission.data.custom.dangerLevel == 10 then
            waveCargoBonus = waveCargoBonus * mission.data.custom.danger10CustomMultiplier
        end
        local servoCargoBonus = 1.0 --For some reason you always need an ungodly # of servos.
        if chosenIngredient.name == "Servo" then
            servoCargoBonus = servoCargoBonus * 1.5 
        end
        local baseAmount = _random:getInt(lowAmount, highAmount)
        local finalAmount = baseAmount * waveCargoBonus * servoCargoBonus * regionalBonus
        finalAmount = math.floor(finalAmount)

        local cargoGood = goods[chosenIngredient.name]

        mission.Log(methodName, "Adding " .. tostring(finalAmount) .. " " .. tostring(chosenIngredient.name) .. " to freighter.")

        _ship:addCargo(cargoGood:good(), finalAmount)

        --arm here
        --first, strip off existing turrets (passive shooting does not work properly with mixed ranges)
        local shipTurrets = {_ship:getTurrets()}
        for _, turret in pairs(shipTurrets) do
            _sector:deleteEntity(turret)
        end
        --next, add cannons
        local cannonRange = 3000 + _random:getInt(0, 150 * mission.data.custom.dangerLevel) --Make them really long range :D
        local cannonFactor = math.floor(mission.data.custom.dangerLevel / 3)
        ShipUtility.addSpecificScalableWeapon(_ship, { WeaponType.Cannon }, cannonFactor, 0, cannonRange)
        raidPirateShipment_applyDurabilityAndDamageBuff(_ship, 0.25)

        _ship:setDropsAttachedTurrets(false) --We futz with the turrets, so we don't necessarily want to drop them.

        --set AI
        local _ShipAI = ShipAI(_ship)
        local _ShipPos = _ship.position

        _ShipAI:setPassiveShooting(true)
        _ShipAI:setFlyLinear(_ShipPos.look * 20000, 0, false)
    end
end

function raidPirateShipment_getRegionalLootBonus()
    local bonus = 1.0

    local x, y = Sector():getCoordinates()
    local dist = length(vec2(x, y))

    if dist <= 215 then
        bonus = 1.25
    end
    if mission.data.custom.inBarrier then
        bonus = 2.0
    end

    return bonus
end

function raidPirateShipment_applyDurabilityAndDamageBuff(ship, perWaveMultiplier)
    local methodName = "Add Wave-based buff"

    local waveBasedBuff = 1.0 + (mission.data.custom.spawnedTransportGroups * perWaveMultiplier)
    if mission.data.custom.dangerLevel == 9 then
        waveBasedBuff = waveBasedBuff * mission.data.custom.danger9CustomMultiplier
    end
    if mission.data.custom.dangerLevel == 10 then
        waveBasedBuff = waveBasedBuff * mission.data.custom.danger10CustomMultiplier
    end

    mission.Log(methodName, "Buff is " .. tostring(waveBasedBuff))

    ESCCUtil.multiplyOverallDurability(ship, waveBasedBuff)

    ship.damageMultiplier = (ship.damageMultiplier or 1) * waveBasedBuff
end

function raidPirateShipment_freighterEscaped()
    mission.data.custom.checkForNoTransports = false
end

--endregion

--region #CLIENT CALLS

function raidPirateShipment_onMarkDroppedGoods()
    local methodName = "On Mark Dropped Goods"

    local _player = Player()
    if not _player then
        return
    end
    if _player.state == PlayerStateType.BuildCraft or _player.state == PlayerStateType.BuildTurret or _player.state == PlayerStateType.PhotoMode then
        return
    end

    local _sector = Sector()
    local renderer = UIRenderer()

    local possibleIngredients = TurretIngredients[mission.data.custom.weaponType]
    local indicatorColor = ESCCUtil.getSaneColor(255, 173, 0)

    for _, entity in pairs({_sector:getEntitiesByComponent(ComponentType.CargoLoot)}) do
        local loot = CargoLoot(entity)
        if valid(entity) then
            for _, ingredient in pairs(possibleIngredients) do
                if loot:matches(ingredient.name) then
                    local indicator = TargetIndicator(entity)
                    indicator.visuals = TargetIndicatorVisuals.Tilted
                    indicator.color = indicatorColor

                    renderer:renderTargetIndicator(indicator)
                end
            end
        end
    end

    renderer:display()
end

--endregion

--region #MAKEBULLETIN CALLS

function raidPirateShipment_formatDescription(station)
    local stationFaction = Faction(station.factionIndex)
    local aggressive = stationFaction:getTrait("aggressive")

    local descriptionType = 1
    if aggressive > 0.5 then
        descriptionType = 2
    elseif aggressive < -0.5 then
        descriptionType = 3
    end

    local descriptionOptions = {
        "Greetings, Captain. We've received credible intelligence that some local pirate are developing a new type of ${_WEAPONTYPE}. If they succeed, it would adversely impact ouf combat operations in the area. We need you to disrupt their shipping operation in (${_X}:${_Y}). Don't worry - you'll be well compensated.", --Netural
        "We've heard some rumors of pirate scum developing a new type of ${_WEAPONTYPE}. We will not allow this to happen. They're moving a large caravan through sector (${_X}:${_Y}). Intercept and eliminate it. We'd prefer if you left no survivors, but destroying a single group of their freighters should suffice.", --Aggressive
        "Peace be with you, Captain. We've discovered that some nearby pirates intend to build a new type of ${_WEAPONTYPE}. We cannot allow this. Their ships are already threatening enough, even without this addition to their aresnal. Their convoy is moving through (${_X}:${_Y}). Any disruption will be a welcome reprive." --Peaceful
    }

    return descriptionOptions[descriptionType]
end

mission.makeBulletin = function(station)
    local methodName = "Make Bulletin"

    local _sector = Sector()
    local _random = random()

    local target = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 5, 17, insideBarrier)

    if not target.x or not target.y then
        mission.Log(methodName, "target.x or target.y not set - returning nil.")
        return
    end

    local dangerLevel = _random:getInt(1, 10)

    local missionDifficulty = "Medium"
    if dangerLevel > 5 then
        missionDifficulty = "Difficult"
    end
    if dangerLevel == 10 then
        missionDifficulty = "Extreme"
    end

    --Choose from available weapon types in this part of the galaxy
    --We can't use an offset here, unfortunately. Otherwise we might end up with a weapon that can't be built in this sector due to either tech level or type constraints.
    local useSector = math.max(0, math.floor(length(vec2(x, y)))) 
    local armedWeaponTypes = {WeaponTypes.getArmed()}
    local weaponTypes = Balancing_GetWeaponProbability(useSector, 0)
    local weaponIndexes = {}
    --Now we need to pick one.
    for ok, ov in pairs(armedWeaponTypes) do
        --ov or "outer value" is the weapon index - ok = 1 / ov = 0 - chaingun is index 0, so ov is chaingun.
        for ik, iv in pairs(weaponTypes) do
            --ik or "inner key" is the weapon index - this is what we want. We don't care about iv or "inner value" - iv is the probability.
            if ik == ov then
                table.insert(weaponIndexes, ik)
                break --break out of inner loop. We only care about index, since this means that the weapon is in the probability list for distance.
            end
        end
    end
    --Why do all of this? To keep it so that we don't get a railgun prototype out in the iron/titanium region of the galaxy.
    --Picking by weight would be easier, but we want equal odds of all the weapons.
    --Once we have the list of indexes, though, getting the actual name of the weapon type is easy enough.
    local missionWeaponType = getRandomEntry(weaponIndexes)
    mission.Log(methodName, WeaponTypes.nameByType[missionWeaponType] .. " (" .. tostring(missionWeaponType) .. ") is the chosen weapon for this mission.")
    local missionWeaponTypeName = WeaponTypes.nameByType[missionWeaponType]

    --Format description
    local missionDescription = raidPirateShipment_formatDescription(station)

    local baseReward = 25000
    if dangerLevel > 5 then
        baseReward = baseReward + 5000
    end
    if dangerLevel == 10 then
        baseReward = baseReward + 5000
    end
    if insideBarrier then
        baseReward = baseReward * 2
    end

    reward = baseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates())
    reputation = 6000
    if dangerLevel == 10 then
        reputation = reputation + 2000
    end

    local bulletin = {
        --data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = missionDescription,
        difficulty = missionDifficulty,
        reward = "¢${reward}",
        script = "missions/raidpirateshipment.lua",
        formatArguments = { _X = target.x , _Y = target.y, _WEAPONTYPE = missionWeaponTypeName, reward = createMonetaryString(reward)},
        msg = "Thanks for your help. The shipment will be moving through \\s(%1%:%2%) soon.",
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments._X, self.formatArguments._Y)
        ]],

        --data that's important for our mission
        arguments = {{
            giver = station.index,
            location = target,
            reward = { credits = reward, relations = reputation, paymentMessage = "Earned %1% for raiding the pirate shipment." },
            punishment = { relations = 4000 },
            dangerLevel = dangerLevel,
            initialDesc = missionDescription,
            weaponType = missionWeaponType,
            weaponTypeName= WeaponTypes.nameByType[missionWeaponType],
            inBarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion