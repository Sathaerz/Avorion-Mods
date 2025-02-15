--[[
    THE ANNIHILATORIUM
    NOTES:
        - Based on an old request for an 'arena' sector. I don't really like the idea of messing with sector templates, but this is good :D
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - N/A
    ROUGH OUTLINE
        - Go to arena. Fight dangerous waves of pirates.
    DANGER LEVEL
        1+ - You fight 5x waves per danger level. Waves are increasingly difficult. Final wave always has a miniboss.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Balancing = include ("galaxy")
local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Spawn_Boss_Debug = 0

mission._Name = "The Annihilatorium"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/crossed-rifles.png"
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Come on down to (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Defeat ${_OVERALLWAVES} waves", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Waves Defeated: ${_SURVIVEDWAVES} / ${_OVERALLWAVES}", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Speak with the Annihilatorium when ready to proceed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Master Of The Arena mode is engaged", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Never seen a show like that in my life! Here's your money!"

mission.data.custom.stationScriptPath = "player/missions/annihilatorium/annihilatoriumstation.lua"
mission.data.custom.bossScriptPath = "player/missions/annihilatorium/annihilatoriumboss.lua"
mission.data.custom.mainSoundtrack = "data/music/background/omftitle.ogg"
mission.data.custom.waveTracks = {
    "data/music/background/omfdangerroom.ogg",
    "data/music/background/omfdesert.ogg",
    "data/music/background/omffirepit.ogg",
    "data/music/background/omfpowerplant.ogg",
    "data/music/background/omfstadium.ogg"
}
mission.data.custom.bossTrack = "data/music/special/lasselyxminiboss.ogg"
mission.data.custom.motaBossTrack = "data/music/special/acmoaapexincircle.ogg"

local Annihilatorium_init = initialize
function initialize(_Data_in, bulletin)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

        local _X, _Y = _Data_in.location.x, _Data_in.location.y

        local _Sector = Sector()
        local _Giver = Entity(_Data_in.giver)

        --[[=====================================================
            CUSTOM MISSION DATA SETUP:
        =========================================================]]
        mission.data.custom.dangerLevel = _Data_in.dangerLevel
        mission.data.custom.overallWaves = _Data_in.dangerLevel * 5
        mission.data.custom.survivedWaves = 0
        mission.data.custom.checkForWaveVanquish = false
        mission.data.custom.spawnedBossThisWave = false
        mission.data.custom.spawnedBossTitle = nil
        mission.data.custom.bossBountyFactor = 1
        mission.data.custom.masterOfTheArena = false --Master of the Arena mode - makes the mission much more difficult but the payout is more.
        mission.data.custom.motaTimer = 0

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { _X = _X, _Y = _Y }
        mission.data.description[3].arguments = { _X = _X, _Y = _Y }
        mission.data.description[4].arguments = { _OVERALLWAVES = mission.data.custom.overallWaves }
        mission.data.description[5].arguments = { _OVERALLWAVES = mission.data.custom.overallWaves, _SURVIVEDWAVES = mission.data.custom.survivedWaves }
    end

    --Run standard initialization. Manages _restoring on its own.
    Annihilatorium_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS
--Try to keep the timer calls outside of onBeginServer / onSectorEntered / onSectorArrivalConfirmed unless they are non-repeating and 30 seconds or less.

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    invokeStopArenaMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    invokeStopArenaMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    invokeStopArenaMusic()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onRestore = function()
    local annihilatoriumStation = Entity(Uuid(mission.data.custom.annihilatoriumStationIndex))
    if annihilatoriumStation and valid(annihilatoriumStation) then
        annihilatoriumStation.invincible = true
    end
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    local methodName = "On Target Location Left"
    mission.Log(methodName, "Running.")

    mission.data.custom.checkForWaveVanquish = false

    if onServer() then
        if mission.data.custom.masterOfTheArena then
            fail()
        end
    end

    if onClient() then
        stopArenaMusic()
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y)
    local methodName = "Phase 1 On Target Location Entered"
    mission.Log(methodName, "Entering target sector.")
    
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true

    if onServer() then
        mission.Log(methodName, "Making the sector")
        makeSector(_X, _Y) 
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].sectorCallbacks = {}
mission.phases[2].onBegin = function()
    --Start the music whenever phase 2 starts.
    if onClient() then
        playArenaMusic()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    --Restart the music whenever we come back.
    invokePlayArenaMusic()
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    if mission.data.custom.masterOfTheArena then
        mission.data.custom.motaTimer = (mission.data.custom.motaTimer or 0) + timeStep
        --print("mota timer is " .. tostring(mission.data.custom.motaTimer)) --Spams like crazy. Be careful about uncommenting this.
    end

    local _sector = Sector()

    local delScriptPath = "entity/utility/delayeddelete.lua"

    --Remove Warzone ships
    local warzoneShips = { _sector:getEntitiesByScriptValue("war_zone_reinforcement") }
    for _, wzShip in pairs(warzoneShips) do
        if not wzShip.playerOrAllianceOwned then
            wzShip:addScriptOnce(delScriptPath, random():getFloat(4, 8))
        end
    end

    --Remove Xsotan ships (local events are suppressed, but player could have gone into the sector w/ alien attack on)
    local xsotanTags = { "is_xsotan", "xsotan_summoner_minion", "xsotan_master_summoner_minion", "xsotan_revenant" }

    for idx, tag in pairs(xsotanTags) do
        local xsotans = { _sector:getEntitiesByScriptValue(tag)}
        for idx2, xsotan in pairs(xsotans) do
            xsotan:addScriptOnce(delScriptPath, random():getFloat(4, 8))
        end
    end

    --Fail the mission if the player builds a station in the sector.
    local stations = { _sector:getEntitiesByType(EntityType.Station)}
    for _, station in pairs(stations) do
        if station.playerOrAllianceOwned then
            mission.data.failMessage = "You can't build a station here!!! That clearly violates the terms of your liability waiver!"
            fail()
        end
    end
end

mission.phases[2].onEntityDestroyed = function(id, lastDamageInflictor)
    if atTargetLocation() then
        local destroyedEntity = Entity(id)
        if destroyedEntity:getValue("annihilatorium_boss_payout") then
            payBossBounty()
        end
    end
end

--region #PHASE 2 TIMERS

if onServer() then

mission.phases[2].timers[1] = {
    time = 5,
    callback = function()
        local methodName = "Phase 2 Timer 1 Callback"
        if atTargetLocation() and mission.data.custom.checkForWaveVanquish then
            local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

            if pirateCt == 0 then
                mission.Log(methodName, "Survived pirate wave - resetting / incrementing appropriate variables.")

                mission.data.custom.spawnedBossThisWave = false
                mission.data.custom.spawnedBossTitle = false
                mission.data.custom.checkForWaveVanquish = false
                mission.data.custom.bossBountyFactor = 1
                mission.data.custom.survivedWaves = mission.data.custom.survivedWaves + 1
                mission.data.custom.motaTimer = 0

                mission.data.description[5].arguments._SURVIVEDWAVES = mission.data.custom.survivedWaves
                mission.data.description[6].visible = true

                sync()
                invokeClientFunction(Player(), "showWaveDefeatedText")
                invokeClientFunction(Player(), "playArenaMusic")
            end
        end
    end,
    repeating = true
}

mission.phases[2].timers[2] = {
    time = 10,
    callback = function()
        if not mission.data.custom.checkForWaveVanquish and mission.data.custom.survivedWaves >= mission.data.custom.overallWaves then
            finishAndReward()
        end
    end,
    repeating = true
}

mission.phases[2].timers[3] = {
    time = 5,
    callback = function()
        if atTargetLocation() then
            local timeBetweenWaves = 3.5 * 60 --1 loop of omf title.
            if mission.data.custom.masterOfTheArena and not mission.data.custom.checkForWaveVanquish and mission.data.custom.survivedWaves < mission.data.custom.overallWaves and mission.data.custom.motaTimer >= timeBetweenWaves then
                spawnWave()

                mission.data.description[6].visible = false
                sync()
            end
        end
    end,
    repeating = true
}

end

--endregion

--region #PHASE 2 SECTOR CALLBACKS

if onServer() then

mission.phases[2].sectorCallbacks[1] = {
    name = "onAnnihilatoriumSpawnWave",
    func = function()
        local methodName = "On Spawn Wave Callback"
        mission.Log(methodName, "Runnning.")

        if mission.data.custom.survivedWaves < mission.data.custom.overallWaves then
            spawnWave()

            mission.data.description[6].visible = false
            sync()
        else
            Sector():broadcastChatMessage("", 3, "You've defeated all the waves! You'll be rewarded shortly.")
        end
    end
}

mission.phases[2].sectorCallbacks[2] = {
    name = "onEnableMOTAMode",
    func = function()
        local _sector = Sector()

        if mission.data.custom.masterOfTheArena then
            _sector:broadcastChatMessage("", 1, "You've already engaged Master Of The Arena mode!")
        else
            if mission.data.custom.survivedWaves == 0 then
                mission.data.custom.masterOfTheArena = true
                mission.data.description[7].visible = true
                _sector:broadcastChatMessage("", 2, "Master Of The Arena mode is engaged! Leaving the area will result in failure.")
                sync()
            else
                _sector:broadcastChatMessage("", 1, "Cannot engage Master Of The Arena mode after clearing waves!")
            end
        end
    end
}

end

--endregion

--endregion

--region #SERVER CALLS

function makeSector(_X, _Y)
    local _MethodName = "Build Main Sector"

    mission.Log(_MethodName, "Building Sector")
    local _Generator = SectorGenerator(_X, _Y)

    mission.Log(_MethodName, "Building outpost.")
    local _SmugglerFaction = MissionUT.getMissionSmugglerFaction()

    local _AnnihilatoriumStation = _Generator:createMilitaryBase(_SmugglerFaction)

    _AnnihilatoriumStation.invincible = true
    --no consumer / crew / bulletin board.
    _AnnihilatoriumStation:removeScript("consumer.lua")
    _AnnihilatoriumStation:removeScript("crewboard.lua")
    _AnnihilatoriumStation:removeScript("bulletinboard.lua")
    _AnnihilatoriumStation:removeScript("militaryoutpost.lua")
    _AnnihilatoriumStation:addScriptOnce(mission.data.custom.stationScriptPath, mission.data.custom.dangerLevel)

    mission.data.custom.annihilatoriumStationIndex = _AnnihilatoriumStation.index.string

    -- create asteroid rings
    mission.Log(_MethodName, "Building asteroid rings.")
    local _random = random()
    local matrix = _AnnihilatoriumStation.position
    local radius = 500
    local angle = 0

    for i = 1, _random:getInt(2, 3) do
        radius = radius + getFloat(500, 600)
        local ringMatrix = _Generator:getUniformPositionInSector(0)
        ringMatrix.pos = matrix.pos

        for i = 0, (_random:getInt(70, 100)) do
            local size = getFloat(5, 15)
            local asteroidPos = vec3(math.cos(angle), math.sin(angle), 0) * (radius + getFloat(0, 10))
            asteroidPos = ringMatrix:transformCoord(asteroidPos)

            _Generator:createSmallAsteroid(asteroidPos, size, false, _Generator:getAsteroidType())
            angle = angle + getFloat(1, 2)
        end
    end

    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true

    sync()
end

function getWaveTable(waveNumber)
    local waveTables = {
        { waveDanger = 1, waveShips = {4}, bonus = 1.25 },
        { waveDanger = 1, waveShips = {4}, bonus = 1.25 },
        { waveDanger = 1, waveShips = {4}, bonus = 1.25 },
        { waveDanger = 1, waveShips = {4}, bonus = 1.25 },
        { waveDanger = 1, waveShips = {4}, bonus = 1.25, bossOnDangerLevel = 1 },
        { waveDanger = 2, waveShips = {4}, bonus = 1.225 },
        { waveDanger = 2, waveShips = {4}, bonus = 1.225 },
        { waveDanger = 2, waveShips = {4}, bonus = 1.225 },
        { waveDanger = 2, waveShips = {4}, bonus = 1.225 },
        { waveDanger = 2, waveShips = {4}, bonus = 1.225, boss = true },
        { waveDanger = 3, waveShips = {4, 1}, bonus = 1.2 },
        { waveDanger = 3, waveShips = {4, 1}, bonus = 1.2 },
        { waveDanger = 3, waveShips = {4, 1}, bonus = 1.2 },
        { waveDanger = 3, waveShips = {4, 1}, bonus = 1.2 },
        { waveDanger = 3, waveShips = {4, 1}, bonus = 1.2, bossOnDangerLevel = 3 },
        { waveDanger = 4, waveShips = {4, 1}, bonus = 1.175 },
        { waveDanger = 4, waveShips = {4, 1}, bonus = 1.175 },
        { waveDanger = 4, waveShips = {4, 1}, bonus = 1.175 },
        { waveDanger = 4, waveShips = {4, 1}, bonus = 1.175 },
        { waveDanger = 4, waveShips = {4, 1}, bonus = 1.175, boss = true },
        { waveDanger = 5, waveShips = {4, 2}, bonus = 1.15 },
        { waveDanger = 5, waveShips = {4, 2}, bonus = 1.15 },
        { waveDanger = 5, waveShips = {4, 2}, bonus = 1.15 },
        { waveDanger = 5, waveShips = {4, 2}, bonus = 1.15 },
        { waveDanger = 5, waveShips = {4, 2}, bonus = 1.15, bossOnDangerLevel = 5 },
        { waveDanger = 6, waveShips = {4, 2}, bonus = 1.125 },
        { waveDanger = 6, waveShips = {4, 2}, bonus = 1.125 },
        { waveDanger = 6, waveShips = {4, 2}, bonus = 1.125 },
        { waveDanger = 6, waveShips = {4, 2}, bonus = 1.125 },
        { waveDanger = 6, waveShips = {4, 2}, bonus = 1.125, boss = true },
        { waveDanger = 7, waveShips = {4, 3}, bonus = 1.1 },
        { waveDanger = 7, waveShips = {4, 3}, bonus = 1.1 },
        { waveDanger = 7, waveShips = {4, 3}, bonus = 1.1 },
        { waveDanger = 7, waveShips = {4, 3}, bonus = 1.1 },
        { waveDanger = 7, waveShips = {4, 3}, bonus = 1.1, bossOnDangerLevel = 7 },
        { waveDanger = 8, waveShips = {4, 3}, bonus = 1.075 },
        { waveDanger = 8, waveShips = {4, 3}, bonus = 1.075 },
        { waveDanger = 8, waveShips = {4, 3}, bonus = 1.075 },
        { waveDanger = 8, waveShips = {4, 3}, bonus = 1.075 },
        { waveDanger = 8, waveShips = {4, 3}, bonus = 1.075, boss = true },
        { waveDanger = 9, waveShips = {4, 4}, bonus = 1.05 },
        { waveDanger = 9, waveShips = {4, 4}, bonus = 1.05 },
        { waveDanger = 9, waveShips = {4, 4}, bonus = 1.05 },
        { waveDanger = 9, waveShips = {4, 4}, bonus = 1.05 },
        { waveDanger = 9, waveShips = {4, 4}, bonus = 1.05, bossOnDangerLevel = 9 },
        { waveDanger = 10, waveShips = {4, 4}, bonus = 1.025 },
        { waveDanger = 10, waveShips = {4, 4}, bonus = 1.025 },
        { waveDanger = 10, waveShips = {4, 4}, bonus = 1.025 },
        { waveDanger = 10, waveShips = {4, 4}, bonus = 1.025 },
        { waveDanger = 10, waveShips = {4, 4}, bonus = 1.025, boss = true }
    }

    return waveTables[waveNumber]
end

function spawnWave()
    local methodName = "Spawn Wave"

    local nextWaveNumber = mission.data.custom.survivedWaves + 1

    mission.Log(methodName, "Spawning wave number " .. tostring(nextWaveNumber))

    --Get corresponding wave table
    local useWaveTable = getWaveTable(nextWaveNumber)
    local waveDanger = useWaveTable.waveDanger
    local waveShipTable = useWaveTable.waveShips
    local useBossMusic = false
    local shouldSpawnBoss = false

    --Spawn ship in table.
    for _, waveShips in pairs(waveShipTable) do
        mission.Log(methodName, "Spawning wave table with " .. tostring(waveShips))

        local waveShipsToSpawn = waveShips
        if not mission.data.custom.spawnedBossThisWave and (useWaveTable.bossOnDangerLevel == mission.data.custom.dangerLevel or useWaveTable.boss) then
            mission.Log(methodName, "Spawning one less enemy in this group in favor of a boss")

            mission.data.custom.spawnedBossThisWave = true
            waveShipsToSpawn = waveShipsToSpawn - 1
            shouldSpawnBoss = true
        end

        --Get ESCC wave table for the danger level / # of ships
        local waveSpawnTable = ESCCUtil.getStandardWave(waveDanger, waveShipsToSpawn, "Standard", false)
        local distance = 250 --_#DistAdj

        --Spawn the ships
        local pirateGenerator = AsyncPirateGenerator(nil, onWaveSpawned)
        local posCounter = 1
        local piratePositions = pirateGenerator:getStandardPositions(waveShips, distance)

        pirateGenerator:startBatch()

        for _, pirate in pairs(waveSpawnTable) do
            pirateGenerator:createScaledPirateByName(pirate, piratePositions[posCounter])
            posCounter = posCounter + 1
        end

        pirateGenerator:endBatch()
    end

    if shouldSpawnBoss or mission._Spawn_Boss_Debug == 1 then
        useBossMusic = true
        spawnBoss(waveDanger)
    end

    --invoke music
    invokeClientFunction(Player(), "playCombatMusic", useBossMusic)
end

function onWaveSpawned(generated)
    local methodName = "On Wave Spawned"
    mission.Log(methodName, "Running.")

    local _SmugglerFaction = MissionUT.getMissionSmugglerFaction()

    local nextWaveNumber = mission.data.custom.survivedWaves + 1
    local useWaveTable = getWaveTable(nextWaveNumber)

    --register friend faction / set delete on exit
    for _, pirate in pairs(generated) do
        local pirateAI = ShipAI(pirate)
        pirateAI:registerFriendFaction(_SmugglerFaction.index)

        pirate.damageMultiplier = (pirate.damageMultiplier or 1) * useWaveTable.bonus * getDifficultyBonus()

        local durabilityBonus = useWaveTable.bonus * getDifficultyBonus()

        local pirateShield = Shield(pirate.index)
        if pirateShield then
            pirateShield.maxDurabilityFactor = (pirateShield.maxDurabilityFactor or 1) * durabilityBonus
        else
            durabilityBonus = durabilityBonus * 1.5
        end

        local pirateDurability = Durability(pirate.index)
        if pirateDurability then
            pirateDurability.maxDurabilityFactor = (pirateDurability.maxDurabilityFactor or 1) * durabilityBonus
        end

        if mission.data.custom.masterOfTheArena then
            pirate.damageMultiplier= (pirate.damageMultiplier or 1) * 4

            local motaDurabilityBonus = 4

            if pirateShield then
                pirateShield.maxDurabilityFactor = (pirateShield.maxDurabilityFactor) * motaDurabilityBonus
            else
                motaDurabilityBonus = motaDurabilityBonus * 1.5
            end

            if pirateDurability then
                pirateDurability.maxDurabilityFactor = (pirateDurability.maxDurabilityFactor or 1) * motaDurabilityBonus
            end
        end

        MissionUT.deleteOnPlayersLeft(pirate)
        pirate:removeScript("fleeondamaged.lua") --No running! Fight until you die!
    end

    --Set appropriate custom data values
    mission.data.custom.checkForWaveVanquish = true

    --add buffs / resolve placer
    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function spawnBoss(waveDanger)
    local methodName = "Spawn Boss"

    mission.Log(methodName, "Running.")
    local pirateGenerator = AsyncPirateGenerator(nil, onBossSpawned)

    local bossTypes = {
        "Marauder",
        "Raider",
        "Ravager",
        "Ravager",
        "Prowler",
        "Prowler",
        "Pillager",
        "Pillager",
        "Devastator",
        "Devastator"
    }

    pirateGenerator:startBatch()

    if mission.data.custom.masterOfTheArena then
        pirateGenerator:createScaledExecutioner(pirateGenerator:getGenericPosition(), waveDanger * 100)
    else
        pirateGenerator:createScaledPirateByName(bossTypes[waveDanger], pirateGenerator:getGenericPosition())
    end

    pirateGenerator:endBatch()
end

function onBossSpawned(generated)
    local methodName = "On Boss Spawned"
    local bossEnemy = generated[1]

    local _SmugglerFaction = MissionUT.getMissionSmugglerFaction()

    local pirateAI = ShipAI(bossEnemy)
    pirateAI:registerFriendFaction(_SmugglerFaction.index)
    
    mission.Log(methodName, "Making Boss Enemy")

    local newTitle = "${script}" .. bossEnemy.title
    local titleArgs = bossEnemy:getTitleArguments() --We mess with the titleArgs in bossFuncs.

    local x, y = Sector():getCoordinates()

    mission.Log(methodName, "Setting script value tables")
    local laserSniperDamage = Balancing_GetSectorWeaponDPS(x, y) * 32 --Roughly 1/4 the damage of a longinus, but enemies will use their damge multiplier.
    local laserSniperValues = {
        _DamagePerFrame = laserSniperDamage,
        _TimeToActive = 15,
        _TargetPriority = 5,
        _UseEntityDamageMult = true,
        _TargetCycle = 15,
        _TargetingTime = 2.25
    }

    local torpedoSlammerValues = {
        _TimeToActive = 15,
        _TargetPriority = 7,
        _UseEntityDamageMult = true,
        _ROF = 8,
        _UpAdjust = false,
        _ForwardAdjustFactor = 2,
        _DurabilityFactor = 8
    }

    local allyBoosterValuesHealer = {
        _BoostCycle = 30,
        _HealWhenBoosting = true, 
        _HealPctWhenBoosting = 25
    }

    --This is basically just for the Blackguard.
    local allyBoosterValues = {
        _BoostCycle = 15
    }

    local apdBaseValue = Balancing_GetTechLevel(x, y)

    local apdValues = {
        _ROF = 0.6,
        _TargetTorps = true,
        _TargetFighters = true,
        _FighterDamage = math.max(8, apdBaseValue * 0.9),
        _TorpDamage = math.max(8, (apdBaseValue / 4) * 0.9),
        _MaxTargets = math.floor(math.max(2, apdBaseValue / 8.5))
    }

    mission.Log(methodName, "Defining boss function table")
    local bossFuncs = {
        function() --1 Relentless (eternal / phasemode)
            bossEnemy:addScriptOnce("eternal.lua")
            bossEnemy:addScriptOnce("phasemode.lua")

            titleArgs.script = "Relentless "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for eternal / +0.25 for phasemode
        end,
        function() --2 Overgrown (eternal / thorns)
            bossEnemy:addScriptOnce("eternal.lua")
            bossEnemy:addScriptOnce("thorns.lua")

            titleArgs.script = "Overgrown "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for eternal / +0.25 for thorns
        end,
        function() --3 Berserking (eternal / frenzy)
            bossEnemy:addScriptOnce("eternal.lua")
            bossEnemy:addScriptOnce("frenzy.lua")

            titleArgs.script = "Berserking "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for eternal / +0.25 for frenzy
        end,
        function() --4 Unbreakable (adaptive / ironcurtain)
            bossEnemy:addScriptOnce("ironcurtain.lua")
            bossEnemy:addScriptOnce("adaptivedefense.lua")

            titleArgs.script = "Unbreakable "
            mission.data.custom.bossBountyFactor = 2.5 -- +1 for ironcurtain / +0.5 for adaptivedefense
        end,
        function() --5 Blackguard (allybooster / avenger)
            bossEnemy:addScriptOnce("allybooster.lua", allyBoosterValues)
            bossEnemy:addScriptOnce("avenger.lua")

            titleArgs.script = "Blackguard "
            mission.data.custom.bossBountyFactor = 1.75 -- +0.5 for allybooster / +0.25 for avenger
        end,
        function() --6 Rampaging (ironcurtain / (buffed) frenzy)
            local frenzyValues = {
                _IncreasePerUpdate = 0.125,
                _DamageThreshold = 0.5,
                _UpdateCycle = 5
            }

            bossEnemy:addScriptOnce("ironcurtain.lua")
            bossEnemy:addScriptOnce("frenzy.lua", frenzyValues)

            titleArgs.script = "Rampaging "
            mission.data.custom.bossBountyFactor = 2.5 -- +1 for ironcurtain / +0.5 for (buffed) frenzy
        end,
        function() --7 Juggernaut (ironcurtain / lasersniper)
            bossEnemy:addScriptOnce("ironcurtain.lua")
            bossEnemy:addScriptOnce("lasersniper.lua", laserSniperValues)

            titleArgs.script = "Juggernaut "
            mission.data.custom.bossBountyFactor = 3 -- +1 for ironcurtain / +1 for lasersniper
        end,
        function() --8 Assassin (phasemode / lasersniper)
            bossEnemy:addScriptOnce("phasemode.lua")
            bossEnemy:addScriptOnce("lasersniper.lua", laserSniperValues)

            titleArgs.script = "Assassin "
            mission.data.custom.bossBountyFactor = 2.25 -- +0.25 for phasemode / +1 for lasersniper
        end,
        function() --9 Brimstone (overdrive / lasersniper)
            bossEnemy:addScriptOnce("overdrive.lua")
            bossEnemy:addScriptOnce("lasersniper.lua", laserSniperValues)

            titleArgs.script = "Brimstone "
            mission.data.custom.bossBountyFactor = 2.25 -- +1 for lasersniper / +0.25 for overdrive
        end,
        function() --10 Raving (apd / lasersniper)
            bossEnemy:addScriptOnce("absolutepointdefense.lua", apdValues)
            bossEnemy:addScriptOnce("lasersniper.lua", laserSniperValues)

            titleArgs.script = "Raving "
            mission.data.custom.bossBountyFactor = 2 -- +1 for lasersniper / +0 for apd
        end,
        function() --11 Penetrator (afterburn / (buffed) lasersniper)
            laserSniperValues._ShieldPen = true

            bossEnemy:addScriptOnce("afterburn.lua")
            bossEnemy:addScriptOnce("lasersniper.lua", laserSniperValues)

            titleArgs.script = "Penetrator "
            mission.data.custom.bossBountyFactor = 2.75 -- +1.5 for (buffed) lasersniper / +0.25 for afterburn
        end,
        function() --12 Punisher (avenger / torpslammer)
            bossEnemy:addScriptOnce("avenger.lua")
            bossEnemy:addScriptOnce("torpedoslammer.lua", torpedoSlammerValues)

            titleArgs.script = "Punisher "
            mission.data.custom.bossBountyFactor = 2.25 -- +1 for torpslammer / +0.25 for avenger
        end,
        function() --13 Saboteur (phasemode / torpslammer)
            bossEnemy:addScriptOnce("phasemode.lua")
            bossEnemy:addScriptOnce("torpedoslammer.lua", torpedoSlammerValues)

            titleArgs.script = "Saboteur "
            mission.data.custom.bossBountyFactor = 2.25 -- +1 for torpslammer / +0.25 for phasemode
        end,
        function() --14 Mercurial (afterturn / (buffed) torpslammer)
            torpedoSlammerValues._ReachFactor = 2
            torpedoSlammerValues._AccelFactor = 8
            torpedoSlammerValues._VelocityFactor = 16
            torpedoSlammerValues._TurningSpeedFactor = 8

            bossEnemy:addScriptOnce("afterburn.lua")
            bossEnemy:addScriptOnce("torpedoslammer.lua", torpedoSlammerValues)

            titleArgs.script = "Mercurial "
            mission.data.custom.bossBountyFactor = 2.75 -- +1.5 for (buffed) torpedoslammer / +0.25 for afterburn
        end,
        function() --15 Vindictive (overdrive / (buffed) torpslammer)
            torpedoSlammerValues._PreferWarheadType = 2 --Neutron
            torpedoSlammerValues._PreferSecondaryWarheadType = 3 --Fusion

            bossEnemy:addScriptOnce("overdrive.lua")
            bossEnemy:addScriptOnce("torpedoslammer.lua", torpedoSlammerValues)

            titleArgs.script = "Vindictive "
            mission.data.custom.bossBountyFactor = 2.75 -- +1.5 for (buffed) torpedoslammer / +0.25 for overdrive
        end,
        function() --16 Thunderstrike (adaptive / (buffed) torpslammer)
            torpedoSlammerValues._PreferWarheadType = 6 --Ion
            torpedoSlammerValues._PreferSecondaryWarheadType = 9 --EMP
            torpedoSlammerValues._ROF = 4

            bossEnemy:addScriptOnce("adaptivedefense.lua")
            bossEnemy:addScriptOnce("torpedoslammer.lua", torpedoSlammerValues)

            titleArgs.script = "Thunderstrike "
            mission.data.custom.bossBountyFactor = 3 -- +1.5 for (buffed) torpedoslammer / +0.5 for adaptivedefense
        end,
        function() --17 Charlatan ((healing) allybooster / eternal)
            bossEnemy:addScriptOnce("allybooster.lua", allyBoosterValuesHealer)
            bossEnemy:addScriptOnce("eternal.lua")

            titleArgs.script = "Charlatan "
            mission.data.custom.bossBountyFactor = 1.91 -- +0.66 for (healing) allybooster / +0.25 for eternal
        end,
        function() --18 Traditor ((healing) allybooster / ironcurtain)
            bossEnemy:addScriptOnce("allybooster.lua", allyBoosterValuesHealer)
            bossEnemy:addScriptOnce("ironcurtain.lua")

            titleArgs.script = "Traditor "
            mission.data.custom.bossBountyFactor = 2.66 -- +1 for ironcurtain / +0.66 for (healing) allybooster
        end,
        function() --19 Seeker (eternal / evenger)
            bossEnemy:addScriptOnce("eternal.lua", 0.015, 0)
            bossEnemy:addScriptOnce("avenger.lua")

            titleArgs.script = "Seeker "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for eternal and +0.25 for avenger
        end,
        function() --20 Bastion ((healing) allybooster / apd)
            bossEnemy:addScriptOnce("allybooster.lua", allyBoosterValuesHealer)
            bossEnemy:addScriptOnce("absolutepointdefense.lua", apdValues)

            titleArgs.script = "Bastion "
            mission.data.custom.bossBountyFactor = 1.66 -- +0.66 for (healing) allybooster and +0 for absolutepointdefense
        end,
        function() --21 Overclocked (overdrive / afterburn)
            bossEnemy:addScriptOnce("overdrive.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Overclocked "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for afterburn / +0.25 for overdrive
        end,
        function() --22 Synapse ((dmg booster) linker / adaptive)
            local linkerArgs = {   
                linkCycle = 6,
                boostDamageWhenLinking = true
            }

            bossEnemy:addScriptOnce("adaptivedefense.lua")
            bossEnemy:addScriptOnce("escclinker.lua", linkerArgs)

            titleArgs.script = "Synapse "
            mission.data.custom.bossBountyFactor = 2 -- +0.5 for adaptive defense / +0.5 for (dmg booster) linker
        end,
        function() --23 Holistic (linker / eternal)
            bossEnemy:addScriptOnce("eternal.lua")
            bossEnemy:addScriptOnce("escclinker.lua")

            titleArgs.script = "Holistic "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for eternal / +0.25 for linker
        end,
        function() --24 Warlord (linker / avenger)
            bossEnemy:addScriptOnce("avenger.lua")
            bossEnemy:addScriptOnce("escclinker.lua")

            titleArgs.script = "Warlord "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for avenger / +0.25 for linker
        end,
        function() --25 Mendicant ((healing) allybooster / (buffed) linker) + severe damage nerf
            local linkerValues = {
                healPctWhenLinking = 25
            }

            bossEnemy:addScriptOnce("allybooster.lua", allyBoosterValuesHealer)
            bossEnemy:addScriptOnce("escclinker.lua", linkerValues)

            bossEnemy.damageMultiplier = (enemy.damageMultiplier or 1) * 0.125

            titleArgs.script = "Mendicant "
            mission.data.custom.bossBountyFactor = 0.5 --You killed a beggar, you monster.
        end,
        function() --26 Nemean (phasemode / iron curtain)
            bossEnemy:addScriptOnce("phasemode.lua")
            bossEnemy:addScriptOnce("ironcurtain.lua")

            titleArgs.script = "Nemean "
            mission.data.custom.bossBountyFactor = 2.25 -- +1 for ironcurtain / +0.25 for phasemode
        end,
        function() --27 Nightingale ((buffed) linker / afterturn)
            local linkerValues = {
                healPctWhenLinking = 25
            }

            bossEnemy:addScriptOnce("afterburn.lua")
            bossEnemy:addScriptOnce("escclinker.lua", linkerValues)

            titleArgs.script = "Nightingale "
            mission.data.custom.bossBountyFactor = 1.58 -- +0.25 for afterburn / +0.33 for buffed linker
        end,
        function() --28 Doomlord (afterburn + avenger) - named after the Eurasian Bullfinch :D
            bossEnemy:addScriptOnce("avenger.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Doomlord "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for avenger / +0.25 for afterburn
        end,
        function() --29 Bloodwind (afterburn + frenzy)
            bossEnemy:addScriptOnce("frenzy.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Bloodwind "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for frenzy / +0.25 for afterburn
        end,
        function() --30 Headwind (afterburn + thorns)
            bossEnemy:addScriptOnce("thorns.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Headwind "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for thorns / +0.25 for afterburn
        end,
        function() --31 Erinyes (overdrive + avenger)
            bossEnemy:addScriptOnce("avenger.lua")
            bossEnemy:addScriptOnce("overdrive.lua")

            titleArgs.script = "Erinyes "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for avenger / +0.25 for overdrive
        end,
        function() --32 Bloodthirsty ((buffed frenzy) + overdrive)
            local frenzyValues = {
                _DamageThreshold = 0.75,
                _IncreasePerUpdate = 0.15,
                _UpdateCycle = 5
            }

            bossEnemy:addScriptOnce("frenzy.lua", frenzyValues)
            bossEnemy:addScriptOnce("overdrive.lua")

            titleArgs.script = "Bloodthirsty "
            mission.data.custom.bossBountyFactor = 1.58 -- +0.33 for (buffed) frenzy / +0.25 for overdrive
        end,
        function() --33 Slipstream (afterburn + phasemode)
            bossEnemy:addScriptOnce("phasemode.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Slipstream "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for phasemode / +0.25 for afterburn
        end,
        function() --34 Bushwhacker (afterburn + overdrive)
            bossEnemy:addScriptOnce("overdrive.lua")
            bossEnemy:addScriptOnce("afterburn.lua")

            titleArgs.script = "Bushwhacker "
            mission.data.custom.bossBountyFactor = 1.5 -- +0.25 for overdrive / +0.25 for afterburn
        end
    }

    mission.Log(methodName, "Setting durability and damage multipliers")
    local bossDurabilityBonus = 3 * getDifficultyBonus()

    local bossShield = Shield(bossEnemy.index)
    if bossShield then
        bossShield.maxDurabilityFactor = (bossShield.maxDurabilityFactor or 1) * bossDurabilityBonus
    else
        bossDurabilityBonus = bossDurabilityBonus * 1.5
    end

    local enemyDurability = Durability(bossEnemy.index)
    if enemyDurability then
        enemyDurability.maxDurabilityFactor = (enemyDurability.maxDurabilityFactor or 1) * bossDurabilityBonus 
    end

    bossEnemy.damageMultiplier = (bossEnemy.damageMultiplier or 1) * 2 * getDifficultyBonus()

    mission.Log(methodName, "Setting unboardable / undockable")
    Boarding(bossEnemy).boardable = false
    bossEnemy.dockable = false

    mission.Log(methodName, "Running scripts / setting values")
    local bossFunc = getRandomEntry(bossFuncs)
    bossFunc()

    bossEnemy:setValue("annihilatorium_boss_payout", true)
    bossEnemy:setValue("_escc_enhanced_title", true)
    bossEnemy:setTitle(newTitle, titleArgs)

    mission.Log(methodName, "Registering as boss")
    invokeClientFunction(Player(), "registerAnnihilatoriumBoss", bossEnemy.index)

    mission.data.custom.spawnedBossTitle = bossEnemy.translatedTitle

    mission.Log(methodName, "Adding danger 10 multipliers if applicable")
    --With the player having to kill five of these enemies, this makes this the best mission for farming legendary turrets.
    --But we don't want to make things too easy for the player :)
    if mission.data.custom.dangerLevel == 10 then
        bossEnemy:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
        
        local bossDurability = Durability(bossEnemy.index)
        if bossDurability then
            bossDurability.maxDurabilityFactor = (bossDurability.maxDurabilityFactor or 1) * 1.25
        end

        bossEnemy.damageMultiplier = (bossEnemy.damageMultiplier or 1) * 1.5
    end

    mission.Log(methodName, "Adding spawn utility buffs")
    if mission.data.custom.masterOfTheArena then
        SpawnUtility.addAnnihilatoriumMOTABossBuff(bossEnemy)
    else
        SpawnUtility.addEnemyBuffs(generated)
    end
    Placer.resolveIntersections(generated)
end

function getDifficultyBonus()
    return 1 + (mission.data.custom.dangerLevel * 0.01) -- +1% to +10%.
end

function payBossBounty()
    local _player = Player()

    local sectorFactor = Balancing.GetSectorRewardFactor(Sector():getCoordinates()) --onDestroyed has an atTargetLocation() call so we should always be @ the sector.
    local bossFactor = mission.data.custom.bossBountyFactor
    local difficultyFactor = 1 + (mission.data.custom.dangerLevel * 0.005) -- +0.5% to +5%
    local randomFactor = random():getFloat(0.99, 1.05) --A little variety
    local motaFactor = 1
    if mission.data.custom.masterOfTheArena then
        motaFactor = 3
    end

    local receiver = _player.craftFaction or _player

    local payout = 10000 * sectorFactor * bossFactor * difficultyFactor * randomFactor * motaFactor

    receiver:receive("Earned %1% credits for defeating the ${_BOSSTITLE}." % { _BOSSTITLE = mission.data.custom.spawnedBossTitle }, payout, 0, 0, 0, 0, 0, 0, 0)
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    if mission.data.custom.masterOfTheArena then
        mission.data.reward.credits = mission.data.reward.credits * 3
    end

    reward()
    accomplish()
end

--endregion

--region #CLIENT / SERVER UTILITY CALLS

function invokeStopArenaMusic()
    local methodName = "Invoke Stop Arena Music"

    if onClient() then
        mission.Log(methodName, "Invoked on Client => Stopping Music")

        stopArenaMusic()
    else
        mission.Log(methodName, "Called on Server => Invoking on Client")

        invokeClientFunction(Player(), "invokeStopArenaMusic")
    end
end

function invokePlayArenaMusic()
    local methodName = "Invoke Start Arena Music"

    if onClient() then
        mission.Log(methodName, "Invoked on Client => Playing Music")

        playArenaMusic()
    else
        mission.Log(methodName, "Called on Server => Invoking on Client")

        invokeClientFunction(Player(), "invokePlayArenaMusic")
    end
end

--endregion

--region #CLIENT CALLS

function playArenaMusic()
    local methodName = "Play Arena Music"

    mission.Log(methodName, "Playing music")
    local mus = Music()

    mission.Log(methodName, "Music autoplay is : " .. tostring(mus.autoPlay))

    mus.autoPlay = false
    mus:fadeOut(1.5)
    mus:playTrack(mission.data.custom.mainSoundtrack, true, nil)
end

function playCombatMusic(useBossMusic)
    local methodName = "Play Combat Music"

    mission.Log(methodName, "Playing music")

    local useTrack = getRandomEntry(mission.data.custom.waveTracks)
    if useBossMusic then
        if mission.data.custom.masterOfTheArena then
            useTrack = mission.data.custom.motaBossTrack
        else
            useTrack = mission.data.custom.bossTrack
        end
    end
    mission.Log(methodName, "Playing track " .. tostring(useTrack))
    local mus = Music()

    mus.autoPlay = false
    mus:fadeOut(1.5)
    mus:playTrack(useTrack, true, nil)
end

function stopArenaMusic()
    local methodName = "Stop Arena Music"

    mission.Log(methodName, "Resetting music")
    local mus = Music()
    mus.autoPlay = true
    mus:fadeOut(1.5)
end

function showWaveDefeatedText()
    --All of this data should be available on the client.
    local platitudeTable = {
        "Good job!",
        "Well done!",
        "Keep going!",
        "You're almost there!",
        "Hang in there!",
        "You got this!",
        "Almost there!",
        "Nice work!",
        "Keep it up!",
        "You're doing great!",
        "Fantastic effort!",
        "Stay strong!",
        "Way to go!",
        "Keep pushing!",
        "Success is near!",
        "Don't stop now!",
        "Great progress!",
        "Keep moving forward!",
        "Amazing job!",
        "That's the spirit!",
        "Great job!"
    }

    local platitude = getRandomEntry(platitudeTable)

    local fmt = { _WAVE = mission.data.custom.survivedWaves, _MAXWAVE = mission.data.custom.overallWaves }
    displayMissionAccomplishedText("WAVE DEFEATED: ${_WAVE} OF ${_MAXWAVE}" % fmt, platitude)
end

function registerAnnihilatoriumBoss(idx)
    registerBoss(idx, nil, nil, nil, nil, true)
end

--endregion

--region #MAKEBULLETIN CALL

function formatDescription()
    local descTable = {
        "You there! Step right up! A test of your might! A test of your reflexes! A test of your ship's construction! Come on down to the Annihilatorium and face the most vicious pirate scum on this side of the galaxy! Are you brave enough to lock horns with the nastiest scum in these sectors? We'll be waiting for you at (${_X}:${_Y})!",
        "Come one, come all to the galaxy-famous Annihilatorium! We've got ships the likes of which have only been seen in your nightmares, folks, and they're ripe for the fighting! Think you're captain enough to try them on for size? Come on down to (${_X}:${_Y})! We'll be waiting for you!",
        "Step right up, ladies and gents! Witness the ultimate showdown in the stars at The Annihilatorium - where we've got all sorts of ships waiting to battle to the death! Thrills, explosions, and cosmic chaos await! Only the strongest will survive! Come on down to (${_X}:${_Y}) and see for yourself who's standing when the dust settles!"
    }

    return getRandomEntry(descTable)
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"

    local _sector = Sector()
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local target = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 2, 15, insideBarrier)

    if not target.x or not target.y then
        print("ERROR - Target.x or Target.y not set - returning nil.")
        return 
    end

    if target.x == 0 and target.y == 0 then
        print("ERROR - Cannot spawn mission at 0:0 - returning nil.")
        return
    end

    local _DangerLevel = random():getInt(1, 10)

    local _Difficulty = "Difficult"
    if _DangerLevel >= 5 then
        _Difficulty = "Extreme"
    end
    if _DangerLevel == 10 then
        _Difficulty = "Death Sentence"
    end
    
    local _Description = formatDescription()

    local baseRewardTable = {
        100000,
        105000, --+5k
        110000, --+5k
        115000, --+5k
        125000, --+10k
        135000, --+10k
        145000, --+10k
        160000, --+15k
        175000, --+15k
        200000  --+25k
    }

    local baseReward = baseRewardTable[_DangerLevel] * _DangerLevel
    if insideBarrier then
        baseReward = baseReward * 2
    end

    reward = ESCCUtil.clampToNearest(baseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates()), 100000, "Up")

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/annihilatorium.lua",
        formatArguments = { _X = target.x, _Y = target.y, reward = createMonetaryString(reward)},
        msg = "Step right up! Come on down to \\s(%1%:%2%)!",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/annihilatorium.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept an additional arena mission! Abandon your current one or complete it.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments._X, self.formatArguments._Y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = target,
            reward = {credits = reward, relations = 8000, paymentMessage = "Earned %1% credits for defeating all challengers."},
            dangerLevel = _DangerLevel,
            initialDesc = _Description
        }},
    }

    return bulletin
end

--endregion