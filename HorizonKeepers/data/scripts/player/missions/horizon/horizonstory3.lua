--[[
    MISSION 3: Chasing Shadows
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
HorizonUtil = include("horizonutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local ShipGenerator = include("shipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include("shiputility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Chasing Shadows"

--region #INIT / DATA

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/snowflake-2.png"
mission.data.priority = 9
mission.data.description = {
    { text = "Mace has decrypted the chip for you. Varlance said that he would contact you when he has a plan of action." },
    { text = "Read Varlance's mail", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${_X}:${_Y}) and wait for the freighters", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the freighters before they jump", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Pursue the freighters to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the freighters before they jump again", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Read Varlance's second mail", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Meet Varlance in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Interrogate the survivors", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 10 --Key everything off of danger 10.
mission.data.custom.transportsSpawned = false
mission.data.custom.phase3PirateGroupSpawned = false
mission.data.custom.phase5PirateKOd = false
mission.data.custom.phase5MiniBossTimer = 0
mission.data.custom.phase5MiniBossesSpawned = false
mission.data.custom.phase6VarlanceDialogTimer = 0
mission.data.custom.phase6VarlanceDialogAllowed = false
mission.data.custom.hyperspaceCounter = 0

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if atTargetLocation() then
        ESCCUtil.allPiratesDepart()
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationEntered = function(_X, _Y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

mission.globalPhase.onTargetLocationLeft = function(_X, _Y)
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    --Get a sector that's very close to the outer edge of the barrier.
    mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))

    mission.data.custom.firstLocation = getNextLocation(true)

    local _X = mission.data.custom.firstLocation.x
    local _Y = mission.data.custom.firstLocation.y

    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_X, _Y) --Set the pirate level based on the first location.

    mission.data.description[3].arguments = { _X = mission.data.custom.firstLocation.x, _Y = mission.data.custom.firstLocation.y }
    
    --Send mail to player.
    local _Player = Player()
    local _Mail = Mail()
	_Mail.text = Format("Hey, buddy.\n\nIt's Varlance. I was right about the data we got from that chip. It looks like it's a schedule of shipments. They're all converging on a single sector. I think we should make sure a couple of them are delayed... permanently. I've found two that are scheduled to arrive soon. I'm going to hit one of them, and I'd like you to hit the other one. They'll be heading through (%1%:%2%) shortly. Head there and take them out. Make sure you hit them quick - they'll only be a couple jumps away from their destination by then.\n\nI've already hit another group of pirates and dropped a fake data chip in the wreckage of their shipyard, then dropped some wreckages from a third group. With any luck, the owners of the chip - whoever they are - will think a second group of pirates wiped out their freighters, then got taken out by some rivals.\n\nGood hunting, buddy.\n\nVarlance", _X, _Y)
	_Mail.header = "Plan of Action"
	_Mail.sender = "Varlance @FrostbiteCompany"
	_Mail.id = "_horizon_story3_mail1"
	_Player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = {
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_horizon_story3_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    local _MethodName = "Phase 2 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.firstLocation

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_x, _y)
    if onServer() then
        mission.data.custom.secondLocation = getNextLocation(false)

        mission.data.description[5].arguments = { _X = mission.data.custom.secondLocation.x, _Y = mission.data.custom.secondLocation.y }
        sync()
    end
end

mission.phases[2].updateTargetLocationServer = function(_timestep)
    local _hsctimer = (mission.data.custom.hyperspaceCounter or 0) + _timestep
    mission.data.custom.hyperspaceCounter = _hsctimer

    local _FreighterCount = ESCCUtil.countEntitiesByValue("_horizon3_freighter")

    if _FreighterCount == 0 and mission.data.custom.transportsSpawned then
        setPhase(4) -- we skip right to phase 4.
    end
end

--region #PHASE 2 TIMER CALLS

if onServer() then

mission.phases[2].timers[1] = {
    time = 15,
    callback = function()
        if atTargetLocation() and not mission.data.custom.transportsSpawned then
            mission.data.description[3].fulfilled = true
            mission.data.description[4].visible = true

            spawnTransports()
            spawnEscorts(6, true)
            
            mission.data.custom.hyperspaceCounter = 0
            mission.data.custom.transportsSpawned = true
            sync()
        end
    end,
    repeating = true
}

mission.phases[2].timers[2] = {
    time = 5,
    callback = function()
        if atTargetLocation() and mission.data.custom.transportsSpawned and mission.data.custom.hyperspaceCounter >= 180 then
            jumpTransports()
            
            mission.data.custom.hyperspaceCounter = 0

            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBegin = function()
    local _MethodName = "Phase 3 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.secondLocation

    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true
end

mission.phases[3].onTargetLocationEntered = function(_x, _y)
    if onServer() then
        if not mission.data.custom.phase3PirateGroupSpawned then
            spawnEscorts(8, false)
            mission.data.custom.phase3PirateGroupSpawned = true
        end
        local _Freighters = { Sector():getEntitiesByScriptValue("_horizon3_freighter") }
        for _, _ship in pairs(_Freighters) do
            local _ShipAI = ShipAI(_ship)
            local _ShipPos = _ship.position

            _ShipAI:setFlyLinear(_ShipPos.look * 20000, 0, false)
        end
    end
end

mission.phases[3].updateTargetLocationServer = function(_timestep)
    local _hsctimer = (mission.data.custom.hyperspaceCounter or 0) + _timestep
    mission.data.custom.hyperspaceCounter = _hsctimer

    local _FreighterCount = ESCCUtil.countEntitiesByValue("_horizon3_freighter")

    if _FreighterCount == 0 and mission.data.custom.transportsSpawned then
        nextPhase()
    end
end

--region #PHASE 3 TIMER CALLS

if onServer() then

mission.phases[3].timers[2] = {
    time = 5,
    callback = function()
        if atTargetLocation() and mission.data.custom.transportsSpawned and mission.data.custom.hyperspaceCounter >= 180 then
            jumpTransports2() --This fails the mission so no need to worry about anything else here.
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    local _MethodName = "Phase 4 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = nil

    mission.data.description[4].fulfilled = true
    mission.data.description[5].fulfilled = true
    mission.data.description[6].fulfilled = true
    mission.data.description[7].visible = true
end

mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    mission.data.custom.thirdLocation = getNextLocation(false)
    
    local _X = mission.data.custom.thirdLocation.x
    local _Y = mission.data.custom.thirdLocation.y

    mission.data.description[8].arguments = { _X = mission.data.custom.firstLocation.x, _Y = mission.data.custom.firstLocation.y }
    
    --Send mail to player.
    local _Player = Player()
    local _Mail = Mail()
	_Mail.text = Format("Good news, buddy. There's another group of pirates that was gonna link up with the freighters you took out. If we move quickly enough we can catch them by surprise. Head to (%1%:%2%). I'll meet you there.\n\nBy the way... did you notice a strange ship with their caravan? There was one in the group I eliminated - it's not like any pirate ship I've seen. We need more information. Try to leave some of them alive to talk.\n\nVarlance", _X, _Y)
	_Mail.header = "Meet up"
	_Mail.sender = "Varlance @FrostbiteCompany"
	_Mail.id = "_horizon_story3_mail2"
	_Player:addMail(_Mail)

    _Player:setValue("_horizonkeepers_story3_cargolooted", true)
end

mission.phases[4].playerCallbacks = {
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_horizon_story3_mail2" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].sectorCallbacks = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBegin = function()
    local _MethodName = "Phase 5 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.thirdLocation

    mission.data.description[7].fulfilled = true
    mission.data.description[8].visible = true
end

mission.phases[5].onTargetLocationEntered = function(_x, _y)
    local _MethodName = "Phase 5 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[8].fulfilled = true
    mission.data.description[9].visible = true

    mission.data.custom.phase5MiniBossesSpawned = false
    mission.data.custom.phase5MiniBossTimer = 0

    if onServer() then
        spawnPirateGroup()
        spawnVarlance()
    end
end

mission.phases[5].onTargetLocationArrivalConfirmed = function(_x, _y)
    HorizonUtil.varlanceChatter("I've got your back, buddy. Hope you've got mine.")
end

mission.phases[5].updateTargetLocationServer = function(_timeStep)
    mission.data.custom.phase5MiniBossTimer = mission.data.custom.phase5MiniBossTimer + _timeStep
end

--region #PHASE 5 CALLBACK CALLS

mission.phases[5].sectorCallbacks[1] = {
    name = "onEntityKOed",
    func = function(_shipID, _reviveID)
        local _MethodName = "Phase 5 Custom Callback 1"
        mission.Log(_MethodName, "Calling.")
        mission.data.custom.phase5PirateKOd = true
    end
}

--endregion

--region #PHASE 5 TIMER CALLS

if onServer() then

mission.phases[5].timers[1] = {
    time = 10,
    callback = function()
        local _MethodName = "Phae 5 Timer 1 Callback"
        if atTargetLocation() and mission.data.custom.phase5MiniBossTimer >= 10 and not mission.data.custom.phase5MiniBossesSpawned then
            local _pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
            mission.Log(_MethodName, "Player is on location and minibosses not yet spawned - there are " .. tostring(_pirateCt) .. " pirates.")

            if _pirateCt <= 7 then
                spawnPirateBosses()

                HorizonUtil.varlanceChatter("Another Deadshot... The energy readings from that Bombardier are concerning, though. Stay frosty.")
            end
        end
    end,
    repeating = true
}

mission.phases[5].timers[2] = {
    time = 180, --He doesn't have the resources of Adriana, can't respawn as quickly.
    callback = function()
        local _MethodName = "Phase 5 Timer 2 Callback"

        if atTargetLocation() then
            mission.Log(_MethodName, "On Location - respawning Varlance if needed.")

            spawnVarlance()
        end
    end,
    repeating = true
}

mission.phases[5].timers[3] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 7 Timer 3 Callback"

        local _PirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

        if atTargetLocation() and _PirateCt == 1 and mission.data.custom.phase5PirateKOd and mission.data.custom.phase5MiniBossesSpawned then
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[6] = {}
mission.phases[6].onBegin = function()
    local _MethodName = "Phase 5 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[9].fulfilled = true
    mission.data.description[10].visible = true
end

mission.phases[6].onBeginServer = function()
    spawnVarlance()
    local _Pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    invokeClientFunction(Player(), "onPhase6PirateDialog", _Pirates[1].id, _Pirates[1].translatedTitle)
end

mission.phases[6].updateTargetLocationServer = function(_timeStep)
    --Give the player a few seconds to process this.
    if mission.data.custom.phase6VarlanceDialogAllowed then
        mission.data.custom.phase6VarlanceDialogTimer = mission.data.custom.phase6VarlanceDialogTimer + _timeStep

        if mission.data.custom.phase6VarlanceDialogAllowed and mission.data.custom.phase6VarlanceDialogTimer >= 5 then
            --we're already in the dialog so no need to allow it again. It WILL keep invoking if we don't do this.
            mission.data.custom.phase6VarlanceDialogAllowed = false 

            invokeClientFunction(Player(), "onPhase6VarlanceDialog", mission.data.custom.varlanceID)
        end
    end
end

local onPhase6PirateDialogEnd = makeDialogServerCallback("onPhase6PirateDialogEnd", 6, function()
    local _Pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    local _Pirate = _Pirates[1]

    _Pirate:removeScript("entity/utility/kobehavior.lua")

    local _PirateDura = Durability(_Pirate)
    _PirateDura.invincibility = 0.0

    _Pirate:destroy(mission.data.custom.varlanceID)

    mission.data.custom.phase6VarlanceDialogAllowed = true
end)

local onPhase6VarlanceDialogEnd = makeDialogServerCallback("onPhase6VarlanceDialogEnd", 6, function()
    local _Varlance = Entity(mission.data.custom.varlanceID)
    _Varlance:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))

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
        target.x, target.y = MissionUT.getEmptySector(x, y, 6, 16, false)
    end

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function spawnTransports()
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _random = random()
    --Spawn 5 large freighters and 6 escorts. Start a jump timer that's equal to the # of shipment 1 jumps * 15 seconds.
    local _SectorVol = Balancing_GetSectorShipVolume(_X, _Y)
    local _Vol1 = _SectorVol * 8
    local _Vol2 = _SectorVol * 11
    local _Faction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)

    local look = _random:getVector(-100, 100)
    local up = _random:getVector(-100, 100)
    local pos = vec3(0, 0, 0)
    local _Player = Player()
    local _Ship = Entity(_Player.craftIndex)

    if _Ship then
        pos = _Ship.translationf
    end

    local _basepos = ESCCUtil.getVectorAtDistance(pos, 4000, true)
    local _unit = 90
    local _p1 = vec3(_basepos.x + (_unit*2), _basepos.y + (_unit*1), _basepos.z + (_unit*1))
    local _p2 = vec3(_basepos.x, _basepos.y + (_unit*-1), _basepos.z)
    local _p3 = vec3(_basepos.x + (_unit*-2), _basepos.y + (_unit*-1), _basepos.z + (_unit*-1))
    local _p4 = vec3(_basepos.x + (_unit*-4), _basepos.y + (_unit*1), _basepos.z + (_unit*-1))
    local _p5 = vec3(_basepos.x + (_unit*-6), _basepos.y + (_unit*-1), _basepos.z + (_unit*1))

    local _Freighters = {}

    table.insert(_Freighters, ShipGenerator.createFreighterShip(_Faction, MatrixLookUpPosition(look, up, _p1), _Vol1))
    table.insert(_Freighters, ShipGenerator.createTradingShip(_Faction, MatrixLookUpPosition(look, up, _p2), _Vol1))
    table.insert(_Freighters, HorizonUtil.spawnHorizonFreighter(false, MatrixLookUpPosition(look, up, _p3), _Faction))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(_Faction, MatrixLookUpPosition(look, up, _p4), _Vol2))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(_Faction, MatrixLookUpPosition(look, up, _p5), _Vol2))

    for _, _ship in pairs(_Freighters) do
        _ship:setValue("_horizon3_freighter", true)
        _ship:setValue("is_pirate", true)
        ESCCUtil.removeCivilScripts(_ship)
        Boarding(_ship).boardable = false

        if not _Player:getValue("_horizonkeepers_story3_cargolooted") then
            ShipUtility.addCargoToCraft(_ship)
        end

        local _ShipAI = ShipAI(_ship)
        local _ShipPos = _ship.position

        _ShipAI:setPassiveShooting(true)
        _ShipAI:setFlyLinear(_ShipPos.look * 20000, 0, false)
    end

    shuffle(_random, _Freighters)

    if _Player:getValue("_horizonkeepers_story3_cargolooted") then
        ShipUtility.addCargoToCraft(_Freighters[1])
    end

    _Sector:broadcastChatMessage(_Freighters[1], ChatMessageType.Chatter, "Enemies, here?! How did they find us? Charge the hyperdrives now!")
end

function jumpTransports()
    local _Sector = Sector()
    local _Freighters = {_Sector:getEntitiesByScriptValue("_horizon3_freighter")}
    --This isn't timed for failure because of the amount of work the player has to do to get here. Imagine failing after going through phase 1-4.
    --That would SUCK. So since we're not timed, we don't particularly care about getting a non-blocked jumping route. The player will have more than
    --enough time to go around the rifts.
    local _JumpTo = mission.data.custom.secondLocation

    --This should be one of the last things we do before syncing to prevent premature ending of the mission due to freighters still being left.
    for _, _F in pairs(_Freighters) do
        _Sector:transferEntity(_F, _JumpTo.x, _JumpTo.y, SectorChangeType.Jump)
    end

    sync()
    Player():sendChatMessage("Nav Computer", 0, "The freighters have jumped to \\s(%1%,%2%).", _JumpTo.x, _JumpTo.y)
end

function jumpTransports2()
    local _Sector = Sector()
    local _Freighters = {_Sector:getEntitiesByScriptValue("_horizon3_freighter")}

    for _, _F in pairs(_Freighters) do
        _F:addScriptOnce("utility/delayeddelete.lua", random():getFloat(2, 4))
    end

    Player():sendChatMessage("Varlance", 0, "They've reached their destination. We'll have to hit the next shipment.")
    fail()
end

function spawnEscorts(_EscortCt, _SpawnNearTransports)
    local _MethodName = "Spawn Shipment Escort"
    mission.Log(_MethodName, "Spawning escorts at danger level " .. tostring(mission.data.custom.dangerLevel))

    --Pick a random transport and use that as the centerpiece in our formation. Spawn the pirates in a rough sphere around it.
    local _Freighters = { Sector():getEntitiesByScriptValue("_horizon3_freighter") }
    shuffle(random(), _Freighters)
    local _Centerpos = _Freighters[1].translationf

    local _PirateGenerator = AsyncPirateGenerator(nil, onEscortsFinished)
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _EscortCt, "Standard")

    _PirateGenerator:startBatch()
    _PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    local _GetEscortPosition = function(_cpos, _pgen)
        return _pgen:getGenericPosition()
    end
    if _SpawnNearTransports then
        _GetEscortPosition = function(_cpos, _pgen)
            local vec = ESCCUtil.getVectorAtDistance(_cpos, 1000, false)
            local look = vec3(math.random(), math.random(), math.random())
            local up = vec3(math.random(), math.random(), math.random())

            return MatrixLookUpPosition(look, up, vec)
        end
    end

    for _, _Pirate in pairs(_PirateTable) do
        _PirateGenerator:createPirateByName(_Pirate, _GetEscortPosition(_Centerpos, _PirateGenerator))
    end

    _PirateGenerator:endBatch()
end

function onEscortsFinished(_Generated)
    local _MethodName = "On Freighter Escorts Generated"
    SpawnUtility.addEnemyBuffs(_Generated)

    Placer.resolveIntersections()
end

function spawnPirateGroup()
    local _PirateGenerator = AsyncPirateGenerator(nil, onPirateGroupFinished)
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard")

    _PirateGenerator:startBatch()
    _PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    for _, _Pirate in pairs(_PirateTable) do
        _PirateGenerator:createPirateByName(_Pirate, _PirateGenerator:getGenericPosition())
    end

    _PirateGenerator:endBatch()
end

function onPirateGroupFinished(_Generated)
    local _MethodName = "On Pirate Ambush Group Finished"
    _Generated[1]:addScriptOnce("entity/utility/kobehavior.lua")

    SpawnUtility.addEnemyBuffs(_Generated)

    Placer.resolveIntersections()
end

function spawnPirateBosses()
    local _MethodName = "Spawn Shipment Escort"
    mission.Log(_MethodName, "Spawning escorts at danger level " .. tostring(mission.data.custom.dangerLevel))
    local _PirateGenerator = AsyncPirateGenerator(nil, onPirateBossesSpawned)
    local _PirateTable = { "Devastator", "Devastator" }

    _PirateGenerator:startBatch()
    _PirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    for _, _Pirate in pairs(_PirateTable) do
        _PirateGenerator:createPirateByName(_Pirate, _PirateGenerator:getGenericPosition())
    end

    _PirateGenerator:endBatch()
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

        local _Varlance = HorizonUtil.spawnVarlanceNormal(true)
        local _VarlanceAI = ShipAI(_Varlance)
    
        _VarlanceAI:setAggressive()

        mission.data.custom.varlanceID = _Varlance.index
    end
end

function onPirateBossesSpawned(_Generated)

    local _Deadshot = _Generated[1]
    local _Sector = Sector()
    local x, y = _Sector:getCoordinates()
    local _dpf = Balancing_GetSectorWeaponDPS(x, y) * 250

    local _LaserSniperValues = { --#LONGINUS_SNIPER
        _DamagePerFrame = _dpf,
        _TimeToActive = 10,
        _TargetCycle = 15,
        _TargetingTime = 2.25, --Take longer than normal to target.
        _TargetPriority = 1,
        _UseEntityDamageMult = true
    }

    ESCCUtil.setDeadshot(_Deadshot)
    _Deadshot:addScriptOnce("lasersniper.lua", _LaserSniperValues)
    _Deadshot:addScriptOnce("player/missions/horizon/story3/horizonstory3miniboss.lua")

    local _Bombard = _Generated[2]

    local _TorpSlamValues = {
        _ROF = 4,
        _DurabilityFactor = 2,
        _TimeToActive = 10,
        _TargetPriority = 4,
        _UseEntityDamageMult = true,
        _PreferBodyType = 6, --Panther
        _PreferWarheadType = 10 --Anti-matter.
    }

    ESCCUtil.setBombardier(_Bombard)
    _Bombard:addScriptOnce("torpedoslammer.lua", _TorpSlamValues)
    _Bombard:addScriptOnce("player/missions/horizon/story3/horizonstory3miniboss.lua")

    SpawnUtility.addEnemyBuffs(_Generated)

    mission.data.custom.phase5MiniBossesSpawned = true
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _player = Player()

    local _AccomplishMessage = "Frostbite Company thanks you. Here's your compensation."
    local _BaseReward = 14000000

    _player:setValue("_horizonkeepers_story_stage", 4)

    _player:sendChatMessage("Frostbite Company", 0, _AccomplishMessage)
    mission.data.reward = {credits = _BaseReward, paymentMessage = "Earned %1% credits for destroying the pirate freighters." }

    HorizonUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT / SERVER / DIALOG CALLS

function onPhase6PirateDialog(_PirateID, _PirateTitle)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}
    local d9 = {}
    local d10 = {}
    local d11 = {}
    local d12 = {}
    local d13 = {}
    local d14 = {}
    local d15 = {}
    local d16 = {}

    --branch for 'where are the keepers?'
    local d11_a_1 = {}
    --branch for 'why did you turn to piracy?'
    local d11_b_1 = {}
    local d11_b_2 = {}

    d0.text = "Tch. You've won. Come to rub it in our faces before you kill us?"
    d0.followUp = d1

    d1.text = "There might be a way out of it for you. Tell us what we want to know." --v
    d1.followUp = d2

    d2.text = "Why should we cooperate with you?" 
    d2.followUp = d3

    d3.text = "Put it this way. Cooperate with us, you might live. Don't, you die. Are you feeling lucky?" --v
    d3.followUp = d4

    d4.text = "... Fine. What do you want to know?"
    d4.answers = {
        { answer = "What was that strange ship?", followUp = d5 }
    }

    d5.text = "I have no idea what you're talking about."
    d5.answers = {
        { answer = "It was fast and heavily armored.", followUp = d6 }
    }

    d6.text = "Oh yes. Because that narrows it down plenty."
    d6.answers = {
        { answer = "It was green and orange.", followUp = d7 }
    }

    d7.text = "... Ah. That one."
    d7.followUp = d8

    d8.text = "That would be a freighter from one of our business partners. Tougher nut to crack than what you're used to huh?"
    d8.answers = {
        { answer = "Tell us about your business partners.", followUp = d9 }
    }

    d9.text = "They're the keepers of the horizon. Those who have seen past the petty squabbles in this galaxy and found a way to transcend them."
    d9.answers = {
        { answer = "Stop being cryptic.", followUp = d10 }
    }

    d10.text = "No. The company is literally called Horizon Keepers, LTD. You can look it up yourself."
    d10.followUp = d11

    d11.text = "... Anything else?"
    d11.answers = {
        { answer = "Where are the keepers?", followUp = d11_a_1 },
        { answer = "Why did you turn to piracy?", followUp = d11_b_1 },
        { answer = "Are you ready to die?", followUp = d12 }
    }

    d11_a_1.text = "Heh. You think they would tell someone like me that? Beyond your reach, captain. Beyond your reach."
    d11_a_1.followUp = d11

    d11_b_1.text = "Isn't it obvious? The greedy factions suck up every resource in sight. They enrich themselves at the expense of the rest of us. We're dregs, abandoned by the galactic order you hold so dear."
    d11_b_1.followUp = d11_b_2

    d11_b_2.text = "What other choice do we have?"
    d11_b_2.followUp = d11

    d12.text = "Wait."
    d12.followUp = d13

    d13.text = "You said you would spare us if we cooperated."
    d13.followUp = d14

    d14.text = "Will you honor your bargain and let us go? If you think you can get us to grovel for our lives, you're mistaken."
    d14.followUp = d15

    local d15values = { _PIRATE = _PirateTitle }
    d15.text = "I said no such thing. Weapons, full spread on the ${_PIRATE}." % d15values
    d15.followUp = d16

    d16.text = "I should have known. See you in hell, you piece of s-"
    d16.onEnd = onPhase6PirateDialogEnd

    ESCCUtil.setTalkerTextColors({d1, d3, d15}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    --Fade out the music, then show the script.
    Music():fadeOut(1.5)

    ScriptUI(_PirateID):interactShowDialog(d0, false)
end

function onPhase6VarlanceDialog(_VarlanceID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}
    local d9 = {}
    local d10 = {}
    local d11 = {}

    d0.text = "Horizon Keepers, LTD huh?"
    d0.followUp = d1

    d1.text = "I'll have to look into them. Any information gotten at gunpoint is suspect."
    d1.followUp = d2

    d2.text = "Stay sharp in the meantime. I'll be in touch."
    d2.answers = {
        { answer = "You got it.", onSelect = onPhase6VarlanceDialogEnd },
        { answer = "Wait.", followUp = d3 }
    }

    d3.text = "... Hmmm? What's on your mind?"
    d3.answers = {
        { answer = "Why did you kill those pirates?", followUp = d4 },
        { answer = "Never mind.", onSelect = onPhase6VarlanceDialogEnd }
    }

    d4.text = "They're trash. You can make whatever socioeconomic argument you want - the galaxy is better off without their like."
    d4.answers = {
        { answer = "They were defenseless.", followUp = d5 },
        { answer = "You're right.", onSelect = onPhase6VarlanceDialogEnd }
    }

    d5.text = "Hmph. Don't go soft on me now, buddy. You ever hear the story of Swoks? Not the copycat out in the iron wastes... the first one."
    d5.followUp = d6

    d6.text = "Real nasty piece of work. Took people for ransom. Tortured and killed anyone who dared cross him. It's easier to list the crimes he didn't commit."
    d6.followUp = d7

    d7.text = "He got caught by some captain a while back. A real do-gooder. Took him to a local military outpost and dumped him there."
    d7.followUp = d8

    d8.text = "Within a week, he broke out and was back to his old tricks. Plundering and killing like the Xsotan would be back in force tomorrow."
    d8.followUp = d9

    d9.text = "He found the captain who took him in. Murdered his whole family. Made him watch the tapes and then spaced him. News wouldn't shut up about it for months."
    d9.followUp = d10

    d10.text = "Do you think that the pirates would have shown you the same mercy if you were on the other end of the blade? I guarantee you they wouldn't."
    d10.followUp = d11

    d11.text = "I'll be in touch."
    d11.onEnd = onPhase6VarlanceDialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(_VarlanceID):interactShowDialog(d0, false)
end

--endregion