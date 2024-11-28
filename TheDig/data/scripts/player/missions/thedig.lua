package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Balancing = include ("galaxy")
local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local CaptainGenerator = include("captaingenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")
local Xsotan = include("story/xsotan")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "The Dig"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Defend the miners", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many miners be destroyed - ${_DESTROYED}/${_MAXDESTROYED} Lost", bulletPoint = true, fulfilled = false, visible = false },
    { text = "(Optional) Harvest resources", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 10 * 60 --Player has 10 minutes to head to the sector. Take the time limit off when the player arrives.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "We've got the resources we needed! Thank you for defending our miners."
mission.data.abandonMessage = "We're disappointed you decided to abandon this contract. We'll have to call off our expedition now."
mission.data.failMessage = "Our miners have been destroyed. Thousands of skilled personnel were lost due to your failure."

local TheDig_init = initialize
function initialize(_Data_in, bulletin)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel) .. " threattype: " .. tostring(_Data_in.threatType))

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
        mission.data.custom.threatType = _Data_in.threatType
        mission.data.custom.friendlyFaction = _Giver.factionIndex
        mission.data.custom.timePassed = 0
        if mission.data.custom.threatType == 1 then --1 = faction / 2 = pirates / 3 = xsotan
            mission.data.custom.enemyFaction = _Data_in.enemyFaction 

            local _MissionDoer = Player().craftFaction or Player()
            local _Relation = _MissionDoer:getRelation(mission.data.custom.enemyFaction)
            local _EnemyFaction = Faction(mission.data.custom.enemyFaction)
            local _GiverFaction = Faction(_Giver.factionIndex)
            local _Relation2Giver = _GiverFaction:getRelation(mission.data.custom.enemyFaction)

            mission.data.custom.enemyRelationLevel = _Relation.level
            mission.data.custom.enemyRelationStatus = _Relation.status
            mission.data.custom.enemyRelationLevel2Giver = _Relation2Giver.level
            mission.data.custom.enemyRelationStatus2Giver = _Relation2Giver.status

            mission.Log(_MethodName, "Enemy faction is : " .. tostring(_EnemyFaction.name))
            mission.data.custom.enemyName = _EnemyFaction.name
        end
        local minXsoSize = 0
        local maxXsoSize = 2
        local maxDestroyable = 6
        if mission.data.custom.dangerLevel > 5 then
            maxDestroyable = maxDestroyable - 1 --4 max
            minXsoSize = minXsoSize + 1
        end
        if mission.data.custom.dangerLevel == 10 then
            maxDestroyable = maxDestroyable - 1 --3 max
            minXsoSize = minXsoSize + 1
            maxXsoSize = maxXsoSize + 1
        end
        mission.data.custom.minXsotanSizeBonus = minXsoSize
        mission.data.custom.maxXsotanSizeBonus = maxXsoSize
        mission.data.custom.spawnXsotanWaveNext = false
        mission.data.custom.maxDestroyed = maxDestroyable
        mission.data.custom.enemyShipsSpawned = 0
        mission.data.custom.destroyed = 0
        mission.data.custom.inBarrier = _Data_in.inBarrier

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { x = _X, y = _Y, enemyName = mission.data.custom.enemyName }
        mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
    end

    --Run vanilla init. Managers _restoring on its own.
    TheDig_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS

mission.getRewardedItems = function()
    --25% of getting a random rarity mining upgrade.
    if random():test(0.25) then
        local _SeedInt = random():getInt(1, 20000)
        local _Rarities = {RarityType.Common, RarityType.Common, RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare}

        if mission.data.custom.inBarrier then
            _Rarities = {RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare, RarityType.Rare, RarityType.Exceptional, RarityType.Exotic}
        end

        shuffle(random(), _Rarities)

        return SystemUpgradeTemplate("data/scripts/systems/miningsystem.lua", Rarity(_Rarities[1]), Seed(_SeedInt))
    end
end

mission.globalPhase = {}
mission.globalPhase.timers = {}
mission.globalPhase.onAbandon = function()
    local methodName = "Global Phase On Abandon"

    if mission.data.custom.destroyed == 0 then
        mission.Log(methodName, "No miners destroyed - halving penalty.")
        mission.data.punishment.relations = mission.data.punishment.relations / 2
        punish()
    else
        mission.Log(methodName, "Miners destroyed - full penalty.")
        punish()
    end

    if mission.data.location then
        if atTargetLocation() then
            minersDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        runFullSectorCleanup(true) --The solar winds blow everything away. Whooooosh.
    end
end

--region #GLOBALPHASE TIMERS

if onServer() then

mission.globalPhase.timers[1] = {
    time = 130, 
    callback = function() 
        local _MethodName = "Global Phase Timer 1"
        mission.Log(_MethodName, "Beginning...")

        mission.data.custom.timePassed = (mission.data.custom.timePassed or 0) + 130

        mission.Log(_MethodName, "Time passed is " .. tostring(mission.data.custom.timePassed))

        --Give the player a 5 minute grace period.
        if mission.data.custom.timePassed >= 300 and not atTargetLocation() then
            mission.data.custom.destroyed = mission.data.custom.destroyed + 1
            mission.Log(_MethodName, "Not on location - incrementing destroyed to : " .. tostring(mission.data.custom.destroyed))

            if mission.data.custom.destroyed >= mission.data.custom.maxDestroyed then
                failAndPunish()
            end

            mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
            mission.data.abandonMessage = mission.data.failMessage

            sync()
        end
    end,
    repeating = true
}
    
end
    
--endregion

mission.phases[1] = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _random = random()
    local missionTime = 25 * 60 --minimum 25 mins
    missionTime = missionTime + (_random:getInt(1, 5) * 60) --add up to 5 minutes.
    missionTime = missionTime + (_random:getInt(1, mission.data.custom.dangerLevel) * 60) --add up to dangerlevel minutes.

    mission.data.timeLimit = mission.internals.timePassed + missionTime --Defend the miners for X minutes.
    mission.internals.fulfilled = true --At this point, this mission will succeed at timeout, and not fail.

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true

    if onServer() then
        spawnMiningSector(x, y)
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onBeginServer = function()
    local methodName = "Phase 2 On Begin Server"
    mission.Log(methodName, "Starting.")

    if mission.data.custom.threatType == 1 then --enemy faction
        local _Galaxy = Galaxy()
        local _MissionDoer = Player().craftFaction or Player()
        local enemyFaction = Faction(mission.data.custom.enemyFaction)
        local friendlyFaction = Faction(mission.data.custom.friendlyFaction)

        if mission.data.custom.enemyRelationStatus ~= RelationStatus.War then
            mission.Log(methodName, "Enemy faction not already at war with player. Declaring war.")
            
            _Galaxy:setFactionRelations(enemyFaction, _MissionDoer, -100000)
            _Galaxy:setFactionRelationStatus(enemyFaction, _MissionDoer, RelationStatus.War)
        end

        if mission.data.custom.enemyRelationStatus2Giver ~= RelationStatus.War then
            mission.Log(methodName, "Enemy faction not already at war with mission faction. Declaring war.")

            _Galaxy:setFactionRelations(enemyFaction, friendlyFaction, -100000)
            _Galaxy:setFactionRelationStatus(enemyFaction, friendlyFaction, RelationStatus.War)
        end

        Player():sendChatMessage(mission.data.custom.enemyName, 0, "We claimed this asteroid field! We won't let this aggression go unanswered.")
    elseif mission.data.custom.threatType == 3 then --xsotan
        Player():sendChatMessage("", 3, "Your sensors picked up a short burst of subspace signals."%_t)
    end
end

mission.phases[2].updateServer = function(timeStep)
    if mission.data.custom.destroyed >= mission.data.custom.maxDestroyed then
        failAndPunish()
    end
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local methodName = "Phase 2 on Entity Destroyed"
    --mission.Log(methodName, "Beginning...")
    if Entity(_ID):getValue("_thedig_defendobjective") then
        mission.Log(methodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
        mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
        mission.data.abandonMessage = mission.data.failMessage

        mission.Log(methodName, "Number of miners destroyed " .. tostring(mission.data.custom.destroyed))
        sync()
    end
end

mission.phases[2].onAccomplish = function()
    doMissionEndCleanup()

    if mission.data.custom.destroyed == 0 then --give the player a bonus if no miners are lost.
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " Plus a bonus for no losses."
        mission.data.reward.credits = mission.data.reward.credits * 1.25 
    end

    reward()
end

mission.phases[2].onFail = function()
    doMissionEndCleanup()
end

mission.phases[2].onAbandon = function()
    if mission.data.custom.threatType == 1 then --faction
        --reset the original relation between the two factions but NOT the player.
        local _Faction = Faction(mission.data.custom.enemyFaction)
        local _FriendlyFaction = Faction(mission.data.custom.friendlyFaction)
        local _Galaxy = Galaxy()

        _Galaxy:setFactionRelations(_Faction, _FriendlyFaction, mission.data.custom.enemyRelationLevel2Giver)
        _Galaxy:setFactionRelationStatus(_Faction, _FriendlyFaction, mission.data.custom.enemyRelationStatus2Giver)
    end
end

--region #PHASE 2 TIMERS

if onServer() then

mission.phases[2].timers[1] = {
    time = 60,
    callback = function()
        --Every minute the player isn't in the sector, lose a miner.
        if not atTargetLocation() then
            mission.data.custom.destroyed = mission.data.custom.destroyed + 1
            mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
            sync()
        end
    end,
    repeating = true
}

mission.phases[2].timers[2] = {
    time = 60,
    callback = function()
        if atTargetLocation() then
            spawnGiverFactionMiner()
        end
    end,
    repeating = false
}

mission.phases[2].timers[3] = {
    time = 120,
    callback = function()
        --Every 2 minutes, spawn miners until there are 4.
        if atTargetLocation() then
            spawnGiverFactionMiner()
        end
    end,
    repeating = true
}

mission.phases[2].timers[4] = {
    time = 150, 
    callback = function()
        --Every 2:30, spawn an attack wave.
        if atTargetLocation() then
            local threatFuncs = {
                function()
                    spawnFactionWave()
                end,
                function()
                    spawnPirateWave()
                end,
                function()
                    spawnXsotanWave()
                end,
            }

            threatFuncs[mission.data.custom.threatType]()
        end
    end,
    repeating = true
}

mission.phases[2].timers[5] = {
    time = 300,
    callback = function()
        --The xsotan aren't that dangerous compared to the high level pirates, so we give them a little extra help.
        if atTargetLocation() and mission.data.custom.threatType == 3 then
            local _random = random()
            local pctChance = 0.1 * mission.data.custom.dangerLevel

            if _random:test(pctChance) or mission.data.custom.spawnXsotanWaveNext then
                mission.data.custom.spawnXsotanWaveNext = false
                spawnXsotanWave()
            else
                local pctChance2 = math.min(pctChance * 2, 1.0) --caps @ danger 5.
                if _random:test(pctChance2) then
                    mission.data.custom.spawnXsotanWaveNext = true
                end
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function spawnMiningSector(x, y)
    local generator = SectorGenerator(x, y)
    local _random = random()

    local numFields = _random:getInt(2, 4)

    for i = 1, numFields do
        local mat = generator:createAsteroidField(0.075)
        if _random:test(0.5) then generator:createBigAsteroid(mat) end
    end

    local numRichFields = _random:getInt(4, 6)

    for _ = 1, numRichFields do
        generator:createAsteroidField(1)
    end

    local numSmallFields = _random:getInt(8, 15)
    for i = 1, numSmallFields do
        local mat = generator:createSmallAsteroidField(0.1)
        if _random:test(0.15) then generator:createStash(mat) end
    end

    Placer.resolveIntersections()
end

function spawnGiverFactionMiner()
    local miners = {Sector():getEntitiesByScriptValue("_thedig_defendobjective")}

    if #miners < 4 then
        --spawn a new miner.
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        local _ShipGenerator = AsyncShipGenerator(nil, onMinerFinished)
        local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * random():getInt(2, 8)
        local _Faction = Faction(mission.data.custom.friendlyFaction)
    
        _ShipGenerator:startBatch()
        
        _ShipGenerator:createMiningShip(_Faction, _ShipGenerator:getGenericPosition(), _Vol1)
    
        _ShipGenerator:endBatch()
    end
end

function onMinerFinished(_Generated)
    local methodName = "On Miner Finished"
    mission.Log(methodName, "Starting.")

    local _Ship = _Generated[1]

    --Multiply durability so the ship isn't instakilled.
    mission.Log(methodName, "Updating durability.")
    local _Dura = Durability(_Ship)

    local _DurabilityBonus = 2

    local _Shield = Shield(_Ship)
    if _Shield then
        _Shield.maxDurabilityFactor = _Shield.maxDurabilityFactor * 2
    else
        _DurabilityBonus = _DurabilityBonus + 1
    end

    if _Dura then
        _Dura.maxDurabilityFactor = _Dura.maxDurabilityFactor * _DurabilityBonus
    end

    mission.Log(methodName, "Adding captain, setting script values, adding scripts.")
    --needs a captain before it will mine.
    local crewComponent = CrewComponent(_Ship)
    crewComponent:setCaptain(CaptainGenerator():generate())
    _Ship:addScript("ai/mine.lua")
    _Ship:addScript("ai/thedigminer.lua")
    _Ship:setValue("_thedig_defendobjective", true)
    _Ship:setValue("_thedig_player", Player().index)
end

function minersDepart()
    local methodName = "Miners Depart"
    mission.Log(methodName, "Running.")

    local miners = {Sector():getEntitiesByScriptValue("_thedig_defendobjective")}

    for _, miner in pairs(miners) do
        miner:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function getPirateWingTable(wingScriptValue)
    local _MethodName = "Get Pirate Wing Spawn Table"
    mission.Log(_MethodName, "Beginning...")

    local _MaxCt = 4
    if mission.data.custom.dangerLevel == 10 and random():test(0.5) then
        _MaxCt = _MaxCt + 1
    end

    local _Pirates = {Sector():getEntitiesByScriptValue(wingScriptValue)}

    local _SpawnCt = _MaxCt - #_Pirates

    local _SpawnTable = {}
    if _SpawnCt > 0 then
        _SpawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _SpawnCt, "Standard", false)
    end

    return _SpawnTable
end

function spawnPirateWave()
    local methodName = "Spawn Pirate Wave"
    mission.Log(methodName, "Running.")

    --standard alpha / beta wing setup. 4/4 split.
    local distance = 250 --_#DistAdj

    local _spawnFunc = function(wingScriptValue, wingOnSpawnFunc)
        local _WingSpawnTable = getPirateWingTable(wingScriptValue)
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
    _spawnFunc("_thedig_alpha_wing", onEnemyAlphaWingFinished)

    --spawn beta
    _spawnFunc("_thedig_beta_wing", onEnemyBetaWingFinished)
end

function getFactionWingTable(wingScriptValue)
    local _MethodName = "Get Faction Wing Spawn Table"
    mission.Log(_MethodName, "Beginning...")

    local _Enemies = {Sector():getEntitiesByScriptValue(wingScriptValue)}

    local _SpawnCt = 3 - #_Enemies

    local _SpawnTable = {}
    if _SpawnCt > 0 then
        local _DefenderShips = 1
        if _SpawnCt > 1 and random():test(0.05 * mission.data.custom.dangerLevel) then --50% chance @ danger 10
            _DefenderShips = _DefenderShips + 1
        end

        _SpawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _DefenderShips, "Standard", true)
    end

    while #_SpawnTable < _SpawnCt do
        table.insert(_SpawnTable, "MS")
    end

    return _SpawnTable
end

function spawnFactionWave()
    local methodName = "Spawn Faction Wave"
    mission.Log(methodName, "Running.")

    --standard alpha / beta wing setup. 3/3 split because heavy defenders are a nightmare to deal with.
    local distance = 2500 --_#FACTDistAdj

    local _spawnFunc = function(wingScriptValue, wingOnSpawnFunc)
        local wingSpawnTable = getFactionWingTable(wingScriptValue)
        local wingGenerator = AsyncShipGenerator(nil, wingOnSpawnFunc)
        local enemyFaction = Faction(mission.data.custom.enemyFaction)

        local posCounter = 1
        local wingPositions = wingGenerator:getStandardPositions(#wingSpawnTable, distance)

        wingGenerator:startBatch()

        for _, es in pairs(wingSpawnTable) do
            wingGenerator:createDefenderByName(enemyFaction, wingPositions[posCounter], es)
            posCounter = posCounter + 1
        end

        wingGenerator:endBatch()
    end

    --spawn alpha
    _spawnFunc("_thedig_alpha_wing", onEnemyAlphaWingFinished)

    --spawn beta
    _spawnFunc("_thedig_beta_wing", onEnemyBetaWingFinished)
end

function onEnemyAlphaWingFinished(generated)
    for _, enemyShip in pairs(generated) do
        enemyShip:setValue("_thedig_alpha_wing", true)

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local enemiesSpawned = mission.data.custom.enemyShipsSpawned + 1
        local _Factor = 2
        if enemiesSpawned >= 20 then
            _Factor = 3
        end
        if enemiesSpawned % _Factor ~= 0 then
            enemyShip:setDropsLoot(false)
        end
        mission.data.custom.enemyShipsSpawned = enemiesSpawned

        if mission.data.custom.threatType == 1 then
            enemyShip:removeScript("patrol.lua")
            enemyShip:removeScript("antismuggle.lua")

            local enemyShipAI = ShipAI(enemyShip)
            enemyShipAI:setAggressive()
        end
    end

    if mission.data.custom.threatType == 2 then --defender ship + buff = nightmare
        SpawnUtility.addEnemyBuffs(generated)
    end

    Placer.resolveIntersections(generated)
end

function onEnemyBetaWingFinished(generated)
    local methodName = "On Enemy Beta Wing Finished"

    local _sector = Sector()
    local _random = random()
    local x, y = _sector:getCoordinates()
    local specialEnemyCtMax = 1
    local addSpecialEnemy = _random:test(0.025 * mission.data.custom.dangerLevel)

    local torpedoEnemies = { _sector:getEntitiesByScript("torpedoslammer.lua") }
    local laserEnemies = { _sector:getEntitiesByScript("lasersniper.lua") }
    local specialPirates = #torpedoEnemies + #laserEnemies
    local specialAdded = 0

    for _, enemyShip in pairs(generated) do
        enemyShip:setValue("_thedig_beta_wing", true)
        enemyShip:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = "_thedig_defendobjective" })

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local enemiesSpawned = mission.data.custom.enemyShipsSpawned + 1
        local _Factor = 2
        if enemiesSpawned >= 20 then
            _Factor = 3
        end
        if enemiesSpawned % _Factor ~= 0 then
            enemyShip:setDropsLoot(false)
        end
        mission.data.custom.enemyShipsSpawned = enemiesSpawned

        --Add torpedo slammer / deadshot scripts if necessary.
        if (specialPirates + specialAdded) < specialEnemyCtMax and addSpecialEnemy then
            if _random:test(0.5) then
                local _TorpSlammerValues = {
                    _TimeToActive = 30,
                    _ROF = 8,
                    _UpAdjust = false,
                    _ForwardAdjustFactor = 2,
                    _PreferWarheadType = _random:getInt(1,3), --nuclear, fusion, or neutron picked at random
                    _TargetPriority = 2, --Target tag.
                    _TargetTag = "_thedig_defendobjective"
                }

                if mission.data.custom.threatType == 1 then --faction
                    ESCCUtil.setFusilier(enemyShip)
                elseif mission.data.custom.threatType == 2 then --pirate
                    ESCCUtil.setBombardier(enemyShip)
                end
                enemyShip:addScript("torpedoslammer.lua", _TorpSlammerValues)
            else
                local _dpf = Balancing_GetSectorWeaponDPS(x, y) * 125 --Same as a Xsotan Longinus.
            
                mission.Log(methodName,"Setting dpf to " .. tostring(_dpf))

                local _LaserSniperValues = { --#LONGINUS_SNIPER
                    _DamagePerFrame = _dpf,
                    _TimeToActive = 30,
                    _TargetCycle = 15,
                    _TargetingTime = 2.25, --Take longer than normal to target.
                    _TargetPriority = 3, --Target tag.
                    _TargetTag = "_thedig_defendobjective"
                }

                if mission.data.custom.threatType == 1 then --faction
                    ESCCUtil.setMarksman(enemyShip)
                elseif mission.data.custom.threatType == 2 then --pirate
                    ESCCUtil.setDeadshot(enemyShip)
                end
                enemyShip:addScriptOnce("lasersniper.lua", _LaserSniperValues)
            end

            specialAdded = specialAdded + 1
        end

        if mission.data.custom.threatType == 1 then
            enemyShip:removeScript("patrol.lua")
            enemyShip:removeScript("antismuggle.lua")

            local enemyShipAI = ShipAI(enemyShip)
            enemyShipAI:setAggressive()
        end
    end

    if mission.data.custom.threatType == 2 then --defender ship + buff = nightmare
        SpawnUtility.addEnemyBuffs(generated)
    end
    
    Placer.resolveIntersections(generated)
end

function spawnXsotanWave()
    local methodName = "Spawn Xsotan Wave"
    mission.Log(methodName, "Running.")

    local _sector = Sector()
    local _random = random()
    local secGenerator = SectorGenerator(_sector:getCoordinates())
    local players = {_sector:getPlayers()}

    local xsotanByNameTable = {}
    local xsotanTable = {}

    --spawn in a group of 5. Add a 6th @ danger 10.
    local waveSize = 5
    if mission.data.custom.dangerLevel == 10 then
        waveSize = waveSize + 1
    end

    --up to a 20% chance for a special and/or quantum xsotan inside the barrier - 10% outside.
    --10% chance for a summoner at danger level 10 regardless of inside or outside of barrier.
    local addSummoner = false
    local addQuantum = false
    local addSpecial = false

    local summoners = {_sector:getEntitiesByScript("enemies/summoner.lua")}
    if #summoners == 0 and mission.data.custom.dangerLevel == 10 and _random:test(0.1) then
        addSummoner = true
    end

    local quantumSpecialChance = 0.02 * mission.data.custom.dangerLevel
    if _random:test(quantumSpecialChance) then
        addQuantum = true
    end
    if _random:test(quantumSpecialChance) then
        addSpecial = true
    end

    if addSummoner then
        table.insert(xsotanByNameTable, "Summoner")
    end
    if addQuantum then
        table.insert(xsotanByNameTable, "Quantum")
    end
    if addSpecial then
        table.insert(xsotanByNameTable, "Special")
    end
    for _ = 1, waveSize - #xsotanByNameTable do
        table.insert(xsotanByNameTable, "Ship")
    end

    local dist = 1500
    for _, xsotanName in pairs(xsotanByNameTable) do
        local sizeFactor = 1 + random():getInt(mission.data.custom.minXsotanSizeBonus, mission.data.custom.maxXsotanSizeBonus)

        local nXsotan = nil
        if xsotanName == "Summoner" then
            nXsotan = Xsotan.createSummoner(secGenerator:getPositionInSector(dist), sizeFactor)
        elseif xsotanName == "Quantum" then
            nXsotan = Xsotan.createQuantum(secGenerator:getPositionInSector(dist), sizeFactor)
        elseif xsotanName == "Special" then
            local xsotanFunction = getRandomEntry(Xsotan.getSpecialXsotanFunctions())

            nXsotan = xsotanFunction(secGenerator:getPositionInSector(dist), sizeFactor)
        else
            nXsotan = Xsotan.createShip(secGenerator:getPositionInSector(dist), sizeFactor)
        end

        if nXsotan and valid(nXsotan) then
            local xsotanAI = ShipAI(nXsotan.id)

            for _, p in pairs(players) do
                xsotanAI:registerEnemyFaction(p.index)
            end

            xsotanAI:registerEnemyFaction(mission.data.custom.friendlyFaction)
            
            xsotanAI:setAggressive()

            table.insert(xsotanTable, nXsotan)
        end
    end

    SpawnUtility.addEnemyBuffs(xsotanTable)

    Placer.resolveIntersections(xsotanTable)
end

function doMissionEndCleanup()
    if mission.data.custom.threatType == 1 then --enemy faction
        local _Rgen = ESCCUtil.getRand()
        local _MissionDoer = Player().craftFaction or Player()
        local _Faction = Faction(mission.data.custom.enemyFaction)
        local _FriendlyFaction = Faction(mission.data.custom.friendlyFaction)
        local _Galaxy = Galaxy()

        local _Entities = {Sector():getEntitiesByFaction(_Faction.index)}
        for _, _E in pairs(_Entities) do
            if _E.type == EntityType.Ship then
                _E:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(4, 8))
            end
        end

        _Galaxy:setFactionRelations(_Faction, _FriendlyFaction, mission.data.custom.enemyRelationLevel2Giver)
        _Galaxy:setFactionRelationStatus(_Faction, _FriendlyFaction, mission.data.custom.enemyRelationStatus2Giver)
        _Galaxy:setFactionRelations(_Faction, _MissionDoer, mission.data.custom.enemyRelationLevel - 10000)
        _Galaxy:setFactionRelationStatus(_Faction, _MissionDoer, mission.data.custom.enemyRelationStatus)
    elseif mission.data.custom.threatType == 2 then --pirates
        ESCCUtil.allPiratesDepart()
    elseif mission.data.custom.threatType == 3 then --xsotan
        ESCCUtil.allXsotanDepart()
    end

    minersDepart()
end

function failAndPunish()
    local _MethodName = "Fail and Punish"
    mission.Log(_MethodName, "Running lose condition.")

    punish()
    fail()
end

--endregion

--region #MAKEBULLETIN CALLS

function formatDescription(_Station, _ThreatType)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _FinalDescription = ""
    if _DescriptionType == 1 then --Neutral.
        _FinalDescription = "We've received reports that some solar wind currents have blown a number of disparate asteroid belts into a converging course. We believe they'll meet in sector (${x}:${y}). We're putting together a task force to take advantage of this, and we're looking for a captain to lead it. Protect our mining operation. We'll pay you for your efforts. You're also welcome to mine as much as you want."
    
        if _ThreatType == 1 then
            _FinalDescription = _FinalDescription .. "\n\nA nearby faction - ${enemyName} - has claimed the sector. Protect our ships from any aggression."
        else
            _FinalDescription = _FinalDescription .. "\n\nWe're not sure what threats are out there. Proceed with caution."
        end

    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "Some asteroid fields will be converging in sector (${x}:${y}) on solar currents. We're getting ready to take advantage of this, but our military is engaged elsewhere and cannot respond. It displeases us to have to turn to an independent captain, but we have no other options. You will protect our miners - for compensation, of course. You may also mine the field - how magnanimous of us, yes?"
    
        if _ThreatType == 1 then
            _FinalDescription = _FinalDescription .. "\n\nA nearby faction - ${enemyName} - has claimed the sector. How laughable. Crush them if they dare attack."
        else
            _FinalDescription = _FinalDescription .. "\n\nThe pirate and xsotan scum are always lurking. Crush them if they dare attack us."
        end

    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "Peace be upon you, captain. We've received word that a few scattered belts of asteroids will be merging in sector (${x}:${y}) due to the local solar winds. We're putting together a group of miners to harvest the bounty of resources, but our military is ill-suited for anything more than peacekeeping. We need your help. Please protect our miners. You are welcome to mine as well."
    
        if _ThreatType == 1 then
            _FinalDescription = _FinalDescription .. "\n\nA nearby faciton - ${enemyName} - has claimed to the sector. We fear a peaceful solution can't be found."
        else
            _FinalDescription = _FinalDescription .. "\n\nWe don't know what threats are out there. Please keep our people safe."
        end

    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 8, 16, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local dangerLevel = _Rgen:getInt(1, 10)
    local threatType = _Rgen:getInt(1, 3) --1 = faction / 2 = pirates / 3 = xsotan

    local _Difficulty = "Medium"
    if threatType == 1 then
        _Difficulty = "Difficult"
    end

    if dangerLevel >= 5 then --the faction defenders are powerful and can blow up miners quickly.
        _Difficulty = "Difficult"
        if threatType == 1 then
            _Difficulty = "Extreme"
        end
    end

    if dangerLevel == 10 then
        _Difficulty = "Extreme"
    end
    
    local _Description = formatDescription(_Station, threatType)

    local giverFaction = _Station.factionIndex
    local enemyFaction = nil
    local enemyFactionName = nil
    if threatType == 1 then
        local factionNeighbors = MissionUT.getNeighboringFactions(giverFaction, 125)
        shuffle(random(), factionNeighbors)

        if #factionNeighbors > 0 then
            enemyFaction = factionNeighbors[1].index
            enemyFactionName = factionNeighbors[1].name
            mission.Log(_MethodName, "The enemy faction is " .. tostring(enemyFactionName))
        else
            threatType = _Rgen:getInt(1, 2) + 1 --pirates or xsotan.
        end
    end

    local baseReward = 50000
    if dangerLevel >= 5 then
        baseReward = baseReward + 5000
    end
    if dangerLevel == 10 then
        baseReward = baseReward + 5000
    end

    if threatType == 1 then --the faction version tends to be more difficult, even at danger 1.
        baseReward = baseReward * 1.5
    end

    if insideBarrier then
        baseReward = baseReward * 2
    end

    local baseRepReward = 1000 --Why is this so low? Becasue you get a ton of extra rep from killing the pirates or xsotan w/ the miners active.

    reward = baseReward * Balancing.GetSectorRewardFactor(Sector():getCoordinates()) --SET REWARD HERE
    repReward = baseRepReward

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission._Name,
        description = _Description,
        difficulty =  _Difficulty,
        reward = "¢${reward}",
        script = "missions/thedig.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward), enemyName = enemyFactionName},
        msg = "Thank you. Please meet our miners in sector \\s(%1%:%2%).",
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
            reward = { credits = reward, relations = repReward, paymentMessage = "Earned %1% credits for defending the miners."},
            punishment = { relations = 16000 },
            dangerLevel = dangerLevel,
            threatType = threatType,
            enemyFaction = enemyFaction,
            initialDesc = _Description,
            inBarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion