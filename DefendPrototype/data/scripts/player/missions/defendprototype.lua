--[[
    Defend Prototype Battleship
    NOTES:
        - Had the idea for this for a while, but now I think I've got the tech to make this happen.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - None. Take it from a mission board.
    ROUGH OUTLINE
        - Go to location. Defend Battleship.
        - Difficulty 1 - Military Outpost / Shipyard / Repair Dock / Equipment Dock
        - Difficulty 5+ - Shipyard / Repair Dock / Equipment Dock, switch to "high" table instead of low table.
        - Difficulty 8+ - Shipyard only, enemy waves have +1 enemy.
        - Difficulty 10 - Every other wave has a deadshot.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Balancing = include ("galaxy")
local SectorGenerator = include ("SectorGenerator")
local PrototypeGenerator = include("defendprotogenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local TorpedoUtility = include ("torpedoutility")
local ShipGenerator = include("shipgenerator")
local Placer = include("placer")
local UpgradeGenerator = include ("upgradegenerator")

mission._Debug = 0
mission._Name = "Defend Prototype Battleship"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Prepare your defense", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defend the Prototype", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 10 * 60 --Player has 10 minutes to head to the sector. Take the time limit off when the player arrives.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "..." --Placeholder, varies by faction.
mission.data.failMessage = "..." --Placeholder, varies by faction.

mission.data.custom.prototypeScriptPath = "player/missions/defendprototype/defendprotoboss.lua"
mission.data.custom.prototypeScriptValue = "is_prototype"
mission.data.custom.defendPrototypeTracks = {
    "data/music/background/blockdodgerlaststand.ogg",
    "data/music/background/cncthedefense.ogg",
    "data/music/background/hr2shortcircuit.ogg",
    "data/music/background/d3dpissedofficebox.ogg",
    "data/music/background/mw2mercsdragonsteeth.ogg",
    "data/music/background/ys2pcepalaceofdestruction.ogg"
}

local DefendPrototype_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)

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
            mission.data.custom.friendlyFaction = _Giver.factionIndex
            mission.data.custom.waveCounter = 1
            mission.data.custom.piratesSpawned = 0
            mission.data.custom.piratesKilled = 0
            mission.data.custom.piratesToKill = 30 + math.floor((mission.data.custom.dangerLevel * 1.5)) --From 30 to 45 at level 10.
            mission.data.custom.phaseTwoTimer = 0
            mission.data.custom.rewardBonus = true
            mission.data.custom.defendPrototypeTrack = getRandomEntry(mission.data.custom.defendPrototypeTracks)
            mission.data.custom.inBarrier = _Data_in.inbarrier

            if not mission.data.custom.friendlyFaction then
                print("ERROR: Friendly faction is nil - aborting.")
                terminate()
                return
            end

            --[[=====================================================
                MISSION DESCRIPTION SETUP:
            =========================================================]]
            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { x = _X, y = _Y }
            mission.data.description[3].arguments = { _X = _X, _Y = _Y }

            mission.data.accomplishMessage = _Data_in.winMsg
            mission.data.failMessage = _Data_in.loseMsg

            --Run standard initialization
            DefendPrototype_init(_Data_in)
        else
            --Restoring
            DefendPrototype_init()
        end
    end
    
    if onClient() then
        if not _restoring then
            initialSync()
        else
            sync()
        end
    end
end

--endregion

--region #PHASE CALLS
--Try to keep the timer calls outside of onBeginServer / onSectorEntered / onSectorArrivalConfirmed unless they are non-repeating and 30 seconds or less.

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.getRewardedItems = function()
    local _random = random()

    if _random:test(0.25) then
        local _X, _Y = mission.data.location.x, mission.data.location.y
        local _upgradeGenerator = UpgradeGenerator()
        local _upgradeRarities = getSectorRarityTables(_X, _Y, _upgradeGenerator)
        local _seedInt = _random:getInt(1, 20000)
        return SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(getValueFromDistribution(_upgradeRarities)), Seed(_seedInt))
    end
end

mission.globalPhase.onAbandon = function()
    failAndPunish() --Will run globalPhase.onFail and clean up the sector.
end

mission.globalPhase.onFail = function()
    setGameMusic()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    setGameMusic()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(false)
    end
end

--PHASE 1

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false 
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    spawnDefenseSector(_X, _Y)
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _sector = Sector()

    local prototypeTable = { _sector:getEntitiesByScriptValue(mission.data.custom.prototypeScriptValue) }
    local prototype = prototypeTable[1]

    _sector:broadcastChatMessage(prototype, ChatMessageType.Chatter, "Thank you for the assistance! The pirates are on their way. Use this time to set up your defensive line!")

    nextPhase()
end

--PHASE 2

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phaseTwoTimer = mission.data.custom.phaseTwoTimer + timeStep

    --It's unlikely that we'd be out of the sector since the timer only ticks while we're in the sector, but it's still good to check.
    if atTargetLocation() and mission.data.custom.phaseTwoTimer >= 180 then
        local _sector = Sector()

        local prototypeTable = { _sector:getEntitiesByScriptValue(mission.data.custom.prototypeScriptValue) }
        local prototype = prototypeTable[1]

        _sector:broadcastChatMessage(prototype, ChatMessageType.Chatter, "They'll be here soon! Get ready!")
        nextPhase()
    end
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    onDefendPrototypeLocationEntered(_X, _Y)
end

mission.phases[2].onTargetLocationLeft = function(_X, _Y)
    onDefendPrototypeLocationLeft(_X, _Y)
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    --It's unlikely that we hit this, unless the player has a massive xsotan attack event on them and they manage to overwhelm the defenders.
    onDefendPrototypeEntityDestroyed(_ID, _LastDamageInflictor)
end


--PHASE 3

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[3].onBeginServer = function()
    setCustomMusic(mission.data.custom.defendPrototypeTrack)
end

mission.phases[3].onTargetLocationEntered = function(_X, _Y)
    onDefendPrototypeLocationEntered(_X, _Y)
end

mission.phases[3].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic(mission.data.custom.defendPrototypeTrack)
end

mission.phases[3].onTargetLocationLeft = function(_X, _Y)
    onDefendPrototypeLocationLeft(_X, _Y)

    if onServer() then
        setGameMusic()
    end
end

mission.phases[3].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    onDefendPrototypeEntityDestroyed(_ID, _LastDamageInflictor)
end

--region #PHASE 3 TIMERS

if onServer() then

--Timer 1 = spawn first wave
mission.phases[3].timers[1] = {
    time = 5,
    callback = function()
        if atTargetLocation() then
            spawnBackgroundPirates()
        end
    end,
    repeating = false
}

--Timer 2 = spawn background pirates
mission.phases[3].timers[2] = {
    time = 60,
    callback = function()
        if atTargetLocation() then
            spawnBackgroundPirates()
        end
    end,
    repeating = true
}

--Timer 3 - finish conditions - both win and lose.
mission.phases[3].timers[3] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 3 Timer 3 Callback"
        mission.Log(_MethodName, "Beginning...")
        mission.Log(_MethodName, "Number of pirates destroyed " .. tostring(mission.data.custom.piratesKilled))

        local _Sector = Sector()
        local _OnLocation = atTargetLocation()
        local _Prototypes = {_Sector:getEntitiesByScriptValue(mission.data.custom.prototypeScriptValue)}

        if _OnLocation and mission.data.custom.piratesKilled >= mission.data.custom.piratesToKill then
            finishAndReward()
        end

        if _OnLocation and #_Prototypes == 0 then
            --Happens if the prototype gets destroyed while we're out of sector 
            -- it's possible for this to happen in the 5 minute window between the player leaving and returning before failing the mission.
            failAndPunish()
        end
    end,
    repeating = true
}

--Timer 4 - station buffs.
mission.phases[3].timers[4] = {
    time = 30,
    callback = function()
        local _MethodName = "Phase 3 Timer 4 Callback"
        --If the shipyard is up, it will repair the prototype. Repairs 5% by default, and +1% for each other station in the area.

        local _Sector = Sector()

        --Get the shipyard
        local _Shipyards = {_Sector:getEntitiesByScript("data/scripts/entity/merchants/shipyard.lua")}
        local _Shipyard = _Shipyards[1]

        --Get the prototype
        local _Prototypes = {_Sector:getEntitiesByScriptValue(mission.data.custom.prototypeScriptValue)}
        local _Prototype = _Prototypes[1]

        if atTargetLocation() and _Shipyard and valid(_Shipyard) and _Prototype and valid(_Prototype) then
            mission.Log(_MethodName, "On location and a shipyard is present. Repairing the prototype.")
            --Get the # of other stations
            local _Stations = {_Sector:getEntitiesByType(EntityType.Station)}
            local _StationCt = #_Stations

            --Repair the prototype
            local _RepairPct = _StationCt * 0.01 --1% per station.
            if mission.data.custom.dangerLevel == 10 then
                _RepairPct = 0.03 --Give a 3% automatically on difficulty 10. 
            end
            local _ProtoHull = _Prototype.durability
            local _ProtoMaxHull = _Prototype.maxDurability
    
            local _RepairAmt = _ProtoMaxHull * _RepairPct
            local prototypeHPRatio = _ProtoHull / _ProtoMaxHull

            --If the player lets the prototype HP dip below 75%, they don't get the bonus.
            if prototypeHPRatio < 0.75 then
                mission.data.custom.rewardBonus = false
            end
    
            if _ProtoHull < _ProtoMaxHull then
                mission.Log(_MethodName, "Prototype hull BEFORE: " .. tostring(_Prototype.durability))
                _Prototype.durability = math.min(_Prototype.durability + _RepairAmt, _ProtoMaxHull)
                mission.Log(_MethodName, "Prototype hull AFTER: " .. tostring(_Prototype.durability))
                
                invokeClientFunction(Player(), "playHealAnimations", _Shipyard, _Prototype)
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function spawnDefenseSector(_X, _Y)
    local _MethodName = "Spawn Defense Sector"

    local _Generator = SectorGenerator(_X, _Y)
    local _Faction = Faction(mission.data.custom.friendlyFaction)

    mission.Log(_MethodName, "Building sector for friendly faction: " .. tostring(_Faction.name))

    local _SpawnOutpost = true
    local _SpawnDocks = true

    if mission.data.custom.dangerLevel >= 5 then
        _SpawnOutpost = false
    end

    if mission.data.custom.dangerLevel >= 8 then
        _SpawnDocks = false
    end

    local _Stations = {}

    if _SpawnOutpost then
        local _MilBase = _Generator:createMilitaryBase(_Faction)

        _MilBase:setValue("_defendprototype_station", true)
        table.insert(_Stations, _MilBase)
    end

    if _SpawnDocks then
        local _RepairDock = _Generator:createRepairDock(_Faction)
        local _EquipDock = _Generator:createEquipmentDock(_Faction)

        _RepairDock:setValue("_defendprototype_station", true)
        _EquipDock:setValue("_defendprototype_station", true)
        table.insert(_Stations, _RepairDock)
        table.insert(_Stations, _EquipDock)
    end

    local _Shipyard = _Generator:createShipyard(_Faction)

    _Shipyard:setValue("_defendprototype_station", true)
    table.insert(_Stations, _Shipyard)

    for _, _s in pairs(_Stations) do
        --Remove cargo to prevent abuse - also remove bulletin boards.
        local _StationBay = CargoBay(_s)
        _StationBay:clear()
        _s:setDropsLoot(false)
        _s:removeScript("bulletinboard.lua")
        _s:removeScript("missionbulletins.lua")
        _s:removeScript("story/bulletins.lua")
    end

    --Make asteroid fields.
    local maxFields = random():getInt(2, 5)
    for _ = 1, maxFields do
        _Generator:createSmallAsteroidField()
    end

    --Add sector defenders - higher levels get more defenders because the pirates get brutal @ danger 10.
    local _DefendersMax = 3
    if mission.data.custom.dangerLevel >= 5 then
        _DefendersMax = _DefendersMax + 1
    end

    for _ = 1, _DefendersMax do
        ShipGenerator.createDefender(_Faction, _Generator:getPositionInSector())
    end

    --Make prototype.
    spawnPrototype(_Shipyard.position)

    --Prototype should be near the shipyard, but not intersect with it.
    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true
end

function spawnPrototype(_position)
    local _MethodName = "Spawn Prototype"
    local _DuraFactor = 2
    local _DamageFactor = 1.4

    local _Danger = mission.data.custom.dangerLevel
    local _Faction = Faction(mission.data.custom.friendlyFaction)
    local _BattleShip = PrototypeGenerator.create(_position, _Faction, _Danger, nil)

    --Add durability.
    local durability = Durability(_BattleShip)
    if durability then 
        local _Factor = (durability.maxDurabilityFactor or 1) * _DuraFactor
        mission.Log(_MethodName, "Setting durability factor of the prototype to : " .. tostring(_Factor))
        durability.maxDurabilityFactor = _Factor
    end

    --Add damage.
    local _FinalDamageFactor = (_BattleShip.damageMultiplier or 1) * _DamageFactor
    mission.Log(_MethodName, "Setting final damage factor to : " .. tostring(_FinalDamageFactor))
    _BattleShip.damageMultiplier = _FinalDamageFactor

    --Attach "boss" script to the prototype so the player can track HP
    _BattleShip:addScriptOnce(mission.data.custom.prototypeScriptPath)
end

function onDefendPrototypeEntityDestroyed(_ID, _LastDamageInflictor)
    local _DestroyedEntity = Entity(_ID)
    if atTargetLocation() then
        if _DestroyedEntity:getValue(mission.data.custom.prototypeScriptValue) then
            failAndPunish()
        end

        if _DestroyedEntity:getValue("is_pirate") then
            mission.data.custom.piratesKilled = mission.data.custom.piratesKilled + 1
        end
    end
end

function onDefendPrototypeLocationLeft(x, y)
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

function onDefendPrototypeLocationEntered(x, y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

function getWingSpawnTables(_WingScriptValue)
    local _MethodName = "Get Wing Spawn Table"
    mission.Log(_MethodName, "Getting table for " .. tostring(_WingScriptValue))

    local _Danger = mission.data.custom.dangerLevel

    local _MaxCt = 4
    if _WingScriptValue == "_defendprototype_gamma_wing" then
        _MaxCt = 3
    end

    if mission.data.custom.dangerLevel == 10 and random():test(0.5) then
        _MaxCt = _MaxCt + 1
    end

    local _Pirates = {Sector():getEntitiesByScriptValue(_WingScriptValue)}
    local _Ct = #_Pirates

    local _SpawnCt = _MaxCt - _Ct
    local _SpawnDanger = _Danger

    local _Threat = "Standard"
    if mission.data.custom.dangerLevel >= 6 then
        _Threat = "High"
    end

    local _SpawnTable = {}
    if _SpawnCt > 0 then
        _SpawnTable = ESCCUtil.getStandardWave(_SpawnDanger, _SpawnCt, _Threat, false)
    end

    return _SpawnTable
end

function spawnBackgroundPirates()
    local _MethodName = "Spawn Background Pirates"
    mission.Log(_MethodName, "Beginning...")

    local distance = 250 --_#DistAdj

    local _spawnFunc = function(wingScriptValue, wingOnSpawnFunc)
        local _WingSpawnTable = getWingSpawnTables(wingScriptValue)
        local wingGenerator = AsyncPirateGenerator(nil, wingOnSpawnFunc)

        local posCounter = 1
        local wingPositions = wingGenerator:getStandardPositions(#_WingSpawnTable, distance)
        
        wingGenerator:startBatch()

        for _, p in pairs(_WingSpawnTable) do
            wingGenerator:createScaledPirateByName(p, wingPositions[posCounter])
            posCounter = posCounter + 1
        end

        wingGenerator:endBatch()
    end

    --spawn alpha
    _spawnFunc("_defendprototype_alpha_wing", onAlphaBackgroundPiratesFinished)

    --spawn beta
    _spawnFunc("_defendprototype_beta_wing", onBetaBackgroundPiratesFinished)

    --spawn gamma if conditions are met
    if mission.data.custom.dangerLevel >= 6 then
        local _mod = 6
        if mission.data.custom.dangerLevel >= 8 then
            _mod = 4
        end

        local modWaveCounter = mission.data.custom.waveCounter % _mod
        if modWaveCounter == 0 then
            if random():test(0.5) then
                mission.Log(_MethodName, "Mod is " .. tostring(_mod) .. " wave counter is " .. tostring(mission.data.custom.waveCounter) .. " and 50% test passed.")
                _spawnFunc("_defendprototype_gamma_wing", onGammaBackgroundPiratesFinished)
            else
                mission.Log(_MethodName, "50% test failed")
            end
        else
            mission.Log(_MethodName, "Mod Wave Counter is " .. tostring(modWaveCounter))
        end
    end

    mission.data.custom.waveCounter = mission.data.custom.waveCounter + 1 --Regardless of how many pirates we actually spawn, increment the wave counter.
end

function onAlphaBackgroundPiratesFinished(_Generated)
    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_defendprototype_alpha_wing", true)

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local _PiratesSpawned = mission.data.custom.piratesSpawned + 1
        local _Factor = 2
        if _PiratesSpawned >= 20 then
            _Factor = 3
        end
        if _PiratesSpawned % _Factor ~= 0 then
            _Pirate:setDropsLoot(false)
        end
        mission.data.custom.piratesSpawned = _PiratesSpawned
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function onBetaBackgroundPiratesFinished(_Generated)
    local _MethodName = "On Beta Background Pirates Finished"
    local _Sector = Sector()
    local _random = random()
    local _X, _Y = _Sector:getCoordinates()

    local _SlamCtMax = 1
    local slamChance = 0.2 * mission.data.custom.dangerLevel
    slamChance = math.min(slamChance, 1) --Caps out at 100% @ danger level 5
    if _random:test(slamChance) then
        _SlamCtMax = _SlamCtMax + 1
    end

    --Deadshots have a scaling chance to spawn on even waves capping out at 50% @ danger level 10.
    local _DeadshotCtMax = 0
    local _DeadshotIncrement = 0.025
    if mission.data.custom.dangerLevel == 10 then
        _DeadshotIncrement = 0.05
    end
    local _DeadshotChance = _DeadshotIncrement * mission.data.custom.dangerLevel
    if mission.data.custom.waveCounter % 2 == 0 and _random:test(_DeadshotChance) then
        _DeadshotCtMax = _DeadshotCtMax + 1
    end
    mission.Log(_MethodName, "_DeadshotCtMax = " .. tostring(_DeadshotCtMax))

    local _Slammers = {_Sector:getEntitiesByScript("torpedoslammer.lua")}
    local _SlamCt = #_Slammers
    local _SlamAdded = 0

    local _Deadshots = {_Sector:getEntitiesByScript("lasersniper.lua")}
    local _DeadshotCt = #_Deadshots
    local _DeadshotAdded = 0

    --Torpedo ships need to be more dangerous @ lower levels due to the much less dangerous pirate ships that spawn. Otherwise the player could just enter the sector and let the mission run itself.
    --At higher levels, the scorchers and devastators will more than make up for the weaker torpedo multipliers. The devastators can even go toe to toe with the battleship.
    local _DmgFactor = 4
    local _tta = 20
    local _PrefType = TorpedoUtility.WarheadType.Tandem
    if mission.data.custom.dangerLevel >= 6 then
        _PrefType = TorpedoUtility.WarheadType.Nuclear
        _DmgFactor = 2
        _tta = 25
    elseif mission.data.custom.dangerLevel == 10 then
        _PrefType = TorpedoUtility.WarheadType.Nuclear
        _DmgFactor = 1
        _tta = 30
    end

    local _TorpSlammerValues = {
        _TimeToActive = _tta,
        _ROF = 8,
        _UpAdjust = false,
        _DamageFactor = _DmgFactor,
        _DurabilityFactor = 8,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = _PrefType,
        _TargetPriority = 2, --Target tag.
        _TargetTag = mission.data.custom.prototypeScriptValue
    }

    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_defendprototype_beta_wing", true)
        _Pirate:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = mission.data.custom.prototypeScriptValue })

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local _PiratesSpawned = mission.data.custom.piratesSpawned + 1
        local _Factor = 2
        if _PiratesSpawned >= 20 then
            _Factor = 3
        end
        if _PiratesSpawned % _Factor ~= 0 then
            _Pirate:setDropsLoot(false)
        end
        mission.data.custom.piratesSpawned = _PiratesSpawned

        --Add torpedo slammer scripts if necessary.
        if _SlamCt + _SlamAdded < _SlamCtMax then
            ESCCUtil.setBombardier(_Pirate)
            _Pirate:addScript("torpedoslammer.lua", _TorpSlammerValues)
            _SlamAdded = _SlamAdded + 1
        end
    end

    if _DeadshotCtMax > 0 then
        for _, _Pirate in pairs(_Generated) do
            if _DeadshotCt + _DeadshotAdded < _DeadshotCtMax and not _Pirate:hasScript("torpedoslammer.lua") then
                --Don't add lasersniper to torpslammer
                local _dpf = Balancing_GetSectorWeaponDPS(_X, _Y) * 125 --Same as a Xsotan Longinus.
            
                mission.Log(_MethodName,"Setting dpf to " .. tostring(_dpf))

                local _LaserSniperValues = { --#LONGINUS_SNIPER
                    _DamagePerFrame = _dpf,
                    _TimeToActive = 30,
                    _TargetCycle = 15,
                    _TargetingTime = 2.25, --Take longer than normal to target.
                    _TargetPriority = 3, --Target tag.
                    _TargetTag = mission.data.custom.prototypeScriptValue
                }

                ESCCUtil.setDeadshot(_Pirate)
                _Pirate:addScriptOnce("lasersniper.lua", _LaserSniperValues)

                _DeadshotAdded = _DeadshotAdded + 1 --Only add one deadshot per wave.
            end
        end
    end

    SpawnUtility.addEnemyBuffs(_Generated)
end

function onGammaBackgroundPiratesFinished(_Generated)
    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_defendprototype_gamma_wing", true)
        _Pirate:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = "_defendprototype_station" })

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local _PiratesSpawned = mission.data.custom.piratesSpawned + 1
        local _Factor = 2
        if _PiratesSpawned >= 20 then
            _Factor = 3
        end
        if _PiratesSpawned % _Factor ~= 0 then
            _Pirate:setDropsLoot(false)
        end
        mission.data.custom.piratesSpawned = _PiratesSpawned
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function getSectorRarityTables(_X, _Y, _upgradeGenerator)
    local _dangerLevel = mission.data.custom.dangerLevel
    local _rarities = _upgradeGenerator:getSectorRarityDistribution(_X, _Y)
    _rarities[-1] = 0 --no petty
    _rarities[0] = 0 --no common
    _rarities[1] = 0 --no uncommon
    _rarities[2] = 0 --no rare

    local _dangerFactors = {
        { _exceptional = 1, _exotic = 1}, --1
        { _exceptional = 1, _exotic = 1}, --2
        { _exceptional = 1, _exotic = 1}, --3
        { _exceptional = 1, _exotic = 1}, --4
        { _exceptional = 0.5, _exotic = 1}, --5
        { _exceptional = 0.5, _exotic = 1}, --6
        { _exceptional = 0.5, _exotic = 0.75}, --7
        { _exceptional = 0.25, _exotic = 0.75}, --8
        { _exceptional = 0.25, _exotic = 0.5}, --9
        { _exceptional = 0.12, _exotic = 0.5} --10
    }
    
    _rarities[3] = _rarities[3] * _dangerFactors[_dangerLevel]._exceptional
    _rarities[4] = _rarities[4] * _dangerFactors[_dangerLevel]._exotic

    return _rarities
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    if mission.data.custom.rewardBonus then
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " This includes a bonus for excellent work."
        mission.data.reward.credits = mission.data.reward.credits * 1.1
    end

    reward()
    accomplish()
end

function failAndPunish()
    local _MethodName = "Fail and Punish"
    mission.Log(_MethodName, "Running lose condition.")

    punish()
    fail()
end

--endregion

--region #CLIENT CALLS

function playHealAnimations(_Shipyard, _Prototype)
    local _MethodName = "Play Heal Animations"
    mission.Log(_MethodName, "On location and a shipyard is present. Playing animations.")
    --Draw a laser beam to indicate the prototype has been healed.
    local _Sector = Sector()
    local _ProtoHull = _Prototype.durability
    local _ProtoMaxHull = _Prototype.maxDurability

    if _ProtoHull < _ProtoMaxHull then
        local _syPos = _Shipyard.translationf
        local _ptPos = _Prototype.translationf
        local _Color = ColorRGB(0, 0.8, 0.5)

        local _repairLaser = _Sector:createLaser(_syPos, _ptPos, _Color, 16)
        _repairLaser.maxAliveTime = 1.5
        _repairLaser.collision = false

        local direction = random():getDirection()
        _Sector:createHyperspaceJumpAnimation(_Prototype, direction, ColorRGB(0.0, 1.0, 0.6), 0.2)
    end
end
callable(nil, "playHealAnimations")

--endregion

--region #MAKEBULLETIN CALLS

function formatWinMessage(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")
    local _MsgType = 1 --1 = Neutral / 2 = Aggressive / 3 = Peaceful

    if _Aggressive > 0.5 then
        _MsgType = 2
    elseif _Aggressive <= -0.5 then
        _MsgType = 3
    end

    local _Msgs = 
    { 
        "Thanks. Here's your reward, as promised.",
        "Thank you for taking care of that scum. We transferred the reward to your account.",
        "Thank you for your trouble. We transferred the reward to your account."
    }

    return _Msgs[_MsgType]
end

function formatLoseMessage(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")
    local _MsgType = 1 --1 = Neutral / 2 = Aggressive / 3 = Peaceful

    if _Aggressive > 0.5 then
        _MsgType = 2
    elseif _Aggressive <= -0.5 then
        _MsgType = 3
    end

    local _Msgs = {
        "You couldn't defend our battleship? That was irreplacable tech. We're going to have to rethink our future dealings with you.",
        "We see that you weren't up for the task. Unfortunate, but unsurprising. We should have taken care of it ourselves.",
        "You couldn't defend it? This is bad... we won't have the resources to field another for some time..."
    }

    return _Msgs[_MsgType]
end

function formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _Desc = {
        "This is an emergency request. We've been developing a new prototype that should have better combat performance than our normal battleships, but we haven't gotten it fully operational. A local pirate gang is clearly worried about this - they're planning a major raid on the shipyard to destroy it. We can't have that.\n\nThe shipyard is located in this sector: (${x}:${y}). Please head there and set up your defense.",
        "Our latest weapon program has finally borne fruit in a prototype battleship that's sure to bring both our enemies and the local pirates to their knees. Unfortunately, the pirates seem to have gotten wind of this and have decided to launch an attack in a desperate bid to retain control before we can get the design underway. Typical scum.\n\nOur shipyard is here: (${x}:${y}). Wipe out all unauthorized ships in the area.",
        "This is an emergency request. We've built a new prototype battleship, but it's not finished yet. We've also received credible intelligence of an all-out pirate attack meant to take out our new ship! Please defend it for us.\n\nThe shipyard is located in (${x}:${y}). Please head there and disrupt the pirate attack."
    }

    return _Desc[_DescriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Sector = Sector()
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = _Sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 7, 20, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    --local _DangerLevel = 10
    local _DangerLevel = _Rgen:getInt(1, 10)

    local _Difficulty = "Medium"
    if _DangerLevel > 5 then
        _Difficulty = "Difficult"
    end
    if _DangerLevel == 10 then --This danger level in particular is brutally difficult.
        _Difficulty = "Extreme"
    end
    
    local _Description = formatDescription(_Station)
    local _WinMsg = formatWinMessage(_Station)
    local _LoseMsg = formatLoseMessage(_Station)

    local _BaseReward = 400000
    if _DangerLevel >= 5 then
        _BaseReward = _BaseReward + 400000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 500000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRewardFactor(_Sector:getCoordinates()) --SET REWARD HERE
    reputation = 1000 --Don't need to give more than this - the amount of rep the player will gain from killing pirates is insane.

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/defendprototype.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you. Our shipyard is in \\s(%i:%i). Please protect our prototype.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = target,
            reward = {credits = reward, relations = reputation, paymentMessage = "Earned %1% for defending the prototype."},
            punishment = { relations = 16000 },
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            winMsg = _WinMsg,
            loseMsg = _LoseMsg,
            inbarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion