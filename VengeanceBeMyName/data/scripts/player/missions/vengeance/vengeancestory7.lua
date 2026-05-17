--[[
The Best Defense...
- Main pirate guy attacks the NPC's fleet. The player is tasked with saving it.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "The Best Defense..."

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "Gruznier is dead. Xinull's fortress is destroyed. It is only a matter of time before Xinull's empire crumbles and you can strike at him directly. But you know what they say about cornered rats..." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Protect the Spears of Adrasteia ships", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Ships rescued: ${_RESCUED}", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.reinforcementDangerLevel = 8 --Adjust this for balance.
mission.data.custom.rescuedShips = {} --Rescued ships will help you in subsequent sectors. Have to rescue at least half the ships.
mission.data.custom.allowPhaseAdvance = false
mission.data.custom.phase2Timer = 0
mission.data.custom.phase3Timer = 0
mission.data.custom.phase4Timer = 0
mission.data.custom.phase5Timer = 0
mission.data.custom.phase6Timer = 0
mission.data.custom.phase7Timer = 0
--Easy balance levers
mission.data.custom.phase3ReinforcementTime = 25
mission.data.custom.phase4ReinforcementTime = 30
mission.data.custom.phase5ReinforcementTime = 35
mission.data.custom.phase6ReinforcementTime = 40
mission.data.custom.torpSlamBaseMultiplier = 1.5

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

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBegin = function()
    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }
end

mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.firstSector = vengeStory7_getNextLocation(true)

    local x = mission.data.custom.firstSector.x
    local y = mission.data.custom.firstSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    local _player = Player()
    local _mail = Mail()

    if _player:getValue("_vbmn7_multiple_attempts") then
        _mail.text = Format("Captain.\n\nI was executing a warm-up operation against Xinull's goons when they counterattacked my fleet. My new captains are not battle-hardened, and were quickly scattered across multiple sectors. They are under fire now. I am loathe to ask you to bail me out again, but I have no other option. I... cannot lose everything. Not again. Start with (%1%:%2%). Hurry!\n\nAllison", x, y)
    else
        _mail.text = Format("Captain.\n\nI've overextended my fleet. We were on a multi-pronged offensive against some of Xinull's remaining forces when he split us up. All of my ships are scattered and under attack. I am loathe to ask you to bail me out, but I have no other options. I... cannot lose everything. Not now. Start with (%1%:%2%). Hurry!\n\nAllison", x, y)
    end

    _mail.header = "Emergency Request"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story7_mail1"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story7_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {} --Save 1x Cruiser
mission.phases[2].triggers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.firstSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    --I did this in 15 minutes with a barely-optimized ship loadout AND while stopping for loot. 20 minutes is enough.
    mission.data.timeLimit = mission.internals.timePassed + (20 * 60) --Start mission timer after hitting the first sector.
    mission.data.timeLimitInDescription = true

    mission.data.description[3].visible = false
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    if onServer() then
        mission.data.custom.secondSector = vengeStory7_getNextLocation(false)

        local _player = Player()
        if _player:hasScript("events/alienattack.lua") then
            _player:removeScript("events/alienattack.lua")
            _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
        end

        vengeStory7_spawnPirateAttackers(6, 1)
        vengeStory7_spawnAdrasteiaShipsToDefend()
        vengeStory7_addCleanupScript()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercssnakecity.ogg")

    mission.data.custom.phase2Timer = 0 --Reset timer.
    --Reset triggers
    for _, trigger in pairs(mission.phases[2].triggers) do
        trigger.triggered = false
    end
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase2Timer = mission.data.custom.phase2Timer + timeStep
end

--region #PHASE 2 TRIGGERS

if onServer() then

mission.phases[2].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase2Timer >= 20
    end,
    callback = function()
        vengeStory7_spawnAllison()
    end,
    repeating = false
}

mission.phases[2].triggers[2] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase2Timer >= 30
    end,
    callback = function()
        VengeUtil.allisonChatter(nil, "Thanks for coming. Eliminate the pirates as quickly as you can.") --Highly unlikely she warps out in 10s but if she does I'm okay with the player missing this.
    end,
    repeating = false
}

mission.phases[2].triggers[3] = { --Allison departure trigger
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0 and mission.data.custom.allowPhaseAdvance
    end,
    callback = function()
        vengeStory7_addSavedShips()
        VengeUtil.allisonChatter(nil, "There are more. Keep moving.")
        vengeStory7_friendlyShipsDepart(true)

        mission.data.custom.allowPhaseAdvance = false
        nextPhase()
    end,
    repeating = false
}

end

--endregion

mission.phases[3] = {} --Save 1x Missile Cruiser
mission.phases[3].triggers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBegin = function()
    mission.data.location = mission.data.custom.secondSector

    mission.data.description[3].visible = true
    mission.data.description[4].visible = false

    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }
end

mission.phases[3].onTargetLocationEntered = function(x, y)
    mission.data.description[3].visible = false
    mission.data.description[4].visible = true

    if onServer() then
        mission.data.custom.thirdSector = vengeStory7_getNextLocation(false)

        vengeStory7_spawnPirateAttackers(6, 2)
        vengeStory7_spawnAdrasteiaShipsToDefend()
        vengeStory7_addCleanupScript()
    end
end

mission.phases[3].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercssnakecity.ogg")

    mission.data.custom.phase3Timer = 0
    --reset triggers
    for _, trigger in pairs(mission.phases[3].triggers) do
        trigger.triggered = false
    end
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase3Timer = mission.data.custom.phase3Timer + timeStep
end

--region #PHASE 3 TRIGGERS

mission.phases[3].triggers[1] = { --Reinforcement timer trigger
    condition = function()
        return atTargetLocation() and mission.data.custom.phase3Timer >= mission.data.custom.phase3ReinforcementTime
    end,
    callback = function()
        vengeStory7_spawnAllison()
        vengeStory7_spawnSavedShips()
    end,
    repeating = false
}

mission.phases[3].triggers[2] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0 and mission.data.custom.allowPhaseAdvance
    end,
    callback = function()
        vengeStory7_addSavedShips()
        vengeStory7_friendlyShipsDepart(true)

        mission.data.custom.allowPhaseAdvance = false
        nextPhase()
    end,
    repeating = false
}

--endregion

mission.phases[4] = {} --Save 1x Cruiser + 1x Missile Cruiser
mission.phases[4].triggers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.location = mission.data.custom.thirdSector

    mission.data.description[3].visible = true
    mission.data.description[4].visible = false

    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }
end

mission.phases[4].onTargetLocationEntered = function(x, y)
    mission.data.description[3].visible = false
    mission.data.description[4].visible = true

    if onServer() then
        mission.data.custom.fourthSector = vengeStory7_getNextLocation(false)

        vengeStory7_spawnPirateAttackers(6, 1)
        vengeStory7_spawnPirateAttackers(6, 2)
        vengeStory7_spawnAdrasteiaShipsToDefend()
        vengeStory7_addCleanupScript()
    end
end

mission.phases[4].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercssnakecity.ogg")

    mission.data.custom.phase4Timer = 0
    --reset triggers
    for _, trigger in pairs(mission.phases[4].triggers) do
        trigger.triggered = false
    end
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase4Timer = mission.data.custom.phase4Timer + timeStep
end

--region #PHASE 4 TRIGGERS

mission.phases[4].triggers[1] = { --Reinforcement timer trigger
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4Timer >= mission.data.custom.phase4ReinforcementTime
    end,
    callback = function()
        vengeStory7_spawnAllison()
        vengeStory7_spawnSavedShips()
    end,
    repeating = false
}

mission.phases[4].triggers[2] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0 and mission.data.custom.allowPhaseAdvance
    end,
    callback = function()
        vengeStory7_addSavedShips()
        vengeStory7_friendlyShipsDepart(true)

        mission.data.custom.allowPhaseAdvance = false
        nextPhase()
    end,
    repeating = false
}

--endregion

mission.phases[5] = {} --Save 2x Cruiser
mission.phases[5].triggers = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBegin = function()
    mission.data.location = mission.data.custom.fourthSector

    mission.data.description[3].visible = true
    mission.data.description[4].visible = false

    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }
end

mission.phases[5].onTargetLocationEntered = function(x, y)
    mission.data.description[3].visible = false
    mission.data.description[4].visible = true

    if onServer() then
        mission.data.custom.fifthSector = vengeStory7_getNextLocation(false)

        vengeStory7_spawnPirateAttackers(6, 1)
        vengeStory7_spawnPirateAttackers(6, 2)
        vengeStory7_spawnAdrasteiaShipsToDefend()
        vengeStory7_addCleanupScript()
    end
end

mission.phases[5].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercssnakecity.ogg")

    mission.data.custom.phase5Timer = 0
    --reset triggers
    for _, trigger in pairs(mission.phases[5].triggers) do
        trigger.triggered = false
    end
end

mission.phases[5].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase5Timer = mission.data.custom.phase5Timer + timeStep
end

--region #PHASE 5 TRIGGERS

if onServer() then

mission.phases[5].triggers[1] = { --Reinforcement timer trigger
    condition = function()
        return atTargetLocation() and mission.data.custom.phase5Timer >= mission.data.custom.phase5ReinforcementTime
    end,
    callback = function()
        vengeStory7_spawnAllison()
        vengeStory7_spawnSavedShips()
    end,
    repeating = false
}

mission.phases[5].triggers[2] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0 and mission.data.custom.allowPhaseAdvance
    end,
    callback = function()
        vengeStory7_addSavedShips()
        VengeUtil.allisonChatter(nil, "One more sector to go. Keep it up.")
        vengeStory7_friendlyShipsDepart(true)

        mission.data.custom.allowPhaseAdvance = false
        nextPhase()
    end,
    repeating = false
}

mission.phases[5].triggers[3] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt < 8 and mission.data.custom.phase5Timer >= 10
    end,
    callback = function()
        vengeStory7_spawnPirateAttackers(4, 3)
        vengeStory7_spawnPirateAttackers(4, 3)
    end,
    repeating = false
}

end

--endregion

mission.phases[6] = {} --Save 2x Missile Cruiser
mission.phases[6].triggers = {}
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].onBegin = function()
    mission.data.location = mission.data.custom.fifthSector

    mission.data.description[3].visible = true
    mission.data.description[4].visible = false

    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }
end

mission.phases[6].onTargetLocationEntered = function(x, y)
    mission.data.description[3].visible = false
    mission.data.description[4].visible = true

    if onServer() then
        vengeStory7_spawnPirateAttackers(6, 1)
        vengeStory7_spawnPirateAttackers(6, 2)
        vengeStory7_spawnAdrasteiaShipsToDefend()
        vengeStory7_addCleanupScript()
    end
end

mission.phases[6].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercssnakecity.ogg")

    mission.data.custom.phase6Timer = 0
    --reset triggers
    for _, trigger in pairs(mission.phases[6].triggers) do
        trigger.triggered = false
    end
end

mission.phases[6].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase6Timer = mission.data.custom.phase6Timer + timeStep
end

--region #PHASE 6 TRIGGERS

if onServer() then


mission.phases[6].triggers[1] = { --Reinforcement timer trigger
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= mission.data.custom.phase6ReinforcementTime
    end,
    callback = function()
        vengeStory7_spawnAllison()
        vengeStory7_spawnSavedShips()
    end,
    repeating = false
}

mission.phases[6].triggers[2] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0 and mission.data.custom.allowPhaseAdvance
    end,
    callback = function()
        vengeStory7_addSavedShips()
        vengeStory7_friendlyShipsDepart(false)

        mission.data.custom.allowPhaseAdvance = false
        nextPhase()
    end,
    repeating = false
}

mission.phases[6].triggers[3] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt < 8 and mission.data.custom.phase6Timer >= 10
    end,
    callback = function()
        vengeStory7_spawnPirateAttackers(6, 3)
        vengeStory7_spawnPirateAttackers(6, 3)
    end,
    repeating = false
}

end

--endregion

mission.phases[7] = {} --Talk to Allison phase
mission.phases[7].triggers = {}
mission.phases[7].onBegin = function()
    print("You got to phase 7! Congrats!")
    mission.data.description[3].fulfilled = true
    mission.data.description[4].fulfilled = true

    mission.data.description[5].arguments = { _RESCUED = #mission.data.custom.rescuedShips }

    --Guarantee you someone finishes this with 30 seconds left and fails while talking to Allison. I'd be really upset if that happened to me so let's spare any unfortunate souls yeah?
    mission.data.timeLimit = nil
    mission.data.timeLimitInDescription = false
end

mission.phases[7].onBeginServer = function()
    --If Allison is somehow not there, spawn her.
    vengeStory7_spawnAllison()
end

mission.phases[7].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase7Timer = mission.data.custom.phase7Timer + timeStep
end

local vengeStory7_onDialogEndGood = makeDialogServerCallback("vengeStory7_onDialogEndGood", 7, function()
    vengeStory7_friendlyShipsDepart(true)
    vengeStory7_finishAndReward()
end)

local vengeStory7_onDialogEndBad = makeDialogServerCallback("vengeStory7_onDialogEndBad", 7, function()
    Player():setValue("_vbmn7_multiple_attempts", true)
    fail()
end)

--region #PHASE 7 TRIGGERS

if onServer() then

mission.phases[7].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase7Timer >= 10
    end,
    callback = function()
        invokeClientFunction(Player(), "vengeStory7_onEndMissionDialog", mission.data.custom.allisonID)
    end,
    repeating = false
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory7_getNextLocation(useBlockRing)
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 230
    local minDist = 210
    local maxDist = 240
    local minRad, maxRad = 6, 12

    if useBlockRing then
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)

        local _safetyBreakout = 0
        while target.x == x and target.y == y and _safetyBreakout <= 100 do
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)
            _safetyBreakout = _safetyBreakout + 1
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

function vengeStory7_spawnPirateAttackers(pirateCt, wingID)
    local methodName = "Spawn Pirate Attackers"
    mission.Log(methodName, "Beginning...")

    local distance = 250 --_#DistAdj

    local wingFuncTable = {
        vengeStory7_onAlphaPirateAttackersFinished, --Alpha wing attacks _vbmn7_def_objective_1
        vengeStory7_onBetaPirateAttackersFinished, --Beta wing attacks _vbmn7_def_objective_2
        vengeStory7_onDeltaPirateAttackersFinished --Delta wing attacks everyone.
    }

    local wingDangerTable = {
        mission.data.custom.dangerLevel,
        mission.data.custom.dangerLevel,
        mission.data.custom.reinforcementDangerLevel
    }

    local wingSpawnTable = ESCCUtil.getStandardWave(wingDangerTable[wingID], pirateCt, "Standard", false)
    local wingGenerator = AsyncPirateGenerator(nil, wingFuncTable[wingID])

    local wingPositions = wingGenerator:getStandardPositions(pirateCt, distance)

    wingGenerator:startBatch()

    for posIdx, p in pairs(wingSpawnTable) do
        wingGenerator:createScaledPirateByName(p, wingPositions[posIdx])
    end

    wingGenerator:endBatch()
end

function vengeStory7_onAlphaPirateAttackersFinished(generated)
    local targetScriptValue = "_vbmn7_def_objective_1"

    for _, p in pairs(generated) do
        p:addScriptOnce("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = targetScriptValue })
        p:setValue("_vbmn7_alpha_wing", true)
    end

    local torpSlammerValues = {
        _TimeToActivate = 45,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = mission.data.custom.torpSlamBaseMultiplier,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = targetScriptValue,
        _RangeFactor = 3
    }

    shuffle(random(), generated)

    local maxTorpSlammers = 1
    if #generated > 4 then
        maxTorpSlammers = 2
    end
    for idx = 1, maxTorpSlammers do
        generated[idx]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        ESCCUtil.setBombardier(generated[idx])
    end

    --Standard func.
    vengeStory7_onPirateAttackersFinished(generated)
end

function vengeStory7_onBetaPirateAttackersFinished(generated)
    local targetScriptValue = "_vbmn7_def_objective_2"

    for _, p in pairs(generated) do
        p:addScriptOnce("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = targetScriptValue })
        p:setValue("_vbmn7_beta_wing", true)
    end

    local torpSlammerValues = {
        _TimeToActivate = 45,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = mission.data.custom.torpSlamBaseMultiplier,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = targetScriptValue,
        _RangeFactor = 3
    }

    shuffle(random(), generated)

    local maxTorpSlammers = 1
    if #generated > 4 then
        maxTorpSlammers = 2
    end
    for idx = 1, maxTorpSlammers do
        generated[idx]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        ESCCUtil.setBombardier(generated[idx])
    end

    --Standard func.
    vengeStory7_onPirateAttackersFinished(generated)
end

function vengeStory7_onDeltaPirateAttackersFinished(generated)
    local targetScriptValue = "is_adrasteia_warship" --Make sure they don't directly attack Allison, but they should attack the other adrasteia ships.

    for _, p in pairs(generated) do
        p:addScriptOnce("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = targetScriptValue })
        p:setValue("_vbmn7_delta_wing", true)
    end

    local torpSlammerValues = {
        _TimeToActivate = 30,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = mission.data.custom.torpSlamBaseMultiplier,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = targetScriptValue,
        _RangeFactor = 3
    }

    shuffle(random(), generated)

    generated[1]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
    ESCCUtil.setBombardier(generated[1])

    --Standard func.
    vengeStory7_onPirateAttackersFinished(generated)
end

function vengeStory7_onPirateAttackersFinished(generated)
    for _, p in pairs(generated) do
        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 --Xinull goon boost.
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)

    mission.data.custom.allowPhaseAdvance = true
end

function vengeStory7_spawnAllison()
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
        local allison = VengeUtil.spawnAllison(false, false)

        local allisonAI = ShipAI(allison)
        allisonAI:setAggressive()

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory7_spawnAdrasteiaShipsToDefend()
    local methodName = "Adding ships to defend"

    local defenseShips = {}

    local spawnFuncs = {
        function(customValue)
            local ship = VengeUtil.spawnAdrasteiaWarship(true) --We _also_ add a cleanup script, but we should set this to true anyways to show that it will be deleted.
            ship:setValue("_vbmn7_warship_defense_objective", true)
            ship:setValue(customValue, true)
            table.insert(defenseShips, ship)
        end,
        function(customValue)
            local ship = VengeUtil.spawnAdrasteiaMissileShip(true)
            ship:setValue("_vbmn7_missile_ship_defense_objective", true)
            ship:setValue(customValue, true)
            table.insert(defenseShips, ship)
        end
    }

    local phaseIndexFuncTable = {
        nil, --Phase 1 doesn't have a group to rescue.
        function() --Phase 2 has 1 cruiser
            spawnFuncs[1]("_vbmn7_def_objective_1")
        end,
        function() -- Phase 3 has 1 missile cruiser
            spawnFuncs[2]("_vbmn7_def_objective_1")
        end,
        function() -- Phase 4 has 1 cruiser and 1 missile cruiser
            spawnFuncs[1]("_vbmn7_def_objective_1")
            spawnFuncs[2]("_vbmn7_def_objective_2")
        end,
        function() --Phase 5 has 2 cruisers
            spawnFuncs[1]("_vbmn7_def_objective_1")
            spawnFuncs[1]("_vbmn7_def_objective_2")
        end,
        function() --Phase 6 has 2 missile cruisers
            spawnFuncs[2]("_vbmn7_def_objective_1")
            spawnFuncs[2]("_vbmn7_def_objective_2")
        end
    }

    local phaseIdx = mission.internals.phaseIndex
    if phaseIndexFuncTable[phaseIdx] then
        phaseIndexFuncTable[phaseIdx]()
    end

    for _, ship in pairs(defenseShips) do
        mission.Log(methodName, "Setting rescuable ship to aggressive")
        local defenseShipAI = ShipAI(ship)
        defenseShipAI:setAggressive()
    end
end

function vengeStory7_addSavedShips()
    local adrasteiaShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(adrasteiaShips) do
        if ship:getValue("is_adrasteia_cruiser") then
            table.insert(mission.data.custom.rescuedShips, "Cruiser")
        end
        if ship:getValue("is_adrasteia_missile_ship") then
            table.insert(mission.data.custom.rescuedShips, "TorpCruiser")
        end
    end
end

function vengeStory7_spawnSavedShips()
    local methodName = "Spawn Saved Ships"

    for _, ship in pairs(mission.data.custom.rescuedShips) do
        mission.Log(methodName, "Spawning saved " .. ship)
        local savedShip = nil
        if ship == "Cruiser" then
            savedShip = VengeUtil.spawnAdrasteiaWarship(true)
        end
        if ship == "TorpCruiser" then
            savedShip = VengeUtil.spawnAdrasteiaMissileShip(true)
        end

        if savedShip then
            local savedShipAI = ShipAI(savedShip)
            savedShipAI:setAggressive()
        end
    end

    mission.data.custom.rescuedShips = {}
end

function vengeStory7_friendlyShipsDepart(allisonDeparts)
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        local addScript = false --Assume false

        if ship:getValue("is_allison") then
            if allisonDeparts then
                addScript = true
            end
        else
            addScript = true
        end

        if addScript then
            local departTimer = random():getFloat(3, 6)
            if ship:getValue("is_allison") then
                departTimer = departTimer + 3
            end
             
            ship:addScriptOnce("entity/utility/delayeddelete.lua", departTimer)
        end
    end
end

function vengeStory7_addCleanupScript()
    local _sector = Sector()
    _sector:addScript("sector/deleteentitiesonplayersleft.lua", ESCCUtil.allEntityTypes()) --Do not need to invoke as we will presumably be leaving shortly.
    _sector:removeScript("sector/traders.lua")
end

function vengeStory7_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 5000000

    local rescueBonus = 1.0
    local pmtMessage = "Earned %1% credits for saving the Spears of Adrasteia ships."

    if #mission.data.custom.rescuedShips == 8 then
        rescueBonus = 1.25
        pmtMessage = pmtMessage .. " This includes a bonus for saving all of the ships."
    end

    local finalReward = baseReward * rescueBonus

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = finalReward, paymentMessage = pmtMessage}

    _player:setValue("_vengeancebmn_story_stage", 8)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory7_onEndMissionDialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}

    --Player needs to save 5/8 ships to win. Different options based on how many the player saves.
    local rescuedShips = #mission.data.custom.rescuedShips

    if rescuedShips == 8 then --exceptional success
        d0.text = "We managed to save all of them. Incredible."
        d1.text = "Your work today has been exceptional. Xinull threw away dozens of ships for nothing."
        d2.text = "Our work continues. I'll be in touch. Thank you for a job well done, Captain."

        d2.onEnd = vengeStory7_onDialogEndGood
    elseif rescuedShips < 8 and rescuedShips >= 5 then --success
        d0.text = "You saved my fleet. The losses are unfortunate, but not unexpected."
        d1.text = "This is... fine. I can rebuild from here. I must."
        d2.text = "Our work continues. I'll be in touch. Thank you, Captain."

        d2.onEnd = vengeStory7_onDialogEndGood
    elseif rescuedShips < 5 and rescuedShips > 0 then --failure
        d0.text = "Despite your efforts, we couldn't save enough. This won't be enough..."
        d1.text = "I was afraid of this. Still, I didn't lose everything. That's a start, at least..."
        d2.text = "I will do my best to rebuild. Until then, Captain."

        d2.onEnd = vengeStory7_onDialogEndBad
    else --rescuedShips == 0 --abject failure
        d0.text = "I... Really? You couldn't save any of them? That is..."
        d1.text = "I'm alive, at least. I suppose that will have to do."
        d2.text = "I will do my best to rebuild. Until then..."

        d2.onEnd = vengeStory7_onDialogEndBad
    end

    d0.followUp = d1
    d1.followUp = d2
    
    ESCCUtil.setTalkerTextColors({ d0, d1, d2 }, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion