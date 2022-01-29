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
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You received the following request from ${factionName}:" },
    { text = "This is an emergecy request. Despite your success in crippling the pirate supply lines, they've managed to tap a backup cache of materiel and are attacking one of our installations in force. We were under the impression that it was hidden, so we left it exposed to counterattack. You should have enough money and hardware to get a 2nd ship moving. The outpost is located in sector (${_X}:${_Y}). We'll need your help to defend it." },
    { text = "Build and outfit a 2nd ship", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defend the Military Outpost from the pirates", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Thank you. The reward has been transferred to your account. We'll be in touch."

local LOTW_Mission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

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
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
            mission.data.custom.destroyed = 0
            mission.data.custom.friendlyFaction = _Player:getValue("_lotw_faction")
            mission.data.custom.missionsFailed = _FailureCt
            mission.data.custom.failureCounter = 0 --Used to fail the mission if the player is out of sector for to long, not to count mission failures.

            mission.data.custom.outpostLocation = getNextLocation()

            local missionReward = ESCCUtil.clampToNearest(150000 + (50000 * Balancing.GetSectorRichnessFactor(_Sector:getCoordinates())), 5000, "Up")

            missionData_in = {location = nil, reward = {credits = missionReward, relations = 12000, paymentMessage = "Earned %1% credits for defending the outpost."}}
    
            LOTW_Mission_init(missionData_in)

            setMissionFactionData(_X, _Y) --Have to be sneaky about this. Normaly this SHOULD be set by the init function, but since it's not from a station it will get funky.
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

mission.globalPhase.onFail = function()
    local _Player = Player()
    local _FailureCt =_Player:getValue("_lotw_mission4_failures") or 0
    _FailureCt = _FailureCt + 1
    _Player:setValue("_lotw_mission4_failures", _FailureCt)
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    local _Faction = Faction(mission.data.custom.friendlyFaction) --The phase is already set to 1 by the time we hit this, so it has to be done it this way.
    local _Player = Player()

    mission.data.description[1].arguments = { factionName = _Faction.name }
    mission.data.description[2].arguments = { _X = mission.data.custom.outpostLocation.x, _Y = mission.data.custom.outpostLocation.y }

    --Start the timer to see if the player has a 2nd ship. If they already have a 2nd one we can just skip this instantly.
    if _Player.numShips > 1 then
        nextPhase()
    else
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
    end
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].noPlayerEventsTargetSector = true
mission.phases[2].noLocalPlayerEventsTargetSector = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.outpostLocation

    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { x = mission.data.location.x, y = mission.data.location.y }
    mission.data.description[4].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 2 On Enter Target Location"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true

    --Make sector.
    buildSector(x, y)

    --Spawn enemies.
    spawnBackgroundPirates()
    --Set timers.
    mission.phases[2].timers[1] = {
        time = 45,
        callback = function()
            local _Sector = Sector()
            local _X, _Y = _Sector:getCoordinates()
            if _X == mission.data.location.x and _Y == mission.data.location.y then
                spawnBackgroundPirates()
            end
        end,
        repeating = true
    }
        --Timer 3 = soft fail timer
        mission.phases[2].timers[2] = {
            time = 60, 
            callback = function() 
                local _Sector = Sector()
                local _X, _Y = _Sector:getCoordinates()
                if _X ~= mission.data.location.x or _Y ~= mission.data.location.y then
                    mission.data.custom.failureCounter = mission.data.custom.failureCounter + 1
                end
            end,
            repeating = true
        }
        --Timer 4 = advancement / objective timer
        mission.phases[2].timers[3] = {
            time = 10,
            callback = function()
                local _MethodName = "Phase 1 Timer 4 Callback"
                mission.Log(_MethodName, "Beginning...")
                mission.Log(_MethodName, "Number of pirates destroyed " .. tostring(mission.data.custom.destroyed))
                if mission.data.custom.destroyed >= 20 then
                    ESCCUtil.allPiratesDepart()
                    finishAndReward()
                end
                if mission.data.custom.failureCounter >= 3 then
                    fail()
                end
            end,
            repeating = true
        }
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    local _Sector = Sector()
    local _DefendObjective = {_Sector:getEntitiesByScriptValue("_lotw_mission4_defendobjective")}

    _Sector:broadcastChatMessage(_DefendObjective[1], ChatMessageType.Chatter, "Prioritize destroying enemies with torpedoes! We've marked them with a special icon.")
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 2 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")

    local _Entity = Entity(_ID)

    if _Entity:getValue("_lotw_mission4_objective") then
        mission.Log(_MethodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
    end

    if _Entity:getValue("_lotw_mission4_defendobjective") then
        fail()
    end
end

mission.phases[2].onTargetLocationLeft = function(x, y)
    mission.data.custom.destroyed = 0
end

--endregion

--region #SERVER CALLS

function setMissionFactionData(_X, _Y)
    local _MethodName = "Set Mission Faction Data"
    mission.Log(_MethodName, "Beginning...")
    --We're going to have to do some sneaky stuff w/ credits here.
    local _Faction = Faction(Player():getValue("_lotw_faction"))
    mission.data.giver = {}
    mission.data.giver.id = _Faction.index
    mission.data.giver.factionIndex = _Faction.index
    mission.data.giver.coordinates = { x = _X, y = _Y }
    mission.data.giver.baseTitle = _Faction.name
end

function getNextLocation()
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, false)

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function buildSector(_X, _Y)
    local _MethodName = "Build Sector"
    local _Faction = Faction(mission.data.custom.friendlyFaction)

    local generator = SectorGenerator(_X, _Y)
    local _Rgen = ESCCUtil.getRand()
    for _ = 1, _Rgen:getInt(3, 5) do
        generator:createSmallAsteroidField()
    end
    generator:createAsteroidField()

    local _Station = generator:createMilitaryBase(_Faction)
    _Station.position = Matrix()
    _Station:setValue("_lotw_mission4_defendobjective", true)
    local _StationSphere = _Station:getBoundingSphere()
    local _AsteroidRemovalSphere = Sphere(_StationSphere.center, _StationSphere.radius * 15) 
    local _RemovalCandidates = {Sector():getEntitiesByLocation(_AsteroidRemovalSphere)}
    mission.Log(_MethodName, "Found " .. #_RemovalCandidates .. " candidates for removal. Any asteroids in this list will be removed.")
    for _, _En in pairs(_RemovalCandidates) do
        if _En.isAsteroid then
            --Don't stump the AI.
            Sector():deleteEntity(_En)
        end
    end
    --Remove scripts.
    _Station:removeScript("icon.lua")
    _Station:removeScript("consumer.lua")
    _Station:removeScript("backup.lua")
    Sector():removeScript("traders.lua")
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

    local _DuraFactor = 1.0 + (0.2 * mission.data.custom.missionsFailed)
    local _Dura = Durability(_Station)
    if _Dura then
        _Dura.maxDurabilityFactor = _Dura.maxDurabilityFactor * _DuraFactor
    end

    local _Shield = Shield(_Station)
    if _Shield then
        _Shield.maxDurabilityFactor = _Shield.maxDurabilityFactor * _DuraFactor
    end

    Placer.resolveIntersections()

    Sector():addScriptOnce("deleteentitiesonplayersleft.lua")
end

function getWingSpawnTables(_WingScriptValue)
    local _MethodName = "Get Wing Spawn Table"
    mission.Log(_MethodName, "Beginning...")

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
    mission.Log(_MethodName, "Counting pirates " .. tostring(#_Pirates) .. " found")
    for _, _Pirate in pairs (_Pirates) do
        local _TArgs = _Pirate:getTitleArguments()
        for _, _TArg in pairs(_TArgs) do
            local _Title = _TArg
            if _Title == "Bandit" then
                mission.Log(_MethodName, "Bandit")
                _BanditCt = _BanditCt + 1
            end
            if _Title == "Pirate" then
                mission.Log(_MethodName, "Pirate")
                _PirateCt = _PirateCt + 1
            end
            if _Title == "Marauder" then
                mission.Log(_MethodName, "Marauder")
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

function spawnBackgroundPirates()
    local _MethodName = "Spawn Background Pirates"
    mission.Log(_MethodName, "Beginning...")

    local _AlphaSpawnTable = getWingSpawnTables("_lotw_alpha_wing")
    local generator = AsyncPirateGenerator(nil, onAlphaBackgroundPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    local pirate_positions = generator:getStandardPositions(#_AlphaSpawnTable, distance)
    for _, p in pairs(_AlphaSpawnTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()

    local _BetaSpawnTable = getWingSpawnTables("_lotw_beta_wing")
    generator = AsyncPirateGenerator(nil, onBetaBackgroundPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    local pirate_positions = generator:getStandardPositions(#_BetaSpawnTable, distance)
    for _, p in pairs(_BetaSpawnTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onAlphaBackgroundPiratesFinished(_Generated)
    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_lotw_mission4_objective", true)
        _Pirate:setValue("_lotw_alpha_wing", true)
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function onBetaBackgroundPiratesFinished(_Generated)
    local _SlamCtMax = 2
    local _Slammers = {Sector():getEntitiesByScript("torpedoslammer.lua")}
    local _SlamCt = #_Slammers
    local _SlamAdded = 0

    local _TorpSlammerValues = {}
    _TorpSlammerValues._TimeToActive = 25
    _TorpSlammerValues._ROF = 8
    _TorpSlammerValues._UpAdjust = false
    _TorpSlammerValues._DamageFactor = 0.1 --The station will DIE if this is set any higher, it's actually quite funny to watch.
    _TorpSlammerValues._DurabilityFactor = 8
    _TorpSlammerValues._ForwardAdjustFactor = 2
    _TorpSlammerValues._PreferWarheadType = TorpedoUtility.WarheadType.Nuclear
    _TorpSlammerValues._TargetPriority = 2
    _TorpSlammerValues._TargetScriptValue = "_lotw_mission4_defendobjective"

    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_lotw_mission4_objective", true)
        _Pirate:setValue("_lotw_beta_wing", true)

        if _SlamCt + _SlamAdded < _SlamCtMax then
            local _TitleArguments = _Pirate:getTitleArguments()
            local _OldTitle = _TitleArguments.title
            _TitleArguments.title = "Bombardier " .. _OldTitle

            _Pirate:setTitleArguments(_TitleArguments)

            _Pirate:removeScript("icon.lua")
            _Pirate:addScript("icon.lua", "data/textures/icons/pixel/torpedoboat.png")
            _Pirate:addScript("torpedoslammer.lua", _TorpSlammerValues)
            _SlamAdded = _SlamAdded + 1
        end

        local _ShipAI = ShipAI(_Pirate)
        local _DefenseObjectives = {Sector():getEntitiesByScriptValue("_lotw_mission4_defendobjective")}
        _ShipAI:setAttack(_DefenseObjectives[1])
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    _Player:setValue("_lotw_story_4_accomplished", true)

    reward()
    accomplish()
end

--endregion