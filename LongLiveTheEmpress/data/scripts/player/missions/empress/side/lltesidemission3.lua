--[[
    Rank 1 side mission.
    Resistance is Futile
    This is Long live the EMPRESS, not Long live the EMPEROR. You kids should be glad that I am even giving you this.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Player must have sided with the emperor.
    ROUGH OUTLINE
        - Player goes to designated location.
        - Player meets nearby faction (chosen at random - 50% pirates, 50% local faction)
        - If nearby faction is not already at war with player, they declare war on the player immediately and max negative rep.
        - Player must destroy all stations in the sector.
        - Faction will constantly send reinforcements while at least 1 station remains.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - pirates will use high threat ships from the corresponding danger level table.
            - factions will simply use the generic defender ship with the faction standard spawn / danger table
            - up to 5 defenders present at any given time.
            - defenders will respawn every 2 minutes so the player has some breathing room if they kill all of them
            - if defender is damaged too badly, it will warp out and allow a new one to take its place
            - 1 station always present, chosen at random between military outpost, shipyard, and repair dock
            - 50% chance to get a 2nd station, 50% chance to get a 3rd station (These are rolled independently)
        6 - [These conditions are present at danger level 6 and above]
            - Maximum defenders increased by +1 (6 total)
            - Secondary / Tertiary station chance increased to 60%
            - 7% chance per danger level above 5 to include a carrier in each wave (up to a maximum of 35% @ level 10)
        8 - [These conditions are present at danger level 8 and above]
            - Maximum defenders increased by +1 (7 total)
            - Secondary / Tertiary station chance increased to 70%
        10 - [These conditions are present at danger level 10]
            - Maximum defenders increased by +1 (8 total)
            - Secondary / Tertiary station chance increased to 80%
            - First station will always be a military outpost, and Military outpost gets turrets damage buff
            - IF FACTION - 3 heavy defenders + blocker ship will spawn upon first station being destroyed.
            - IF PIRATE - Executioner will spawn upon first station being destroyed.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run other includes.
include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")
local Placer = include ("placer")

mission._Debug = 0
mission._Name = "Resistance is Futile"

--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "Initialize"
    if onServer() then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local _Rgen = ESCCUtil.getRand()
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local target = {}
            target.x, target.y = MissionUT.getSector(x, y, 6, 18, false, false, false, false, insideBarrier)

            if not target then
                mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
                terminate()
                return
            end

            local _Name = "The Cavaliers" 
            local _Faction = Galaxy():findFaction(_Name)
            
            --Standard mission data.
            mission.data.brief = "Resistance is Futile"
            mission.data.title = "Resistance is Futile"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "The Emperor of The Cavaliers has asked you to attack a faction that refuses to submit to his rule.",
                "If you choose to go through with this, it could have severe consequences.",
                { text = "Destroy the faction outpost in (${xLoc}:${yLoc})", arguments = {xLoc = target.x, yLoc = target.y}, bulletPoint = true, fulfilled = false }
            }

            local _RewardBase = 280000
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .pirates
                .pirateLevel
                .maxDefenders
                .secondStation
                .thirdStation
                .builtMainSector
                .firstStationid
                .localFactionIndex
                .hunterWaveSpawned
            =========================================================]]
            mission.data.custom.dangerLevel = _Rgen:getInt(1, 10)
            mission.data.custom.maxDefenders = 5
            if mission.data.custom.dangerLevel >= 8 then
                _RewardBase = _RewardBase + 30000
            end
            if mission.data.custom.dangerLevel == 10 then
                _RewardBase = _RewardBase + 55000
            end

            local _Rgen = ESCCUtil.getRand()           
            local _StationChance = 5
            mission.data.custom.pirates = _Rgen:getInt(1, 2) == 1
            if mission.data.custom.dangerLevel >= 6 then
                mission.data.custom.maxDefenders = mission.data.custom.maxDefenders + 1
                mission.data.custom.carrierChance = 0.07 * (mission.data.custom.dangerLevel - 5)
                _StationChance = _StationChance + 1
            end
            if mission.data.custom.dangerLevel >= 8 then
                mission.data.custom.maxDefenders = mission.data.custom.maxDefenders + 1
                _StationChance = _StationChance + 1
            end
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.maxDefenders = mission.data.custom.maxDefenders + 1
                _StationChance = _StationChance + 1
            end
            mission.data.custom.secondStation = (_Rgen:getInt(1, 10) <= _StationChance)
            mission.data.custom.thirdStation = (_Rgen:getInt(1, 10) <= _StationChance)

            mission.Log(_MethodName, "dangerLevel is " .. tostring(mission.data.custom.dangerLevel) .. " pirates is " .. tostring(mission.data.custom.pirates) .. " maxDefenders is " .. tostring(mission.data.custom.maxDefenders) .. " secondStation is " .. tostring(mission.data.custom.secondStation) .. " thirdStation is " .. tostring(mission.data.custom.thirdStation))

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRewardFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = target, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, "The target is located in \\s(%1%:%2%). Go and crush them! Long live the emperor!", target.x, target.y)
        else
            --Restoring
            llte_sidemission_init()
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

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].triggers = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y) 
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    
    if not mission.data.custom.builtMainSector then
        --Generate the sector.
        local _Faction = nil
        local _Rgen = ESCCUtil.getRand()
        local _Generator = SectorGenerator(_X, _Y)

        for _ = 1, _Rgen:getInt(3, 5) do
            _Generator:createSmallAsteroidField()
        end
        _Generator:createAsteroidField()

        if not mission.data.custom.pirates then
            _Faction = Galaxy():getNearestFaction(_X, _Y)
        end
        if mission.data.custom.pirates or not _Faction then
            mission.Log(_MethodName, "Pirates is " .. tostring(mission.data.custom.pirates) .. " or _Faction was nil. Using pirates.")
            local _PirateLevel = Balancing_GetPirateLevel(_X, _Y)

            _Faction = Galaxy():getPirateFaction(_PirateLevel)
            mission.data.custom.pirateLevel = _PirateLevel
            --Just in case _Faction is nil
            mission.data.custom.pirates = true
        end
        
        mission.data.custom.localFactionIndex = _Faction.index
        mission.Log(_MethodName, "Faction index is " .. tostring(mission.data.custom.localFactionIndex) .. " Faction name is " .. tostring(_Faction.name))

        local _StationTable = { "Shipyard", "RepairDock", "Outpost" }

        --Spawn stations.
        if mission.data.custom.dangerLevel == 10 then
            local _FirstStation = "Outpost"
            _StationTable = { "Shipyard", "RepairDock" }
            local _Station = spawnStationByName(_Generator, _Faction, _FirstStation)
            mission.data.custom.firstStationid = _Station.id
        else
            local _Index = _Rgen:getInt(1, #_StationTable)
            local _FirstStation = _StationTable[_Index]
            table.remove(_StationTable, _Index)
            local _Station = spawnStationByName(_Generator, _Faction, _FirstStation)
            mission.data.custom.firstStationid = _Station.id
        end
        if mission.data.custom.secondStation then
            local _Index = _Rgen:getInt(1, #_StationTable)
            local _XStation = _StationTable[_Index]
            table.remove(_StationTable, _Index)
            spawnStationByName(_Generator, _Faction, _XStation)
        end
        if mission.data.custom.thirdStation then
            local _Index = _Rgen:getInt(1, #_StationTable)
            local _XStation = _StationTable[_Index]
            table.remove(_StationTable, _Index)
            spawnStationByName(_Generator, _Faction, _XStation)
        end

        local _Entities = {Sector():getEntitiesByFaction(_Faction.index)}
        for _, _En in pairs(_Entities) do
            if _En.type == EntityType.Station then
                Boarding(_En).boardable = false
            end
        end

        local _InitialDefenders = 5
        if mission.data.custom.dangerLevel >= 6 then
            _InitialDefenders = _InitialDefenders + math.ceil((mission.data.custom.dangerLevel - 5) / 2)
        end

        local _SpawnTable = ESCCUtil.getStandardTable(mission.data.custom.dangerLevel, "Standard", not mission.data.custom.pirates)
        if mission.data.custom.pirates then
            local _SpawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _InitialDefenders, "Standard")
            
            local generator = AsyncPirateGenerator(nil, onDefendersFinished)
            generator.pirateLevel = mission.data.custom.pirateLevel

            generator:startBatch()
        
            for _, _Ship in pairs(_SpawnTable) do
                generator:createScaledPirateByName(_Ship, generator.getGenericPosition())
            end

            generator:endBatch()
        else
            local _SpawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _InitialDefenders, "Standard", true)

            local generator = AsyncShipGenerator(nil, onDefendersFinished)

            generator:startBatch()

            for _, _Ship in pairs(_SpawnTable) do
                generator:createDefenderByName(_Faction, generator.getGenericPosition(), _Ship)
            end

            generator:endBatch()
        end

        local _DCD = {}
        _DCD._DefenseLeader = mission.data.custom.firstStationid
        _DCD._DefenderCycleTime = 120
        _DCD._DangerLevel = mission.data.custom.dangerLevel
        _DCD._MaxDefenders = mission.data.custom.maxDefenders
        _DCD._DefenderHPThreshold = 0.5
        _DCD._DefenderOmicronThreshold = 0.5
        _DCD._ForceWaveAtThreshold = 0.5
        _DCD._ForcedDefenderDamageScale = 3
        _DCD._IsPirate = mission.data.custom.pirates
        _DCD._Factionid = mission.data.custom.localFactionIndex
        _DCD._PirateLevel = _PirateLevel
        _DCD._UseLeaderSupply = false
        _DCD._LowTable = "High"
        if not mission.data.custom.pirates and mission.data.custom.dangerLevel >= 6 then
            _DCD._AddPctToEachWave = { { pct = mission.data.custom.carrierChance, name = "C" } }
        end

        Sector():addScript("sector/background/defensecontroller.lua", _DCD)

        Placer.resolveIntersections()

        mission.data.custom.builtMainSector = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 1 on Target Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")

    mission.Log(_MethodName, "Setting Phase 1 Trigger 1")
    mission.phases[1].triggers[1] = {
        condition = function()
            local _MethodName = "Phase 1 Trigger 1 Condition"
            local _Faction = Faction(mission.data.custom.localFactionIndex)
            local _Entities = {Sector():getEntitiesByFaction(_Faction.index)}
            mission.Log(_MethodName, "_Faction is " .. tostring(_Faction.name) .. " #_Entities is " .. tostring(#_Entities), 0)        
            if _Entities and #_Entities == 0 then
                return true
            end
            return false
        end,
        callback = function()
            local _MethodName = "Phase 1 Trigger 1 Callback"
            mission.Log(_MethodName, "Finished mission - rewarding player.")
            finishAndReward()
        end,
        repeating = false
    }

    local _Faction = Faction(mission.data.custom.localFactionIndex)
    --If the player isn't already at war with the faction, add an interaction script and declare war.
    local _Relation = Player():getRelation(_Faction.index)
    if _Relation.status ~= RelationStatus.War then
        mission.Log(_MethodName, "Local faction not already at war with player. Declaring war.")
        local _Entities = {Sector():getEntitiesByFaction(_Faction.index)}
        for _, _E in pairs(_Entities) do
            if _E.type == EntityType.Ship or _E.type == EntityType.Station then
                _E:addScriptOnce("player/missions/empress/side/side3/llteside3dialogue1.lua")
            end
        end
    end    
end

mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 On Entity Destroyed"
    mission.Log(_MethodName, "Beginning...", 0)

    if mission.data.custom.dangerLevel == 10 and Entity(_ID):getValue("_llte_side3_station") and not mission.data.custom.hunterWaveSpawned then
        mission.Log(_MethodName, "Spawning Hunter Wave.")
        local _Stations = {Sector():getEntitiesByType(EntityType.Station)}
        local _Rgen = ESCCUtil.getRand()
        local _BroadcastStation = _Stations[_Rgen:getInt(1, #_Stations)]
        Sector():broadcastChatMessage(_BroadcastStation, ChatMessageType.Chatter, "Did you think we'd make this easy for you? Get ready to die!")

        if mission.data.custom.pirates then
            mission.phases[1].timers[1] = {
                time = 10,
                callback = function()
                    local _HunterWaveGenerator = AsyncPirateGenerator(nil, onHunterWaveFinished)
                    _HunterWaveGenerator.pirateLevel = mission.data.custom.pirateLevel

                    _HunterWaveGenerator:startBatch()

                    _HunterWaveGenerator:createScaledExecutioner(_HunterWaveGenerator:getGenericPosition(), 2000)
                    _HunterWaveGenerator:createScaledExecutioner(_HunterWaveGenerator:getGenericPosition(), 2000)

                    _HunterWaveGenerator:endBatch()
               end,
               repeating = false
            }
        else
            mission.phases[1].timers[1] = {
                time = 10,
                callback = function()
                    local _Faction = Faction(mission.data.custom.localFactionIndex)
                    local _HunterWaveGenerator = AsyncShipGenerator(nil, onHunterWaveFinished)

                    local _HunterPositions = _HunterWaveGenerator:getStandardPositions(350, 4)

                    _HunterWaveGenerator:startBatch()

                    _HunterWaveGenerator:createDefenderByName(_Faction, _HunterPositions[1], "H")
                    _HunterWaveGenerator:createDefenderByName(_Faction, _HunterPositions[2], "H")
                    _HunterWaveGenerator:createDefenderByName(_Faction, _HunterPositions[3], "BLOCKER")
                    _HunterWaveGenerator:createDefenderByName(_Faction, _HunterPositions[4], "H")
                    

                    _HunterWaveGenerator:endBatch()
                end,
                repeating = false
            }
        end

        mission.data.custom.hunterWaveSpawned = true
    end
end

--endregion

--region #SERVER CALLS

function spawnStationByName(_Generator, _Faction, _Name)
    local _MethodName = "Spawning Station By Name"
    local _Station = nil
    if _Name == "Outpost" then
        _Station = _Generator:createMilitaryBase(_Faction)
        _Station:addCrew(60, CrewMan(CrewProfessionType.Pilot))
        if mission.data.custom.dangerLevel == 10 then
            ShipUtility.addScalableArtilleryEquipment(_Station, 3.0, 1.0, false)
        end
    elseif _Name == "Shipyard" then
        _Station = _Generator:createShipyard(_Faction)
    elseif _Name == "RepairDock" then
        _Station = _Generator:createRepairDock(_Faction)
    end

    if _Station then
        _Station:setValue("_llte_side3_station", true)
        mission.Log(_MethodName, "Set side3 station value. Confirming value is - " .. tostring(_Station:getValue("_llte_side3_station")))

        local _ShipAI = ShipAI(_Station)
        _ShipAI:setAggressive()
    end

    return _Station
end

function onDefendersFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)
end

function onHunterWaveFinished(_Generated)
    onDefendersFinished(_Generated)

    local _Rgen = ESCCUtil.getRand()

    local _HunterLines = {}
    --A little variety in case of abandon / recomplete.
    if mission.data.custom.pirates then
        _HunterLines = {
            "Targets verified. Commencing hostilities.",
            "Cavaliers sighted. Excising.",
            "This is the end of the road for you.",
            "Time to cut the head from the beast."
        }
    else
        --These guys are especially dangerous.
        for _, _S in pairs(_Generated) do
            _S.damageMultiplier = (_S.damageMultiplier or 1) * 2
        end

        _HunterLines = {
            "Hunter group on station! Moving to engage now!",
            "I can't believe you started the party without us.",
            "This is the Hunter group. We're here and closing the jaws.",
            "Engines to full, weapons hot! Engage the targets now!",
            "Empty all magazines! Fire! Fire! Fire!"
        }
    end

    Sector():broadcastChatMessage(_Generated[_Rgen:getInt(1, #_Generated)], ChatMessageType.Chatter, randomEntry(_HunterLines))
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "Did they really think they could resist our might?",
        "Excellent work, General. The galaxy will soon be ours...",
        "All will bow before me, or suffer the consequences!",
        "We shall destroy all who oppose us!",
        "The Cavaliers will rule the galaxy!",
        "We will bring law and order to this galaxy!",
        "We'll crush the pirates! We'll crush the Xsotan! And we'll crush the complacent fools who suffer them!"
    }

    mission.data.reward.paymentMessage = "Earned %1% credits for crushing the resistance."
    _Player:sendChatMessage("The Emperor", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)])
    reward()
    accomplish()
end

--endregion

--region #CLIENT / SERVER CALLS

function factionDeclareWar()
    local _MethodName = "Faction Declare War"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client - Invoking on Server.")
        invokeServerFunction("factionDeclareWar")
        return
    else
        mission.Log(_MethodName, "Calling on Server")
    end

    local _Faction = Faction(mission.data.custom.localFactionIndex)
    local _Galaxy = Galaxy()
    local _Player = Player()
    _Galaxy:setFactionRelations(_Faction, _Player, -100000)
    _Galaxy:setFactionRelationStatus(_Faction, _Player, RelationStatus.War)
end
callable(nil, "factionDeclareWar")

--endregion