--[[
    Rank 2 side mission.
    Eradicate Xsotan Infestation
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Rank 2
    ROUGH OUTLINE
        - Jump to the target sector.
        - Start killing Xsotan.
        - An infestor will show up after you've killed 25 of them.
        - Kill that and you're done. That's literally it.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - Maximum # of Xsotan in the sector is 10.
            - Xsotan will be size 1 to 3
            - Infestor size is 3 + max size + min size and has a +60% damage buff. In addition, it is always a summoner.
        6 - [These conditions are present at danger level 6 and above]
            - The first Xsotan in each wave has a 50% chance to be quantum.
        8 - [These conditions are present at danger level 8 and above]
            - Increases the maximum # of Xsotan by 1 (to 11)
            - Increases the maximum size of Xsotan by 1 (size 1 to 4)
        10 - [These conditions are present at danger level 10]
            - You have to kill 30 Xsotan instead of 25.
            - The first Xsotan in each wave is guaranteed to be quantum.
            - The second Xsotan in each wave has a 50% chance to be a summoner. This obviously has no effect if there is only 1 xsotan in a wave.
            - Increases the maximum # of Xsotan by 1 (to 12)
            - Increases the minimum and maximum size of Xsotan by 1 (size 2 to 5)
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
local SectorUpgradeGenerator = include ("upgradegenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local Xsotan = include("story/xsotan")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Eradicate Xsotan Infestation"

--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Eradicate Xsotan Infestation Begin...")

    if onServer() then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local specs = SectorSpecifics()
            local _Rgen = ESCCUtil.getRand()
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local coords = specs.getShuffledCoordinates(random(), x, y, 5, 12)
            local serverSeed = Server().seed
            local target = nil

            --Look for a sector that's not on the blacklist.
            for _, coord in pairs(coords) do
                mission.Log(_MethodName, "Evaluating Coord X: " .. tostring(coord.x) .. " - Y: " .. tostring(coord.y))
                local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)

                if insideBarrier == MissionUT.checkSectorInsideBarrier(coord.x, coord.y) then
                    if not regular and not offgrid and not blocked and not home then
                        if not Galaxy():sectorExists(coord.x, coord.y) then
                            target = coord
                            break
                        end
                    end
                end
            end

            if not target then
                mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
                terminate()
                return
            end

            --Standard mission data.
            mission.data.brief = "Eradicate Xsotan Infestation"
            mission.data.title = "Eradicate Xsotan Infestation"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "You were asked to destroy a nearby area that is infested with Xsotan.",
                { text = "Head to sector (${xLoc}:${yLoc}) and destroy all present Xsotan", arguments = {xLoc = target.x, yLoc = target.y}, bulletPoint = true, fulfilled = false },
                { text = "Destroy the Xsotan Infestor", bulletPoint = true, fulfilled = false, visible = false }
            }

            local _RewardBase = 80000
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .maximumXsotan
                .xsotanKillreq
                .xsotanSizeBonus
                .xsotanKilled
                .infestorSpawned
            =========================================================]]
            mission.data.custom.maximumXsotan = 10
            mission.data.custom.xsotanSizeBonus = { min = 0, max = 2 }
            mission.data.custom.xsotanKilled = 0
            mission.data.custom.xsotanKillreq = 25

            mission.data.custom.dangerLevel = _Rgen:getInt(1, 10)
            if mission.data.custom.dangerLevel >= 8 then
                _RewardBase = _RewardBase + 3000
                mission.data.custom.maximumXsotan = mission.data.custom.maximumXsotan + 1
                mission.data.custom.xsotanSizeBonus.max = mission.data.custom.xsotanSizeBonus.max + 1
            end
            if mission.data.custom.dangerLevel == 10 then
                _RewardBase = _RewardBase + 5500
                mission.data.custom.maximumXsotan = mission.data.custom.maximumXsotan + 1
                mission.data.custom.xsotanSizeBonus.min = mission.data.custom.xsotanSizeBonus.min + 1
                mission.data.custom.xsotanSizeBonus.max = mission.data.custom.xsotanSizeBonus.max + 1
                mission.data.custom.xsotanKillreq = mission.data.custom.xsotanKillreq + 5
            end

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = target, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, "The infestation is located at \\s(%1%:%2%). Please destroy all of the Xsotan.", target.x, target.y)
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
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    local rgen = ESCCUtil.getRand()
    mission.Log(_MethodName, "Generating asteroid fields.")
    local generator = SectorGenerator(x, y)
    for _ = 1, rgen:getInt(2,6) do
        generator:createSmallAsteroidField()
    end

    mission.Log(_MethodName, "Generating Xsotan.")
    --Spawn the maximum number of Xsotan.
    spawnXsotanWave()
    --Start a 1-minute timer up so they come in waves.
    mission.phases[1].timers[1] = { time = 60, callback = function() spawnXsotanWave() end, repeating = true }
end

mission.phases[1].onTargetLocationLeft = function(x, y)
    local _MethodName = "Phase 1 On Target Location Left"
    mission.Log(_MethodName, "Beginning...")
    --Reset.
    mission.data.custom.xsotanKilled = 0
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 1 Update Target Location"

    local _XKR = mission.data.custom.xsotanKillreq
    if mission.data.custom.xsotanKilled >= _XKR and not mission.data.custom.infestorSpawned then
        mission.Log(_MethodName, tostring(_XKR) .. "+ Xsotan killed. Spawning Infestor.")
        spawnXsotanInfestor()        

        mission.data.description[3].visible = true
        showMissionUpdated("Eradicate Xsotan Infestation")

        mission.data.custom.infestorSpawned = true
        sync()
    end
end

mission.phases[1].onEntityDestroyed = function(id, lastDamageInflictor)
    local _MethodName = "Phase 1 On Entity Destroyed"
    local _Sector = Sector()

    local _X, _Y = _Sector:getCoordinates()

    if _X == mission.data.location.x and _Y == mission.data.location.y then
        local entity = Entity(id)
        if valid(entity) and entity:getValue("_llte_infestation_xsotan") then
            mission.data.custom.xsotanKilled = mission.data.custom.xsotanKilled + 1
        end
    
        if entity:getValue("_llte_is_infestor") then
            local rgen = ESCCUtil.getRand()
            local _Xsos = {Sector():getEntitiesByScriptValue("is_xsotan")}
            if _Xsos then
                for _, _Xso in pairs(_Xsos) do
                    _Xso:addScriptOnce("utility/delayeddelete.lua", rgen:getFloat(5, 9))
                end
            end
    
            finishAndReward()
        end
        
        mission.Log(_MethodName, tostring(mission.data.custom.xsotanKilled) .. " Xsotan killed so far.")
    end
end

mission.phases[1].onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        --Abandoned out-of-sector.
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        --boop mission x/y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY)
    end
end

--endregion

--region #SERVER CALLS

function spawnXsotanWave()
    local _MethodName = "Spawn Xsotan"
    
    local _SpawnCount = mission.data.custom.maximumXsotan - ESCCUtil.countEntitiesByValue("_llte_infestation_xsotan")
    local rgen = ESCCUtil.getRand()
    local _Generator = SectorGenerator(Sector():getCoordinates())
    local _Players = {Sector():getPlayers()}
    local _XsotanByNameTable = {}
    local _XsotanTable = {}

    mission.Log(_MethodName, "Spawning " .. tostring(_SpawnCount) .. " Xsotan ships.")
    --Use the same method for spawning a background Xsotan in the swarm event.
    --If danger level is 6+, 50% chance to add a quantum to each wave.
    local _AddSmn = false
    local _AddQuantum = false
    if mission.data.custom.dangerLevel >= 6 and rgen:getInt(1, 2) - 1 == 1 then
        mission.Log(_MethodName, "Adding danger 6 quantum to spawn table")
        _AddQuantum = true
    end
    --If danger level is 10, 100% chance to add a quantum and a 50% chance to add a summoner to each wave.
    if mission.data.custom.dangerLevel == 10 then
        mission.Log(_MethodName, "Adding danger 10 quantum to spawn table")
        _AddQuantum = true
        if rgen:getInt(1, 2) - 1 == 1 then 
            mission.Log(_MethodName, "Adding summoner to spawn table")
            _AddSmn = true 
        end
    end

    --Build our Xsotan name table.
    if _AddQuantum then table.insert(_XsotanByNameTable, "Quantum") end
    if _SpawnCount > 1 and _AddSmn then table.insert(_XsotanByNameTable, "Summoner") end
    if _SpawnCount - #_XsotanByNameTable > 0 then
        for _ = 1, _SpawnCount - #_XsotanByNameTable do
            table.insert(_XsotanByNameTable, "Ship")
        end
    end
    
    mission.Log(_MethodName, "Spawning final count of " .. tostring(#_XsotanByNameTable) .. " Xsotan ships.")
    --Spawn Xsotan based on what's in the nametable.
    for _ = 1, #_XsotanByNameTable do
        local xsoSize = 1.0 + rgen:getInt(mission.data.custom.xsotanSizeBonus.min, mission.data.custom.xsotanSizeBonus.max)
        local _Xsotan = nil
        local _Dist = 1500
        if _XsotanByNameTable[_] == "Summoner" then
            _Xsotan = Xsotan.createSummoner(_Generator:getPositionInSector(_Dist), xsoSize)
        elseif _XsotanByNameTable[_] == "Quantum" then
            _Xsotan = Xsotan.createQuantum(_Generator:getPositionInSector(_Dist), xsoSize)
        else
            _Xsotan = Xsotan.createShip(_Generator:getPositionInSector(_Dist), xsoSize)
        end

        if _Xsotan then
            if valid(_Xsotan) then
                for _, p in pairs(_Players) do
                    ShipAI(_Xsotan.id):registerEnemyFaction(p.index)
                end
                ShipAI(_Xsotan.id):setAggressive()
            end
            _Xsotan:setValue("_llte_infestation_xsotan", true)
            table.insert(_XsotanTable, _Xsotan)
        else
            Lmission.Log(_MethodName, "ERROR - Xsotan was nil")
        end
    end

    SpawnUtility.addEnemyBuffs(_XsotanTable)
end

function spawnXsotanInfestor()
    local _MethodName = "Spawn Xsotan Infestor"
    mission.Log(_MethodName, "Beginning...")

    local _InfestorSize = mission.data.custom.xsotanSizeBonus.min + mission.data.custom.xsotanSizeBonus.max + 3
    local _Players = {Sector():getPlayers()}
    local _X, _Y = Sector():getCoordinates()
    local _Generator = SectorGenerator(_X, _Y)
    --Initialize a bunch of turret generator stuff.
    local _TurretGenerator = SectorTurretGenerator()
    local _TurretRarities = _TurretGenerator:getSectorRarityDistribution(_X, _Y)
    local _UpgradeGenerator = SectorUpgradeGenerator()
    local _UpgradeRarities = _UpgradeGenerator:getSectorRarityDistribution(_X, _Y)

    local _XsotanInfestor = Xsotan.createSummoner(_Generator:getPositionInSector(2500), _InfestorSize)
    if valid(_XsotanInfestor) then
        for _, p in pairs(_Players) do
            ShipAI(_XsotanInfestor.id):registerEnemyFaction(p.index)
        end
        ShipAI(_XsotanInfestor.id):setAggressive()
    end
    _XsotanInfestor:setTitle("${toughness}Xsotan Infestor", {toughness = "", ship = name})
    _XsotanInfestor:setValue("_llte_is_infestor", true)

    --Add extra loot. Guarantee rare+ with less likely rares.
    local _DropCount = 2
    _TurretRarities[-1] = 0 --No petty.
    _TurretRarities[0] = 0 --No common
    _TurretRarities[1] = 0 --No uncommon
    _TurretRarities[2] = _TurretRarities[2] * 0.5 --Cut rare chance in half

    _UpgradeRarities[-1] = 0
    _UpgradeRarities[0] = 0
    _UpgradeRarities[1] = 0
    _UpgradeRarities[2] = _UpgradeRarities[2] * 0.5 --See above.

    mission.Log(_MethodName, "Adding extra turret / system loot to infestor")
    _TurretGenerator.rarities = _TurretRarities
    for _ = 1, _DropCount do
        Loot(_XsotanInfestor):insert(InventoryTurret(_TurretGenerator:generate(_X, _Y)))
    end
    mission.Log(_MethodName, "Adding extra system loot.")
    for _ = 1, _DropCount do
        Loot(_XsotanInfestor):insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, getValueFromDistribution(_UpgradeRarities)))
    end

    if mission.data.custom.dangerLevel == 10 then 
        _TurretRarities[2] = 0
        _UpgradeRarities[2] = 0
        mission.Log(_MethodName, "Adding an extra exceptional+ turret / system to infestor loot")   

        Loot(_XsotanInfestor):insert(InventoryTurret(_TurretGenerator:generate(_X, _Y)))
        Loot(_XsotanInfestor):insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, getValueFromDistribution(_UpgradeRarities)))
    end
    
    local _XostanInfestorTable = {}
    table.insert(_XostanInfestorTable, _XostanInfestor)
    SpawnUtility.addEnemyBuffs(_XostanInfestorTable)

    _XsotanInfestor.damageMultiplier = (_XsotanInfestor.damageMultiplier or 1 ) * 1.6
end

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
        "Thank you for destroying those Xsotan.",
        "We appreciate you taking care of the infestation."
    }

    local _RepReward = 2
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end    

    --Increase reputation by 2 (3 @ 10 danger)
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + _RepReward)
    _Player:sendChatMessage("The Cavaliers", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion