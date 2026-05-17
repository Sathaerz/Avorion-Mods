--[[
... Is a Good Offense
- Attack the main pirate guy back with a focus on isolating him.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")
include("goodsindex")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local ShipGenerator = include("shipgenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local ShipUtility = include("shiputility")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "... Is a Good Offense"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "After helping the Spears of Adrasteia recover from being on the back foot, you can't help but wonder what's next. Surely Xinull's forces have started to buckle? You've destroyed dozens of his ships and killed hundreds of his men. What could he possibly have left?" },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Follow the Ravager to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the Pirate Ravager before it can escape", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Use the map", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Read Allison's second mail", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy supply convoys", bulletPoint = true, fulfilled = false, visible = false },
    { text = "${_CONVOYKILLED} / ${_CONVOYSTOKILL} convoys destroyed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many convoys escape", bulletPoint = true, fulfilled = false, visible = false },
    { text = "${_CONVOYESCAPE} / 2 convoys escaped", bulletPoint = true, fulfilled = false, visible = false },
    { text = "You may leave the sector at any time to complete the mission", bulletPoint = true, fulfilled = false, visible = false },
    { text = "(Optional) Continue destroying convoys for a bonus", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.convoysKilled = 0
mission.data.custom.convoysToKill = 3
mission.data.custom.lowPerWaveMultiplier = 0.25 --Used for background pirates / transports
mission.data.custom.highPerWaveMultiplier = 0.5 --Used for transport escorts.
mission.data.custom.convoysEscaped = 0
mission.data.custom.phase3RavagerJumpTimer = 0
mission.data.custom.skippedPhase4Bonus = true
mission.data.custom.p4SectorGenerated = false
mission.data.custom.phase4RavagerJumpTimer = 0
mission.data.custom.phase6Timer = 0
mission.data.custom.convoysSpawned = 0
mission.data.custom.backgroundPirateScriptValue = "_vbmn8_background_pirate"
mission.data.custom.convoyScriptValue = "_vbmn8_convoy"
mission.data.custom.convoyEscapeTimer = 0
mission.data.custom.startConvoyEscapeSequence = false
mission.data.custom.checkForNoTransports = false
mission.data.custom.timeUntilConvoyEscape = 120 --Give the player 2 minutes. Adjust as needed.
mission.data.custom.playMusicWhenReEntering = false
mission.data.custom.phase7OOSTimer = 0
mission.data.custom.phase7DialogStarted = false

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationEntered = function(x, y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

mission.globalPhase.onTargetLocationArrivalConfirmed = function(x, y)
    if mission.data.custom.playMusicWhenReEntering then
        setCustomMusic("data/music/vengeance/vampsurvivorsgazeupatstars.ogg")
    end
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    setGameMusic()
    if mission.internals.phaseIndex ~= 7 then
        mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
        mission.data.timeLimitInDescription = true --Show the player how much time is left.
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBegin = function()
    mission.data.description[10].arguments = { _CONVOYKILLED = mission.data.custom.convoysKilled, _CONVOYSTOKILL = mission.data.custom.convoysToKill }
    mission.data.description[12].arguments = { _CONVOYESCAPE = mission.data.custom.convoysEscaped }
end

mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.firstSector = vengeStory8_getNextLocation(true)

    local x = mission.data.custom.firstSector.x
    local y = mission.data.custom.firstSector.y
    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(x, y)

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    local _player = Player()
    local _mail = Mail()

    _mail.text = Format("Hello again, Captain.\n\nWe're almost there. Xinull's forces are decimated and on the run. But he's proven to be... elusive. Every time I think I've pinned him down, he slips away. So we're doing this the old-fashioned way - we cut off his supplies. He's tried to keep the routes of his freighter convoys a secret, but I know where we can find some information. Head to (%1%:%2%) and kill the pirate with the map. It'll be the one that runs away.\n\nAllison", x, y)
    _mail.header = "Final Strike"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story8_mail1"
    _player:addMail(_mail)    
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story8_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.firstSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[5].visible = true

    if onServer() then
        vengeStory8_createFirstSector(x, y)
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function()
    nextPhase()
end

mission.phases[3] = {} --First chance to kill Ravager
mission.phases[3].triggers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    mission.data.custom.jumpSector = vengeStory8_getNextLocation(false)

    local x = mission.data.custom.jumpSector.x
    local y = mission.data.custom.jumpSector.y

    mission.data.description[4].arguments = { _X = x, _Y = y }

    sync()
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase3RavagerJumpTimer = mission.data.custom.phase3RavagerJumpTimer + timeStep
end

mission.phases[3].onEntityDestroyed = function(id, lastDamageInflictor)
    vengeStory8_handleP3P4EntityDestroyed(id, lastDamageInflictor)
end

mission.phases[3].onPreRenderHud = function()
    vengeStory8_handleMarkRunner()
end

--region #PHASE 3 TRIGGERS

if onServer() then

mission.phases[3].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase3RavagerJumpTimer >= 20
    end,
    callback = function()
        local _sector = Sector()
        local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")
        _sector:broadcastChatMessage(runner, ChatMessageType.Chatter, "Go, go, go! We're almost there! We're almost out of here!"%_t)
    end,
    repeating = false
}

mission.phases[3].triggers[2] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase3RavagerJumpTimer >= 30
    end,
    callback = function()
        local _sector = Sector()
        local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")

        --yes, we rob the player of blowing it up at the last second but this lets us be lazy and move to the next phase here
        --without having to do a fancy sector callback or something like that.
        if runner then
            runner.invincible = true 

            local x = mission.data.custom.jumpSector.x
            local y = mission.data.custom.jumpSector.y

            runner:addScriptOnce("entity/utility/delayedjump.lua", x, y, random():getFloat(1, 3))
        end

        mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to pursue.
        mission.data.timeLimitInDescription = true --Show the player how much time is left.
        nextPhase()
    end,
    repeating = false
}

end

--endregion

mission.phases[4] = {} --Second chance to kill Ravager
mission.phases[4].triggers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.location = mission.data.custom.jumpSector

    mission.data.custom.skippedPhase4Bonus = false

    mission.data.description[4].visible = true
    mission.data.description[5].visible = false
end

mission.phases[4].onTargetLocationEntered = function(x, y)
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true

    if onServer() and not mission.data.custom.p4SectorGenerated then
        local pirateGenerator = AsyncPirateGenerator(nil, vengeStory8_onRunnerPirateGroupFinished)
        pirateGenerator.pirateLevel = mission.data.custom.pirateLevel

        local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard", false)

        pirateGenerator:startBatch()

        for _, p in pairs(pirateTable) do
            pirateGenerator:createScaledPirateByName(p, pirateGenerator:getGenericPosition())
        end

        pirateGenerator:endBatch()

        vengeStory8_addCleanupScript()

        mission.data.custom.p4SectorGenerated = true
    end
end

mission.phases[4].onTargetLocationArrivalConfirmed = function(x, y)
    local _sector = Sector()

    local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")
    runner.invincible = false

    _sector:broadcastChatMessage(runner, ChatMessageType.Chatter, "You again?! RUN!")
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase4RavagerJumpTimer = mission.data.custom.phase4RavagerJumpTimer + timeStep
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    vengeStory8_handleP3P4EntityDestroyed(id, lastDamageInflictor)
end

mission.phases[4].onPreRenderHud = function()
    vengeStory8_handleMarkRunner()
end

--region #PHASE 4 TRIGGERS

if onServer() then

mission.phases[4].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4RavagerJumpTimer >= 30
    end,
    callback = function()
        local _sector = Sector()
        local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")
        _sector:broadcastChatMessage(runner, ChatMessageType.Chatter, "Go, go, go! We're almost there! We can lose them this time!")
    end,
    repeating = false
}

mission.phases[4].triggers[2] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4RavagerJumpTimer >= 40
    end,
    callback = function()
        local _sector = Sector()
        local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")

        --yes, we rob the player of blowing it up at the last second but this lets us be lazy and fail here.
        if runner then
            runner.invincible = true 

            runner:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(1, 3))
        end

        vengeStory8_sendFailMail(1)
        fail()
    end,
    repeating = false
}

end

--endregion

mission.phases[5] = {} --Use map phase
mission.phases[5].playerCallbacks = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBegin = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].fulfilled = true --True even if we didn't see it b/c we blew up the ravager too quickly.
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true

    mission.data.location = nil
end

mission.phases[5].onBeginServer = function()
    mission.data.custom.convoySector = vengeStory8_getNextLocation(true) --Just in case the player jumps somewhere else before reading the mail.

    local x = mission.data.custom.convoySector.x
    local y = mission.data.custom.convoySector.y

    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(x, y)

    mission.data.description[8].arguments = { _X = x, _Y = y }

    sync()
end

--region #PHASE 5 PLAYER CALLBACKS

if onServer() then

mission.phases[5].playerCallbacks[1] = {
    name = "_vbmn8_read_map",
    func = function()
        local methodName = "Phase 5 Callback 1"
        mission.Log(methodName, "Player used map item.")

        local _player = Player()
        local _mail = Mail()

        local x = mission.data.custom.convoySector.x
        local y = mission.data.custom.convoySector.y

        _player:sendChatMessage("", ChatMessageType.Information, "Your ship's systems quickly analyze the map. It seems the convoy will approach (${_X}:${_Y}) next." % { _X = x, _Y = y})

        _mail.text = Format("Hello again, Captain.\n\nHave you found anything yet? If you have, head there and send us the telemetry. My captains are ready, and we'll jump in to help. Let's get to work.\n\nAllison", x, y)
        _mail.header = "Coordinates?"
        _mail.sender = "Allison @SpearsOfAdrasteia"
        _mail.id = "_vbmn_story8_mail2"
        _player:addMail(_mail)

        mission.data.description[6].fulfilled = true
        mission.data.description[7].visible = true
        sync()
    end
}

mission.phases[5].playerCallbacks[2] = {
    name = "onMailRead",
    func = function(playerIndex, mailIndex)
		local _mail = Player():getMail(mailIndex)
		if _mail.id == "_vbmn_story8_mail2" then
			nextPhase()
		end
    end
}

end

--endregion

mission.phases[6] = {} --Kill convoy phase
mission.phases[6].triggers = {}
mission.phases[6].timers = {}
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].onBegin = function()
    mission.data.location = mission.data.custom.convoySector

    mission.data.description[7].fulfilled = true
    mission.data.description[8].visible = true
end

mission.phases[6].onTargetLocationEntered = function(x, y)
    mission.data.description[8].fulfilled = true
    mission.data.description[9].visible = true
    mission.data.description[10].visible = true
    mission.data.description[11].visible = true
    mission.data.description[12].visible = true
end

mission.phases[6].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/vampsurvivorsgazeupatstars.ogg")
    mission.data.custom.playMusicWhenReEntering = true
end

mission.phases[6].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase6Timer = mission.data.custom.phase6Timer + timeStep
    mission.data.custom.convoyEscapeTimer = mission.data.custom.convoyEscapeTimer + timeStep

    --Manage convoy destruction
    vengeStory8_handleConvoyDestruction()

    --Manage convoy escape
    vengeStory8_handleConvoyEscape()
end

mission.phases[6].onPreRenderHud = function()
    if atTargetLocation() then
        vengeStory8_handleMarkCargo()
    end
end

--region #PHASE 6 TRIGGERS

if onServer() then

mission.phases[6].triggers[1] = { --Spawn adrasteia reinforcements
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= 10
    end,
    callback = function()
        vengeStory8_spawnAdrasteiaReinforcements(true)
    end,
    repeating = false
}

mission.phases[6].triggers[2] = { --Allison greets player
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= 12
    end,
    callback = function()
        VengeUtil.allisonChatter(nil, "Erinyes on station. The convoys will be here soon. Show them no mercy.")
    end,
    repeating = false
}

mission.phases[6].triggers[3] = { --Spawn first convoy
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= 30
    end,
    callback = function()
        vengeStory8_spawnConvoy()
        vengeStory8_spawnConvoyEscorts()
    end,
    repeating = false
}

mission.phases[6].triggers[4] = { --Allison remarks on convoy escorts
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= 35
    end,
    callback = function()
        VengeUtil.allisonChatter(nil, "Those are much tougher than the rabble I'd expect. I wonder where Xinull scraped up the money to hire them? No matter, they'll die all the same.")
    end,
    repeating = false
}

end

--endregion

--region #PHASE 6 TIMERS

if onServer() then

mission.phases[6].timers[1] = { --Convoy spawn timer
    time = 240,
    callback = function()
        local methodName = "Phase 6 Timer 1 Callback"
        local convoyCt = ESCCUtil.countEntitiesByValue(mission.data.custom.convoyScriptValue)
        if atTargetLocation() then
            if convoyCt == 0 then --Spawning 2 convoys at once is chaos - if one is already in the area spawn a wave of background pirates instead.
                mission.Log(methodName, "Spawning convoy.")
                vengeStory8_spawnConvoy()
                vengeStory8_spawnConvoyEscorts()
            else
                mission.Log(methodName, "Convoy is already present. Spawning background pirates instead.")
                vengeStory8_spawnBackgroundPirates()
            end
        end
    end,
    repeating = true
}

mission.phases[6].timers[2] = { --Adrasteia reinforcement timer
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory8_spawnAdrasteiaReinforcements(false)
        end
    end,
    repeating = true
}

mission.phases[6].timers[3] = { --Background pirate timer
    time = 90,
    callback = function()
        if atTargetLocation() then
            vengeStory8_spawnBackgroundPirates()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[7] = {} --Kill extra convoy phase / talk to Allison on leaving phase
mission.phases[7].triggers = {}
mission.phases[7].timers = {}
mission.phases[7].onBegin = function()
    mission.data.description[9].fulfilled = true
    mission.data.description[11].fulfilled = true
    mission.data.description[12].fulfilled = true
    mission.data.description[13].visible = true
    mission.data.description[14].visible = true
end

mission.phases[7].updateTargetLocationServer = function(timeStep)
    mission.data.custom.convoyEscapeTimer = mission.data.custom.convoyEscapeTimer + timeStep

    --Manage convoy destruction
    vengeStory8_handleConvoyDestruction()

    --Manage convoy escape
    vengeStory8_handleConvoyEscape()
end

mission.phases[7].updateServer = function(timeStep)
    if not atTargetLocation() then
        mission.data.custom.phase7OOSTimer = mission.data.custom.phase7OOSTimer + timeStep
    end
end

mission.phases[7].onSectorArrivalConfirmed = function(x, y)
    if not atTargetLocation() then
        mission.data.description[10].fulfilled = true
        mission.data.description[13].fulfilled = true
        mission.data.description[14].fulfilled = true
        mission.data.description[15].visible = true

        sync()

        vengeStory8_spawnAllison(true)
    end
end

mission.phases[7].onPreRenderHud = function()
    if atTargetLocation() then
        vengeStory8_handleMarkCargo()
    end
end

local vengeStory8_phase7Dialog1CrimeComplaint = makeDialogServerCallback("vengeStory8_phase7Dialog1CrimeComplaint", 7, function()
    Player():setValue("_vbmn8_complained_about_crimes", true)
end)

local vengeStory8_onPhase7Dialog1End = makeDialogServerCallback("vengeStory8_onPhase7Dialog1End", 7, function()
    vengeStory8_friendlyShipsDepart()
    vengeStory8_finishAndReward()
end)

--region #PHASE 7 TRIGGERS

if onServer() then

mission.phases[7].triggers[1] = {
    condition = function()
        return not atTargetLocation() and mission.data.custom.phase7OOSTimer >= 5
    end,
    callback = function()
        vengeStory8_spawnAllison(true)
    end,
    repeating = false
}

end

--endregion

--region #PHASE 7 TIMERS

if onServer() then

mission.phases[7].timers[1] = { --Convoy spawn timer
    time = 240,
    callback = function()
        if atTargetLocation() then
            vengeStory8_spawnConvoy()
            vengeStory8_spawnConvoyEscorts()
        end
    end,
    repeating = true
}

mission.phases[7].timers[2] = { --Background pirate timer
    time = 90,
    callback = function()
        if atTargetLocation() then
            vengeStory8_spawnBackgroundPirates()
        end
    end,
    repeating = true
}

mission.phases[7].timers[3] = {
    time = 5,
    callback = function()
        local methodName = "Phase 7 Timer 3"
        --mission.Log(methodName, "Calling.") --Careful turning this one on, it is spammy.

        if not atTargetLocation() then
            local allisonCt = ESCCUtil.countEntitiesByValue("is_allison")

            if allisonCt > 0 and not mission.data.custom.phase7DialogStarted then
                mission.data.custom.phase7DialogStarted = true
                invokeClientFunction(Player(), "vengeStory8_phase7Dialog1", mission.data.custom.allisonID)
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory8_getNextLocation(useBlockRing)
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 230
    local minDist = 218
    local maxDist = 242
    local minRad, maxRad = 6, 12

    if useBlockRing then
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false) 

        local safetyBreakout = 0
        while target.x == x and target.y == y and safetyBreakout <= 100 do
            if safetyBreakout % 10 == 0 then
                mission.Log(methodName, "Attempt " .. tostring(safetyBreakout) .. " to find a valid sector.")
            end
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)
            safetyBreakout = safetyBreakout + 1
        end
    else
        target.x, target.y = MissionUT.getEmptySector(x, y, minRad, maxRad, false)

        --Enforce distance constraint
        local dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
        if dist < minDist or dist > maxDist then
            mission.Log(methodName, "Distance constraint violated (" .. tostring(dist) .. ")")
            local safetyBreakout = 0
            while (dist < minDist or dist > maxDist) and safetyBreakout < 100 do
                if safetyBreakout % 10 == 0 then
                    mission.Log(methodName, "Attempt " .. tostring(safetyBreakout) .. " to find a valid sector.")
                end
                target.x, target.y = MissionUT.getEmptySector(x, y, minRad, maxRad, false)
                dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
            end
        end
    end

    --Nil check
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location (no empty location found). Terminating script.")
        terminate()
        return
    end

    --Distance constraint check
    local dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
    if dist < minDist or dist > maxDist then
        mission.Log(methodName, "Could not find a suitable mission location (distance constraint violated). Terminating script.")
        terminate()
        return
    end

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))

    return target
end

function vengeStory8_createFirstSector(x, y)
    local generator = SectorGenerator(x, y)

    for _ = 1, 4 do
        generator:createSmallAsteroidField()
    end

    --Create first group of pirates
    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory8_onRunnerPirateGroupFinished)
    pirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard", false)

    pirateGenerator:startBatch()

    for _, p in pairs(pirateTable) do
        pirateGenerator:createScaledPirateByName(p, pirateGenerator:getGenericPosition())
    end

    pirateGenerator:endBatch()

    --Create runner
    local pirateGenerator2 = AsyncPirateGenerator(nil, vengeStory8_onRunnerFinished)
    pirateGenerator2.pirateLevel = mission.data.custom.pirateLevel

    pirateGenerator2:startBatch()

    pirateGenerator2:createScaledRavager(pirateGenerator2:getGenericPosition())

    pirateGenerator2:endBatch()

    Placer.resolveIntersections()

    --We move on to the next sector fairly quickly, and the normal cleanUpSector routine only hits the last mission location.
    --So we add a cleanup script early.
    vengeStory8_addCleanupScript() 

    mission.data.custom.cleanUpSector = true
end

function vengeStory8_onRunnerPirateGroupFinished(generated)
    SpawnUtility.addEnemyBuffs(generated)

    Placer.resolveIntersections(generated)
end

function vengeStory8_onRunnerFinished(generated)
    local runnerRavager = generated[1]

    runnerRavager:addMultiplier(StatsBonuses.Velocity, 2)
    runnerRavager:addMultiplier(StatsBonuses.Acceleration, 2)

    runnerRavager:setValue("is_runner", true)
    runnerRavager:setValue("bDisableXAI", true) --AI handled by this mission.

    local runnerAI = ShipAI(runnerRavager)
    local dir = random():getDirection()
    local finalLoc = dir * 20000

    runnerAI:setFlyLinear(finalLoc, 0, false)
    runnerAI:setPassiveShooting(true)
end

function vengeStory8_handleP3P4EntityDestroyed(id, lastDamageInflictor)
    local methodName = "Handle Phase 3 / Phase 4 Entity Destroyed"
    local destroyedEntity = Entity(id)
    
    if destroyedEntity and valid(destroyedEntity) then
        if destroyedEntity:getValue("is_runner") then
            mission.Log(methodName, "Player killed the runner!")

            local playerHasMap = false

            local _player = Player()
            local items = _player:getInventory():getItemsByType(InventoryItemType.UsableItem)
            for _, slot in pairs(items) do
                local item = slot.item

                if item:getValue("subtype") == "VbmnStoryPirateMap" then
                    playerHasMap = true
                    break
                end
            end

            if not playerHasMap then
                mission.Log(methodName, "Player does not have map - adding map.")
                _player:getInventory():add(UsableInventoryItem("vbmn8piratemap.lua", Rarity(RarityType.Exotic)))
            else
                mission.Log(methodName, "Player already has map. Not adding it.")
            end

            setPhase(5) --Set to use map phase.
        else
            mission.Log(methodName, "Something else killed!")
        end
    end
end

function vengeStory8_spawnConvoy()
    --AKA Spawnvoy.
    local methodName = "Spawn Pirate Transports"
    mission.Log(methodName, "Running.")

    --Reset mission / timer variables before we do anything.
    mission.data.custom.convoyEscapeTimer = 0
    mission.data.custom.startConvoyEscapeSequence = false
    mission.data.custom.checkForNoTransports = true

    local _sector = Sector()
    local _random = random()

    local x, y = _sector:getCoordinates()
    local sectorVolume = Balancing_GetSectorShipVolume(x, y)
    local _Vol1 = sectorVolume * 4
    local _Vol2 = sectorVolume * 6
    local _Vol3 = sectorVolume * 8
    local pirateFaction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)

    local look = _random:getVector(-100, 100)
    local up = _random:getVector(-100, 100)
    local pos = vec3(0, 0, 0)

    local _basepos = ESCCUtil.getVectorAtDistance(pos, 4000, true)
    local _unit = 150
    local _p1 = vec3(_basepos.x + (_unit*2), _basepos.y + (_unit*1), _basepos.z + (_unit*1))
    local _p2 = vec3(_basepos.x, _basepos.y + (_unit*-1), _basepos.z)
    local _p3 = vec3(_basepos.x + (_unit*-2), _basepos.y + (_unit*-1), _basepos.z + (_unit*-1))
    local _p4 = vec3(_basepos.x + (_unit*-4), _basepos.y + (_unit*1), _basepos.z + (_unit*-1))
    local _p5 = vec3(_basepos.x + (_unit*-6), _basepos.y + (_unit*-1), _basepos.z + (_unit*1))

    local _Freighters = {}

    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p1), _Vol1))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p2), _Vol1))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p3), _Vol3))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p4), _Vol2))
    table.insert(_Freighters, ShipGenerator.createFreighterShip(pirateFaction, MatrixLookUpPosition(look, up, _p5), _Vol2))

    for _, _ship in pairs(_Freighters) do
        _ship:setValue("is_pirate", true)
        _ship:setValue("bDisableXAI", true) --Disable any Xavorion AI
        _ship:setValue(mission.data.custom.convoyScriptValue, true)
        ESCCUtil.removeCivilScripts(_ship)
        Boarding(_ship).boardable = false

        --add cargo here
        local possibleIngredients = {
            { name = "Oxygen", factor = 100 },
            { name = "Gun", factor = 1 },
            { name = "Ammunition", factor = 1 },
            { name = "Food", factor = 5 },
            { name = "Fuel", factor = 1 },
            { name = "Water", factor = 50 },
            { name = "Clothes", factor = 5 },
            { name = "Food Bar", factor = 5 },
            { name = "Energy Cell", factor = 5 }
        }
        if _random:test(0.5) then
            table.insert(possibleIngredients, { name = "Medical Supplies", factor = 1 })
        end
        if _random:test(0.25) then
            table.insert(possibleIngredients, { name = "Body Armor", factor = 0.5 })
        end
        local chosenGood = getRandomEntry(possibleIngredients)

        --Pick an amount.
        local lowAmount = 100
        local highAmount = 150
        local waveCargoBonus = 1.0 + (mission.data.custom.convoysSpawned * 0.1)
        local baseAmount = _random:getInt(lowAmount, highAmount)
        local finalAmount = baseAmount * waveCargoBonus * chosenGood.factor
        finalAmount = math.floor(finalAmount)

        local cargoGood = goods[chosenGood.name]

        mission.Log(methodName, "Adding " .. tostring(finalAmount) .. " " .. tostring(chosenGood.name) .. " to freighter.")

        _ship:addCargo(cargoGood:good(), finalAmount)

        --arm here
        --first, strip off existing turrets (passive shooting does not work properly with mixed ranges)
        local shipTurrets = {_ship:getTurrets()}
        for _, turret in pairs(shipTurrets) do
            _sector:deleteEntity(turret)
        end
        --next, add cannons
        local cannonRange = 3000 + _random:getInt(0, 150 * mission.data.custom.dangerLevel) --Make them really long range :D
        local cannonFactor = math.floor(mission.data.custom.dangerLevel / 3)
        ShipUtility.addSpecificScalableWeapon(_ship, { WeaponType.Cannon }, cannonFactor, 0, cannonRange)
        vengeStory8_applyDurabilityAndDamageBuff(_ship, mission.data.custom.lowPerWaveMultiplier)

        _ship:setDropsAttachedTurrets(false) --We futz with the turrets, so we don't necessarily want to drop them.

        --set AI
        local _ShipAI = ShipAI(_ship)
        local _ShipPos = _ship.position

        _ShipAI:setPassiveShooting(true)
        _ShipAI:setFlyLinear(_ShipPos.look * 20000, 0, false)
    end

end

function vengeStory8_spawnConvoyEscorts()
    local methodName = "Spawn Shipment Escort"
    mission.Log(methodName, "Spawning escorts at danger level " .. tostring(mission.data.custom.dangerLevel))

    local _random = random()

    --Pick a random transport and use that as the centerpiece in our formation. Spawn the pirates in a rough sphere around it.
    local freighters = { Sector():getEntitiesByScriptValue(mission.data.custom.convoyScriptValue) }
    shuffle(_random, freighters)
    local centerpos = freighters[1].translationf

    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory8_onConvoyEscortsFinished)
    pirateGenerator.pirateLevel = mission.data.custom.pirateLevel

    local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, "High")

    pirateGenerator:startBatch()

    local getEscortPosition = function(_cpos)
        local vec = ESCCUtil.getVectorAtDistance(_cpos, 1000, false)
        local look = vec3(math.random(), math.random(), math.random())
        local up = vec3(math.random(), math.random(), math.random())

        return MatrixLookUpPosition(look, up, vec)
    end

    for _, p in pairs(pirateTable) do
        pirateGenerator:createPirateByName(p, getEscortPosition(centerpos))
    end

    pirateGenerator:endBatch()
end

function vengeStory8_onConvoyEscortsFinished(generated)
    for _, ship in pairs(generated) do
        vengeStory8_applyDurabilityAndDamageBuff(ship, mission.data.custom.highPerWaveMultiplier)
    end

    SpawnUtility.addEnemyBuffs(generated)

    Placer.resolveIntersections(generated)

    mission.data.custom.convoysSpawned = mission.data.custom.convoysSpawned + 1
end

function vengeStory8_spawnBackgroundPirates()
    local methodName = "Spawn Background Pirates"
    mission.Log(methodName, "Running.")

    local backgroundPirateCt = ESCCUtil.countEntitiesByValue(mission.data.custom.backgroundPirateScriptValue)
    local maxBackgroundPirates = 6

    if backgroundPirateCt < maxBackgroundPirates then
        local piratesToSpawn = maxBackgroundPirates - backgroundPirateCt
        piratesToSpawn = math.min(piratesToSpawn, 4) --cap at mission value. max is 5 @ danger 10.

        mission.Log(methodName, "Spawning " .. tostring(piratesToSpawn) .. " pirates.")

        local spawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, piratesToSpawn, "Standard", false)

        local generator = AsyncPirateGenerator(nil, vengeStory8_onBackgroundPiratesFinished)
        generator.pirateLevel = mission.data.custom.pirateLevel
    
        generator:startBatch()
    
        local distance = 250 --_#DistAdj
        local pirate_positions = generator:getStandardPositions(piratesToSpawn, distance)
        for idx, p in pairs(spawnTable) do
            generator:createScaledPirateByName(p, pirate_positions[idx])
        end
    
        generator:endBatch()
    end
end

function vengeStory8_onBackgroundPiratesFinished(generated)
    for _, ship in pairs(generated) do
        ship:setValue(mission.data.custom.backgroundPirateScriptValue, true)
        vengeStory8_applyDurabilityAndDamageBuff(ship, mission.data.custom.lowPerWaveMultiplier)
        ship:setDropsLoot(false)
    end

    SpawnUtility.addEnemyBuffs(generated)
end

function vengeStory8_applyDurabilityAndDamageBuff(ship, perWaveMultiplier)
    local methodName = "Add Wave-based buff"
    local useWaveMultiplier = perWaveMultiplier

    if mission.internals.phaseIndex == 7 then
        mission.Log(methodName, "In phase 7 - increasing multiplier by 50%.")
        useWaveMultiplier = useWaveMultiplier * 1.5
    end

    local waveBasedBuff = 1.0 + (mission.data.custom.convoysSpawned * useWaveMultiplier)

    mission.Log(methodName, "Buff is " .. tostring(waveBasedBuff))

    ESCCUtil.multiplyOverallDurability(ship, waveBasedBuff)

    ship.damageMultiplier = (ship.damageMultiplier or 1) * waveBasedBuff
end

function vengeStory8_spawnAdrasteiaReinforcements(fullSpawn)
    vengeStory8_spawnAllison(false)

    local spawnedShips = {}

    if fullSpawn then
        for _ = 1, 2 do
            table.insert(spawnedShips, VengeUtil.spawnAdrasteiaWarship(false))
            table.insert(spawnedShips, VengeUtil.spawnAdrasteiaMissileShip(false))
        end
    else
        local cruiserCt = ESCCUtil.countEntitiesByValue("is_adrasteia_cruiser")
        local missileShipCt = ESCCUtil.countEntitiesByValue("is_adrasteia_missile_ship")

        if cruiserCt < 2 then
            table.insert(spawnedShips, VengeUtil.spawnAdrasteiaWarship(false))
        end

        if missileShipCt < 2 then
            table.insert(spawnedShips, VengeUtil.spawnAdrasteiaMissileShip(false))
        end
    end

    --We want to try and avoid setting other ships to aggressive - it tends to short circuit the AI. That's why we only set it for newly spawned ships.
    --Also, we don't need to add a withdraw script multiple times.
    for _, ship in pairs(spawnedShips) do
        local withdrawMessages = {
            "Withdrawing for repairs.",
            "Withdrawing to rearm.",
            "Will rearm, repair, and return.",
            "We'll be back presently.",
            "Falling back. Will seek repairs.",
            "Falling back to rearm."
        }

        local withdrawData = {
            _Threshold = 0.05,
            _Invincibility = 0.02,
            _MinTime = 1,
            _MaxTime = 3,
            _WithdrawMessage = randomEntry(withdrawMessages)
        }
    
        ship:addScript("ai/withdrawatlowhealth.lua", withdrawData)

        local adrasteiaAI = ShipAI(ship)
        adrasteiaAI:setAggressive()
    end
end

function vengeStory8_spawnAllison(deleteOnLeft)
    local methodName = "Spawn Allison"

    local spawnAllison = true
    if mission.data.custom.allisonID then
        local allison = Entity(mission.data.custom.allisonID)
        if allison and valid(allison) and not allison:getValue("allison_withdrawing") then
            spawnAllison = false
        end
    end

    if spawnAllison then
        mission.Log(methodName, "No Allison in sector - spawning her in.")
        local allison = VengeUtil.spawnAllison(deleteOnLeft, false)

        local allisonAI = ShipAI(allison)
        allisonAI:setAggressive()

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory8_handleConvoyDestruction()
    local transportCt = ESCCUtil.countEntitiesByValue(mission.data.custom.convoyScriptValue)
    if mission.data.custom.checkForNoTransports and transportCt == 0 then
        mission.data.custom.convoysKilled = mission.data.custom.convoysKilled + 1

        --if more than 5 convoys have been killed and we're still in phase 6, move to phase 7.
        if mission.internals.phaseIndex == 6 and mission.data.custom.convoysKilled >= mission.data.custom.convoysToKill then
            nextPhase()
        end

        mission.data.custom.checkForNoTransports = false
        mission.data.description[10].arguments = { _CONVOYKILLED = mission.data.custom.convoysKilled, _CONVOYSTOKILL = mission.data.custom.convoysToKill }
        sync()
    end
end

function vengeStory8_handleConvoyEscape()
    local methodName = "Handle Convoy Escape"
    --mission.Log(methodName, "Calling.") --be careful about adding this one - it is very spammy.

    if mission.data.custom.convoyEscapeTimer >= mission.data.custom.timeUntilConvoyEscape and not mission.data.custom.startConvoyEscapeSequence then
        local transports = { Sector():getEntitiesByScriptValue(mission.data.custom.convoyScriptValue) }

        if transports and #transports > 0 then
            mission.Log(methodName, "At least one transport is alive and escape sequence has not started - starting escape sequence.")
            for _, tp in pairs(transports) do
                local jumpTime = random():getFloat(4, 5)
                tp:addScript("utility/delayeddelete.lua", jumpTime)
            end

            mission.Log(methodName, "Running deferred callback.")
            deferredCallback(3.75, "vengeStory8_convoyEscaped")
        else
            mission.Log(methodName, "All transports are dead! Good job!")
        end

        mission.data.custom.startConvoyEscapeSequence = true
    end
end

function vengeStory8_convoyEscaped() --invoked from vengeStory8_handleConvoyEscape()
    local methodName = "Convoy Escaped"
    mission.Log(methodName, "Calling.")

    mission.data.custom.convoysEscaped = mission.data.custom.convoysEscaped + 1

    mission.data.description[12].arguments = { _CONVOYESCAPE = mission.data.custom.convoysEscaped }
    sync()

    --If 2 or more convoys have escaped and we're still in phase 6, fail.
    if mission.internals.phaseIndex == 6 and mission.data.custom.convoysEscaped >= 2 then
        vengeStory8_sendFailMail(2)
        vengeStory8_friendlyShipsDepart()
        fail()
    end

    mission.data.custom.checkForNoTransports = false
end

function vengeStory8_sendFailMail(failReason)
    --FAIL REASONS
    --1 - ravager escaped too many times
    --2 - too many convoys escaped

    local failReasonMailTable = {
        { --ravager escaped
            text = Format("Hello again.\n\nThe pirate holding the map has escaped. Without it, we won't be able to find Xinull's convoys. I'll track down another one, and will be in touch again.\n\nAllison"),
            mailID = "_vbmn_story8_mailfail1"
        },
        { --convoy escpaed
            text = Format("Hello again.\n\nToo many convoys have escaped from our attack. With more supplies, Xinull can continue to evade my grasp. I'll let you know when I've tracked down another convoy.\n\nAllison"),
            mailID = "_vbmn_story8_mailfail2"
        }
    }

    local _player = Player()
    local _mail = Mail()
    _mail.text = failReasonMailTable[failReason].text
    _mail.header = "Strike Failed"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = failReasonMailTable[failReason].mailid
    _player:addMail(_mail)
end

function vengeStory8_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeStory8_addCleanupScript()
    local _sector = Sector()
    _sector:addScript("sector/deleteentitiesonplayersleft.lua", ESCCUtil.allEntityTypes()) --Do not need to invoke as we will presumably be leaving shortly.
    _sector:removeScript("sector/traders.lua")
end

function vengeStory8_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 5000000

    local gotBonus = false

    local convoyKillBonus = 1.0
    local skipPhase4Bonus = 1.0

    if mission.data.custom.convoysKilled > mission.data.custom.convoysToKill then
        convoyKillBonus = 1.0 + ((mission.data.custom.convoysKilled - mission.data.custom.convoysToKill) * 0.125)
        gotBonus = true
    end

    if mission.data.custom.skippedPhase4Bonus then
        skipPhase4Bonus = 1.05
        gotBonus = true
    end

    local pmtMessage = "Earned %1% credits for destroying the pirate resupply convoys."
    if gotBonus then
        pmtMessage = pmtMessage .. " This includes a bonus for excellent work."
    end

    local finalReward = baseReward * convoyKillBonus * skipPhase4Bonus

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = finalReward, paymentMessage = pmtMessage}

    _player:setValue("_vengeancebmn_story_stage", 9)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory8_handleMarkRunner()
    local _player = Player()
    if not _player then
        return
    end
    if _player.state == PlayerStateType.BuildCraft or _player.state == PlayerStateType.BuildTurret or _player.state == PlayerStateType.PhotoMode then
        return
    end

    local renderer = UIRenderer()

    local _sector = Sector()

    local runner = ESCCUtil.getSingleEntityByValue(_sector, "is_runner")
    local color = ColorRGB(1.0, 0.67, 0.0)

    if runner and valid(runner) then
        local _, size = renderer:calculateEntityTargeter(runner)
    
        renderer:renderEntityTargeter(runner, color, size * 1.25)
        renderer:renderEntityArrow(runner, 30, 10, 250, color)
    end

    renderer:display()
end

function vengeStory8_handleMarkCargo()
    local methodName = "On Mark Dropped Goods"

    local _player = Player()
    if not _player then
        return
    end
    if _player.state == PlayerStateType.BuildCraft or _player.state == PlayerStateType.BuildTurret or _player.state == PlayerStateType.PhotoMode then
        return
    end

    local _sector = Sector()
    local renderer = UIRenderer()

    local possibleGoods = {
        { name = "Oxygen", factor = 100 },
        { name = "Gun", factor = 1 },
        { name = "Ammunition", factor = 1 },
        { name = "Food", factor = 5 },
        { name = "Fuel", factor = 1 },
        { name = "Water", factor = 50 },
        { name = "Clothes", factor = 5 },
        { name = "Food Bar", factor = 5 },
        { name = "Energy Cell", factor = 5 },
        { name = "Medical Supplies", factor = 1 },
        { name = "Body Armor", factor = 0.5 }
    }
    
    local indicatorColor = ESCCUtil.getSaneColor(255, 173, 0)

    for _, entity in pairs({_sector:getEntitiesByComponent(ComponentType.CargoLoot)}) do
        local loot = CargoLoot(entity)
        if valid(entity) then
            for _, cargoGood in pairs(possibleGoods) do
                if loot:matches(cargoGood.name) then
                    local indicator = TargetIndicator(entity)
                    indicator.visuals = TargetIndicatorVisuals.Tilted
                    indicator.color = indicatorColor

                    renderer:renderTargetIndicator(indicator)
                end
            end
        end
    end

    renderer:display()
end

function vengeStory8_phase7Dialog1(allisonID)
    local d0 = {}
    local d1warCrime = {}
    local d1warCrime2 = {}
    local d1warCrime3 = {}
    local d1warCrime4 = {}
    local d1warCrime5 = {}
    local d1warCrime6 = {}
    local d1warCrimeAgain = {}
    local d1warCrimeAgain2 = {}
    local d1warCrimeAgain3 = {}
    local d1warCrimeAgain4 = {}
    local d2a = {}
    local d2b = {}
    local d3 = {}
    local d4 = {}
    local d4aboutHer = {}
    local d4aboutHer2 = {}

    local _player = Player()
    local player5CrimeComplaint = _player:getValue("_vbmn5_complained_about_crimes")
    local player6CrimeComplaint = _player:getValue("_vbmn6_complained_about_crimes")

    d0.text = "Good job. Your work continues to impress me."
    d0.answers = {
        { answer = "Thank you!", followUp = d2a }
    }
    if player5CrimeComplaint and player6CrimeComplaint then
        table.insert(d0.answers, { answer = "This was a also a war crime.", followUp = d1warCrimeAgain, onSelect = vengeStory8_phase7Dialog1CrimeComplaint })
    else
        table.insert(d0.answers, { answer = "This was a war crime.", followUp = d1warCrime, onSelect = vengeStory8_phase7Dialog1CrimeComplaint })
    end

    d1warCrimeAgain.text = "You continue to complain."
    d1warCrimeAgain.followUp = d1warCrimeAgain2

    d1warCrimeAgain2.text = "Have you not seen the pirates track down and slaughter innocent merchants? Raid sectors full of civilians? I know we've discussed this before. These are murderers and criminals that we're dealing with."
    d1warCrimeAgain2.followUp = d1warCrimeAgain3

    d1warCrimeAgain3.text = "Besides, don't tell me your own hands are clean. There are plenty of people out there who will pay good money for you to do their dirty work."
    d1warCrimeAgain3.followUp = d1warCrimeAgain4

    d1warCrimeAgain4.text = "I know of at least one captain who makes her living getting pawns to play the various syndicates off of each other. There are others, I'm sure." --Izzy
    d1warCrimeAgain4.followUp = d1warCrime

    d1warCrime.text = "I want you to understand something."
    d1warCrime.followUp = d1warCrime2

    d1warCrime2.text = "Pirates are non-state actors. War crimes are committed against a state, thus..."
    d1warCrime2.followUp = d1warCrime3

    d1warCrime3.text = "You could dismember them, starve them for a week, cut their tongues out, and eject them into space live as they screamed for mercy. And it still wouldn't be a war crime."
    d1warCrime3.followUp = d1warCrime4

    d1warCrime4.text = "I'm sure it would violate some humanitarian statute somewhere. It doesn't matter."
    d1warCrime4.followUp = d1warCrime5

    d1warCrime5.text = "These people are scum, and need to be treated as such. The factions are too tied up by their precious rules and regulations to solve the problem. And so it falls to us - those who are willing to get blood on their hands..."
    d1warCrime5.followUp = d1warCrime6

    d1warCrime6.text = "... no matter if it's a few drops, or an ocean."
    d1warCrime6.followUp = d2b

    d2a.text = "You're welcome. We're close to the end of the line. By crippling his logistics, we'll force him to leave himself open to resupply."
    d2a.followUp = d3

    d2b.text = "Now, if you don't have any other complaints... we're close to the end of the line. By crippling his logistics, we'll force him to leave himself open to resupply."
    d2b.followUp = d3

    d3.text = "And then... we strike."
    d3.answers = {
        { answer = "I'll be ready.", followUp = d4 },
        { answer = "Is this about the other woman?", followUp = d4aboutHer }
    }

    d4.text = "Good. I'll contact you then, captain."
    d4.onEnd = vengeStory8_onPhase7Dialog1End

    d4aboutHer.text = "... Yes. But I'm still not ready to talk about it. I'll tell you everything once we've killed Xinull."
    d4aboutHer.followUp = d4aboutHer2

    d4aboutHer2.text = "I'll contact you when I see an opening. Until then, captain."
    d4aboutHer2.onEnd = vengeStory8_onPhase7Dialog1End

    local dialogTbl = {
        d0,
        d1warCrime,
        d1warCrime2,
        d1warCrime3,
        d1warCrime4,
        d1warCrime5,
        d1warCrime6,
        d1warCrimeAgain,
        d1warCrimeAgain2,
        d1warCrimeAgain3,
        d1warCrimeAgain4,
        d2a,
        d2b,
        d3,
        d4,
        d4aboutHer,
        d4aboutHer2
    }

    ESCCUtil.setTalkerTextColors(dialogTbl, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion