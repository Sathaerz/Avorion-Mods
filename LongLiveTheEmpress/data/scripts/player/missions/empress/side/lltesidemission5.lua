--[[
    Rank 4 side mission.
    Destroy Entrenched Pirates
    This mission lives up to its name. When Hello There tested it, he said "(give the player a warning  from the scout that mission is a beast compared to the rest)"
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Rank 3
    ROUGH OUTLINE
        - [OPTIONAL] Player goes to sector and fights group of 12 pirates to pick up decryption keys. 
            - The optional pirates have some hints about how this mission works.
            - And they also have some nifty data.
        - Player goes to sector
        - Player fights infinitely respawning waves of pirates while trying to kill the outpost.
        - Once the outpost is destroyed, no more waves spawn (obviously) - the pirates will leave the sector when the player leaves.
        - Every so often, supply ships spawn that attempt to dock to the outpost. If a supply ship successfully docks, it adds to the supply level of the outpost
        - As the supply level increases, the outpost will occasionally fire a large cannon shot at the player. (Can be dodged)
            - If the player completed the optional objective, broadcast chat messages that hint at the cannon firing, shipments spawning, and defenders spawning.
        - Give the outpost fighters. Supply level increases # of fighters.
        - A lot of the stuff in here is going to be handled by a script on the outpost itself. This is so the player can't simply abandon the mission and breeze through the station.
        - See defensecontroller.lua, shipmentcontroller.lua, and stationsiegegun.lua for more information on how these scripts all interlock.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - There are 12 initial defenders with the outpost retrieved from the low threat table.
            - Alt location has 12 ships from the standard table.
            - Defenders respawn every 4 minutes.
            - Supply ships spawn every 2 minutes. Add 5 seconds to put them slightly out of sync with the defender spawn
            - Supply ships slowly get more durable over time. (+10% HP / Shield per supply ship - no upper limit)
            - Supply level of military outpost adds buff to defenders when they spawn in. (+10% shield / hp / damage(?) - no upper limit)
            - Badly damaged defenders will jump out and get replaced in the next defender respawn wave.
            - Cap of 4 defenders. Set a specific value for defenders so that the 10 initial defenders don't count against them.
            - Outpost has a main cannon that does more damage based on the level of the outpost, the danger level of the mission, and supply level of the outpost.
            - Outpost forces a wave of defenders to spawn almost immediately if the player manages to force it below 80% hull before the first wave of defenders spawns.
            - If the outpost forces a defender spawn, the defenders will have a 2.5x damage buff.
            - The outpost will have +30% shields and HP
        5 - [These conditions are present at danger level 5 and above]
            - Forced defender spawns get 3.5x damage.
        6 - [These conditions are present at danger level 6 and above]
            - Supply ships appear more often.
        8 - [These conditions are present at danger level 8 and above]
            - Outpost alternates between standard / high threat tables for waves of ships every 3 waves.
            - Supply is transferred more quickly.
            - Outpost retains its cargo, so the player gets a pretty massive payout for this mission with a little extra effort.
                - The cargo is only retained if the player is less than 175 away from the core, to prevent low-effort farming in low-tech sectors.
            - Forced defender spawns get 5x damage.
        10 - [These conditions are present at danger level 10]
            - Defender waves spawn more frequently. (Every 3 1/2 minutes.)
            - +1 maximum defender (5 total)
            - Supply ships spawn even more frequently and have more supply.
            - Include an extra jammer with each wave of pirates.
            - Military Outpost is named "Arms Fortress" instead and has +50% HP / Shield, and more guns. Nothing special otherwise. "Arms Fortress" is just a cool ass name.
            - Forced defender spawns get 10x damage.
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
local PirateGenerator = include("pirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")
local Placer = include ("placer")

mission._Debug = 0
mission._Name = "Destroy Entrenched Pirates"

mission.data.custom.locations = {}
mission.data.custom.wreckagePieceIds = {}

--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Destroy Entrenched Pirates Begin...")

    if onServer() then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local _Rgen = ESCCUtil.getRand()
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local _Target = {}
            local _OptTarget = {}
            _Target.x, _Target.y = MissionUT.getSector(x, y, 5, 12, false, false, false, false, insideBarrier)
            local _OptLocationOK = false
            while not _OptLocationOK do
                _OptTarget.x, _OptTarget.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, insideBarrier)
                if _OptTarget.x ~= _Target.x or _OptTarget.y ~= _Target.y then
                    _OptLocationOK = true
                end
            end

            if not _Target then
                mission.Log(_MethodName, "ERROR - Could not determine mission location. Terminating script and returning.")
                terminate()
                return
            end
            if not _OptTarget then
                mission.Log(_MethodName, "ERROR - Could not determine mission optional objective location. Terminating script and returning.")
                terminate()
                return
            end

            --Standard mission data.
            mission.data.brief = "Destroy Entrenched Pirates"
            mission.data.title = "Destroy Entrenched Pirates"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "The Cavaliers have contacted you and asked you to destroy a well-defended pirate outpost.",
                { text = "Destroy the outpost in sector (${xLoc}:${yLoc})", arguments = {xLoc = _Target.x, yLoc = _Target.y}, bulletPoint = true, fulfilled = false },
                { text = "(Optional) A group of defenders is gathering in sector (${xLoc}:${yLoc}). Destroy them", arguments = { xLoc = _OptTarget.x, yLoc = _OptTarget.y }, bulletPoint = true, fulfilled = false },
                { text = "Search the wreckages for anything interesting", bulletPoint = true, fulfilled = false, visible = false }
            }

            local _RewardBase = 120000
            local _InitialMessage = "The outpost is located at \\s(%1%:%2%)."
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .locations
                .optlocation
                .pirateLevel
                .maxDefenders
                .defenderRespawnTime
                .freighterRespawnTime
                .freighterSupply
                .freighterSupplyTransfer
                .freighterScale
                .optionalPiratesGenerated
                .optionalPiratesTaunted
                .optionalPiratesAllDestroyed
                .wreckagePieceIds
                .optionalObjectiveCompleted
                .builtMainSector
                .militaryStationid
                .forcedDefenderScale
            =========================================================]]
            mission.data.custom.dangerLevel = _Rgen:getInt(1, 10)
            mission.data.custom.locations = {}
            table.insert(mission.data.custom.locations, _Target)
            table.insert(mission.data.custom.locations, _OptTarget)
            mission.data.custom.optlocation = _OptTarget
            mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_Target.x, _Target.y)
            mission.data.custom.maxDefenders = 4
            mission.data.custom.defenderRespawnTime = 210
            mission.data.custom.forcedDefenderScale = 2.5
            mission.data.custom.freighterRespawnTime = 125
            mission.data.custom.freighterSupply = 500
            mission.data.custom.freighterSupplyTransfer = 50
            mission.data.custom.freighterScale = 8
            --Adjust for danger level. Things like supply transferring faster, etc. can be handled by checking the danger level itself.
            if mission.data.custom.dangerLevel >= 5 then
                mission.data.custom.forcedDefenderScale = 3.5
            end
            if mission.data.custom.dangerLevel >= 6 then
                mission.data.custom.freighterRespawnTime = mission.data.custom.freighterRespawnTime - 30
                mission.data.custom.freighterScale = mission.data.custom.freighterScale + 2
                _RewardBase = _RewardBase + 5000
                mission.data.description[1] = mission.data.description[1] .. " Heavy resistance is expected."
            end
            if mission.data.custom.dangerLevel >= 8 then
                mission.data.custom.freighterSupplyTransfer = 75
                mission.data.custom.freighterScale = mission.data.custom.freighterScale + 2
                mission.data.custom.forcedDefenderScale = 5
                _RewardBase = _RewardBase + 7500
            end
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.maxDefenders = mission.data.custom.maxDefenders + 1
                mission.data.custom.defenderRespawnTime = mission.data.custom.defenderRespawnTime - 15
                mission.data.custom.freighterSupply = mission.data.custom.freighterSupply + 500
                mission.data.custom.freighterSupplyTransfer = 90
                mission.data.custom.freighterScale = mission.data.custom.freighterScale + 2
                mission.data.custom.forcedDefenderScale = 10
                _RewardBase = _RewardBase + 10000
            end
            PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = _Target, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, _InitialMessage, _Target.x, _Target.y)
            if mission.data.custom.dangerLevel >= 8 then
                Player():sendChatMessage("The Cavaliers", 0, "They've fortified their position well. You may want to see what information you can discover before attacking.")
            end
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

mission.globalPhase = {}
mission.globalPhase.timers = {}
mission.globalPhase.onSectorEntered = function(_X, _Y)
    local _MethodName = "Global Phase On Location Entered"
    mission.Log(_MethodName, "Beginning...")

    local _OptX, _OptY = mission.data.custom.optlocation.x, mission.data.custom.optlocation.y
    if _OptX and _OptY then
        if _X == _OptX and _Y == _OptY then
            mission.Log(_MethodName, "Optional Objective Location Entered - running onOptionalLocationEntered callbacks")

            if mission.currentPhase.onOptionalLocationEntered then mission.currentPhase.onOptionalLocationEntered(_X, _Y) end
            if mission.globalPhase.onOptionalLocationEntered then mission.globalPhase.onOptionalLocationEntered(_X, _Y) end
        end
    end
end

mission.globalPhase.onSectorArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Global Phase On Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")

    local _OptX, _OptY = mission.data.custom.optlocation.x, mission.data.custom.optlocation.y
    if _OptX and _OptY then
        if _X == _OptX and _Y == _OptY then
            mission.Log(_MethodName, "Optional Objective Location Arrival Confirmed - running onOptionalLocationArrivalConfirmed callbacks")

            if mission.currentPhase.onOptionalLocationArrivalConfirmed then mission.currentPhase.onOptionalLocationArrivalConfirmed(_X, _Y) end
            if mission.globalPhase.onOptionalLocationArrivalConfirmed then mission.globalPhase.onOptionalLocationArrivalConfirmed(_X, _Y) end
        end
    end
end

mission.globalPhase.updateServer = function(_TimeStep)
    local _MethodName = "Global Phase Update Server"

    local _LX, _LY = mission.data.custom.optlocation.x, mission.data.custom.optlocation.y
    if _LX and _LY then
        local _X, _Y = Sector():getCoordinates()
        if _LX == _X and _LY == _Y then
            --mission.Log(_MethodName, "Running optional location update server.")
            if mission.currentPhase.optionalUpdateServer then mission.currentPhase.optionalUpdateServer(_TimeStep) end
        else
            --mission.Log(_MethodName, "_LX: " .. tostring(_LX) .. " _LY: " .. tostring(_LY) .. " did not match _X: " .. tostring(_X) .. " _Y: " .. tostring(_Y))
        end
    else
        mission.Log(_MethodName, "WARNING - Could not get current location x / y of the mission.")
    end
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y) 
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    --Build the sector, then start the reinforcement and shipment scripts.
    buildObjectiveSector(_X, _Y)
    mission.Log(_MethodName, "Starting scripts.")

    local _Sector = Sector()

    local _MilitaryStation = Entity(mission.data.custom.militaryStationid)
    --ADD DEFENDER CONTROLLER + SHIPMENT CONTROLLER SCRIPT
    if not _Sector:hasScript("sector/background/defensecontroller.lua") then
        --Defense Controller Data
        local _DCD = {}
        _DCD._DefenseLeader = mission.data.custom.militaryStationid
        _DCD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _DCD._DefenderCycleTime = mission.data.custom.defenderRespawnTime
        _DCD._DangerLevel = mission.data.custom.dangerLevel
        _DCD._MaxDefenders = mission.data.custom.maxDefenders
        _DCD._DefenderHPThreshold = 0.5
        _DCD._DefenderOmicronThreshold = 0.5
        _DCD._ForceWaveAtThreshold = 0.8
        _DCD._ForcedDefenderDamageScale = mission.data.custom.forcedDefenderScale
        _DCD._IsPirate = true
        _DCD._Factionid = _MilitaryStation.factionIndex
        _DCD._PirateLevel = mission.data.custom.pirateLevel
        _DCD._UseLeaderSupply = true
        _DCD._LowTable = "Standard"
        _DCD._HighTable = "High"
        _DCD._SupplyPerLevel = 500
        _DCD._SupplyFactor = 0.1 --+10% buff per level.
        if mission.data.custom.dangerLevel >= 8 then
            _DCD._SwapTables = true
            _DCD._SwapOnModulo = 3
        end
        if mission.data.custom.dangerLevel == 10 then
            _DCD._AddToEachWave = { "Jammer" }
        end

        _Sector:addScript("sector/background/defensecontroller.lua", _DCD)
        mission.Log(_MethodName, "Defense controller successfully attached.")
    else
        _Sector:invokeFunction("sector/background/defensecontroller.lua", "setCodesCracked", mission.data.custom.optionalObjectiveCompleted)
    end

    if not _Sector:hasScript("sector/background/shipmentcontroller.lua") then
        --Shipment Controller Data
        local _SCD = {}
        _SCD._ShipmentLeader = mission.data.custom.militaryStationid
        _SCD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _SCD._ShipmentCycleTime = mission.data.custom.freighterRespawnTime
        _SCD._DangerLevel = mission.data.custom.dangerLevel
        _SCD._IsPirate = true
        _SCD._Factionid = _MilitaryStation.factionIndex
        _SCD._PirateLevel = mission.data.custom.pirateLevel
        _SCD._SupplyTransferPerCycle = mission.data.custom.freighterSupplyTransfer
        _SCD._SupplyPerShip = mission.data.custom.freighterSupply
        _SCD._SupplierExtraScale = mission.data.custom.freighterScale
        _SCD._SupplierHealthScale = 0.1

        _Sector:addScript("sector/background/shipmentcontroller.lua", _SCD)
        mission.Log(_MethodName, "Shipment controller successfully attached.")
    else
        _Sector:invokeFunction("sector/background/shipmentcontroller.lua", "setCodesCracked", mission.data.custom.optionalObjectiveCompleted)
    end

    if not _MilitaryStation:hasScript("entity/stationsiegegun.lua") then
        --Siege Gun Data
        local _SGD = {}
        _SGD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _SGD._Velocity = 150
        _SGD._ShotCycle = 30
        _SGD._ShotCycleSupply = 1000
        _SGD._ShotCycleTimer = 30
        _SGD._SupplyPerLevel = 4000 --This ratchets the damage up way too quickly at 500 per level - it will already be doing +40% damage by shot #2.
        _SGD._SupplyFactor = 0.1
        _SGD._FragileShots = false

        local _Dist = ESCCUtil.getDistanceToCenter(_X, _Y)
        --Clamp lowest damage to 10k
        local _Damage = math.max((500 - _Dist) * 10000, 10000)
        if _Dist < 80 then
            _Damage = _Damage + ((80 - _Dist) * 125000)
        end
        _Damage = _Damage * (1 + (mission.data.custom.dangerLevel / 20))
        _SGD._BaseDamagePerShot = _Damage

        _MilitaryStation:addScript("entity/stationsiegegun.lua", _SGD)
        mission.Log(_MethodName, "Attached siege gun script to military outpost.")
    else
        _MilitaryStation:invokeFunction("entity/stationsiegegun.lua", "setCodesCracked", mission.data.custom.optionalObjectiveCompleted)
    end
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 1 Update Target Location"

    if ESCCUtil.countEntitiesByValue("_llte_side5_mainobjective") == 0 and mission.data.custom.builtMainSector then
        mission.Log(_MethodName, "Outpost is destroyed. Running victory condition.")

        --Add deletion scripts to all pirate entities in the sector.
        local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
        for _, _P in pairs(_Pirates) do
            MissionUT.deleteOnPlayersLeft(_P)
        end

        finishAndReward()
    end
end

--Optional sector calls.
mission.phases[1].onOptionalLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 1 On Optional Location Entered"
    mission.Log(_MethodName, "Beginning...")

    if not mission.data.custom.optionalPiratesGenerated then
        mission.Log(_MethodName, "Generating optional pirates.")

        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 10)
        local _CreatedPirateTable = {}

        for _, _Pirate in pairs(_PirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)

        mission.data.custom.optionalPiratesGenerated = true
    end
end

mission.phases[1].onOptionalLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 1 On Optional Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")

    if not mission.data.custom.optionalPiratesTaunted then 
        mission.Log(_MethodName, "Optional pirates did not taunt. Broadcast taunt.")

        local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
        if _Pirates then
            mission.Log(_MethodName, "Sending pirate taunt")
            local _Lines = {
                "Who sold us out? We're going to kill you after we deal with this!",
                "How did they know about the codes? Kill them quickly!",
                "Killing you will be an adequate form of security.",
                "How did you find us? No matter, we'll kill you!",
                "I guess we won't need to worry about the codes if you're dead.",
                "They must be after the codes! Kill all of them!",
                "What's this? We'll kill you!"
            }

            Sector():broadcastChatMessage(_Pirates[1], ChatMessageType.Chatter, randomEntry(_Lines))
        end

        mission.data.custom.optionalPiratesTaunted = true
    end
end

mission.phases[1].optionalUpdateServer = function(_TimeStep)
    local _MethodName = "On Optional Update Server"

    --We can't use onDestroyed to do this because it will still think one is left when the last one is destroyed.
    if ESCCUtil.countEntitiesByValue("is_pirate") == 0 and not mission.data.custom.optionalPiratesAllDestroyed then
        mission.Log(_MethodName, "All optional pirates destroyed. Attach wreckage searching scripts to the wrecks.")

        local _WreckSizes = { 1000, 900, 800, 700, 600, 500, 400, 300, 200, 150, 100, 50, 40, 30, 20, 10 }
        local _TargetWreckSize = 1000
        local _Rgen = ESCCUtil:getRand()

        --Tries to find the largest wreckage size (by block count) that there are at least 5 of.
        local _Wreckages = {Sector():getEntitiesByType(EntityType.Wreckage)}
        for _, _Wsize in pairs(_WreckSizes) do
            local _Count = 0
            for _, _Wr in pairs(_Wreckages) do
                local _Pl = Plan(_Wr.id)
                if _Pl.numBlocks >= _Wsize then _Count = _Count + 1 end
            end
            if _Count >= 5 then 
                _TargetWreckSize = _Wsize
                break
            end
        end

        --Get 5 random wreckages from the table.
        shuffle(_Rgen, _Wreckages)
        local _CandidateWrecks = {}
        for _, _Wreck in pairs(_Wreckages) do
            local _Pl = Plan(_Wreck.id)
            if _Pl.numBlocks >= _TargetWreckSize then
                table.insert(_CandidateWrecks, _Wreck)
                if #_CandidateWrecks >= 5 then
                    break
                end
            end
        end

        --Attaches a script to all of the candidate wreckages that allows them to be searched, and marks them on the player's UI.
        for _, _Wreck in pairs(_CandidateWrecks) do
            table.insert(mission.data.custom.wreckagePieceIds, _Wreck.id)
            _Wreck:addScriptOnce("player/missions/empress/side/side5/llteside5search.lua")
            _Wreck:setValue("_llte_optionalwreck_targetplayer", Player().id)
        end
        local _TargetWreck = Entity(mission.data.custom.wreckagePieceIds[_Rgen:getInt(1, #mission.data.custom.wreckagePieceIds)])
        _TargetWreck:setValue("_llte_optionalwreck_hascode", true)

        registerMarkWreckages()
        showMissionUpdated("Destroy Entrenched Pirates")
        mission.data.description[3].fulfilled = true
        mission.data.description[4].visible = true

        sync()
        mission.data.custom.optionalPiratesAllDestroyed = true
    end
end

--Abandon is always the last call in a phase, imo
mission.phases[1].onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        --Dump all of the cargo in the military base in case the player tries to kill it after abandoning to make things easier.
        --Joke's on them, though. The defense controller won't go away when this is deleted :D
        local _Station = Entity(mission.data.custom.militaryStationid)
        local _StationBay = CargoBay(_Station)
        _StationBay:clear()

        local _EntityTypes = { EntityType.Ship, EntityType.Station, EntityType.Torpedo, EntityType.Fighter, EntityType.Wreckage, EntityType.Asteroid, EntityType.Unknown, EntityType.Other, EntityType.Loot }
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        --Abandoned out-of-sector.
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        --boop mission x/y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
    end
end

--endregion

--region #SERVER CALLS

--region #SPAWN INITIAL OBJECTS

function buildObjectiveSector(_X, _Y)
    local _MethodName = "Build Sector"

    if not mission.data.custom.builtMainSector then
        mission.Log(_MethodName, "Building main sector.")

        --Sector should always have 3-5 small asteroid fields, 1 large asteroid field, and a military outpost + 12 standard defenders
        local generator = SectorGenerator(_X, _Y)
        local _Rgen = ESCCUtil.getRand()
        for _ = 1, _Rgen:getInt(3, 5) do
            generator:createSmallAsteroidField()
        end
        generator:createAsteroidField()

        --Military outpost - get rid of all of the cargo and all of the various scripts, etc.
        local _Faction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)
        local _Station = generator:createMilitaryBase(_Faction)
        _Station.position = Matrix()
        _Station:setValue("is_pirate", true)
        _Station:setValue("_llte_side5_mainobjective", true)
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
        --Add some turrets.
        ShipUtility.addScalableArtilleryEquipment(_Station, 4.0, 1.0, false)
        ShipUtility.addScalableArtilleryEquipment(_Station, 2.0, 1.0, false)
        ShipUtility.addScalableArtilleryEquipment(_Station, 2.0, 1.0, false)
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
        --Remove cargo if we're at a danger level less than 8 or if we're too far outside the barrier.
        local _Dist = ESCCUtil.getDistanceToCenter(_X, _Y)
        if mission.data.custom.dangerLevel < 8 or _Dist > 175 then
            local _StationBay = CargoBay(_Station)
            _StationBay:clear()
        end
        --Change to "Arms Fortress" and buff shields / hp. Effectively a 50% buff to damage via more guns.
        local _DuraFactor = 1.3
        if mission.data.custom.dangerLevel == 10 then
            ShipUtility.addScalableArtilleryEquipment(_Station, 4.0, 1.0, false)
            _DuraFactor = 1.5

            _Station.title = "Arms Fortress"
            _Station:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
        else
            _Station.title = "Military Outpost"
            _Station:addScript("icon.lua", "data/textures/icons/pixel/military.png")
        end
        --Bump station HP / shield.
        local _Dura = Durability(_Station)
        if _Dura then
            _Dura.maxDurabilityFactor = _Dura.maxDurabilityFactor * _DuraFactor
        end

        local _Shield = Shield(_Station)
        if _Shield then
            _Shield.maxDurabilityFactor = _Shield.maxDurabilityFactor * _DuraFactor
        end

        mission.data.custom.militaryStationid = _Station.id

        Placer.resolveIntersections()

        --8 initial defenders from standard threat table.
        local _InitialDefenders = 8
        --At danger 10 we get two extras.
        if mission.data.custom.dangerLevel == 10 then
            _InitialDefenders = _InitialDefenders + 2
        end
        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _InitialDefenders, "Standard")
        local _CreatedPirateTable = {}

        for _, _Pirate in pairs(_PirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
        mission.data.custom.builtMainSector = true
    end
end

--endregion

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "The Empress will be pleased to hear of this.",
        "Thank you for making the galaxy safer.",
        "Your support is appreciated, as always.",
        "Amazing work, " .. _Player.name .. "!",
        "Great job, " .. _Rank .. "!",
        "The telemetry of that battle looked incredible!",
        "We'd expect nothing less from a " .. _Rank .. "!"
    }

    local _RepReward = 4
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end

    --Increase reputation by 4 (5 @ 10 danger)
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + _RepReward)
    _Player:sendChatMessage("The Cavaliers", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onMarkWreckages()
    local _MethodName = "On Mark Wreckages"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    if not mission.data.custom.wreckagePieceIds then 
        mission.Log(_MethodName, "WARNING - Could not find wreckage IDs")
        return 
    end

    for _, wreckId in pairs(mission.data.custom.wreckagePieceIds) do
        local entity = Entity(wreckId)
        if not entity then return end
        
        if entity:hasScript("llteside5search.lua") then
            local _ContainerMarkOrange = ESCCUtil.getSaneColor(255, 173, 0)

            renderer:renderEntityTargeter(entity, _ContainerMarkOrange)
            renderer:renderEntityArrow(entity, 30, 10, 250, _ContainerMarkOrange)
        end
    end

    renderer:display()
end

--endregion

--region #CLIENT / SERVER CALLS

local llte_sidemission_getLoc = getMissionLocation
function getMissionLocation()
    local _Locations = {}
    if mission.data.custom.optionalObjectiveCompleted then
        table.insert(_Locations, ivec2(mission.data.location.x, mission.data.location.y))
    else
        for _, _Loc in pairs(mission.data.custom.locations) do
            table.insert(_Locations, ivec2(_Loc.x, _Loc.y))
        end
    end

    return unpack(_Locations)
end

function registerMarkWreckages()
    local _MethodName = "Register Mark Wreckages"
    if onClient() then
        _MethodName = _MethodName .. " [CLIENT]"
        mission.Log(_MethodName, "Reigstering onPreRenderHud callback.")

        local _Player = Player()
        if _Player:registerCallback("onPreRenderHud", "onMarkWreckages") == 1 then
            mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
        end
    else
        _MethodName = _MethodName .. " [SERVER]"
        mission.Log(_MethodName, "Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkWreckages")
    end
end

function foundCodes()
    local _MethodName = "Found Codes"
    
    if onClient() then
        mission.Log(_MethodName, "Invoking on Client")
        mission.Log(_MethodName, "Unregistering callback and reinvoking on server.")

        local _Player = Player()
        if _Player:unregisterCallback("onPreRenderHud", "onMarkWreckages") == 1 then
            mission.Log(_MethodName, "WARNING - Could not detach prerender callback to script.")
        end

        showMissionUpdated("Destroy Entrenched Pirates")

        invokeServerFunction("foundCodes")
    else
        mission.Log(_MethodName, "Invoking on Server")
    end
    
    mission.data.description[4].fulfilled = true
    mission.data.custom.optionalObjectiveCompleted = true
end
callable(nil, "foundCodes")

--endregion