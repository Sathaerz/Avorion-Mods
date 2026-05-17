--[[
Introductions
- Destroy an unrelated pirate group - main NPC introduces jumps in and introduces herself.
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
mission._Name = "Introductions"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "You recently accepted a job that involved spying on a group of pirates. It's not entirely clear what your employer was looking for, but it seems like they got what they wanted. After paying you, they promised to send their next request in short order." },
    { text = "Read the unknown mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the first wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the second wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the third wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the fourth wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to the other captain", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.showedFirstUpdate = false
mission.data.custom.timeInPhaseTwo = 0
mission.data.custom.timerAdvance = false
mission.data.custom.allisonChatterSent = false
mission.data.custom.allisonPhase6DialogStarted = false

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationEntered = function(x, y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.fightSector = vengeStory2_getNextLocation()

    local x = mission.data.custom.fightSector.x
    local y = mission.data.custom.fightSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    --Send mail to player
    local _player = Player()
    local _mail = Mail()
    _mail.text = Format("Hi.\n\nGood job on the recon assignment. I didn't expect much, but you handled it perfectly. We've got some time until the next pirate raid, so I'll kill two birds with one stone. I want to see how well you fight, and I should probably introduce myself.\n\nThere's an unrelated group of pirates planning on raiding a nearby sector soon. You'll find them gathering in (%1%:%2%). Go there and kill them. Once I'm satisfied, I'll join you.", x, y)
    _mail.header = "Next Request"
    _mail.sender = "UNKNOWN SENDER @UNKNOWN DOMAIN (WARNING!)"
    _mail.id = "_vbmn_story2_mail"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story2_mail" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].triggers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    local _MethodName = "Phase 2 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.fightSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    mission.data.custom.cleanUpSector = true
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    if not mission.data.custom.showedFirstUpdate then
        showMissionUpdated()
        mission.data.custom.showedFirstUpdate = true
    end
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    mission.data.custom.timeInPhaseTwo = (mission.data.custom.timeInPhaseTwo or 0) + timeStep
end

--region #PHASE 2 TRIGGERS

if onServer() then

mission.phases[2].triggers[1] = {
    condition = function()
        if atTargetLocation() and mission.data.custom.timeInPhaseTwo >= 15 then
            return true
        else
            return false
        end
    end,
    callback = function()
        vengeStory2_spawnPirateWave(4) --Wave one.
    end,
    repeating = false
}

end

--endregion

--region #PHASE 2 TIMERS

if onServer() then

mission.phases[2].timers[1] = {
    time = 10, 
    callback = function() 
        if vengeStory2_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].timers = {}
mission.phases[3].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[3].onBeginServer = function()
    vengeStory2_spawnPirateWave(5) --Wave two.
end

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 10, 
    callback = function() 
        if vengeStory2_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].timers = {}
mission.phases[4].onBegin = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
end

mission.phases[4].onBeginServer = function()
    vengeStory2_spawnPirateWave(6) --Wave three.
end

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 10, 
    callback = function() 
        if vengeStory2_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].onBegin = function()
    mission.data.description[6].fulfilled = true
    mission.data.description[7].visible = true
end

mission.phases[5].onBeginServer = function()
    vengeStory2_spawnPirateWave(8) --Wave four. You get some help here.
    vengeStory2_spawnAllison()
end

--region #PHASE 5 TIMERS

if onServer() then

mission.phases[5].timers[1] = {
    time = 5,
    callback = function()
        if atTargetLocation() and not mission.data.custom.allisonChatterSent then
            VengeUtil.allisonChatter(nil, "Erinyes on station. Engaging pirates.")
            mission.data.custom.allisonChatterSent = true
        end
    end,
    repeating = true
}

mission.phases[5].timers[2] = {
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory2_spawnAllison()
        end
    end,
    repeating = true
}

mission.phases[5].timers[3] = {
    time = 10, 
    callback = function() 
        if vengeStory2_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[6] = {}
mission.phases[6].timers = {}
mission.phases[6].onBegin = function()
    mission.data.description[7].fulfilled = true
    mission.data.description[8].visible = true
end

mission.phases[6].onBeginServer = function()
    vengeStory2_spawnAllison()
end

local vengeStory2_onPhase6DialogEnd = makeDialogServerCallback("vengeStory2_onPhase6DialogEnd", 6, function()
    local allison = Entity(mission.data.custom.allisonID)
    allison:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))

    vengeStory2_finishAndReward()
end)

--region #PHASE 6 TIMERS

if onServer() then

mission.phases[6].timers[1] = {
    time = 5,
    callback = function()
        if atTargetLocation() then
            local allison = Entity(mission.data.custom.allisonID)
            if allison and valid(allison) and not mission.data.custom.allisonPhase6DialogStarted then
                mission.data.custom.allisonPhase6DialogStarted = true
                invokeClientFunction(Player(), "vengeStory2_onPhase6Dialog", mission.data.custom.allisonID)
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory2_spawnPirateWave(numPirates)
    local methodName = "Spawn Pirate Wave"
    mission.Log(methodName, "Spawning " .. tostring(numPirates) .. " pirates.")

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, numPirates, "Standard", false)

    local generator = AsyncPirateGenerator(nil, vengeStory2_onPirateWaveFinished)

    generator:startBatch()

    local distance = 250 --_#DistAdj
    local piratePositions = generator:getStandardPositions(numPirates, distance)
    for posIdx, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, piratePositions[posIdx])
    end

    generator:endBatch()
end

function vengeStory2_onPirateWaveFinished(generated)
    local methodName = "On Pirate Wave Spawned"
    mission.Log(methodName, "Running. Setting timerAdvance to true and adding buffs / resolving placer.")

    mission.data.custom.timerAdvance = true

    SpawnUtility.addEnemyBuffs(generated)

    Placer.resolveIntersections(generated)
end

function vengeStory2_spawnAllison()
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
        local allison = VengeUtil.spawnAllison(false, true)
        local allisonAI = ShipAI(allison)

        allisonAI:setAggressive()

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory2_allowPhaseAdvancement()
    local methodName = "Allow Phase Advancement"

    local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

    mission.Log(methodName, "At Target Location: " .. tostring(atTargetLocation()) .. " number of pirates : " .. tostring(pirateCt) .. " timer allowed to advance : " .. tostring(mission.data.custom.timerAdvance))

    if atTargetLocation() and pirateCt == 0 and mission.data.custom.timerAdvance then
        return true
    else
        return false
    end
end

function vengeStory2_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 265

    local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
    target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 4, 8, false)
    local _safetyBreakout = 0
    while target.x == x and target.y == y and _safetyBreakout <= 100 do
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 4, 8, false)
        _safetyBreakout = _safetyBreakout + 1
    end

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function vengeStory2_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 3000000

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = baseReward, paymentMessage = "Earned %1% credits for defeating the pirate raid."}

    _player:setValue("_vengeancebmn_story_stage", 3)
    _player:setValue("encyclopedia_vbmn_spears", true)
    _player:setValue("encyclopedia_vbmn_allison", true)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory2_onPhase6Dialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d1tracking1 = {}
    local d1tracking2 = {}
    local d1tracking3 = {}
    local d1tracking4 = {}
    local d1tracking5 = {}
    local d1tracking6 = {}
    local d1hired = {}
    local d1whatsthejob1 = {}
    local d1whatsthejob2 = {}
    local d1whatsthejob3 = {}
    local d1whatsthejob4 = {}
    local d1whatsthejobgruz = {}
    local d1whatsthejobwtf = {}
    local d1thatspersonal = {}
    local d1explainunitname = {}
    local d1explainyourself1 = {}
    local d1explainyourself2 = {}
    local d1explainyourself3 = {}
    local d2 = {}
    local d3 = {}

    d0.text = "I see you can handle yourself in a fight as well. Good job."
    d0.answers = {
        { answer = "Who are you?", followUp = d1 }
    }

    d1.text = "A reasonable question. I'm Allison Vannier. Commander of the Spears of Adrasteia."
    d1.answers = {
        { answer = "How have you been tracking me?", followUp = d1tracking1 },
        { answer = "Are you the one who hired me?", followUp = d1hired },
        { answer = "What's the job?", followUp = d1whatsthejob1 },
        { answer = "Spears of Adrasteia?", followUp = d1explainunitname }
    }

    d1hired.text = "Yes. Obviously."
    d1hired.followUp = d2

    d1explainunitname.text = "Adrasteia was an ancient Greek goddess. She was worshipped as a goddess of vengeance, but more importantly she represented the inescapability of punishment. Her name felt particularly appropriate, given what I want to do."
    d1explainunitname.answers = {
        { answer = "I see.", followUp = d2 },
        { answer = "What do you want to do?", followUp = d1whatsthejob1 }
    }

    d1tracking1.text = "Bugged your ship."
    d1tracking1.answers = {
        { answer = "Why would you do that?", followUp = d1tracking2 },
        { answer = "Don't do that again.", followUp = d1tracking3 },
        { answer = "That's a little intrusive, don't you think?", followUp = d1tracking4 }
    }

    d1tracking2.text = "Needed to know."
    d1tracking2.answers = {
        { answer = "Needed to know what?", followUp = d1tracking5 }
    }

    d1tracking3.text = "I don't plan on it."
    d1tracking3.followUp = d2

    d1tracking4.text = "You're right. But if you knew what was at stake, you'd do the same."
    d1tracking4.answers = {
        { answer = "What's at stake?", followUp = d1tracking6 }
    }

    d1tracking5.text = "If you could do the job."
    d1tracking5.answers = {
        { answer = "What's the job?", followUp = d1whatsthejob1 }
    }

    d1tracking6.text = "The job. I can't trust something like this to an incompetent captain. I can't."
    d1tracking6.answers = {
        { answer = "What's the job?", followUp = d1whatsthejob1 },
        { answer = "... I see.", followUp = d2 }
    }

    d1whatsthejob1.text = "There's a man, and I want to kill him."
    d1whatsthejob1.answers = {
        { answer = "Who?", followUp = d1whatsthejob2 },
        { answer = "Is it Gruznier?", followUp = d1whatsthejob3 },
        { answer = "Is it Xinull?", followUp = d1whatsthejob4 },
        { answer = "Understood.", followUp = d2 },
        { answer = "Killing is wrong.", followUp = d1whatsthejobwtf }
    }

    d1whatsthejob2.text = "His name is Xinull. He's a pirate boss in this area of space. Not quite as famous as Swoks, but just as nasty."
    d1whatsthejob2.answers = {
        { answer = "Why do you want to kill him?", followUp = d1thatspersonal },
        { answer = "Understood.", followUp = d2 }
    }

    d1whatsthejob3.text = "No. But we're probably going to have to kill him too."
    d1whatsthejob3.answers = {
        { answer = "Who, then?", followUp = d1whatsthejob2 },
        { answer = "Why?", followUp = d1whatsthejobgruz }
    }

    d1whatsthejob4.text = "Very perceptive of you. Yes. Xinull is my target. He's a pirate boss in this area of space, and I'm going to kill him."
    d1whatsthejob4.answers = {
        { answer = "Why?", followUp = d1thatspersonal },
        { answer = "Understood.", followUp = d2 }
    }

    d1whatsthejobwtf.text = "I didn't realize you were a pacifist. You destroyed fifteen pirate ships by my count, and now you're going to tell me you object to killing one man? Get off your high horse."
    d1whatsthejobwtf.followUp = d2

    d1whatsthejobgruz.text = "He's a lackey of my target. His chief enforcer and practically his right hand man."
    d1whatsthejobgruz.answers = {
        { answer = "Who is your target?", followUp = d1whatsthejob2 }
    }

    d1thatspersonal.text = "... That's personal. I'm not ready to talk about it."
    d1thatspersonal.followUp = d2

    d1explainyourself1.text = "What do you mean?"
    d1explainyourself1.answers = {
        { answer = "You're very terse.", followUp = d1explainyourself2 },
        { answer = "You seem very bloodthirsty.", followUp = d1thatspersonal },
        { answer = "Never mind.", followUp = d2 }
    }

    d1explainyourself2.text = "I suppose that's true. I'm not great at talking to people. Never was. Always preferred the controls of a ship, or the sights of a gun. I've gotten worse. Not that it matters."
    d1explainyourself2.answers = {
        { answer = "It matters to me.", followUp = d1explainyourself3 },
        { answer = "I see.", followUp = d2 }
    }

    d1explainyourself3.text = "Why? You hardly know me. Let's get back to the task at hand."
    d1explainyourself3.followUp = d2

    d2.text = "Do you have any other questions?"
    d2.answers = {
        { answer = "How have you been tracking me?", followUp = d1tracking1 },
        { answer = "Are you the one who hired me?", followUp = d1hired },
        { answer = "What's the job?", followUp = d1whatsthejob1 },
        { answer = "Spears of Adrasteia?", followUp = d1explainunitname },
        { answer = "Why are you like this?", followUp = d1explainyourself1 },
        { answer = "No.", followUp = d3 }
    }
    
    d3.text = "So you understand the assignment. Good. This isn't over yet - there's still much work left to be done. I'll send you my next request soon. In the meantime, don't get yourself killed. I'd hate to have to find someone else."
    d3.onEnd = vengeStory2_onPhase6DialogEnd

    d0.talkerColor = VengeUtil.getDialogAllisonTalkerColor()
    d0.textColor = VengeUtil.getDialogAllisonTextColor()
    ESCCUtil.setTalkerTextColors({d1, d1tracking1, d1tracking2, d1tracking3, d1tracking4, d1tracking5, d1tracking6, d1hired, d1whatsthejob1, d1whatsthejob2, d1whatsthejob3, d1whatsthejob4, d1whatsthejobgruz, d1whatsthejobwtf, d1thatspersonal, d1explainunitname, d1explainyourself1, d1explainyourself2, d1explainyourself3, d2, d3}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion