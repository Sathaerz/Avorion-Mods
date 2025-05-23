--[[
    Defend Secret Outpost
    NOTES:
        - Keep track of two wings of pirates here - one of them constantly attacks the base, the other is set to normal aggressive behavior.
        - Add 20% HP to the military outpost every time the player fails.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Have completed the third LOTW mission.
    ROUGH OUTLINE
        - Go to a sector, defend an outpost.
        - Destroy 20 pirates to win.
    DANGER LEVEL
        5 - Two continual wings of 1 bandits and 2 pirates will spawn in the background.
        5 - Start spawning a marauder + additional bandit once 5 pirates have been destroyed.
        5 - One wing will attack the outpost specifically.
        5 - One wing will have normal aggressive behavior.
        5 - Spawn 2 defenders once 10 pirates have been killed.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Placer = include ("placer")
local TorpedoUtility = include ("torpedoutility")

mission._Debug = 0
mission._Name = "Defend Secret Outpost"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You received the following request from ${factionName}:" },
    { text = "This is an emergecy request. Despite your success in crippling the pirate supply lines, they've managed to tap a backup cache of materiel and are attacking one of our installations in force. We were under the impression that it was hidden, so we left it exposed to counterattack. You should have enough money and hardware to get a 2nd ship moving. The outpost is located in sector (${_X}:${_Y}). We'll need your help to defend it." },
    { text = "Build and outfit a 2nd ship", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defend the Military Outpost from the pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Prioritize the marked torpedo enemies", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Thank you. The reward has been transferred to your account. We'll be in touch."

local LOTW_Mission_init = initialize
function initialize()
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer()then
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        if not _restoring then
            local _Player = Player()
            local _FailureCt =_Player:getValue("_lotw_mission4_failures") or 0

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .destroyed
                .friendlyFaction
                .missionsFailed
                .outpostLocation
                .failureCounter
                .firstAlphaInvincible
                .firstBetaInvincible
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
            mission.data.custom.destroyed = 0
            mission.data.custom.friendlyFaction = _Player:getValue("_lotw_faction")
            mission.data.custom.missionsFailed = _FailureCt
            mission.data.custom.failureCounter = 0 --Used to fail the mission if the player is out of sector for to long, not to count mission failures.

            mission.data.custom.outpostLocation = lotwStory4_getNextLocation()
            
            local missionReward = ESCCUtil.clampToNearest(150000 + (50000 * Balancing.GetSectorRewardFactor(_Sector:getCoordinates())), 5000, "Up")

            missionData_in = {location = nil, reward = {credits = missionReward, relations = 12000, paymentMessage = "Earned %1% credits for defending the outpost."}}
    
            LOTW_Mission_init(missionData_in)

            lotwStory4_setMissionFactionData(_X, _Y) --Have to be sneaky about this. Normaly this SHOULD be set by the init function, but since it's not from a station it will get funky.
        else
            --Restoring
            LOTW_Mission_init()
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

--Normally we like doing .globalPhase.noBossEncounters - but we don't want to do that here.

mission.globalPhase.onFail = function()
    local _Player = Player()
    local _FailureCt =_Player:getValue("_lotw_mission4_failures") or 0
    _FailureCt = _FailureCt + 1
    _Player:setValue("_lotw_mission4_failures", _FailureCt)
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Beginning...")

    local _Faction = Faction(mission.data.custom.friendlyFaction) --The phase is already set to 1 by the time we hit this, so it has to be done it this way.
    local _Player = Player()

    mission.data.description[1].arguments = { factionName = _Faction.name }
    mission.data.description[2].arguments = { _X = mission.data.custom.outpostLocation.x, _Y = mission.data.custom.outpostLocation.y }

    --Start the timer to see if the player has a 2nd ship. If they already have a 2nd one we can just skip this instantly.
    if _Player.numShips > 1 then
        nextPhase()
    else
        mission.phases[1].showUpdateOnEnd = true --Show an update on the end of the phase if we need to build a ship.
    end
end

--region #PHASE 1 TIMERS

mission.phases[1].timers[1] = {
    time = 10, 
    callback = function() 
        local _Player = Player()
        if _Player.numShips > 1 then
            nextPhase()
        end
    end,
    repeating = true
}

--endregion

mission.phases[2] = {}
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].noPlayerEventsTargetSector = true
mission.phases[2].noLocalPlayerEventsTargetSector = true
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    local methodName = "Phase 2 On Begin Server"
    mission.Log(methodName, "Beginning...")

    mission.data.location = mission.data.custom.outpostLocation

    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { x = mission.data.location.x, y = mission.data.location.y }
    mission.data.description[4].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    local methodName = "Phase 2 On Enter Target Location"
    mission.Log(methodName, "Beginning...")

    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true

    --Make sector.
    lotwStory4_buildSector(x, y)   
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    local _Sector = Sector()
    local _DefendObjective = {_Sector:getEntitiesByScriptValue("_lotw_mission4_defendobjective")}

    _Sector:broadcastChatMessage(_DefendObjective[1], ChatMessageType.Chatter, "Prioritize destroying enemies with torpedoes! We've marked them with a special icon.")

    nextPhase()
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].noPlayerEventsTargetSector = true
mission.phases[3].noLocalPlayerEventsTargetSector = true
mission.phases[3].onBeginServer = function()
    --Spawn enemies.
    lotwStory4_spawnBackgroundPirates()
end

mission.phases[3].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local methodName = "Phase 2 on Entity Destroyed"
    mission.Log(methodName, "Beginning...")

    local _Entity = Entity(_ID)

    if _Entity:getValue("_lotw_mission4_objective") then
        mission.Log(methodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
    end

    if _Entity:getValue("_lotw_mission4_defendobjective") then
        ESCCUtil.allPiratesDepart()
        fail()
    end
end

mission.phases[3].onTargetLocationLeft = function(x, y)
    mission.data.custom.destroyed = 0
end

--region #PHASE 3 TIMERS

if onServer() then

--Set timers.
mission.phases[3].timers[1] = { --make pirate attack waves
    time = 45,
    callback = function()
        if atTargetLocation() then
            lotwStory4_spawnBackgroundPirates()
        end
    end,
    repeating = true
}

mission.phases[3].timers[2] = { --soft fail timer (3 minutes outside the sector fails the mission)
        time = 60, 
        callback = function()
            if not atTargetLocation() then
                mission.data.custom.failureCounter = mission.data.custom.failureCounter + 1
            end
        end,
        repeating = true
}

mission.phases[3].timers[3] = { --advancement / objective timer
        time = 10,
        callback = function()
            local methodName = "Phase 1 Timer 4 Callback"
            mission.Log(methodName, "Beginning...")
            mission.Log(methodName, "Number of pirates destroyed " .. tostring(mission.data.custom.destroyed))
            if mission.data.custom.destroyed >= 20 then
                ESCCUtil.allPiratesDepart()
                lotwStory4_finishAndReward()
            end
            if mission.data.custom.failureCounter >= 3 then
                fail()
            end
        end,
        repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function lotwStory4_setMissionFactionData(_X, _Y)
    local methodName = "Set Mission Faction Data"
    mission.Log(methodName, "Beginning...")
    --We're going to have to do some sneaky stuff w/ credits here.
    local _Faction = Faction(Player():getValue("_lotw_faction"))
    mission.data.giver = {}
    mission.data.giver.id = _Faction.index
    mission.data.giver.factionIndex = _Faction.index
    mission.data.giver.coordinates = { x = _X, y = _Y }
    mission.data.giver.baseTitle = _Faction.name
end

function lotwStory4_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 10, false)

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function lotwStory4_buildSector(_X, _Y)
    local methodName = "Build Sector"

    local _Faction = Faction(mission.data.custom.friendlyFaction)
    
    if not _Faction or _Faction.isPlayer or _Faction.isAlliance then
        print("ERROR - COULD NOT FIND MISSION FACTION")
        terminate()
        return
    end

    local _sector = Sector()
    local _Rgen = ESCCUtil.getRand()
    local generator = SectorGenerator(_X, _Y)

    for _ = 1, _Rgen:getInt(3, 5) do
        generator:createSmallAsteroidField()
    end
    generator:createAsteroidField()

    local _Station = generator:createMilitaryBase(_Faction)
    _Station.position = Matrix()
    _Station:setValue("no_chatter", true)
    _Station:setValue("_lotw_mission4_defendobjective", true)
    local _StationSphere = _Station:getBoundingSphere()
    local _AsteroidRemovalSphere = Sphere(_StationSphere.center, _StationSphere.radius * 15) 
    local _RemovalCandidates = {_sector:getEntitiesByLocation(_AsteroidRemovalSphere)}
    mission.Log(methodName, "Found " .. #_RemovalCandidates .. " candidates for removal. Any asteroids in this list will be removed.")
    for _, _En in pairs(_RemovalCandidates) do
        if _En.isAsteroid then
            --Don't stump the AI.
            _sector:deleteEntity(_En)
        end
    end
    --Remove scripts.
    _Station:removeScript("consumer.lua")
    _Station:removeScript("backup.lua")
    _Station:removeScript("missionbulletins.lua")
    _sector:removeScript("traders.lua")
    --Set AI to aggressive.
    local _ShipAI = ShipAI(_Station)
    _ShipAI:setAggressive()
    --Add pilots so it can actually use the fighters.
    _Station:addCrew(60, CrewMan(CrewProfessionType.Pilot))
    --No boarding.
    Boarding(_Station).boardable = false
    --Remove cargo to prevent abuse
    local _StationBay = CargoBay(_Station)
    _StationBay:clear()
    _Station:setDropsLoot(false)

    mission.data.custom.stationId = _Station.index.string

    local _DuraFactor = 1.0
    --Anti-frustration feature.
    if mission.data.custom.missionsFailed > 0 then
        local _Factor1 = 0.2 * mission.data.custom.missionsFailed
        local _Factor2 = 0

        --If you get a really bad seed and the outpost is made of tissue paper, start exponentially increasing it after failure #5
        if mission.data.custom.missionsFailed > 5 then
            local _ExpFactor = math.max(1, mission.data.custom.missionsFailed - 5)
            _Factor2 = 0.2 * (_ExpFactor * _ExpFactor)
        end

        _DuraFactor = _DuraFactor + _Factor1 + _Factor2
    end
    local _Dura = Durability(_Station)
    if _Dura then
        _Dura.maxDurabilityFactor = _Dura.maxDurabilityFactor * _DuraFactor
    end

    local _Shield = Shield(_Station)
    if _Shield then
        _Shield.maxDurabilityFactor = _Shield.maxDurabilityFactor * _DuraFactor
    end

    Placer.resolveIntersections()

    local _EntityTypes = ESCCUtil.allEntityTypes()
    _sector:addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
end

function lotwStory4_getWingSpawnTables(_WingScriptValue)
    local methodName = "Get Wing Spawn Table"
    mission.Log(methodName, "Beginning...")

    local _Destroyed = mission.data.custom.destroyed
    
    local _BanditMaxCt = 1
    local _PirateMaxCt = 2
    local _MarauderMaxCt = 0
    if _Destroyed >= 5 then
        _BanditMaxCt = 2
        _MarauderMaxCt = 1
    end

    local _BanditCt = 0
    local _PirateCt = 0
    local _MarauderCt = 0

    local _Pirates = {Sector():getEntitiesByScriptValue(_WingScriptValue)}
    mission.Log(methodName, "Counting pirates " .. tostring(#_Pirates) .. " found")
    for _, _Pirate in pairs (_Pirates) do
        local _TArgs = _Pirate:getTitleArguments()
        for _, _TArg in pairs(_TArgs) do
            local _Title = _TArg
            if _Title == "Bandit" then
                mission.Log(methodName, "Bandit")
                _BanditCt = _BanditCt + 1
            end
            if _Title == "Pirate" then
                mission.Log(methodName, "Pirate")
                _PirateCt = _PirateCt + 1
            end
            if _Title == "Marauder" then
                mission.Log(methodName, "Marauder")
                _MarauderCt = _MarauderCt + 1
            end
        end
    end

    local _SpawnTable = {}
    if _BanditCt < _BanditMaxCt then
        local _SpawnCt = _BanditMaxCt - _BanditCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Bandit")
        end
    end
    if _PirateCt < _PirateMaxCt then
        local _SpawnCt = _PirateMaxCt - _PirateCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Pirate")
        end
    end
    if _MarauderCt < _MarauderMaxCt then
        local _SpawnCt = _MarauderMaxCt - _MarauderCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Marauder")
        end
    end

    return _SpawnTable
end

function lotwStory4_spawnBackgroundPirates()
    local methodName = "Spawn Background Pirates"
    mission.Log(methodName, "Beginning...")

    local distance = 100

    local spawnFunc = function(wingScriptValue, wingOnSpawnFunc)
        local wingSpawnTable = lotwStory4_getWingSpawnTables(wingScriptValue)
        local wingGenerator = AsyncPirateGenerator(nil, wingOnSpawnFunc)

        local posCtr = 1
        local wingPositions = wingGenerator:getStandardPositions(#wingSpawnTable, distance)

        wingGenerator:startBatch()

        for _, p in pairs(wingSpawnTable) do
            wingGenerator:createScaledPirateByName(p, wingPositions[posCtr])
            posCtr = posCtr + 1
        end

        wingGenerator:endBatch()
    end

    spawnFunc("_lotw_alpha_wing", lotwStory4_onAlphaBackgroundPiratesFinished)

    spawnFunc("_lotw_beta_wing", lotwStory4_onBetaBackgroundPiratesFinished)
end

function lotwStory4_onAlphaBackgroundPiratesFinished(_Generated)
    --Make the first alpha wing invincible vs. the station.
    local _Invincible = false
    local _DefenseObjective = nil
    if not mission.data.custom.firstAlphaInvincible then
        local _DefenseObjectives = {Sector():getEntitiesByScriptValue("_lotw_mission4_defendobjective")}
        _DefenseObjective = _DefenseObjectives[1]
        _Invincible = true
        mission.data.custom.firstAlphaInvincible = true
    end

    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_lotw_mission4_objective", true)
        _Pirate:setValue("_lotw_alpha_wing", true)

        if _Invincible then
            local _Dura = Durability(_Pirate)
            if _Dura then
                _Dura:addFactionImmunity(_DefenseObjective.factionIndex)
            end
        end
    end

    SpawnUtility.addEnemyBuffs(_Generated)
end

function lotwStory4_onBetaBackgroundPiratesFinished(_Generated)
    local _sector = Sector()

    local _SlamCtMax = 2
    local _Slammers = {_sector:getEntitiesByScript("torpedoslammer.lua")}
    local _SlamCt = #_Slammers
    local _SlamAdded = 0

    local _TorpSlammerValues = {
        _TimeToActive = 35,
        _ROF = 10,
        _UpAdjust = false,
        _DamageFactor = 0.33, --If you get a bad seed, this might just obliterate the station. That's why it gets more HP for every failure.
        _TorpOffset = -750, --Already balanced this for tech 52 torps in the starting sector, 
        _DurabilityFactor = 8,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = TorpedoUtility.WarheadType.Nuclear,
        _TargetPriority = 2,
        _TargetTag = "_lotw_mission4_defendobjective",
        _ShockwaveFactor = 2 --Give them a show!
    }

    local _DefenseObjectives = {_sector:getEntitiesByScriptValue("_lotw_mission4_defendobjective")}
    local _DefenseObjective = _DefenseObjectives[1]

    --Make the first beta wing invincible.
    local _Invincible = false
    if not mission.data.custom.firstBetaInvincible then
        _Invincible = true
        mission.data.custom.firstBetaInvincible = true
    end

    for _, _Pirate in pairs(_Generated) do
        local _Xinvincible = _Invincible --Set this each loop.
        _Pirate:setValue("_lotw_mission4_objective", true)
        _Pirate:setValue("_lotw_beta_wing", true)

        if _SlamCt + _SlamAdded < _SlamCtMax then
            local _TitleArguments = _Pirate:getTitleArguments()
            local _OldTitle = _TitleArguments.title
            _TitleArguments.title = "Bombardier " .. _OldTitle

            _Pirate:setTitleArguments(_TitleArguments)

            _Pirate:removeScript("icon.lua")
            _Pirate:addScript("icon.lua", "data/textures/icons/pixel/torpedoboatex.png")
            _Pirate:addScript("torpedoslammer.lua", _TorpSlammerValues)

            --Bit of a cheap way to do this but the "fair" way risks making them too powerful for the player to kill.
            _Xinvincible = true
            _SlamAdded = _SlamAdded + 1
        end

        if _Xinvincible then
            local _Dura = Durability(_Pirate)
            if _Dura then
                _Dura:addFactionImmunity(_DefenseObjective.factionIndex)
            end
        end

        local _ShipAI = ShipAI(_Pirate)
        _ShipAI:setAttack(_DefenseObjective)
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function lotwStory4_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _Player = Player()
    _Player:setValue("_lotw_story_stage", 5)

    local station = Entity(Uuid(mission.data.custom.stationId))
    station:setValue("no_chatter", nil)

    --Give the player a 25% bonus if they cmoplete this within 3 attempts and don't let the station HP drop below 80%
    local failedAttempts = _Player:getValue("_lotw_mission4_failures") or 0
    if failedAttempts < 3 then
        local hpRatio = station.durability / station.maxDurability

        if hpRatio >= 0.75 then
            mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " This includes a bonus for excellent work."
            mission.data.reward.credits = mission.data.reward.credits * 1.25
        end
    end

    reward()
    accomplish()
end

--endregion