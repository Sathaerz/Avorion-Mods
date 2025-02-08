--[[
    Destroy Pirate Stronghold
    NOTES:
        - Generic version of Side Mission 5 from LLTE
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")

local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include("pirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")
local Placer = include ("placer")
local UpgradeGenerator = include ("upgradegenerator")

mission._Debug = 0
mission._Name = "Destroy Pirate Stronghold"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Destroy the outpost in sector (${x}:${y})", bulletPoint = true, fulfilled = false },
    { text = "(Optional) A group of defenders is gathering in sector (${xO}:${yO}). Destroy them", bulletPoint = true, fulfilled = false },
    { text = "Search the wreckages for anything interesting", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "..."

--Some other custom data that has to be initialized here, since we need it on both client / server - or else we get weird errors elsewhere in the script.
mission.data.custom.locations = {}
mission.data.custom.wreckagePieceIds = {}
mission.data.custom.wreckageScriptPath = "player/missions/destroystronghold/searchwreckage.lua"

local DestroyStronghold_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y
            local _Xo, _Yo = _Data_in.optLocation.x, _Data_in.optLocation.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)
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
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.locations = {}
            table.insert(mission.data.custom.locations, _Data_in.location)
            table.insert(mission.data.custom.locations, _Data_in.optLocation)
            mission.data.custom.optlocation = _Data_in.optLocation
            mission.data.custom.optionalObjectiveCompleted = false
            mission.data.custom.optionalObjectiveInvoked = false
            mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_Data_in.location.x, _Data_in.location.y)
            mission.data.custom.maxDefenders = 4
            mission.data.custom.defenderRespawnTime = 150
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
            end
            if mission.data.custom.dangerLevel >= 8 then
                mission.data.custom.freighterSupplyTransfer = 75
                mission.data.custom.freighterScale = mission.data.custom.freighterScale + 2
                mission.data.custom.forcedDefenderScale = 5
            end
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.maxDefenders = mission.data.custom.maxDefenders + 1
                mission.data.custom.defenderRespawnTime = mission.data.custom.defenderRespawnTime - 30
                mission.data.custom.freighterSupply = mission.data.custom.freighterSupply + 500
                mission.data.custom.freighterSupplyTransfer = 150
                mission.data.custom.freighterScale = mission.data.custom.freighterScale + 2
                mission.data.custom.forcedDefenderScale = 10
            end
            PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { x = _X, y = _Y }
            mission.data.description[3].arguments = { x = _X, y = _Y }
            mission.data.description[4].arguments = { xO = _Xo, yO = _Yo }

            mission.data.accomplishMessage = _Data_in.winMsg

            --Run standard initialization
            DestroyStronghold_init(_Data_in)
        else
            --Restoring
            DestroyStronghold_init()
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

mission.globalPhase.onAbandon = function()
    if mission.data.location then
        dumpMilitaryStationCargo()
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    --There's no real 'fail' condition but we'll keep this one anyways just in case.
    if mission.data.location then
        dumpMilitaryStationCargo()
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(false)
    end
end

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
    local _SetOptionalObjectiveInvoked = false
    --ADD DEFENDER CONTROLLER + SHIPMENT CONTROLLER SCRIPT
    if not _Sector:hasScript("sector/background/defensecontroller.lua") then
        --Defense Controller Data
        local _defCycleTime = mission.data.custom.defenderRespawnTime
        if mission.data.custom.optionalObjectiveCompleted then
            mission.Log(_MethodName, "Optional objective completed on enter - incrementing defender cycle time.")
            _defCycleTime = _defCycleTime + 15
            _SetOptionalObjectiveInvoked = true
        end

        local _DCD = {}
        _DCD._DefenseLeader = mission.data.custom.militaryStationid
        _DCD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _DCD._DefenderCycleTime = _defCycleTime
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
        if mission.data.custom.optionalObjectiveCompleted and not mission.data.custom.optionalObjectiveInvoked then
            mission.Log(_MethodName, "optional objective invoked - setting sector's defense controller script to have codes cracked & incrementing cycle")
            _Sector:invokeFunction("sector/background/defensecontroller.lua", "setCodesCracked", true)
            _Sector:invokeFunction("sector/background/defensecontroller.lua", "incrementCycleTime", 15)
            _SetOptionalObjectiveInvoked = true
        end
    end

    if not _Sector:hasScript("sector/background/shipmentcontroller.lua") then
        --Shipment Controller Data
        local _shipCycleTime = mission.data.custom.freighterRespawnTime
        if mission.data.custom.optionalObjectiveCompleted then
            mission.Log(_MethodName, "Optional objective completed on enter - incrementing shipment cycle time.")
            _shipCycleTime = _shipCycleTime + 15
            _SetOptionalObjectiveInvoked = true
        end

        local _SCD = {}
        _SCD._ShipmentLeader = mission.data.custom.militaryStationid
        _SCD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _SCD._ShipmentCycleTime = _shipCycleTime
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
        if mission.data.custom.optionalObjectiveCompleted and not mission.data.custom.optionalObjectiveInvoked then
            mission.Log(_MethodName, "optional objective invoked - setting sector's shipment controller script to have codes cracked & incrementing cycle")
            _Sector:invokeFunction("sector/background/shipmentcontroller.lua", "setCodesCracked", true)
            _Sector:invokeFunction("sector/background/shipmentcontroller.lua", "incrementCycleTime", 15)
            _SetOptionalObjectiveInvoked = true
        end
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
        if mission.data.custom.optionalObjectiveCompleted and not mission.data.custom.optionalObjectiveInvoked then
            mission.Log(_MethodName, "optional objective invoked - setting military station's script to have codes cracked")
            _MilitaryStation:invokeFunction("entity/stationsiegegun.lua", "setCodesCracked", true)
            _SetOptionalObjectiveInvoked = true
        end
    end

    if _SetOptionalObjectiveInvoked then
        mission.data.custom.optionalObjectiveInvoked = true
    end
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 1 Update Target Location"

    if ESCCUtil.countEntitiesByValue("_destroystronghold_mainobjective") == 0 and mission.data.custom.builtMainSector then
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

            Sector():broadcastChatMessage(_Pirates[1], ChatMessageType.Chatter, getRandomEntry(_Lines))
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
        mission.Log(_MethodName, "Wreckages found : " .. tostring(#_Wreckages))
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
        shuffle(random(), _Wreckages)
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
            _Wreck:addScriptOnce(mission.data.custom.wreckageScriptPath)
            _Wreck:setValue("_destroystronghold_optionalwreck_targetplayer", Player().index)
        end
        local _TargetWreck = Entity(mission.data.custom.wreckagePieceIds[_Rgen:getInt(1, #mission.data.custom.wreckagePieceIds)])
        _TargetWreck:setValue("_destroystronghold_optionalwreck_hascode", true)

        registerMarkWreckages()
        showMissionUpdated(mission._Name)
        mission.data.description[4].fulfilled = true
        mission.data.description[5].visible = true

        sync()
        mission.data.custom.optionalPiratesAllDestroyed = true
    end
end

--endregion

--region #SERVER CALLS

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
        _Station:setValue("_destroystronghold_mainobjective", true)
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
        _Station:removeScript("bulletinboard.lua")
        _Station:removeScript("missionbulletins.lua")
        _Station:removeScript("story/bulletins.lua")
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
            _Station:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
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

        --finally, (maybe) add a military tcs to the station's loot table.
        if _Rgen:test(0.25) then
            local _upgradeGenerator = UpgradeGenerator()
            local _upgradeRarities = getSectorRarityTables(_X, _Y, _upgradeGenerator)
            local _seedInt = _Rgen:getInt(1, 20000)
            Loot(_Station):insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(getValueFromDistribution(_upgradeRarities)), Seed(_seedInt)))
        end

        mission.data.custom.militaryStationid = _Station.id

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

        Placer.resolveIntersections()

        Sector():addScriptOnce("sector/background/campaignsectormonitor.lua")

        showMissionUpdated(mission._Name)

        mission.data.custom.builtMainSector = true
    end
end

function dumpMilitaryStationCargo()
    if atTargetLocation() then
       --Abandoned in-sector.
        --Dump all of the cargo in the military base in case the player tries to kill it after abandoning to make things easier.
        --Joke's on them, though. The defense controller won't go away when this is deleted :D
        local _Station = Entity(mission.data.custom.militaryStationid)

        if _Station and valid(_Station) then
            local _StationBay = CargoBay(_Station)
            _StationBay:clear()
        end
    end
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

    reward()
    accomplish()
end

--endregion

--region #CLIENT / SERVER CALLS

local DestroyStronghold_getLoc = getMissionLocation
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

        showMissionUpdated(mission._Name)

        invokeServerFunction("foundCodes")
    else
        mission.Log(_MethodName, "Invoking on Server")
    end
    
    mission.data.description[5].fulfilled = true
    mission.data.custom.optionalObjectiveCompleted = true
end
callable(nil, "foundCodes")

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
        
        if entity:hasScript(mission.data.custom.wreckageScriptPath) then
            local _ContainerMarkOrange = ESCCUtil.getSaneColor(255, 173, 0)

            renderer:renderEntityTargeter(entity, _ContainerMarkOrange)
            renderer:renderEntityArrow(entity, 30, 10, 250, _ContainerMarkOrange)
        end
    end

    renderer:display()
end

--endregion

--region #MAKEBULLETIN CALL

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

function formatDescription(_Station, _DangerLevel)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _DescLine1Options = { 
        "There's a pirate base that's been hindering our nearby operations. We'd like you to destroy it. Our intel says that they're dug in pretty well, but we'll pay you just as well for your efforts.",
        "Some pirate scum have decided to construct a fortress in our jurisdiction! We could wipe them out easily, but our forces are busy conquering a nearby upstart and we simply cannot be bothered. So we're turning to independent captains for help.",
        "We've recently received intelligence that some pirates have set up a stronghold in our territory. Our self-defense forces are just for that - self defense. We cannot spare the forces to go on the offense against them. That's where you come in."
    }
    local _DescLine2Options = { 
        "\n\nSeveral of our previous attempts to take them out have ended in failure. Proceed with caution.",
        "\n\nThese are a cut above normal pirates. Expect to commit more forces to the operation.",
        "\n\nThe pirates are especially strong. Make sure you attack with enough ships to deal with them."
    }
    local _DescLine3Options = { 
        "\n\nYou'll find the base at (${x}:${y}).",
        "\n\nYou'll find the base at (${x}:${y}). Leave no survivors.",
        "\n\nYou'll find the base at (${x}:${y}). Please deal with it."
    }

    local _DescLine1 = _DescLine1Options[_DescriptionType]
    local _DescLine2 = ""
    if _DangerLevel >= 7 then
        _DescLine2 = _DescLine2Options[_DescriptionType]
    end
    local _DescLine3 = _DescLine3Options[_DescriptionType]

    local _FinalDescription = _DescLine1 .. _DescLine2 .. _DescLine3

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _sector = Sector()
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local optTarget = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 5, 17, false, false, false, false, insideBarrier)
    local optTargetOK = false
    local breakout = 0 --safety breakout so we don't get locked in a while loop forever
    while not optTargetOK do
        optTarget.x, optTarget.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, insideBarrier)
        if optTarget.x ~= target.x or optTarget.y ~= target.y or breakout > 100 then
            optTargetOK = true
        end
        breakout = breakout + 1
    end

    if not target.x or not target.y or not optTarget.x or not optTarget.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)

    local _Difficulty = "Difficult"
    if _DangerLevel >=  7 then
        _Difficulty = "Extreme"
    end
    
    local _Description = formatDescription(_Station, _DangerLevel)
    local _WinMsg = formatWinMessage(_Station)

    local _BaseReward = 170000
    if _DangerLevel >= 6 then
        _BaseReward = _BaseReward + 6000
    end
    if _DangerLevel >= 8 then
        _BaseReward = _BaseReward + 9000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 12000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates()) --SET REWARD HERE
    reputation = 6000
    if _DangerLevel == 10 then
       reputation = reputation + 2000 
    end

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/destroystronghold.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you. The pirate outpost is located at \\s(%1%:%2%).",
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
            optLocation = optTarget,
            reward = {credits = reward, relations = reputation, paymentMessage = "Earned %1% for destroying the stronghold."},
            punishment = {relations = 8000 },
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            winMsg = _WinMsg
        }},
    }

    return bulletin
end

--endregion