--[[
    NOTES:
    1b - Steel in the Twilight
		i - Gather intel
        ii - Get betrayed
            a - the betrayal is a pirate ambush of 10 ships from the standard threat table.
            b - once the player has destroyed 5 ships, a second group of 5 ships from the high threat table jumps in.
		iii - Confront betrayer
        iv - Destroy pirate shipment I
            a - if the player fails to destroy the freighters within X seconds, they will jump to a random nearby sector and the player will have to pursue them.
            b - it will spawn a new group of escorts each time.
            c - the danger level will increase by 1 each time a jump happens.
        v - Destroy pirate shipment II
            a - same as above, but +1 escort ship.
        vi - Pick up materiel
            a - just grabbing a couple of containers. No twist here. Wind-down before the big climax of this mission.
        vii - deliver to cavaliers
            a - deliver to cavaliers. Show off a big cavalier custom ship before cavs warp out. Use Grandmaster Template until I have a better one.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes..
include("callable")
include("randomext")
include("structuredmission")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include("pirategenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local ShipGenerator = include("shipgenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local Balancing = include ("galaxy")
local ShipUtility = include ("shiputility")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission.tracing = false
mission._Name = "Steel in the Twilight"

mission.data.custom.containerIds = {}

--region #INIT

local llte_storymission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Steel in the Twilight Begin...")

    if onServer()then
        if not _restoring then
            --Standard mission data.
            mission.data.brief = "Steel in the Twilight"
            mission.data.title = "Steel in the Twilight"
			mission.data.icon = "data/textures/icons/cavaliers.png"
			mission.data.priority = 9
            mission.data.description = { 
                "With The Family and The Commune defeated, The Cavaliers are getting ready to take the next step.",
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false },
                --If any of these have an X / Y coordinate, they will be updated with the correct location when starting the appropriate phase.
				{ text = "Contact the informants in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Destroy the pirates in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }, 
				{ text = "Return to (${_X}:${_Y}) and contact the traitor", bulletPoint = true, fulfiled = false, visible = false },
				{ text = "According to the informant, the first shipment is in sector (${_X}:${_Y}). Intercept and destroy it", bulletPoint = true, fulfiled = false, visible = false }, 
                { text = "Intercept and destroy the second shipment in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }, 
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Pick up the materiel in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Rendevous with The Cavaliers in sector (${_X}:${_Y}) with the materiel", bulletPoint = true, fulfilled = false, visible = false }
            }

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .informantSector
                .ambushSector
                .shipment1Sector
                .containerSector
                .containerDropoffSector
                .builtInformantSector
                .pirateLevel
                .smugglerOutpostid
                .ambushSpawned
                .ambushWave2Spawned
                .ambushWave2Taunted
                .shipmentSpawned
                .shipmentJumps
                .shipmentEscortsSpawned
                .containerIds
                .spawnedCavaliers
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable. I do, however, do something interesting with this here ;)
            mission.data.custom.shipmentJumps = 0

            local missionReward = 400000

            missionData_in = {location = nil, reward = {credits = missionReward}}
    
            llte_storymission_init(missionData_in)
        else
            --Restoring
            llte_storymission_init()
            if mission.currentPhase == mission.phases[8] then
                registerMarkContainers(true) --Reregister client callback.
            end
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
mission.globalPhase.updateServer = function(_TimeStep)
    local _MethodName = "Global Phase On Update Server"
    if (mission.currentPhase == mission.phases[5] or mission.currentPhase == mission.phases[6]) and mission.data.custom.shipmentJumps > 5 then
        mission.Log(_MethodName, "Failing")
        Player():sendChatMessage("Nav Computer", 0, "Hyperspace Signature of the target freighters has been lost.")
        fail()
    end
end

mission.globalPhase.onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    registerMarkContainers(false)
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        --The container sector is deleted and regenerated each time the player comes and goes, so it is not necessary to do anything with it here.
        if mission.data.custom.informantSector then
            local _MX, _MY = mission.data.custom.informantSector.x, mission.data.custom.informantSector.y
            Galaxy():loadSector(_MX, _MY)
            invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
        end
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.informantSector =  getNextLocation(true)
    local _X, _Y = mission.data.custom.informantSector.x, mission.data.custom.informantSector.y
    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_X, _Y)
	local _Player = Player()
    local _Mail = Mail()
	_Mail.text = Format("Hello squire!\n\nNow that we have dealt with The Family and The Commune, we can turn our attention towards our mission. We will cleanse the pirates and the Xsotan, bringing safety and justice to the galaxy.\nWe have heard rumors about a particularly powerful group of pirates gathering near the barrier. This will not stand. The Xsotan can be dealt with in due time, but these pirates represent an immediate threat.\n\nI am organizing an assault against them, but we must approach this with caution. Our days of carelessly throwing away lives for the cause died with the emperor.\nGo to (%1%:%2%). We have some contacts there who might be able to tell us more about these pirates.\n\nEmpress Adriana Stahl", _X, _Y)
	_Mail.header = "Taking the Next Step"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story1_mail1"
	_Player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_story1_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.informantSector
    mission.data.description[2].fulfilled = true
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    --Simulate a smuggler outpost. We can delete all of this once the player leaves the 2nd time.
    mission.data.custom.ambushSector = getNextLocation(false)
    buildSmugglerSector(_X, _Y)
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.ambushSector
    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[4].visible = true
end

mission.phases[3].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 3 on Enter Target Location"
    mission.Log(_MethodName, "Beginning...")

    --Spawn pirate ambushers.
    if not mission.data.custom.ambushSpawned then

        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 10, "Standard")
        local _CreatedPirateTable = {}

        for _, _Pirate in pairs(_PirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end
        _CreatedPirateTable[1]:addScript("player/missions/empress/story/story1/lltestory1ambushleader.lua")

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)

        mission.data.custom.ambushSpawned = true
    end
end

mission.phases[3].updateTargetLocationServer = function(_TimeStep)
    --Check for pirate ambushers left.
    local _MethodName = "Phase 3 Update Server"
    local _PirateCount = ESCCUtil.countEntitiesByValue("is_pirate")

    if not mission.data.custom.ambushWave2Spawned and _PirateCount <= 5 then

        local _Generator = AsyncPirateGenerator(nil, onAmbush2PiratesGenerated)
        local _WaveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 5, "High")

        _Generator:startBatch()
    
        local posCounter = 1
        local distance = 250 --_#DistAdj

        local pirate_positions = _Generator:getStandardPositions(#_WaveTable, distance)
        for _, p in pairs(_WaveTable) do
            _Generator:createScaledPirateByName(p, pirate_positions[posCounter])
            posCounter = posCounter + 1
        end
    
        _Generator:endBatch()
        
        mission.data.custom.ambushWave2Spawned = true
    end

    if _PirateCount == 0 then
        nextPhase()
    end
end

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].noBossEncountersTargetSector = true
mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.informantSector
    mission.data.description[4].fulfilled = true
    mission.data.description[5].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[5].visible = true
end

mission.phases[4].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 4 on Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    --Simulate a smuggler outpost. We can delete all of this once the player leaves the 2nd time.
    mission.data.custom.shipment1Sector = getNextLocation(false)
    local _Station = Entity(mission.data.custom.smugglerOutpostid)
    _Station:removeScript("lltestory1dialogue1.lua")
    _Station:addScript("player/missions/empress/story/story1/lltestory1dialogue2.lua")
end

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].noBossEncountersTargetSector = true
mission.phases[5].onBeginServer = function()
    local _MethodName = "Phase 5 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.shipment1Sector
    mission.data.description[5].fulfilled = true
    mission.data.description[6].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[6].visible = true
    --We should still be in the same sector as the station.
    local _Station = Entity(mission.data.custom.smugglerOutpostid)
    if _Station and valid(_Station) then
        _Station:removeScript("lltestory1dialogue2.lua")
    end
end

mission.phases[5].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 3 on Enter Target Location"
    mission.Log(_MethodName, "Beginning...")
    
    --Spawn pirate ambushers.
    if not mission.data.custom.shipmentSpawned then
        --We have to set spawned in the callback or else the phase will advance instantly before the async generator can create the ships.
        --see onFreightersFinished
        spawnFreighters(_X, _Y)
    end

    if not mission.data.custom.shipmentEscortsSpawned then
        spawnFreighterEscort()
        mission.data.custom.shipmentEscortsSpawned = true
    end

    local _TimeToJump = 35 + (mission.data.custom.shipmentJumps * 18)
    mission.Log(_MethodName, "Freighters jumping in " .. tostring(_TimeToJump))
    mission.phases[5].timers[1] = { time = _TimeToJump, callback = function() jumpFreighters() end, repeating = false}
end

mission.phases[5].updateTargetLocationServer = function(_TimeStep)
    local _MethodName = "Phase 5 Update Server"
    local _FreighterCount = ESCCUtil.countEntitiesByValue("_llte_story1_freighter")

    if _FreighterCount == 0 and mission.data.custom.shipmentSpawned then
        nextPhase()
    end
end

mission.phases[6] = {}
mission.phases[6].timers = {}
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].noBossEncountersTargetSector = true
mission.phases[6].onBeginServer = function()
    local _MethodName = "Phase 6 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = getNextLocation(false)
    mission.data.description[6].fulfilled = true
    mission.data.description[7].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[7].visible = true
    --Reset shipment spawn / escort spawn / jumps. Danger level does NOT reset. Better kill them quickly ;)
    mission.data.custom.shipmentSpawned = false
    mission.data.custom.shipmentEscortsSpawned = false
    mission.data.custom.shipmentJumps = 0
end

mission.phases[6].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 3 on Enter Target Location"
    mission.Log(_MethodName, "Beginning...")
    
    --Spawn pirate ambushers.
    if not mission.data.custom.shipmentSpawned then
        spawnFreighters(_X, _Y)
    end

    if not mission.data.custom.shipmentEscortsSpawned then
        spawnFreighterEscort()
        mission.data.custom.shipmentEscortsSpawned = true
    end

    local _TimeToJump = 35 + (mission.data.custom.shipmentJumps * 18)
    mission.Log(_MethodName, "Freighters jumping in " .. tostring(_TimeToJump))
    mission.phases[6].timers[1] = { time = _TimeToJump, callback = function() jumpFreighters() end, repeating = false}
end

mission.phases[6].updateTargetLocationServer = function(_TimeStep)
    local _MethodName = "Phase 5 Update Server"
    local _FreighterCount = ESCCUtil.countEntitiesByValue("_llte_story1_freighter")

    if _FreighterCount == 0 and mission.data.custom.shipmentSpawned then
        nextPhase()
    end
end

mission.phases[7] = {}
mission.phases[7].showUpdateOnEnd = true
mission.phases[7].noBossEncountersTargetSector = true
mission.phases[7].onBeginServer = function()
    local _MethodName = "Phase 7 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = nil
    mission.data.custom.containerSector = getNextLocation(false)
    local _X, _Y = mission.data.custom.containerSector.x, mission.data.custom.containerSector.y
    --Find a second location to drop off the containers at. Make sure it's different from containerSector
    local _FoundDropoff = false
    local _TempLocation
    while not _FoundDropoff do
        _TempLocation = getNextLocation(false)
        if _TempLocation.x ~= _X or _TempLocation.y ~= _Y then
            _FoundDropoff = true
        end
    end
    mission.data.custom.containerDropoffSector = _TempLocation
    local _DX, _DY = mission.data.custom.containerDropoffSector.x, mission.data.custom.containerDropoffSector.y
    mission.data.description[7].fulfilled = true
    mission.data.description[8].visible = true
    local _Player = Player()
    local _Mail = Mail()
    --This is the last time she says "Hello squire!" a la Boxelware.
	_Mail.text = Format("Hello squire!\n\nOur informant tells me that you've been quite busy! Thank you for your help so far. We've tracked down the pirates and we're making final preparations for our assault.\nHowever, we're spread a little thin and we could use your help with one last job.\nWe've got a couple of containers in sector (%1%:%2%) that have materiel that we'll need to pull this off.\nOnce you've picked them up, head to (%3%:%4%). We'll meet you there. Make sure your ship has a couple of docks to grab the containers!\n\nEmpress Adriana Stahl", _X, _Y, _DX, _DY)
	_Mail.header = "Container Pickup"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story1_mail2"
	_Player:addMail(_Mail)
end

mission.phases[7].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_story1_mail2" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[8] = {}
mission.phases[8].showUpdateOnEnd = true
mission.phases[8].noBossEncountersTargetSector = true
mission.phases[8].onBeginServer = function()
    local _MethodName = "Phase 8 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.containerSector
    mission.data.description[8].fulfilled = true
    mission.data.description[9].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[9].visible = true
end

mission.phases[8].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 8 on Enter Target Location"
    mission.Log(_MethodName, "Beginning...")

    buildContainerSector(_X, _Y)
    registerMarkContainers(true) --We don't deregister this until the start of the next phase.
end

mission.phases[8].updateTargetLocationServer = function(_TimeStep)
    local _MethodName = "Phase 8 on Update Target Location"

    --Get the player ship.
    local _PlayerShip = Player().craft
    local _PlayerClamps = DockingClamps(_PlayerShip)
    --Get all docked entities.
    if _PlayerClamps then
        local _DockedStoryContainers = 0
        local _DockedEntityids = {_PlayerClamps:getDockedEntities()} --DOES NOT GIVE ENTITIES - GIVES IDS
        --Leave this commented out unless you want to go nuts with the # of console messages.
        --mission.Log(_MethodName, tostring(#_DockedEntityids) .. " docked entities.")
        for _, _Docked in pairs(_DockedEntityids) do 
            local _DockedEntity = Entity(_Docked)
            if _DockedEntity:getValue("_llte_story1_markcontainer") then
                _DockedStoryContainers = _DockedStoryContainers + 1
            end
        end
        --If the player has 2 docked entities with the _llte_story1_markcontainer value set, advance to the next phase.
        --mission.Log(_MethodName, tostring(_DockedStoryContainers) .. " docked")
        if _DockedStoryContainers >= 2 then
            nextPhase()
        end
    end
end

mission.phases[9] = {}
mission.phases[9].timers = {}
mission.phases[9].noBossEncountersTargetSector = true
mission.phases[9].onBeginServer = function()
    local _MethodName = "Phase 9 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    registerMarkContainers(false)
    mission.data.location = mission.data.custom.containerDropoffSector
    mission.data.description[9].fulfilled = true
    mission.data.description[10].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[10].visible = true
end

mission.phases[9].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 9 On Enter Target Location"
    --Start a timer to spawn the Cavaliers if the player has both containers. If they don't, just move back to phase 8.
    --Looks like I'm less lazy than Boxelware :D
    mission.Log(_MethodName, "Starting timer.")
    if ESCCUtil.countEntitiesByValue("_llte_story1_markcontainer") >= 2 then
        mission.phases[9].timers[1] = { time = 5, callback = function() 
            local _Xloc, _Yloc = Sector():getCoordinates()
            spawnCavaliersShips(_Xloc, _Yloc)
         end, repeating = false}
    else
        mission.phases[9].timers[1] = { time = 2, callback = function() 
            --If the player didn't bring the containers, go back a phase.
            
            mission.data.description[9].fulfilled = false
            mission.data.description[10].visible = false
            setPhase(8)
            showMissionUpdated(mission.data.title)
         end, repeating = false}
    end
    
end

--endregion

--region #SERVER CALLS

--region #SPAWN INITIAL OBJECTS

function buildSmugglerSector(_X, _Y)
    local _MethodName = "Build Main Sector"
    if not mission.data.custom.builtInformantSector then
        mission.Log(_MethodName, "Sector not built yet. Beginning...")

        --Sector should always have 2-3 small asteroid fields, 1 large asteroid field, and a smuggler outpost.
        local _Generator = SectorGenerator(_X, _Y)
        local _Rgen = ESCCUtil.getRand()

        --Get a smuggler faction.
        mission.Log(_MethodName, "Building smuggler outpost.")
        local _SmugglerFaction = MissionUT.getMissionSmugglerFaction()

        local _SmugglerOutpost = _Generator:createStation(_SmugglerFaction, "merchants/smugglersmarket.lua")
        _SmugglerOutpost.title = "Smuggler Hideout"%_t
        _SmugglerOutpost:addScript("merchants/tradingpost.lua")
        _SmugglerOutpost:addScript("player/missions/empress/story/story1/lltestory1dialogue1.lua", mission.data.custom.ambushSector.x, mission.data.custom.ambushSector.y)
        mission.data.custom.smugglerOutpostid = _SmugglerOutpost.id

        for _ = 1, _Rgen:getInt(1, 2) do
            local ship = ShipGenerator.createDefender(_SmugglerFaction, _Generator:getPositionInSector())
            ship:removeScript("antismuggle.lua")
        end

        for _ = 1, _Rgen:getInt(2, 3) do
            _Generator:createSmallAsteroidField()
        end

        _Generator:addOffgridAmbientEvents()
        Placer.resolveIntersections()

        mission.data.custom.builtInformantSector = true
        sync()
    end
end

function buildContainerSector(_X, _Y)
    local _MethodName = "Build Container Sector"
    local _Generator = SectorGenerator(_X, _Y)
    local _Rgen = ESCCUtil.getRand()

    mission.Log(_MethodName, "Clearing container IDs")
    mission.data.custom.containerIds = {}

    --Attach deletion scripts before anything else, just in case something goes wrong here.
    local _EntityTypes = { EntityType.None, EntityType.Container, EntityType.Ship, EntityType.Station, EntityType.Torpedo, EntityType.Fighter, EntityType.Asteroid, EntityType.Wreckage, EntityType.Unknown, EntityType.Other, EntityType.Loot }
    Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)

    for _ = 1, 2 do
        _Generator:createSmallAsteroidField()
    end
    _Generator:createContainerField()
    --Mark two randomly chosen containers.
    local _PossibleContainers = {Sector():getEntities()}
    local _DefinitelyContainers = {}
    for _, _En in pairs(_PossibleContainers) do
        if _En.title == "Container" then
            table.insert(_DefinitelyContainers, _En)
        end
    end
    mission.Log(_MethodName, #_DefinitelyContainers .. " Containers found. Picking two at random to mark.")

    shuffle(_Rgen, _DefinitelyContainers)
    for cidx = 1, 2 do
        local _Ctr = _DefinitelyContainers[cidx]
        mission.Log(_MethodName, "Marked container. " .. tostring(_Ctr.id))
        _Ctr:setValue("_llte_story1_markcontainer", true)
        table.insert(mission.data.custom.containerIds, _Ctr.id)
    end
    
    --Need to sync the container IDs to the client to mark them properly.
    mission.Log(_MethodName, "Syncing.")
    sync()
end

function spawnCavaliersShips(_X, _Y)
    local _MethodName = "Spawn Cavaliers Ships"
    local _Faction =  Galaxy():findFaction("The Cavaliers")
    local _Plan = LoadPlanFromFile("data/plans/cavaliersboss.xml")
    local _Scale = 3.0

    _Plan:scale(vec3(_Scale, _Scale, _Scale))

    local _EmpressBlade = Sector():createShip(_Faction, "", _Plan, PirateGenerator.getGenericPosition())
    _EmpressBlade.name = "Blade of the Empress"
    _EmpressBlade.title = "Adriana's Flagship"

    ShipUtility.addBossAntiTorpedoEquipment(_EmpressBlade)
    ShipUtility.addScalableArtilleryEquipment(_EmpressBlade, 5, 1, false)
    ShipUtility.addScalableArtilleryEquipment(_EmpressBlade, 5, 1, false)

    _EmpressBlade.crew = _EmpressBlade.idealCrew
    _EmpressBlade:addScript("icon.lua", "data/textures/icons/pixel/cavaliers.png")
    _EmpressBlade:setValue("_llte_empressblade", true)
    _EmpressBlade:setValue("is_cavaliers", true)
    _EmpressBlade.damageMultiplier = (_EmpressBlade.damageMultiplier or 1) * 5

    Boarding(_EmpressBlade).boardable = false
    _EmpressBlade.dockable = false

    mission.Log(_MethodName, "Adding script to flagship.")
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")

    _EmpressBlade:addScript("player/missions/empress/story/story1/lltestory1empressblade.lua", _Player.name, _Rank)
    
    local _Generator = AsyncShipGenerator(nil, onCavaliersFinished)
    _Generator:startBatch()

    for _ = 1, 3 do
        _Generator:createDefender(_Faction, PirateGenerator.getGenericPosition())
    end
    for _ = 1, 2 do
        _Generator:createHeavyDefender(_Faction, PirateGenerator.getGenericPosition())
    end
    
    _Generator:endBatch()
end

--endregion

function getNextLocation(_FirstLocation)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    if _FirstLocation then
        --Get a sector that's very close to the outer edge of the barrier.
        mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, Balancing.BlockRingMax + 2)
        target.x, target.y = MissionUT.getEmptySector(_Nx, _Ny, 3, 6, false)
        local _safetyBreakout = 0
        while target.x == x and target.y == y and _safetyBreakout <= 100 do
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 3, 6, false)
            _safetyBreakout = _safetyBreakout + 1
        end
    else
        target.x, target.y = MissionUT.getEmptySector(x, y, 5, 12, false)
    end

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

--First Ambush
function onAmbush2PiratesGenerated(_Generated)
    local _MethodName = "On 2nd Pirate Wave Ambush Generated"
    mission.Log(_MethodName, "Beginning...")

    SpawnUtility.addEnemyBuffs(_Generated)

    if not mission.data.custom.ambushWave2Taunted then
        mission.Log(_MethodName, "Broadcasting Pirate Taunt to Sector")
        mission.Log(_MethodName, "Entity: " .. tostring(_Generated[1].id))

        local _Lines = {
            "You're a long way from home, aren't you?",
            "We'll tear you to pieces!",
            "All ships, weapons to full! Engage! Engage! Engage!",
            "Kill them all! Hahahaha!"
        }

        Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(_Lines))
        mission.data.custom.ambushWave2Taunted = true
    end

end

--Freighters
function spawnFreighters(_X, _Y)
    --Spawn 5 large freighters and 6 escorts. Start a jump timer that's equal to the # of shipment 1 jumps * 15 seconds.
    local _ShipGenerator = AsyncShipGenerator(nil, onFreightersFinished)
    local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * 8
    local _Vol2 = Balancing_GetSectorShipVolume(_X, _Y) * 11
    local _Faction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)

    local look = vec3(1, 0, 0)
    local up = vec3(0, 1, 0)

    _ShipGenerator:startBatch()

    _ShipGenerator:createFreighterShip(_Faction, MatrixLookUpPosition(look, up, vec3(100, 50, 50)), _Vol1)
    _ShipGenerator:createFreighterShip(_Faction, MatrixLookUpPosition(look, up, vec3(0, -50, 0)), _Vol1)
    _ShipGenerator:createTradingShip(_Faction, MatrixLookUpPosition(look, up, vec3(-100, -50, -50)), _Vol1)
    _ShipGenerator:createFreighterShip(_Faction, MatrixLookUpPosition(look, up, vec3(-200, 50, -50)), _Vol2)
    _ShipGenerator:createFreighterShip(_Faction, MatrixLookUpPosition(look, up, vec3(-300, -50, 50)), _Vol2)

    _ShipGenerator:endBatch()
end

function onFreightersFinished(_Generated)
    local _MethodName = "On Pirate Freighters Generated"

    for _, _F in pairs(_Generated) do
        _F:setValue("_llte_story1_freighter", true)
        _F:setValue("is_pirate", true)
        _F:removeScript("civilship.lua")
        _F:removeScript("dialogs/storyhints.lua")
        _F:setValue("is_civil", nil)
        _F:setValue("is_freighter", nil)
        _F:setValue("npc_chatter", nil)
        Boarding(_F).boardable = false
    end

    mission.data.custom.shipmentSpawned = true
end

function jumpFreighters()
    local _Freighters = {Sector():getEntitiesByScriptValue("_llte_story1_freighter")}
    --This isn't timed for failure because of the amount of work the player has to do to get here. Imagine failing after going through phase 1-4.
    --That would SUCK. So since we're not timed, we don't particularly care about getting a non-blocked jumping route. The player will have more than
    --enough time to go around the rifts.
    local _JumpTo = getNextLocation(false)

    mission.data.location = _JumpTo
    if mission.data.custom.dangerLevel < 10 then
        --Maxes at 10.
        mission.data.custom.dangerLevel = mission.data.custom.dangerLevel + 1
    end
    mission.data.custom.shipmentJumps = mission.data.custom.shipmentJumps + 1
    --Allow escorts to spawn again when entering the new sector.
    mission.data.custom.shipmentEscortsSpawned = false
    local _DescriptonIndex = 6
    if mission.currentPhase == mission.phases[6] then
        _DescriptonIndex = 7
    end
    mission.data.description[_DescriptonIndex].text = "The freighters delivering the shipment have escaped to (${_X}:${_Y}). Track them down and destroy them"
    mission.data.description[_DescriptonIndex].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }

    --This should be one of the last things we do before syncing to prevent premature ending of the mission due to freighters still being left.
    for _, _F in pairs(_Freighters) do
        Sector():transferEntity(_F, _JumpTo.x, _JumpTo.y, SectorChangeType.Jump)
    end

    sync()
    Player():sendChatMessage("Nav Computer", 0, "The freighters have jumped to \\s(%1%,%2%).", _JumpTo.x, _JumpTo.y)
    showMissionUpdated("Steel in the Twilight")
end

function spawnFreighterEscort()
    local _MethodName = "Spawn Shipment Escort"
    mission.Log(_MethodName, "Spawning escorts at danger level " .. tostring(mission.data.custom.dangerLevel))
    local _PirateGenerator = AsyncPirateGenerator(nil, onFreighterEscortFinished)
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, "Standard")

    _PirateGenerator:startBatch()
    _PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    for _, _Pirate in pairs(_PirateTable) do
        _PirateGenerator:createPirateByName(_Pirate, _PirateGenerator.getGenericPosition())
    end

    _PirateGenerator:endBatch()
end

function onFreighterEscortFinished(_Generated)
    local _MethodName = "On Freighter Escorts Generated"
    SpawnUtility.addEnemyBuffs(_Generated)
end

function onCavaliersFinished(_Generated)
    local _MethodName = "On Cavaliers Finished"
    for _, _S in pairs(_Generated) do
        _S.title = "Cavaliers " .. _S.title
        _S:removeScript("antismuggle.lua")
        _S:setValue("npc_chatter", nil)
        _S:setValue("is_cavaliers", true)
        LLTEUtil.rebuildShipWeapons(_S, Player():getValue("_llte_cavaliers_strength"))
    end
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()
    _Player:setValue("_llte_story_1_accomplished", true)

    local _WinMsgTable = {
        "Great job, " .. _Rank .. "!"
    }

    --Increase reputation by 1
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + 3)
    _Player:sendChatMessage("Adriana Stahl", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " Here is your reward, as promised.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onMarkContainers()
    local _MethodName = "On Mark Containers"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    for _, _ContainerID in pairs(mission.data.custom.containerIds) do
        local entity = Entity(_ContainerID)
        if not entity then return end

        local _ContainerMarkOrange = ESCCUtil.getSaneColor(255, 173, 0)

        renderer:renderEntityTargeter(entity, _ContainerMarkOrange)
        renderer:renderEntityArrow(entity, 30, 10, 250, _ContainerMarkOrange)
    end

    renderer:display()
end

--endregion

--region #CLIENT / SERVER CALLS

function registerMarkContainers(_Register)
    local _MethodName = "Register Mark Containers"
    if onClient() then
        _MethodName = _MethodName .. " CLIENT"
        local _Msg = "onPreRenderHud callback."
        if _Register then
            _Msg = "Registering " .. _Msg
        else
            _Msg = "Unregistering " .. _Msg
        end
        mission.Log(_MethodName, _Msg)

        local _Player = Player()
        if _Register then
            if _Player:registerCallback("onPreRenderHud", "onMarkContainers") == 1 then
                mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
            end
        else
            if _Player:unregisterCallback("onPreRenderHud", "onMarkContainers") == 1 then
                mission.Log(_MethodName, "WARNING - Could not detach prerender callback to script.")
            end
        end
    else
        _MethodName = _MethodName .. " SERVER"
        mission.Log(_MethodName, "Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkContainers", _Register)
    end
end

function contactedInformant()
    local _MethodName = "Contacted Informant"
    
    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("contactedInformant")
    else
        mission.Log(_MethodName, "Calling on Server")
        nextPhase()
    end
end
callable(nil, "contactedInformant")

function contactedTraitor()
    local _MethodName = "Contacted Traitor"

    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("contactedTraitor")
    else
        mission.Log(_MethodName, "Calling on Server")
        nextPhase()
    end
end
callable(nil, "contactedTraitor")

function contactedAdriana()
    local _MethodName = "Contacted Adriana"

    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("contactedAdriana")
    else
        mission.Log(_MethodName, "Calling on Server")
        --We win. All of the cavaliers ships jump EXCEPT for The Blade of the Empress out and we finish the mission.
        local _Rgen = ESCCUtil.getRand()
        local _Cavaliers = {Sector():getEntitiesByScriptValue("is_cavaliers")}
        for _, _Cav in pairs(_Cavaliers) do
            if not _Cav:getValue("_llte_empressblade") then
                _Cav:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(4, 8))
            end
        end
        --Clean out the informant sector. The container sector is self-cleaning.
        local _MX, _MY = mission.data.custom.informantSector.x, mission.data.custom.informantSector.y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
        --Delete everything on the player leaving.
        local _EntityTypes = { EntityType.None, EntityType.Container, EntityType.Ship, EntityType.Station, EntityType.Torpedo, EntityType.Fighter, EntityType.Asteroid, EntityType.Wreckage, EntityType.Unknown, EntityType.Other, EntityType.Loot }
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
        finishAndReward()
    end
end
callable(nil, "contactedAdriana")

--endregion