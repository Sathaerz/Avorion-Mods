--Rescue Associate

--Pick threat randomly. Threat is either a local faction that the player is NOT allied with, pirates, or xsotan
--If a non allied faction cannot be found, pick pirates / xsotan at random
--Associate starts at 50% health in a sector w/ two stations (no stations if xsotan)
--Associate repairs 2% hp every 30 seconds
--Player has to defend associate until 60% health
--Associate then jumps. Player has to defend associate from another wave of enemies
--If on difficulty 10, associate jumps a 2nd time and player has to defend them _again_ from a one last wave that includes a lasersniper
    -- use longinus for xsotan laser sniper
    -- deadshot for pirates
    -- marksman for faction
--Waves are 4 ships that target the associate, and 4 ships that target anyone. Similar to escort civilian transports.
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes.
include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Xsotan = include("story/xsotan")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 1
mission._Name = "Rescue Associate"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/family.png"

mission.data.description = { 
    "An associate of ours has... gotten in over their head. However, they have some valuable information that we would like to acquire. Find them and bail them out of whatever trouble they've gotten themselves into.",
    { text = "The Associate's last reported location is: (${cX}:${cY})", bulletPoint = true, fulfilled = false },
    { text = "Defend the Associate while they repair their ship", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defend the Associate until they can jump", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defend the Associate until they can jump again", bulletPoint = true, fulfilled = false, visible = false }
}

local fam_sidemission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Rescue Associate Begin...")

    if onServer()then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local target = {}
            target.x, target.y = MissionUT.getSector(x, y, 5, 12, false, false, false, false, insideBarrier)

            local rgen = ESCCUtil.getRand()

            if not target then
                mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
                terminate()
                return
            end

            local _Name = "The Family" 
            local _Faction = Galaxy():findFaction(_Name)

            local _RewardBase = 50000
            --[[=====================================================
                CUSTOM MISSION DATA:
                .familyIndex
                .isInsideBarrier
                .dangerLevel
                .checkphaseenemies
                .threatType
                .spawnEnemyFunc
                .attackingFaction
                .attackingFactionRelLevel
                .attackingFactionRelStatus
                .checkphaseenemies
                .associd
                .associateSpawned
            =========================================================]]
            mission.data.custom.familyindex = _Faction.index
            mission.data.custom.isInsideBarrier = insideBarrier
            mission.data.custom.dangerLevel = 10 --rgen:getInt(1, 10)
            mission.data.custom.checkphaseenemies = {}
            setThreatType(x, y, rgen)

            mission.data.description[2].arguments = { cX = target.x, cY = target.y }

            --Set rewards.
            if mission.data.custom.dangerLevel >= 6 then
                _RewardBase = _RewardBase + 3000
            end
            if mission.data.custom.dangerLevel == 10 then
                _RewardBase = _RewardBase + 5500
            end

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = target, reward = {credits = missionReward}}
    
            fam_sidemission_init(missionData_in)
            Player():sendChatMessage("The Family", 0, "Thank you. Our associated is in \\s(%1%:%2%).", target.x, target.y)
        else
            --Restoring
            fam_sidemission_init()
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

function setThreatType(x, y, rgen)
    local _MethodName = "Set Threat Type"
    mission.data.custom.threatType = rgen:getInt(1,3) --1 = pirates, 2 = xsotan, 3 = faction
    local _faction_threat = false
    if mission.data.custom.threatType == 3 then
        local _factions = MissionUT.getNearbyFactions(x, y) --leave d at its default value of 125
        shuffle(random(), _factions)

        for _, _faction in pairs(_factions) do
			--If there's one that hates the player, set the attacking faction index to that faction.
			local missionDoer = Player().craftFaction or Player()
			local relations = missionDoer:getRelation(_faction.index)
			--print("considering " .. neighbor.name .. " as candidate for attack. Relations are " .. relations)
			if relations.level <= 0 and relations.status ~= RelationStatus.Allies then --Neutral or lower
				print("attacking faction is " .. _faction.name)

                mission.data.custom.attackingFaction = _faction.index
                mission.data.custom.attackingFactionRelLevel = relations.level
                mission.data.custom.attackingFactionRelStatus = relations.status
                _faction_threat = true
				break
			end
        end

        if not _faction_threat then
            mission.Log(_MethodName, "Could not find a suitable faction. Picking pirates / Xsotan.")
            mission.data.custom.threatType = rgen:getInt(1,2) --pick pirates or xsotan.
        end
    end

    mission.Log(_MethodName, "Set threat type to " .. tostring(mission.data.custom.threatType) .. " - 1 is pirates, 2 is xsotan, 3 is faction.")
end

--endregion

--region #PHASE CALLS

mission.globalPhase = {}
mission.globalPhase.timers = {}
mission.globalPhase.onTargetLocationEntered = function(x, y)
    local _MethodName = "Global Phase On Target Location Entered"
    mission.Log(_MethodName, "Removing fail timer.")

    mission.globalPhase.timers[1] = nil
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    local _MethodName = "Global Phase On Target Location Left"
    mission.Log(_MethodName, "Beginning...")

    setFailTimer()
end

mission.globalPhase.onEntityDestroyed = function(_ID, _LastDamageInflictor)
    if Entity(_ID):getValue("_bau_escort_mission_associate") then
        failMission(false)
    end
end

mission.globalPhase.onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
        if mission.data.custom.associd then
            local _Associate = Entity(mission.data.custom.associd)
            if valid(_Associate) then
                local _WithdrawData = {
                    _Threshold = 0.3,
                    _MinTime = 1,
                    _MaxTime = 1,
                    _Invincibility = 0.02
                }

                _Associate:addScript("ai/withdrawatlowhealth.lua", _WithdrawData)
            end
        end
    else
        --Abandoned out-of-sector.
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        --boop mission x/y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "bausectormonitor.lua", "clearMissionAssets", _MX, _MY, true)
    end

    if mission.data.custom.threatType == 3 then
        --reset the relations and status with the faction. Player loses 1000 rep for this.
        local _Faction = Faction(mission.data.custom.attackingFaction)
        local _Galaxy = Galaxy()
        local _MissionDoer = Player().craftFaction or Player()

        _Galaxy:setFactionRelations(_Faction, _MissionDoer, mission.data.custom.attackingFactionRelLevel - 1000)
        _Galaxy:setFactionRelationStatus(_Faction, _MissionDoer, mission.data.custom.attackingFactionRelStatus)
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].noPlayerEventsTargetSector = true
mission.phases[1].noLocalPlayerEventsTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    --Spawn two stations (unless xsotan or in core)
    spawnStations(x, y)
    --Declare war if threat is a faction.
    if mission.data.custom.threatType == 3 then
        factionDeclareWar()
    end
    --Spawn associate
    spawnAssociate()

    local _ect = 2
    if mission.data.custom.dangerLevel == 10 then
        _ect = 3
    end
    --Spawn enemies
    spawnEnemyWave(_ect, false)
    --Spawn enemies attacking associate
    spawnEnemyWave(_ect, true)
    --update objectives
    mission.Log(_MethodName, "Updating mission objectives")
    mission.data.description[3].visible = true
    --next phase.
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].noPlayerEventsTargetSector = true
mission.phases[2].noLocalPlayerEventsTargetSector = true
mission.phases[2].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 2 Update Target Location"
    --mission.Log(_MethodName, "Starting...")

    local _Sector = Sector()
    local _associateTable = {_Sector:getEntitiesByScriptValue("_bau_escort_mission_associate")}
    local _enemyTable = {_Sector:getEntitiesByScriptValue("_bauside1_wing")}

    local _associate = _associateTable[1] --Should only be 1 entry here.
    if _associate and valid(_associate) then
        if (_associate.durability / _associate.maxDurability >= 0.7) and #_enemyTable == 0 and not mission.phases[2].timers[1] then
            mission.Log(_MethodName, "Associate is sufficiently repaired & no enemies - move to next phase.")
            associateReadyToJump()
            --Start a 2nd, shorter timer, etc.
            mission.phases[2].timers[1] = 
            { 
                time = 5, 
                callback = function() 
                    mission.data.description[3].fulfilled = true
                    prepForPhaseAdvance() 
                end, 
                repeating = false 
            }
        end
    end
end

if onServer() then

--Spawn enemies every 80 seconds.
mission.phases[2].timers[2] = {
    time = 75,
    callback = function()
        local _MethodName = "Phase 2 Timer 2 Callback"
        mission.Log(_MethodName, "Starting...")
        local _ect = 2
        if mission.data.custom.dangerLevel == 10 then
            _ect = 3
        end
        --Spawn enemies
        spawnEnemyWave(_ect, false)
        --Spawn enemies attacking associate
        spawnEnemyWave(_ect, true)
    end,
    repeating = true
}

end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].noPlayerEventsTargetSector = true
mission.phases[3].noLocalPlayerEventsTargetSector = true
mission.phases[3].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 3 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[4].visible = true

    --updateFreighter()
    mission.phases[3].timers[2] = { 
        time = 15, 
        callback = function() 
             spawnEnemyWave(4, false)
             spawnEnemyWave(4, true) 
        end, 
        repeating = false
    }
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 3 Update Target Location"
    --mission.Log(_MethodName, "Starting...")

    local _Sector = Sector()
    local _enemyTable = {_Sector:getEntitiesByScriptValue("_bauside1_wing")}

    if mission.data.custom.checkphaseenemies[3] and #_enemyTable == 0 and not mission.phases[3].timers[1] then
        mission.Log(_MethodName, "Associate is sufficiently repaired & no enemies - move to next phase.")
        associateReadyToJump()
        --Start a 2nd, shorter timer, etc.
        mission.data.description[4].fulfilled = true
        mission.phases[3].timers[1] = { time = 5, callback = function() prepForPhaseAdvance() end, repeating = false }
    end
end

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].noBossEncountersTargetSector = true
mission.phases[4].noPlayerEventsTargetSector = true
mission.phases[4].noLocalPlayerEventsTargetSector = true
mission.phases[4].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 4 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[5].visible = true

    if mission.data.custom.dangerLevel < 10 then
        mission.phases[4].timers[2] = { 
            time = 15, 
            callback = function() 
                associateReadyToDepart()
                finishAndReward()
            end, 
            repeating = false
        }
    else
        --danger 10 - one last wave to overcome.
        mission.phases[4].timers[2] = { 
            time = 15, 
            callback = function() 
                 spawnEnemyWave(4, false)
                 spawnEnemyWave(4, true)
                 spawnEnemyLaserShip()
            end, 
            repeating = false
        }
    end
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 3 Update Target Location"
    --mission.Log(_MethodName, "Starting...")

    local _Sector = Sector()
    local _enemyTable = {_Sector:getEntitiesByScriptValue("_bauside1_wing")}

    if mission.data.custom.checkphaseenemies[4] and #_enemyTable == 0 and not mission.phases[4].timers[1] then
        mission.Log(_MethodName, "No remaining enemies - win.")
        associateReadyToDepart()
        mission.phases[4].timers[1] = { time = 5, callback = function() finishAndReward() end, repeating = false }
    end
end

--endregion

--region #OTHER CALLS

function spawnStations(_X, _Y)
    local _MethodName = "Spawn Stations"
    if mission.data.custom.threatType ~= 2 and not mission.data.custom.isInsideBarrier then
        mission.Log(_MethodName, "Station spawn conditions met")
        --get faction first!
        local _Generator = SectorGenerator(_X, _Y)
        local rgen = ESCCUtil.getRand()
        local _Faction = Galaxy():getPirateFaction(Balancing_GetPirateLevel(_X, _Y))
        if mission.data.custom.threatType == 3 then
            _Faction = Faction(mission.data.custom.attackingFaction)
        end

        --always spawn a shipyard
        local _Stations = {}
        local _Shipyard = _Generator:createShipyard(_Faction)
        table.insert(_Stations, _Shipyard)

        --50% chance to spawn an outpost if threat is less than 10 - spawn one if threat IS 10.
        local _spawnMil = rgen:getInt(1, 2)
        if mission.data.custom.dangerLevel == 10 then
            _spawnMil = 1
        end
        if _spawnMil == 1 then
            local _Milbase = _Generator:createMilitaryBase(_Faction)
            table.insert(_Stations, _Milbase)
        end
        
        --50% chance to spawn a small asteroid field regardless.
        local _spawnAst = rgen:getInt(1, 2)
        if _spawnAst == 1 then
            _Generator:createSmallAsteroidField()
        end

        --Clear scripts, etc. from the stations.
        --These do not remove backup. The player is not meant to attack the station. Have fun getting hammered if you do!
        for _, _Station in pairs(_Stations) do
            _Station:removeScript("consumer.lua")
            if mission.data.custom.threatType == 1 then
                _Station:setValue("is_pirate", true)
            end
            local _StationBay = CargoBay(_Station)
            _StationBay:clear()
            Boarding(_Station).boardable = false
        end
    end
end

function factionDeclareWar()
    local _MethodName = "Faction Declare War"
    mission.Log(_MethodName, "Faction declaring war.")

    local _MissionDoer = Player().craftFaction or Player()
    local _Faction = Faction(mission.data.custom.attackingFaction)

    if mission.data.custom.attackingFactionRelStatus ~= RelationStatus.War then
        mission.Log(_MethodName, "Local faction not already at war with player. Declaring war.")
        local _Galaxy = Galaxy()
        _Galaxy:setFactionRelations(_Faction, _MissionDoer, -100000)
        _Galaxy:setFactionRelationStatus(_Faction, _MissionDoer, RelationStatus.War)
    end
end

function spawnAssociate()
    local _MethodName = "Spawn Associate"
    mission.Log(_MethodName, "Spawning Family Associate...")
    --Spawn a cavalier freighter. 
    local shipGenerator = AsyncShipGenerator(nil, onAssociateFinished)
    --This guy is a bit tougher than normal - most of the heavy lifting is done by a durability multipler in onFinished.
    local x, y = Sector():getCoordinates()
    local assocVolume = Balancing_GetSectorShipVolume(x, y) * 4
    local faction = Faction(mission.data.custom.familyindex)

    local look = vec3(1, 0, 0)
    local up = vec3(0, 1, 0)

    shipGenerator:startBatch()
    shipGenerator:createMilitaryShip(faction, MatrixLookUpPosition(look, up, vec3(0, -50, 0)), assocVolume)
    shipGenerator:endBatch()

    mission.data.custom.associateSpawned = true
end

function spawnEnemyWave(_xct, _betaWing)
    --Tried to do a mission.data.custom but it won't save functions becasue it hates me and wants me to do this.
    local _funcs = {
        spawnPirateWave,
        spawnXsotanWave,
        spawnFactionWave
    }

    _funcs[mission.data.custom.threatType](_xct, _betaWing)
end

function spawnEnemyLaserShip()
    --See above
    local _funcs = {
        spawnPirateLaserSniper,
        spawnBAUXsotanLonginus,
        spawnFactionLaserSniper
    }

    _funcs[mission.data.custom.threatType]()
end

function spawnPirateWave(_xct, _betaWing)
    local _MethodName = "Spawn Pirate Wave"
    mission.Log(_MethodName, "Spawning pirate wave")

    local _Sector = Sector()
    local _ScriptValue = "_bauside1_alpha_wing"
    if _betaWing then
        _ScriptValue = "_bauside1_beta_wing"
    end
    local _Pirates = {_Sector:getEntitiesByScriptValue(_ScriptValue)}
    local _ct = _xct - #_Pirates

    if _ct > 0 then
        local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _ct, "Standard", false)

        local generator = AsyncPirateGenerator(nil, onAlphaWingEnemiesFinished)
        if _betaWing then
            generator = AsyncPirateGenerator(nil, onBetaWingEnemiesFinished)
        end
    
        generator:startBatch()
    
        local posCounter = 1
        local distance = 250 --_#DistAdj
        local pirate_positions = generator:getStandardPositions(#waveTable, distance)
        for _, p in pairs(waveTable) do
            generator:createScaledPirateByName(p, pirate_positions[posCounter])
            posCounter = posCounter + 1
        end
    
        generator:endBatch()
    end
end

function spawnXsotanWave(_xct, _betaWing)
    local _MethodName = "Spawn Xsotan Wave"
    mission.Log(_MethodName, "Spawning xsotan wave")

    local _Sector = Sector()
    local _ScriptValue = "_bauside1_alpha_wing"
    if _betaWing then
        _ScriptValue = "_bauside1_beta_wing"
    end
    local _Xsotan = {_Sector:getEntitiesByScriptValue(_ScriptValue)}
    local _ct = _xct - #_Xsotan

    if _ct > 0 then
        local _Players = {Sector():getPlayers()}
        local _XsotanTable = {}
        local _Generator = AsyncShipGenerator(nil, nil)

        local _PosCounter = 1
        local _Distance = 250 --_#DistAdj

        local _Positions = _Generator:getStandardPositions(_Distance, _ct)

        for _ = 1, _ct do
            local _Xsotan = Xsotan.createShip(_Positions[_PosCounter], 1.0)
            _PosCounter = _PosCounter + 1
    
            if _Xsotan and valid(_Xsotan) then
                for _, p in pairs(_Players) do
                    mission.Log(_MethodName, "Registering player INDEX : " .. tostring(p.index) .. " NAME : " .. tostring(p.name) .. " as enemy.")
                    ShipAI(_Xsotan.id):registerEnemyFaction(p.index)
                end
                ShipAI(_Xsotan.id):setAggressive()
                table.insert(_XsotanTable, _Xsotan)
            end
        end

        if _betaWing then
            onBetaWingEnemiesFinished(_XsotanTable)
        else
            onAlphaWingEnemiesFinished(_XsotanTable)
        end
    end
end

function spawnFactionWave(_xct, _betaWing)
    local _MethodName = "Spawn Faction Wave"
    mission.Log(_MethodName, "Spawning faction wave")

    local _Sector = Sector()
    local _ScriptValue = "_bauside1_alpha_wing"
    if _betaWing then
        _ScriptValue = "_bauside1_beta_wing"
    end
    local _Enemies = {_Sector:getEntitiesByScriptValue(_ScriptValue)}
    local _ct = _xct - #_Enemies

    if _ct > 0 then
        local _Faction = Faction(mission.data.custom.attackingFaction)
        local generator = AsyncShipGenerator(nil, onAlphaWingEnemiesFinished)
        if _betaWing then
            generator = AsyncShipGenerator(nil, onBetaWingEnemiesFinished)
        end
    
        generator:startBatch()
    
        local posCounter = 1
        local _Distance = 250 --_#DistAdj
        local enemy_positions = generator:getStandardPositions(_Distance, _ct)
        for _ = 1, _ct do
            generator:createMilitaryShip(_Faction, enemy_positions[posCounter])
            posCounter = posCounter + 1
        end
    
        generator:endBatch()
    end
end

function spawnPirateLaserSniper()
    local _MethodName = "Spawn Pirate Laser Sniper"
    mission.Log(_MethodName, "Spawning...")

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 1, "High", false)

    local generator = AsyncPirateGenerator(nil, onLaserSniperFinished)
    generator:startBatch()

    local distance = 250 --_#DistAdj
    local pirate_positions = generator:getStandardPositions(1, distance)
    generator:createScaledPirateByName(waveTable[1], pirate_positions[1])

    generator:endBatch()
end

function spawnBAUXsotanLonginus()
    local _MethodName = "Spawn Xsotan Longinus" --Likely the palyer's first encounter with a Longinus.
    mission.Log(_MethodName, "Spawning...")

    local _Players = {Sector():getPlayers()}
    local _XsotanTable = {}
    local _Generator = AsyncShipGenerator(nil, nil)

    local _Distance = 250 --_#DistAdj

    local _Positions = _Generator:getStandardPositions(_Distance, 1)
    local _Xsotan = Xsotan.createLonginus(_Positions[1], 1.0)

    if _Xsotan and valid(_Xsotan) then
        for _, p in pairs(_Players) do
            ShipAI(_Xsotan.id):registerEnemyFaction(p.index)
        end
        ShipAI(_Xsotan.id):setAggressive()
        table.insert(_XsotanTable, _Xsotan)
    end

    onLaserSniperFinished(_XsotanTable)
end

function spawnFactionLaserSniper()
    local _MethodName = "Spawn Faction Laser Sniper"
    mission.Log(_MethodName, "Spawning...")

    local _Faction = Faction(mission.data.custom.attackingFaction)
    local generator = AsyncShipGenerator(nil, onLaserSniperFinished)

    generator:startBatch()

    local _Distance = 250 --_#DistAdj
    local enemy_positions = generator:getStandardPositions(_Distance, 1)
    generator:createMilitaryShip(_Faction, enemy_positions[1])

    generator:endBatch()
end

function onAlphaWingEnemiesFinished(generated)
    local _MethodName = "On Alpha Wing Enemies Finished"
    mission.Log(_MethodName, "Beginning...")

    onEnemiesFinished(generated)

    for _, _enemy in pairs(generated) do
        _enemy:setValue("_bauside1_alpha_wing", true)
    end
end

function onBetaWingEnemiesFinished(generated)
    local _MethodName = "On Beta Wing Enemies Finished"
    mission.Log(_MethodName, "Beginning...")

    onEnemiesFinished(generated)

    for _, _enemy in pairs(generated) do
        _enemy:setValue("_bauside1_beta_wing", true)
        _enemy:addScript("ai/priorityattacker.lua", {_TargetTag = "_bau_escort_mission_associate"}) 
    end

    local phaseidx = mission.internals.phaseIndex
    mission.data.custom.checkphaseenemies[phaseidx] = true
end

function onEnemiesFinished(generated)
    local _MethodName = "On Enemies Finished"
    mission.Log(_MethodName, "Beginning...")

    SpawnUtility.addEnemyBuffs(generated)

    for _, _enemy in pairs(generated) do
        _enemy:setValue("_bauside1_wing", true)
        _enemy:setValue("_ESCC_bypass_hazard", true)
        if mission.data.custom.threatType == 3 then
            --Corpos / Xsotans need to register family faction as an enemy.
            mission.Log(_MethodName, "Registering family as enemy faction.")
            local _Name = "The Family" 
            local _FamFaction = Galaxy():findFaction(_Name)

            local _EnemyAI = ShipAI(_enemy)
            _EnemyAI:registerEnemyFaction(_FamFaction.index)
            _EnemyAI:setAggressive()
        end
    end

    local phaseidx = mission.internals.phaseIndex
    mission.data.custom.checkphaseenemies[phaseidx] = true
end

function onLaserSniperFinished(generated)
    local _MethodName = "On Laser Sniper Finished"
    mission.Log(_MethodName, "Beginning...")

    onEnemiesFinished(generated)

    local _LaserShip = generated[1]

    local _X, _Y = Sector():getCoordinates()
    local _dpf = Balancing_GetSectorWeaponDPS(_X, _Y)

    mission.Log(_MethodName,"Setting dpf to " .. tostring(_dpf))

    if mission.data.custom.threatType ~= 2 then
        --Laser sniper
        local _LaserSniperValues = {
            _DamagePerFrame = _dpf,
            _UseEntityDamageMult = true,
            _TargetPriority = 3,
            _TargetTag = "_bau_escort_mission_associate"
        }
        _LaserShip:addScriptOnce("lasersniper.lua", _LaserSniperValues)

        if mission.data.custom.threatType == 1 then
            local _TitleArgs = _LaserShip:getTitleArguments()
            _LaserShip:setTitle("${toughness}${lasername}${title}", {toughness = _TitleArgs.toughness, title = _TitleArgs.title, lasername = "Deadshot "})
        else
            _LaserShip.title = "Marksman " .. _LaserShip.title
        end
    else
        mission.Log(_MethodName, "Adjusting longinus")
        _LaserShip:invokeFunction("lasersniper.lua", "adjustDamage", _dpf)
        _LaserShip:invokeFunction("lasersniper.lua", "adjustTargetPrio", 3, "_bau_escort_mission_associate")
    end
    
    --Add miniboss script

    associateOhNoLaser()
end

function onAssociateFinished(generated)
    local _MethodName = "On Associate Spawned Callback"

    --There should only ever be 1 ship in this batch.
    mission.Log(_MethodName, "Setting Family Values (lawl)")
    local associate = generated[1]
    associate.title = "Family Associate"
    associate:setValue("_bau_escort_mission_associate", true)
    associate:setValue("is_family", true)

    --Unfortunately, you don't get to keep this. It will turn itself off on phase 3.
    associate:addScript("eternal.lua")

    local _assocAI = ShipAI(associate)
    _assocAI:setGuard(associate.translationf)
    _assocAI:setPassiveShooting(true)

    local _Dura = Durability(associate)
    local _DuraFactor = 8

    if mission.data.custom.dangerLevel == 10 then
        _DuraFactor = _DuraFactor * 2 --Difficulty 10 is a nightmare of powerful ships.
    end

    if _Dura then
        _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 1) * _DuraFactor
    end

    if associate.shieldDurability then
        local _damage = associate.shieldMaxDurability * 0.75
        associate:damageShield(_damage, associate.translationf, associate.index)
    end

    local _hulldamage = (associate.maxDurability or 0) * 0.6
    associate:inflictDamage(_hulldamage, 0, 0, 0, vec3(), associate.index)

    mission.data.custom.associd = associate.id
end

function associateReadyToJump()
    local _MethodName = "Associate Ready To Jump"
    mission.Log(_MethodName, "Beginning...")

    if not mission.data.custom.associd then
        mission.Log(_MethodName, "ERROR - associate id was not found. This function will error shortly.")
    end

    local lines = {
        "... Hyperspace is back online! We're getting out of here!",
        "Interference cleared! Getting ready to jump!",
        "Jump drives charged and warming up! Go! Go! Go!",
        "Drives are back on line! We'll be leaving as soon as we can!",
        "Thanks for the assist! We're getting out now!",
        "Jump drive ready! Calculating our escape route!",
        "We're leaving now! Go go go!",
        "That did it! We're getting out of here!"
    }

    local _assoc = Entity(mission.data.custom.associd)
    Sector():broadcastChatMessage(_assoc, ChatMessageType.Chatter, randomEntry(lines))
end

function associateReadyToDepart()
    local _MethodName = "Associate Ready To Depart"
    mission.Log(_MethodName, "Beginning...")

    if not mission.data.custom.associd then
        mission.Log(_MethodName, "ERROR - associate id was not found. This function will error shortly.")
    end

    local lines = {
        "We should be safe from here. Thanks for your help."
    }

    local _assoc = Entity(mission.data.custom.associd)
    Sector():broadcastChatMessage(_assoc, ChatMessageType.Chatter, randomEntry(lines))
end

function associateOhNoLaser()
    local _MethodName = "Associate Oh No Laser!"
    mission.Log(_MethodName, "Beginning...")

    local _ThreatTypes = { "Deadshot", "Longinus", "Marksman" }
    local _ThreatName = _ThreatTypes[mission.data.custom.threatType]

    local lines = {
        "Is that a " .. _ThreatName .. "?? Its laser will tear us to pieces!",
        "A " .. _ThreatName .. "?! Destroy it quickly!",
        "No! A " .. _ThreatName .. "! Kill it before it kills us!",
        "No! NO! Not a " .. _ThreatName .. "! We won't survive its laser weapon!",
        "A " .. _ThreatName .. "? Kill it! Kill it now!"
    }

    local _assoc = Entity(mission.data.custom.associd)
    Sector():broadcastChatMessage(_assoc, ChatMessageType.Chatter, randomEntry(lines))
end

function prepForPhaseAdvance()
    local _MethodName = "Prep for Phase Advance"
    mission.Log(_MethodName, "Preparing for jumping and advancing the mission phase...")
    --Get the next location to jump to.
    local specs = SectorSpecifics()
    local _Rgen = ESCCUtil.getRand()
    local x, y = Sector():getCoordinates()
    local _OtherLocations = MissionUT.getMissionLocations() or {}
    local coords = specs.getShuffledCoordinates(_Rgen, x, y, 10, 18)
    local serverSeed = Server().seed
    local target = nil
    local _LastError = nil

    --Look for a new sector. All of this effort just to get a jumpable-to empty sector.
    for _, coord in pairs(coords) do
        mission.Log(_MethodName, "Evaluating Coord X: " .. tostring(coord.x) .. " - Y: " .. tostring(coord.y))
        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)
        if mission.data.custom.isInsideBarrier == MissionUT.checkSectorInsideBarrier(coord.x, coord.y) and not _OtherLocations:contains(coord.y, coord.y) then
            local _PotentialTarget = false
            if not regular and not offgrid and not blocked and not home then
                _PotentialTarget = true
            end

            if _PotentialTarget then
                --We have a potential target. Check to see if the jump route is okay.
                mission.Log(_MethodName, "Setting Hyperspace range to 25") --Not sure why we can't just do it once at the start of the script but w/e
                local _HyperspaceEngine = HyperspaceEngine(mission.data.custom.associd)
                _HyperspaceEngine.range = 25.0

                local _Assoc = Entity(mission.data.custom.associd)
                local _JumpValid, _Error = _Assoc:isJumpRouteValid(x, y, coord.x, coord.y)
                _Assoc:removeScript("eternal.lua") --we lose eternal here.

                if _JumpValid then
                    if not Galaxy():sectorExists(coord.x, coord.y) then
                        target = coord
                        break
                    end
                else
                    mission.Log(_MethodName, "Jump route to (" .. tostring(coord.x) .. ":" .. tostring(coord.y) .. ") is not valid because of " .. tostring(_Error) .. "Moving to next sector.")
                    _LastError = _Error
                end
            end
        end
    end

    --Once we're here, we MUST be able to continue. Enact a failsafe if we can't find a valid jump route via the above code.
    if not target then
        mission.Log(_MethodName, "[ERROR] Could not find a suitable jump route. Enacting failsafe. Last error was : " .. tostring(_LastError))
        target = {}
        target.x, target.y = MissionUT.getSector(x, y, 6, 12, false, false, false, false, mission.data.custom.isInsideBarrier)
    end

    mission.data.custom.nextlocation = target

    mission.Log(_MethodName, "Invoking client function to open dialog.")
    invokeClientFunction(Player(), "onJumpingDialog", mission.data.custom.associd, tostring(target.x), tostring(target.y))
end

function jumpAndAdvancePhase() 
    local _MethodName = "Jump And Advance Phase"
    mission.Log(_MethodName, "Getting data to advance phase.")

    --Prep for jump
    local target = mission.data.custom.nextlocation

    mission.data.custom.nextlocation = nil
    mission.data.custom.jumpindex = nil

    mission.data.location = target

    --Set a deletion timer, then, finally, we jump.
    local _Associate = Entity(mission.data.custom.associd)
    _Associate:setValue("_escc_deletion_timestamp", Server().unpausedRuntime + 245)
    Sector():transferEntity(_Associate, target.x, target.y, SectorChangeType.Jump)
    --Delete everything we leave behind.
    local _EntityTypes = ESCCUtil.allEntityTypes()
    Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    --Send message to player.
    Player():sendChatMessage("Nav Computer", 0, "The associate has jumped to \\s(%1%,%2%).", target.x, target.y)
    --Advance phase. We fail if we don't jump after the freighter quickly enough.
    setFailTimer()
    --NextPhase automatically syncs, so no need to call sync() separately.
    mission.data.description[2].arguments = { cX = mission.data.location.x, cY = mission.data.location.y }
    nextPhase()
end
callable(nil, "jumpAndAdvancePhase")

function setFailTimer() 
    local _MethodName = "Set Failure Timer"
    mission.Log(_MethodName, "Setting failure timer")
    --4 minutes may be too generous, but people may be doing this mission with a massive ship with a huge hyperspace cooldown.
    mission.globalPhase.timers[1] = { time = 240, callback = function() failMission() end, repeating = false }
end

function failMission() 
    local _MethodName = "Mission Failed"
    mission.Log(_MethodName, "Beginning...")

    local player = Player()
    player:sendChatMessage("The Family", 0, "Contact with our associate has been lost. Moretti will be displeased to hear this...")
    fail()
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _assoc = Entity(mission.data.custom.associd)
    --Associate should be here :D
    if valid(_assoc) then
        local rgen = ESCCUtil.getRand()
        _assoc:addScript("utility/delayeddelete.lua", rgen:getFloat(4, 5))
    end

    local _Player = Player()
    local _Rank = _Player:getValue("_bau_family_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "Moretti will be pleased to hear of this.",
        "Thank you for rescuing our associate."
    }

    local _RepReward = 1
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end

    --Increase reputation by 1 (2 @ 10 danger)
    mission.data.reward.paymentMessage = "Earned %1% credits for rescuing the associate."
    _Player:setValue("_bau_family_rep", (_Player:getValue("_bau_family_rep") or 0) + _RepReward)
    _Player:sendChatMessage("The Family", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT ONLY CALLS

function onJumpingDialog(id, xloc, yloc)
    local _MethodName = "On Jumping Dialog"
    mission.Log(_MethodName, "Beginning...")

    local dialog0 = {}
    dialog0.text = string.format("We'll be heading to (%s:%s) next. Please meet us there!", xloc, yloc)
    dialog0.answers = { { answer = "Acknowledged.", onSelect = "onJumpAcknowledged" } }
    
    ScriptUI(id):interactShowDialog(dialog0, false)
end

function onJumpAcknowledged()
    local _MethodName = "On Jump Acknowledged"
    mission.Log(_MethodName, "Invoking...")

    invokeServerFunction("jumpAndAdvancePhase")
end

--endregion