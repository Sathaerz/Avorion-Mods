--[[
    MISSION 2: Swordfish
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
HorizonUtil = include("horizonutil")

local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include("pirategenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local ShipGenerator = include("shipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include("shiputility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Swordfish"

--region #INIT / DATA

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/snowflake-2.png"
mission.data.priority = 9
mission.data.description = {
    { text = "After defeating the pirates, you've found an encrypted data chip. Varlance said that he knows someone who can break it, but you'll have to find them first..." },
    { text = "Read Varlance's mail", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to the hacker at the Smuggler Hideout", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Do tasks around the sector - talk to the hacker to figure out what needs to be done", bulletPoint = true, fulfilled = false, visible = false },
    { text = "(Optional) Fetch the marked container", bulletPoint = true, fulfilled = false, visible = false },
    { text = "(Optional) Deploy the satellite", bulletPoint = true, fulfilled = false, visible = false },
    { text = "(Optional) Destroy asteroids", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Get the hacker to agree to help you", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Get the artifact from the hideout", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Deliver the Artifact to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Kill the attacking pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Return to (${_X}:${_Y}) and speak with Mace", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 10 --Key everything off of danger 10.
mission.data.custom.annoyedHacker = 0
mission.data.custom.doneContainerJob = false
mission.data.custom.doneSatelliteJob = false 
mission.data.custom.destroyAsteroidJob = false
mission.data.custom.threeJobsDone = false
mission.data.custom.ambushPiratesSpawned = false

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    unregisterMarkContainer()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    unregisterMarkContainer()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    unregisterMarkContainer()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    --Get a sector that's very close to the outer edge of the barrier.
    mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))

    mission.data.custom.hackerSector = getNextLocation(true)

    local _X = mission.data.custom.hackerSector.x
    local _Y = mission.data.custom.hackerSector.y

    mission.data.description[3].arguments = { _X = mission.data.custom.hackerSector.x, _Y = mission.data.custom.hackerSector.y }
    mission.data.description[13].arguments = { _X = mission.data.custom.hackerSector.x, _Y = mission.data.custom.hackerSector.y }

    --Send mail to player.
    local _player = Player()
    local _Mail = Mail()
	_Mail.text = Format("Hey, captain.\n\nIt's me, Varlance - your old buddy from smashing the pirate fleet. I'd love to catch up, but I'll cut to the chase. Found the hacker I mentioned the other day.\nThey've been spending time at a local smuggler's outpost recently. You'll find it at (%1%:%2%). I'll meet you there.\n\nVarlance", _X, _Y)
	_Mail.header = "Found the Hacker"
	_Mail.sender = "Varlance @FrostbiteCompany"
	_Mail.id = "_horizon_story2_mail1"
	_player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_playerIndex, _MailIndex)
			if onServer() then
				local _player = Player()
				local _Mail = _player:getMail(_MailIndex)
				if _Mail.id == "_horizon_story2_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin= function()
    local _MethodName = "Phase 2 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.hackerSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    if onServer() then
        --Simulate a smuggler outpost. We can delete all of this once the player leaves the 2nd time.
        mission.data.custom.deliverToSector = getNextLocation(false)
        mission.data.description[11].arguments = { _X = mission.data.custom.deliverToSector.x, _Y = mission.data.custom.deliverToSector.y }
        buildSmugglerSector(_X, _Y)
        spawnVarlance()
        sync()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(_X, _Y)
    HorizonUtil.varlanceChatter("There it is. Get close and you'll be able to make contact. I'll give you the frequency.")
    nextPhase()
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBegin = function()
    local _MethodName = "Phase 3 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
end

mission.phases[3].onBeginServer = function()
    --We need to figure out a few important values here - first of all, how many asteroids to blow up.
    --Second, the container to fetch.
    local _Sector = Sector()

    mission.data.custom.asteroidCount = #{ _Sector:getEntitiesByType(EntityType.Asteroid) }

    local _Containers = { _Sector:getEntitiesByType(EntityType.Container) }
    shuffle(random(), _Containers)

    mission.data.custom.targetContainer = _Containers[1].id
end

local onPhase3DialogEnd = makeDialogServerCallback("onPhase3DialogEnd", 3, function()
    nextPhase()
end)

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    local _MethodName = "Phase 4 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[4].onBeginServer = function()
    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
    _SmugglerOutpost:removeScript("player/missions/horizon/story2/horizonstory2dialog1.lua")
    _SmugglerOutpost:addScriptOnce("player/missions/horizon/story2/horizonstory2dialog2.lua")

    local _Varlance = Entity(mission.data.custom.varlanceID)
    _Varlance:invokeFunction("torpedoslammer.lua", "resetTimeToActive", 0)
end

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBegin = function()
    local _MethodName = "Phase 5 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[6].visible = true
    mission.data.description[7].visible = true
    mission.data.description[8].visible = true
    mission.data.description[9].visible = true
end

mission.phases[5].onBeginServer = function()
    local _dX = mission.data.custom.deliverToSector.x --_deliverX / _deliveryY
    local _dY = mission.data.custom.deliverToSector.y
    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
    _SmugglerOutpost:removeScript("player/missions/horizon/story2/horizonstory2dialog2.lua")
    _SmugglerOutpost:addScriptOnce("player/missions/horizon/story2/horizonstory2dialog3.lua", _dX, _dY)

    --Give the player the satellite package.
    local item = UsableInventoryItem("horizon2satellitepkg.lua", Rarity(RarityType.Exceptional))
    Player():getInventory():add(item, true)

    registerMarkContainer()
end

--region #PHASE 5 TIMER CALLS

if onServer() then

mission.phases[5].timers[1] = { --Check asteroid job.
    time = 10,
    callback = function()
        local _MethodName = "Phase 5 Timer 1 Callback"
        local _Sector = Sector()
        if atTargetLocation() and not mission.data.custom.destroyAsteroidJob then
            local _AsteroidCt = #{ _Sector:getEntitiesByType(EntityType.Asteroid) }
            local _TargetAsteroidNumber = math.floor(mission.data.custom.asteroidCount * 0.95)

            if _AsteroidCt <= _TargetAsteroidNumber then
                mission.Log(_MethodName, "Asteroid job done.")

                local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
                _SmugglerOutpost:setValue("horizon2_asteroidjob_done", true)
                _SmugglerOutpost:setValue("horizon2_job_done", true)

                mission.data.description[8].fulfilled = true
                mission.data.custom.destroyAsteroidJob = true
                sync()

                spawnLocalTransport()
            end
        end
    end,
    repeating = true
}

mission.phases[5].timers[2] = { --Check satellite job
    time = 10,
    callback = function()
        local _MethodName = "Phase 5 Timer 2 Callback"
        local _Sector = Sector()
        if atTargetLocation() and not mission.data.custom.doneSatelliteJob then
            local _Satellites = { _Sector:getEntitiesByScriptValue("horizon2_research_satellite") }

            if #_Satellites > 0 then
                local _Satellite = _Satellites[1]

                local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
    
                local _Dist = _SmugglerOutpost:getNearestDistance(_Satellite)
    
                if _Dist > 5000 then
                    mission.Log(_MethodName, "Satellite job done.")

                    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
                    _SmugglerOutpost:setValue("horizon2_satellitejob_done", true)
                    _SmugglerOutpost:setValue("horizon2_job_done", true)

                    mission.data.description[7].fulfilled = true
                    mission.data.custom.doneSatelliteJob = true
                    sync()

                    invokeClientFunction(Player(), "onPhase5StationDialog", mission.data.custom.smugglerOutpostid)
                end
            end
        end
    end,
    repeating = true
}

mission.phases[5].timers[3] = { --Check container job
    time = 10,
    callback = function()
        local _MethodName = "Phase 5 Timer 3 Callback"
        local _Sector = Sector()

        --If the player somehow destroys all the containers in the sector, fail. Otherwise, we just pick a new one.
        if atTargetLocation() and not mission.data.custom.doneContainerJob then
            local _Container = Entity(mission.data.custom.targetContainer)

            if not _Container or not valid(_Container) then
                local _Containers = { _Sector:getEntitiesByType(EntityType.Container) }

                if #_Containers > 0 then
                    shuffle(random(), _Containers)
            
                    mission.data.custom.targetContainer = _Containers[1].id
                    sync()
                else
                    fail()
                end
            else
                local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)

                local _Dist = _SmugglerOutpost:getNearestDistance(_Container)

                if _Dist < 300 then
                    mission.Log(_MethodName, "Container job done.")

                    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
                    _SmugglerOutpost:setValue("horizon2_containerjob_done", true)
                    _SmugglerOutpost:setValue("horizon2_job_done", true)

                    unregisterMarkContainer()

                    mission.data.description[6].fulfilled = true
                    mission.data.custom.doneContainerJob = true
                    sync()

                    local _SmugglerDefenders = { _Sector:getEntitiesByScriptValue("horizon2_smuggler_defender") }
                    if #_SmugglerDefenders > 0 then
                        shuffle(random(), _SmugglerDefenders)
                        invokeClientFunction(Player(), "onPhase5DefenderDialog",  _SmugglerDefenders[1].id)
                    else
                        spawnContainerJobDefender()
                    end
                end
            end
            
        end
    end,
    repeating = true
}

mission.phases[5].timers[4] = { --all three sub-jobs.
    time = 10,
    callback = function()
        if not mission.data.custom.threeJobsDone then
            if mission.data.custom.doneContainerJob and mission.data.custom.doneSatelliteJob and mission.data.custom.destroyAsteroidJob then
                mission.data.description[5].fulfilled = true
                mission.data.custom.threeJobsDone = true
                sync()
            end
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[6] = {}
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].onBegin = function()
    local _MethodName = "Phase 6 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[5].fulfilled = true
    mission.data.description[6].fulfilled = true
    mission.data.description[7].fulfilled = true
    mission.data.description[8].fulfilled = true
    mission.data.description[9].fulfilled = true
    mission.data.description[10].visible = true
end

mission.phases[6].onBeginServer = function()
    local _MethodName = "Phase 6 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    unregisterMarkContainer()

    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
    _SmugglerOutpost:removeScript("player/missions/horizon/story2/horizonstory2dialog3.lua")
    _SmugglerOutpost:addScriptOnce("player/missions/horizon/story2/horizonstory2dialog4.lua")
end

mission.phases[6].updateServer = function()
    local _player = Player()
    local _Ship = Entity(_player.craftIndex)

    if _Ship then
        for good, amount in pairs(_Ship:findCargos("Ancient Artifact")) do
            if amount > 0 then
                nextPhase()
                break
            end
        end
    end
end

mission.phases[7] = {}
mission.phases[7].timers = {}
mission.phases[7].showUpdateOnEnd = true
mission.phases[7].onBegin  = function()
    local _MethodName = "Phase 7 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.deliverToSector

    mission.data.description[10].fulfilled = true
    mission.data.description[11].visible = true
end

mission.phases[7].onBeginServer = function()
    local _MethodName = "Phase 7 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
    _SmugglerOutpost:removeScript("player/missions/horizon/story2/horizonstory2dialog4.lua")
end

mission.phases[7].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 7 on Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[11].fulfilled = true

    if onServer() then
        buildPirateAmbushSector()
    end
end

mission.phases[7].onTargetLocationLeft = function()
    mission.data.custom.ambushPiratesSpawned = false
end

mission.phases[7].onTargetLocationArrivalConfirmed = function(_X, _Y)
    --Get the player's current ship.
    local _player = Player()
    local _Ship = Entity(_player.craftIndex)

    --Then get the pirates.
    local _Pirates = { Sector():getEntitiesByScriptValue("is_pirate") }

    local _HasArtifact = false
    if _Ship then
        for good, amount in pairs(_Ship:findCargos("Ancient Artifact")) do
            if amount > 0 then
                _HasArtifact = true
                break
            end
        end
    end

    if _HasArtifact then
        invokeClientFunction(_player, "onPhase7PirateDialog", _Pirates[1].id)
    else
        invokeClientFunction(_player, "onPhase7PirateNoArtifactDialog", _Pirates[1].id)
    end
end

local onPhase7TakeArtifact = makeDialogServerCallback("onPhase7TakeArtifact", 7, function()
    --Get the player's current ship.
    local _player = Player()
    local _Ship = Entity(_player.craftIndex)

    if _Ship then
        for good, amount in pairs(_Ship:findCargos("Ancient Artifact")) do
            if amount > 0 then
                _Ship:removeCargo(good, amount)
                break
            end
        end
    end
end)

local onPhase7DialogFinish = makeDialogServerCallback("onPhase7DialogFinish", 7, function()
    mission.data.description[12].visible = true
    

    local _Pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    for _, _Pirate in pairs (_Pirates) do
        local ai = ShipAI(_Pirate)
        ai:clearFriendFactions()
    end

    sync()
end) 

--region #PHASE 7 TIMER CALLS

if onServer() then

mission.phases[7].timers[1] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 7 Timer 1 Callback"

        local _PirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

        if atTargetLocation() and _PirateCt <= 5 and not mission.data.custom.ambushPiratesSpawned then
            spawnPirateAmbush()
        end
    end,
    repeating = true
}

mission.phases[7].timers[2] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 7 Timer 2 Callback"

        local _PirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

        if atTargetLocation() and _PirateCt == 0 and mission.data.custom.ambushPiratesSpawned then
            nextPhase()
        end
    end,
    repeating = true
}

end
    
--endregion

mission.phases[8] = {}
mission.phases[8].timers = {}
mission.phases[8].onBegin = function()
    local _MethodName = "Phase 8 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.hackerSector

    mission.data.description[12].fulfilled = true
    mission.data.description[13].visible = true
end

mission.phases[8].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 8 on Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    if onServer() then
        local _SmugglerOutpost = Entity(mission.data.custom.smugglerOutpostid)
        _SmugglerOutpost:addScriptOnce("player/missions/horizon/story2/horizonstory2dialog5.lua")
    end
end

mission.phases[8].onSectorArrivalConfirmed = function(_X, _Y)
    if onServer() then
        HorizonUtil.varlanceChatter("Welcome back. I see your paint's a bit chipped. Fought hard, buddy?")
    end
end

local onPhase8DialogFinish = makeDialogServerCallback("onPhase8DialogFinish", 8, function()
    finishAndReward()
end)

--endregion

--region #SERVER CALLS

function getNextLocation(_onBlockRing)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    if _onBlockRing then
        --Get a sector that's very close to the outer edge of the barrier.
        mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, Balancing.BlockRingMax + 10)
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 3, 6, false)
        local _safetyBreakout = 0
        while target.x == x and target.y == y and _safetyBreakout <= 100 do
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 3, 6, false)
            _safetyBreakout = _safetyBreakout + 1
        end
    else
        target.x, target.y = MissionUT.getEmptySector(x, y, 6, 12, false)
    end

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function buildSmugglerSector(_X, _Y)
    local _MethodName = "Build Main Sector"
    
    mission.Log(_MethodName, "Sector not built yet. Beginning...")

    --Sector should always have 2-3 small asteroid fields, 1 large asteroid field, and a smuggler outpost.
    local _Generator = SectorGenerator(_X, _Y)
    local _Rgen = random()

    --Get a smuggler faction.
    mission.Log(_MethodName, "Building smuggler outpost.")
    local _SmugglerFaction = ESCCUtil.getNeutralSmugglerFaction()

    local _SmugglerOutpost = _Generator:createStation(_SmugglerFaction, "merchants/smugglersmarket.lua")
    _SmugglerOutpost.title = "Smuggler Hideout"%_t
    _SmugglerOutpost:setValue("horizon_story_player", Player().index)
    _SmugglerOutpost:setValue("horizon_story_jobs_done", 0)
    _SmugglerOutpost:addScript("merchants/tradingpost.lua")
    _SmugglerOutpost:addScriptOnce("player/missions/horizon/story2/horizonstory2dialog1.lua")
    mission.data.custom.smugglerOutpostid = _SmugglerOutpost.id

    _Generator:createShipyard(_SmugglerFaction)

    for _ = 1, 3 do
        local ship = ShipGenerator.createDefender(_SmugglerFaction, _Generator:getPositionInSector())
        ship:setValue("horizon2_smuggler_defender", true)
        ship:removeScript("antismuggle.lua")
    end

    for _ = 1, _Rgen:getInt(3, 5) do
        _Generator:createSmallAsteroidField()
    end

    _Generator:createAsteroidField()

    _Generator:createContainerField()

    _Generator:addOffgridAmbientEvents()
    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true

    sync()
end

function spawnContainerJobDefender()
    local xrand = random()

    local dir = xrand:getDirection()
    local pos = dir * xrand:getInt(1000, 1200)

    local onContainerDefenderFinished = function(ships)
        local _Defender = ships[1]

        _Defender:setValue("horizon2_smuggler_defender", true)
        _Defender:removeScript("antismuggle.lua")

        invokeClientFunction(Player(), "onPhase5DefenderDialog",  _Defender.id)
    end

    local _Faction = ESCCUtil.getNeutralSmugglerFaction()

    local generator = AsyncShipGenerator(nil, onContainerDefenderFinished)
    generator:startBatch()

    pos = pos + dir * 200
    local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)

    generator:createDefender(_Faction, matrix)

    generator:endBatch()
end

function spawnVarlance()
    local _MethodName = "Spawn Varlance"

    local _spawnVarlance = true
    if mission.data.custom.varlanceID then
        local _Varlance = Entity(mission.data.custom.varlanceID)
        if _Varlance and valid(_Varlance) and not _Varlance:getValue("varlance_withdrawing") then
            _spawnVarlance = false
        end
    end

    if _spawnVarlance then
        mission.Log(_MethodName, "No Varlance in sector - spawning him in.")

        local _Varlance = HorizonUtil.spawnVarlanceNormal(false)
        local _VarlanceAI = ShipAI(_Varlance)
    
        _VarlanceAI:setIdle()
        _VarlanceAI:setPassiveShooting(true)

        local _SmugglerHideout = Entity(mission.data.custom.smugglerOutpostid)
        local _Radius = _SmugglerHideout:getBoundingSphere().radius * 3

        local _VarlanceDurability = Durability(_Varlance)
        _VarlanceDurability.invincibility = 0.5

        local _VarlanceSlammerValues = {
            _ROF = 8,
            _DurabilityFactor = 50,
            _TimeToActive = math.huge,
            _DamageFactor = 10,
            _TargetPriority = 6,
            _ReachFactor = 2,
            _UseEntityDamageMult = true,
            _PreferBodyType = 9, --Hawk
            _PreferWarheadType = 4 --Tandem
        }

        _Varlance:addScriptOnce("torpedoslammer.lua", _VarlanceSlammerValues)

        _VarlanceAI:setFlyLinear(_SmugglerHideout.translationf, _Radius, false)

        mission.data.custom.varlanceID = _Varlance.index
    end
end

function spawnLocalTransport()
    local _MethodName = "Spawn Local Transport"

    mission.Log(_MethodName, "Running.")

    -- this is the position where the trader spawns
    local dir = random():getDirection()
    local pos = dir * 1500

    -- this is the position where the trader will jump into hyperspace
    local destination = -pos + vec3(math.random(), math.random(), math.random()) * 1000
    destination = normalize(destination) * 1500

    --use this for onfinished.
    local onTransportFinished = function(ships)
        local _MethodName = "On Transport Finished"
        local _Transport = ships[1]

        mission.Log(_MethodName, "Transport spawned. Setting destination.")

		ShipUtility.addCargoToCraft(_Transport)
        _Transport:addScriptOnce("ai/passsector.lua", destination)
        _Transport:setValue("passing_ship", true)

        Placer.resolveIntersections(ships)

        invokeClientFunction(Player(), "onPhase5FreighterDialog", _Transport.id, _Transport.translatedTitle)
    end

    local _Faction = ESCCUtil.getNeutralSmugglerFaction()

    local generator = AsyncShipGenerator(nil, onTransportFinished)
    generator:startBatch()

    pos = pos + dir * 200
    local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)

    generator:createFreighterShip(_Faction, matrix)

    generator:endBatch()
end

function buildPirateAmbushSector()
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard")
    local _CreatedPirateTable = {}

    for _, _Pirate in pairs(_PirateTable) do
        _Pirate = PirateGenerator.createScaledPirateByName(_Pirate, PirateGenerator.getGenericPosition())

        local _player = Player()
        local allianceIndex = _player.allianceIndex
        local ai = ShipAI(_Pirate)
        ai:registerFriendFaction(_player.index)
        if allianceIndex then
            ai:registerFriendFaction(allianceIndex)
        end

        MissionUT.deleteOnPlayersLeft(_Pirate)
        table.insert(_CreatedPirateTable, _Pirate)
    end

    SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
end

function spawnPirateAmbush()
    local _MethodName = "Spawning ambush."
    local _Generator = AsyncPirateGenerator(nil, onPirateAmbushFinished)
    local _WaveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 5, "High")

    mission.Log(_MethodName, "Spawning first group.")
    _Generator:startBatch()

    local posCounter = 1
    local distance = 250 --_#DistAdj

    local pirate_positions = _Generator:getStandardPositions(#_WaveTable, distance)
    for _, p in pairs(_WaveTable) do
        _Generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    _Generator:endBatch()

    --Spawn a torpedo strike team.
    local _Generator2 = AsyncPirateGenerator(nil, onTorpStrikePirateSpawned)
    local _WaveTable2 = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 2, "High")

    mission.Log(_MethodName, "Spawning torp strike group.")
    _Generator2:startBatch()

    for _, p in pairs(_WaveTable2) do
        _Generator2:createScaledPirateByName(p, _Generator2:getGenericPosition())
    end

    _Generator2:endBatch()

    mission.data.custom.ambushPiratesSpawned = true
end

function onPirateAmbushFinished(_Generated)
    local _MethodName = "On Pirate Ambush Finished"
    SpawnUtility.addEnemyBuffs(_Generated)

    mission.Log(_MethodName, "Broadcasting Pirate Taunt to Sector")

    local _Lines = {
        "You're a long way from home, aren't you?",
        "We'll tear you to pieces!",
        "All ships, weapons to full! Engage! Engage! Engage!",
        "Kill them all! Hahahaha!"
    }

    Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, getRandomEntry(_Lines))  
end

function onTorpStrikePirateSpawned(_Generated)
    for _, _Ship in pairs(_Generated) do
        local _TorpSlamValues = {
            _ROF = 2,
            _DurabilityFactor = 2,
            _TimeToActive = 0,
            _DamageFactor = 3,
            _UseEntityDamageMult = true,
            _TargetPriority = 4
        }

        _Ship:addScriptOnce("torpedoslammer.lua", _TorpSlamValues)
        _Ship:addScriptOnce("utility/delayeddelete.lua", random():getFloat(8, 9)) --Should give it enough time to fire 3x and peace out.
        ESCCUtil.setBombardier(_Ship)
    end

    Placer.resolveIntersections(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _player = Player()

    local _AccomplishMessage = "Frostbite Company thanks you. Here's your compensation."
    local _BaseReward = 10000000
    local _BonusReward = 0
    if mission.data.custom.doneContainerJob then
        _BonusReward = _BonusReward + 300000
        mission.Log(_MethodName, "Container job done - increasing reward to " .. tostring(_BonusReward))
    end
    if mission.data.custom.doneSatelliteJob then
        _BonusReward = _BonusReward + 300000
        mission.Log(_MethodName, "Satellite job done - increasing reward to " .. tostring(_BonusReward))
    end
    if mission.data.custom.destroyAsteroidJob then
        _BonusReward = _BonusReward + 300000
        mission.Log(_MethodName, "Asteroid job done - increasing reward to " .. tostring(_BonusReward))
    end
    if mission.data.custom.threeJobsDone then
        _AccomplishMessage = "Frostbite Company thanks you. Here's your compensation. Mace sends their regards as well."
        _BonusReward = _BonusReward * 3
    end

    _player:setValue("_horizonkeepers_story_stage", 3)

    _player:sendChatMessage("Frostbite Company", 0, _AccomplishMessage)
    mission.data.reward = {credits = _BaseReward + _BonusReward, paymentMessage = "Earned %1% credits for decrypting the chip." }

    HorizonUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onMarkContainer()
    local _MethodName = "On Mark Container"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    --Be careful about enabling both of these. They can cause a stupid amount of spam if something goes wrong with the callback(s)
    if not mission.data.custom.targetContainer then 
        --mission.Log(_MethodName, "WARNING - Could not find target container ID.")
        return 
    end

    local _TargetContainer = Entity(mission.data.custom.targetContainer)

    if not _TargetContainer or not valid(_TargetContainer) then
        --mission.Log(_MethodName, "WARNING - Target container not valid entity.")
        return 
    else
        local _ContainerMarkOrange = ESCCUtil.getSaneColor(255, 173, 0)

        renderer:renderEntityTargeter(_TargetContainer, _ContainerMarkOrange)
        renderer:renderEntityArrow(_TargetContainer, 30, 10, 250, _ContainerMarkOrange)
    end

    renderer:display()
end

--endregion

--region #CLIENT / SERVER UTILITY CALLS

function registerMarkContainer()
    local _MethodName = "Register Mark Containers"

    if onClient() then
        mission.Log(_MethodName, "Invoked on Client - Reigstering onPreRenderHud callback.")

        if Player():registerCallback("onPreRenderHud", "onMarkContainer") == 1 then
            mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
        end
    else
        mission.Log(_MethodName, "Calling on Server => Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkContainer")
    end
end

function unregisterMarkContainer()
    local _MethodName = "Unregister Mark Containers"
    
    if onClient() then
        mission.Log(_MethodName, "Invoking on Client - Unregistering callback.")

        if Player():unregisterCallback("onPreRenderHud", "onMarkContainer") == 1 then
            mission.Log(_MethodName, "WARNING - Could not detach prerender callback to script.")
        end
    else
        mission.Log(_MethodName, "Calling on Server => Invoking on Client")
        
        invokeClientFunction(Player(), "unregisterMarkContainer")
    end
end

--endregion

--region #CLIENT / SERVER / DIALOG CALLS

function contactedHacker()
    local _MethodName = "Contacted Hacker"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client => Invoking on Server.")

        invokeServerFunction("contactedHacker")
        return
    end

    mission.Log(_MethodName, "Calling on Server")

    invokeClientFunction(Player(), "onPhase3Dialog", mission.data.custom.varlanceID)
end
callable(nil, "contactedHacker")

function contactedHacker2(_proceed)
    local _MethodName = "Contacted Hacker 2"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client => Invoking on Server.")

        invokeServerFunction("contactedHacker2", _proceed)
        return
    end

    mission.Log(_MethodName, "Calling on Server")

    if _proceed then
        if mission.internals.phaseIndex == 4 then
            nextPhase() --Takes us into phase 5 - the subjob phase.
        end
    else
        mission.data.custom.annoyedHacker = mission.data.custom.annoyedHacker + 1

        if mission.data.custom.annoyedHacker % 2 == 1 then
            local _VarlanceLines = {
                "Try not to aggravate them. We need their help.",
                "Stay cool. I'd rather not piss them off.",
                "Don't provoke them. Our best shot is to keep the peace."
            }

            shuffle(random(), _VarlanceLines)

            HorizonUtil.varlanceChatter(_VarlanceLines[1])
        end
    end
end
callable(nil, "contactedHacker2")

function contactedHackerGiveSat()
    local _MethodName = "Contacted Hacker Give Sat"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client => Invoking on Server.")

        invokeServerFunction("contactedHackerGiveSat")
        return
    end

    mission.Log(_MethodName, "Calling on Server")

    local item = UsableInventoryItem("horizon2satellitepkg.lua", Rarity(RarityType.Exceptional))
    Player():getInventory():add(item, true)
end
callable(nil, "contactedHackerGiveSat")

function contactedHacker3()
    local _MethodName = "Contacted Hacker 3"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client => Invoking on Server.")

        invokeServerFunction("contactedHacker3", _proceed)
        return
    end

    mission.Log(_MethodName, "Calling on Server - advancing phase.")

    if mission.internals.phaseIndex == 5 then
        nextPhase() --Takes us into phase 6 - where we grab the satellite.
    end
end
callable(nil, "contactedHacker3")

function contactedHacker4()
    local _MethodName = "Contacted Hacker 4"
    if onClient() then
        mission.Log(_MethodName, "Calling on Client => Invoking on Server.")

        invokeServerFunction("contactedHacker4", _proceed)
        return
    end

    mission.Log(_MethodName, "Calling on Server - advancing phase.")

    if mission.internals.phaseIndex == 8 then
        invokeClientFunction(Player(), "onPhase8Dialog", mission.data.custom.varlanceID)
    end
end
callable(nil, "contactedHacker4")

function onPhase3Dialog(varlanceID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    d0.text = "Damn. They didn't use to be this uncooperative. See if you can get them to open up. Maybe there's some odd jobs you can do around the sector. Create some goodwill."
    d0.answers = {
        { answer = "I have to run errands?", followUp = d1 },
        { answer = "Alright.", followUp = d2 }
    }

    d1.text = "Best way to get what we want."
    d1.answers = {
        { answer = "I could threaten them.", followUp = d3 },
        { answer = "Fine. You're right.", followUp = d4 }
    }

    d2.text = "I'll hold down the fort while you get to work, buddy. Don't worry about any pirates or Xsotan."
    d2.onEnd = onPhase3DialogEnd

    d3.text = "Won't work. They'll just go to ground again, and none of the other hackers in the area will work with us afterwards."
    d3.followUp = d4

    d4.text = "I understand your frustration. Unfortunately, we need to play nice. I'll hold down the fort while you get to work, buddy. Don't worry about any pirates or Xsotan."
    d4.onEnd = onPhase3DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(varlanceID):interactShowDialog(d0, false)
end

function onPhase5FreighterDialog(freighterID, freighterTitle)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    --I guess if the dialog is invoked too quickly, the talker title doesn't have a chance to "register" on the client, so we send the title over.
    d0.text = "Huh. There are less asteroids here than I remember. Is that your doing? Thanks. This sector will be much easier to navigate."
    d0.talker = freighterTitle
    d0.followUp = d1

    d1.text = "We have to fly carefully because we're carying vital goods for stations in this sector - and others. If our ship gets damaged, who knows how many would suffer?"
    d1.talker = freighterTitle
    d1.followUp = d2    

    d2.text = "Sometimes the best way to help others is to help yourself. Put on your own oxygen mask first and all that."
    d2.talker = freighterTitle
    d2.followUp = d3

    d3.text = "Sorry for rambling. I'll let you go now. Good luck, and thanks again."
    d3.talker = freighterTitle

    ScriptUI(freighterID):interactShowDialog(d0, false)
end

function onPhase5DefenderDialog(defenderID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    d0.text = "Dropping off a crate for someone at the station, are you?"
    d0.answers = {
        { answer = "They don't want to be seen accessing it.", followUp = d1 }
    }

    d1.text = "That's ridiculous."
    d1.followUp = d2    

    d2.text = "The other week, some pirates launched an intense attack on this sector. Their fleet had several Pillagers and Scorchers. We were afraid, but we charged in and started firing."
    d2.followUp = d3

    d3.text = "If we had given into our doubts... we would all be dead. Being afraid is natural - bravery isn't the absence of fear but the willingness to act despite that fear. Perhaps your crate-accessing friend could learn a thing or two about that."

    ScriptUI(defenderID):interactShowDialog(d0, false)
end

function onPhase5StationDialog(stationID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    d0.text = "Ugh! Who set that stupid satellite up to play 'Boots, Beer, and a Broken Heart' on loop?! That song was stale a hundred years ago!"
    d0.followUp = d1

    d1.text = "Did Mace do this again? Remember the satellite set up to play 'Whiskey, Wildflowers, and Tears'? I swear if they're doing another misdirection play to raid the food bars..."
    d1.followUp = d2    

    d2.talker = "Station Chief"
    d2.text = "To hell with that! We're not doing this again. Just cut that thing out of the local net!"
    d2.followUp = d3

    d3.text = "You got it! Cutting it off now!"

    ScriptUI(stationID):interactShowDialog(d0, false)
end

function onPhase7PirateDialog(pirateID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}

    d0.text = "... Who are you?"
    d0.answers = {
        { answer = "I'm working with Mace.", followUp = d1 }
    }

    d1.text = "Huh. Guess they're too much of a coward to do their own dirty work. Fine. Do you have the artifact?"
    d1.answers = {
        { answer = "Yes. Here it is.", followUp = d2, onSelect = onPhase7TakeArtifact }
    }

    d2.text = "Heh. Thanks."
    d2.followUp = d3

    d3.text = "Yep. That's the real deal. You just can't find pre-exodus tech like this anymore."
    d3.followUp = d4

    d4.text = "It's a shame. We were going to kill that nerd after they handed over the goods."
    d4.followUp = d5

    d5.text = "I suppose killing you will serve well enough as a message. Time to die, captain."
    d5.onEnd = onPhase7DialogFinish

    ScriptUI(pirateID):interactShowDialog(d0, false)
end

function onPhase7PirateNoArtifactDialog(pirateID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    d0.text = "... Who are you?"
    d0.answers = {
        { answer = "I'm working with Mace.", followUp = d1 }
    }

    d1.text = "Huh. Guess they're too much of a coward to do their own dirty work. Fine. Do you have the artifact?"
    d1.answers = {
        { answer = "Nope. I pitched it.", followUp = d2 }
    }

    d2.text = "You idiot!"
    d2.followUp = d3

    d3.text = "Do you have any idea how much that was worth?! We'll kill you!"
    d3.onEnd = onPhase7DialogFinish

    ScriptUI(pirateID):interactShowDialog(d0, false)
end

function onPhase8Dialog(varlanceID)
    local d0 = {}
    local d1 = {}

    d0.text = "I've got the data dump. At first glance, this looks like a schedule of some sort."
    d0.followUp = d1

    d1.text = "It's going to take some time to go through this and come up with a plan of action. I'll be in touch. Stay sharp in the meantime, buddy."
    d1.onEnd = onPhase8DialogFinish

    ESCCUtil.setTalkerTextColors({d0, d1}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(varlanceID):interactShowDialog(d0, false)
end

--endregion