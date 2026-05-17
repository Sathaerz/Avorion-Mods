--[[
Et Tu, Brute
- Attack the pirate guy's lieutenant and kill him.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local PirateGenerator = include("pirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Et Tu, Brute"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "With your help, Allison has destroyed Xinull's outpost and killed all of his men in the sector. She promised that she would contact you when she was ready to make it personal. It doesn't get much more personal than killing someone's second in command." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirates in the area", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Await further instructions", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Kill Brute Gruznier", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.phase3ChatterSent = false
mission.data.custom.phase4TimerEnabled = false
mission.data.custom.phase4Timer = 0
mission.data.custom.phase4JammerTimerEnabled = false
mission.data.custom.phase4JammerTimer = 0
mission.data.custom.phase4GruzSpawnTimerEnabled = false
mission.data.custom.phase4GruzSpawnTimer = 0
mission.data.custom.phase6Timer = 0

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
    local pcmFunc = function()
        setCustomMusic("data/music/vengeance/mw2mercsgotterdammerung.ogg")
    end

    local phaseIndexFuncTable = {
        nil, --Phase 1 has no location
        nil, --Phase 2 only creates the sector
        pcmFunc, --Phase 3 is wipe out pirates
        pcmFunc, --Phase 4 is war crimes
        nil, --Phase 5 is Gruznier fight and has its own music
        nil --Phase 6 is just talking with Allison
    }
    
    local phaseIdx = mission.internals.phaseIndex
    if phaseIndexFuncTable[phaseIdx] then
        phaseIndexFuncTable[phaseIdx]()
    end
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    setGameMusic()
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.gruzSector = vengeStory6_getNextLocation()

    local x = mission.data.custom.gruzSector.x
    local y = mission.data.custom.gruzSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    local _player = Player()
    local _mail = Mail()
    _mail.text = Format("Hello again, Captain.\n\nMy subordinates and I have captured a pirate crew. That jammer we used to destroy the Arms Fortress has one last job - we're going to use it as bait. If we tune the ECM to boost signals instead of suppressing them, we should be able to contact pirates in nearby sectors. Pair that with some recently-destroyed pirate ships, and...\n\n... it should work for our purposes. We're going to try and lure in Gruznier - Xinull's right hand - and we're going to kill him. My scouts have found some pirates in sector (%1%:%2%). Go there.\n\nAllison", x, y)
    _mail.header = "Next Steps"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story6_mail1"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story6_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.gruzSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if onServer() then
        local _player = Player()
        if _player:hasScript("events/alienattack.lua") then
            _player:removeScript("events/alienattack.lua")
            _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
        end
        
        vengeStory6_createObjectiveSector(x, y)
        vengeStory6_spawnAllison()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2mercsgotterdammerung.ogg")
    nextPhase()
end

mission.phases[3] = {}
mission.phases[3].triggers = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true

--region #PHASE 3 TRIGGERS

if onServer() then

mission.phases[3].triggers[1] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return atTargetLocation() and pirateCt == 0
    end,
    callback = function()
        nextPhase()
    end,
    repeating = false
}

end

--endregion

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 10,
    callback = function()
        if atTargetLocation() and not mission.data.custom.phase3ChatterSent then
            mission.data.custom.phase3ChatterSent = true
            VengeUtil.allisonChatter(nil, "Business as usual. Clean them up and we'll move on to the next phase.")
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[4] = {} --AKA the war crimes phase
mission.phases[4].triggers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[4].onBeginServer = function()
    vengeStory6_spawnAllison()

    local allison = ESCCUtil.getSingleEntityByValue(nil, "is_allison")
    local allisonAI = ShipAI(allison)
    allisonAI:stop()

    invokeClientFunction(Player(), "vengeStory6_phase4Dialog1", mission.data.custom.allisonID)
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 4 Update Target Location Server"

    if mission.data.custom.phase4TimerEnabled then
        --mission.Log(methodName, "Updating phase 4 timer.") --Careful about enabling this due to spam.
        mission.data.custom.phase4Timer = mission.data.custom.phase4Timer + timeStep
    end

    if mission.data.custom.phase4JammerTimerEnabled then
        --mission.Log(methodName, "Updating phase 4 jammer timer.") --Careful about enabling this due to spam.
        mission.data.custom.phase4JammerTimer = mission.data.custom.phase4JammerTimer + timeStep
    end

    if mission.data.custom.phase4GruzSpawnTimerEnabled then
        --mission.Log(methodName, "Updating phase 4 gruznier spawn timer.") --Careful about enabling this due to spam.
        mission.data.custom.phase4GruzSpawnTimer = mission.data.custom.phase4GruzSpawnTimer + timeStep
    end

    --mission.Log(methodName, "Timer status - p4 : " .. tostring(mission.data.custom.phase4Timer) .. " - p4 jammer : " .. tostring(mission.data.custom.phase4JammerTimer) .. " - p4 gruznier : " .. tostring(mission.data.custom.phase4GruzSpawnTimer)) --Careful about enabling this due to spam.
end

local vengeStory6_onPhase4Dialog1End = makeDialogServerCallback("vengeStory6_onPhase4Dialog1End", 4, function()
    --Spawn jammer and start timer.
    vengeStory6_spawnJammer()
    mission.data.custom.phase4TimerEnabled = true
end)

local vengeStory6_onPhase4Dialog2End = makeDialogServerCallback("vengeStory6_onPhase4Dialog2End", 4, function()
    --Destroy the jammer and chain into the last bit of dialog
    setGameMusic()
    local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn6_jammer")

    local jammerDurability = Durability(jammer)
    if jammerDurability then
        jammerDurability.invincibility = 0.0
    end

    jammer:destroy(mission.data.custom.allisonID)

    mission.data.custom.phase4JammerTimerEnabled = true
end)

local vengeStory6_onPhase4Dialog3End = makeDialogServerCallback("vengeStory6_onPhase4Dialog3End", 4, function()
    --Start gruz timer.
    mission.data.custom.phase4GruzSpawnTimerEnabled = true
end)

local vengeStory6_phase4Dialog1CrimeComplaint = makeDialogServerCallback("vengeStory6_phase4Dialog1CrimeComplaint", 4, function()
    Player():setValue("_vbmn6_complained_about_crimes", true)
end)

local vengeStory6_onGruznierPreFightDialogEnd = makeDialogServerCallback("vengeStory6_onGruznierPreFightDialogEnd", 4, function()
    nextPhase()
end)

--region #PHASE 4 TRIGGERS

if onServer() then

mission.phases[4].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4Timer >= 20
    end,
    callback = function()
        local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn6_jammer")
        local jammerAI = ShipAI(jammer)

        jammerAI:stop()

        invokeClientFunction(Player(), "vengeStory6_phase4Dialog2", jammer.index)
    end,
    repeating = false
}

mission.phases[4].triggers[2] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4JammerTimer >= 2
    end,
    callback = function()
        invokeClientFunction(Player(), "vengeStory6_phase4Dialog3", mission.data.custom.allisonID)
    end,
    repeating = false
}

mission.phases[4].triggers[3] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4GruzSpawnTimer >= 10
    end,
    callback = function()
        local _sector = Sector()
        local _player = Player()

        local x, y = _sector:getCoordinates()
        local pLevel = Balancing_GetPirateLevel(x, y)
        local pFaction = Galaxy():getPirateFaction(pLevel)

        local useLootFunc = 1
        if _player:getValue("_vbmn6_killed_gruznier") then
            useLootFunc = 2
        end

        local gruz = VengeUtil.spawnGruznier(pFaction, false, useLootFunc, 0)

        --Make his hull / shield invincible so Allison can't shoot him down with PDCs.
        gruz.invincible = true
        local gruzShield = Shield(gruz.index)
        gruzShield.invincible = true

        --Stop all of the player ships so they don't ambush him and kill him while dialog is ongoing.
        local ships = { _sector:getEntitiesByType(EntityType.Ship) }
        for _, ship in pairs(ships) do
            if ship.playerOrAllianceOwned then
                local ai = ShipAI(ship)
                ai:stop()
            end
        end

        local gruzAI = ShipAI(gruz)
        gruzAI:registerFriendFaction(_player.index)

        invokeClientFunction(_player, "vengeStory6_onPhase4CutScene", gruz.index)
    end,
    repeating = false
}

mission.phases[4].triggers[4] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase4GruzSpawnTimer >= 16
    end,
    callback = function()
        local gruz = ESCCUtil.getSingleEntityByValue(nil, "is_gruznier")
        invokeClientFunction(Player(), "vengeStory6_gruznierPreFightDialog", gruz.index)
    end,
    repeating = false
}

end

--endregion

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBegin = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
end

mission.phases[5].onBeginServer = function()
    local _sector = Sector()

    local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")
    local allisonAI = ShipAI(allison)

    allisonAI:setAggressive()

    local gruz = ESCCUtil.getSingleEntityByValue(_sector, "is_gruznier")
    gruz.invincible = false
    local gruzShield = Shield(gruz.index)
    gruzShield.invincible = false
    VengeUtil.setGruznierAttack(gruz, false, 1)
end

mission.phases[5].onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)

    if atTargetLocation() and destroyedEntity:getValue("is_gruznier") then
        local _player = Player()
        _player:setValue("_vbmn6_killed_gruznier", true)
        _player:setValue("_vbmn_gruznier_kills", 1)
        nextPhase()
    end
end

--region #PHASE 5 TIMERS

if onServer() then

mission.phases[5].timers[1] = {
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory6_spawnAllison()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[6] = {}
mission.phases[6].triggers = {}
mission.phases[6].onBegin = function()
    mission.data.description[6].fulfilled = true
    mission.data.description[7].visible = true
end

mission.phases[6].onBeginServer = function()
    --All of the pirates depart.
    ESCCUtil.allPiratesDepart()

    --Spawn Allison if needed.
    vengeStory6_spawnAllison()
end

mission.phases[6].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase6Timer = mission.data.custom.phase6Timer + timeStep
end

local vengeStory6_onPostGruznierFightDialogEnd = makeDialogServerCallback("vengeStory6_onPostGruznierFightDialogEnd", 6, function()
    vengeStory6_friendlyShipsDepart()
    vengeStory6_finishAndReward()
end)

--region #PHASE 6 TRIGGERS

if onServer() then

mission.phases[6].triggers[1] = {
    condition = function()
        return atTargetLocation() and mission.data.custom.phase6Timer >= 5
    end,
    callback = function()
        invokeClientFunction(Player(), "vengeStory6_postGruznierFightDialog", mission.data.custom.allisonID)
    end,
    repeating = false
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory6_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 240

    local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
    target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
    local _safetyBreakout = 0
    while target.x == x and target.y == y and _safetyBreakout <= 100 do
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
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

function vengeStory6_createObjectiveSector(x, y)
    --Create a few small asteroid fields
    local generator = SectorGenerator(x, y)
    for _ = 1, 4 do
        generator:createSmallAsteroidField()
    end

    --Create a group of 8 pirates initially
    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory6_onInitialPiratesFinished)

    local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard", false)

    pirateGenerator:startBatch()

    for _, p in pairs(pirateTable) do
        pirateGenerator:createScaledPirateByName(p, pirateGenerator:getGenericPosition())
    end

    pirateGenerator:endBatch()

    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true
end

function vengeStory6_onInitialPiratesFinished(generated)
    for _, p in pairs(generated) do
        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 --Xinull goon boost
    end

    local torpSlammerValues = {
        _TimeToActivate = 10,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = 1.25,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = "is_allison",
        _RangeFactor = 3
    }

    shuffle(random(), generated)

    for idx = 1, 2 do
        generated[idx]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        ESCCUtil.setBombardier(generated[idx])
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory6_spawnAllison()
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

function vengeStory6_spawnJammer()
    local jammer = PirateGenerator.createScaledJammer(PirateGenerator.getGenericPosition())
    jammer.factionIndex = VengeUtil.getFriendlyFaction().index

    Boarding(jammer).boardable = false

    jammer:removeScript("blocker.lua")
    jammer:setValue("_vbmn6_jammer", true)
    jammer:setValue("is_pirate", nil)
    jammer:setValue("_ESCC_bypass_hazard", true)

    local jammerAI = ShipAI(jammer)
    jammerAI:setFlyLinear(jammer.look * 20000, 0, false)

    local jammerDurability = Durability(jammer)
    if jammerDurability then
        jammerDurability.invincibility = 0.02
    end
end

function vengeStory6_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeStory6_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 4500000

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = baseReward, paymentMessage = "Earned %1% credits for defeating Brute Gruznier."}
    
    _player:setValue("_vengeancebmn_story_stage", 7)
    _player:setValue("encyclopedia_vbmn_gruznier", true)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory6_phase4Dialog1(allisonID)
    local _player = Player()

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d4what = {}
    local d4why = {}
    local d4crime = {}
    local d4cold = {}
    local d4what2 = {} --The same as d4what but without the option to go back, otherwise we could get some nasty loops.
    local d5 = {}
    local d6 = {}
    local d7 = {}

    d0.text = "That's the last of them."
    d0.followUp = d1

    d1.text = "We'll bring the jammer with the captured pirates in, then we'll broadcast their cries for help."
    d1.followUp = d2

    d2.text = "Gruznier should be around here somewhere... I suspect he'll come running."
    d2.followUp = d3

    d3.text = "Tch. They accuse me of being too soft..."
    d3.followUp = d4

    d4.text = "And yet..."
    d4.answers = {
        { answer = "What's your plan for Gruznier?", followUp = d4what },
        { answer = "Why are you doing this?", followUp = d4why },
        { answer = "This is a war crime.", onSelect = vengeStory6_phase4Dialog1CrimeComplaint, followUp = d4crime }
    }

    d4what.text = "The jammer has been rigged to explode. We kill his friends and greet him with a field of corpses. He'll get angry and attack us. We kill him too. Not a particularly complicated plan. I figure you've had enough of those."
    d4what.answers = {
        { answer = "Cold.", followUp = d4cold },
        { answer = "Why are you doing this?", followUp = d4why },
        { answer = "This is a war crime.", onSelect = vengeStory6_phase4Dialog1CrimeComplaint, followUp = d4crime },
        { answer = "Understood. What then?", followUp = d5 }
    }

    if _player:getValue("_vbmn5_hold_you_to_it") then
        d4why.text = "I promised I'd tell you, did I not? I think I'm ready to talk about it, but... now's not the time. We'll discuss this after Gruznier is space dust."
    else
        d4why.text = "I think I'm ready to tell you about it, but we'll discuss this later."
    end
    d4why.answers = {
        { answer = "Fair enough. What's your plan for Gruznier?", followUp = d4what2 }
    }

    if _player:getValue("_vbmn5_complained_about_crimes") then
        d4crime.text = "This again. I told you to save your sympathy for people who deserve it. Besides, you can't commit war crimes if there's no war. This isn't war. It's personal."
    else
        d4crime.text = "You should save that sense of sympathy for people who deserve it. Have you not seen them attacking defenseless merchants? Trader caravans? These people are scum. They deserve what's coming to them."
    end
    d4crime.answers = {
        { answer = "Why are you doing this?", followUp = d4why },
        { answer = "Fine. What's your plan for Gruznier?", followUp = d4what2 }
    }

    d4cold.text = "It's deserved."
    d4cold.answers = {
        { answer = "What then?", followUp = d5 }
    }

    d4what2.text = "The jammer has been rigged to explode. We kill his friends and greet him with a field of corpses. He'll get angry and attack us. We kill him too. Not a particularly complicated plan. I figure you've had enough of those."
    d4what2.answers = {
        { answer = "What then?", followUp = d5 }
    }

    d5.text = "Xinull is still out there. We keep making steps towards killing him."
    d5.answers = {
        { answer = "What about afterwards?", followUp = d6 },
        { answer = "Understood.", followUp = d7 }
    }

    d6.text = "I haven't thought about it much. One thing at a time. I'll worry about the future after he's dead."
    d6.followUp = d7

    d7.text = "The jammer will be here soon. Get ready."
    d7.onEnd = vengeStory6_onPhase4Dialog1End

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4, d4what, d4why, d4crime, d4cold, d4what2, d5, d6, d7}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeStory6_phase4Dialog2(jammerID)
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

    d0.text = "You won't get away with this!"
    d0.followUp = d1

    d1.text = "We'll see about that. If I fail, I suppose you'll see me in hell soon enough."
    d1.followUp = d2
    
    d2.text = "There's something wrong with you."
    d2.followUp = d3

    d3.text = "I won't deny that."
    d3.followUp = d4

    d4.text = "Now beg for help, or you'll suffer before I kill you."
    d4.followUp = d5

    d5.text = "You foul b-"
    d5.followUp = d6

    d6.text = "AAAAAAAGH!"
    d6.followUp = d7

    d7.text = "None of that. My crew on board is monitoring the channels."
    d7.followUp = d8

    d8.text = "Beg."
    d8.followUp = d9

    d9.text = "..."
    d9.followUp = d10

    d10.text = "Help us, Gruznier! Help us! HELP US!"
    d10.followUp = d11

    d11.text = "Better. More."
    d11.followUp = d12

    d12.text = "HELP! PLEASE HELP! WE'RE BEING EXECUTED! SAVE US!"
    d12.followUp = d13

    d13.text = "Good. All spears, abandon ship. Set the wreckage to rebroadcast."
    d13.followUp = d14 --As cool as it would be to blow up the jammer mid-dialog, we can't do that because it is coming from the jammer and that screws things up.

    d14.text = "And now..."
    d14.onEnd = vengeStory6_onPhase4Dialog2End

    ESCCUtil.setTalkerTextColors({ d1, d3, d4, d7, d8, d11, d13, d14 }, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(jammerID):interactShowDialog(d0, false)
end

function vengeStory6_phase4Dialog3(allisonID)
    local d0 = {
        text = "... We wait.",
        onEnd = vengeStory6_onPhase4Dialog3End
    }
    
    ESCCUtil.setTalkerTextColors({ d0 }, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeStory6_onPhase4CutScene(gruznierID)
    startBossCameraAnimation(gruznierID)
end

function vengeStory6_gruznierPreFightDialog(gruznierID)
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

    d0.text = "YOU!"
    d0.followUp = d1

    d1.text = "Hello, Gruznier."
    d1.followUp = d2

    d2.text = "Me. Xinull. We killers. But you. You monster."
    d2.followUp = d3

    d3.text = "This could have been avoided."
    d3.followUp = d4

    d4.text = "Yes. You go away. No kill Gruznier friends."
    d4.followUp = d5

    d5.text = "You could have let me leave with her. The moment you decided against that... you set this in motion."
    d5.followUp = d6

    d6.text = "You was too soft. Needed toughness."
    d6.followUp = d7

    d7.text = "Am I still too soft?"
    d7.followUp = d8

    d8.text = "No. But not hard either. Twisted. Warped. You turn killing to depraved art. You. Monster. You worse than us now."
    d8.followUp = d9

    d9.text = "The scholars can debate that."
    d9.followUp = d10

    d10.text = "After you're dead, of course."
    d10.followUp = d11

    d11.text = "${_PLAYERNAME}, you know what to do." % {_PLAYERNAME = Player().name }
    d11.followUp = d12

    d12.text = "YOU KILL GRUZNIER FRIENDS! GRUZNIER KILL YOU!"
    d12.onEnd = vengeStory6_onGruznierPreFightDialogEnd

    ESCCUtil.setTalkerTextColors({ d1, d3, d5, d7, d9, d10, d11 }, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    --for _, dialog in pairs({ d0, d2, d4, d6, d8, d12 }) do
    --    dialog.talker = "Brute Gruznier"
    --end

    ScriptUI(gruznierID):interactShowDialog(d0, false)
end

function vengeStory6_postGruznierFightDialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2name = {}
    local d2knowyou = {}
    local d2whyhate = {}
    local d2whoisshe = {}
    local d2yourname = {}
    local d2stillpirate = {}
    local d2sorry = {}
    local d2yourparents = {}
    local d2sorryaboutparents = {}
    local d2whyleave = {}
    local d2enjoyit = {}
    local d2whathappened = {}
    local d2whatstheplan = {}
    local d2hub = {}
    local d3 = {}
    local d4 = {}

    d0.text = "Well done. Gruznier lies defeated. If he somehow survived the battle, my crew will ensure his demise."
    d0.followUp = d1

    d1.text = "I suppose you have some questions for me. Ask and I shall answer."
    d1.answers = {
        { answer = "Is your name really Allison?", followUp = d2name },
        { answer = "Why do the pirates seem to know you?", followUp = d2knowyou },
        { answer = "Why do you hate the pirates so much?", followUp = d2whyhate },
        { answer = "Who is the woman you mentioned?", followUp = d2whoisshe }
    }

    d2name.text = "Yes. Any other questions?"
    d2name.answers = {
        { answer = "Did Xinull give you that name?", followUp = d2yourname },
        { answer = "Yes.", followUp = d2hub },
        { answer = "No.", followUp = d3 }
    }

    d2knowyou.text = "I used to be one of Xinull's underlings."
    d2knowyou.answers = {
        { answer = "Are you still?", followUp = d2stillpirate },
        { answer = "Why did you leave?", followUp = d2whyleave }
    }

    d2whyhate.text = "Because Xinull's pirates are scum - the sort of pirates who pillage and kill wantonly without purpose. They also marooned me and left me for dead in an asteroid belt. There are... other reasons as well."
    d2whyhate.answers = {
        { answer = "I see.", followUp = d2hub },
        { answer = "Why do they seem to know you?", followUp = d2knowyou },
        { answer = "What happened?", followUp = d2whathappened }
    }

    d2whoisshe.text = "... Mmm. I thought I was ready to talk about that one, but not yet. Still too painful of a memory - the scar needs some time to fade. In case it's not obvious, she's dead."
    d2whoisshe.answers = {
        { answer = "I'm sorry.", followUp = d2sorry },
        { answer = "Why do you hate the pirates so much?", followUp = d2whyhate },
        { answer = "I see.", followUp = d2hub }
    }

    d2yourname.text = "No. It is mine. Or the one given to me by my parents, such that it is."
    d2yourname.answers = {
        { answer = "I see.", followUp = d2hub },
        { answer = "Are they still alive?", followUp = d2yourparents }
    }

    d2stillpirate.text = "No."
    d2stillpirate.answers = {
        { answer = "Why did you leave?", followUp = d2whyleave },
        { answer = "Why do you hate the pirates so much?", followUp = d2whyhate }
    }

    d2sorry.text = "So am I."
    d2sorry.followUp = d2hub

    d2yourparents.text = "They are not. Xinull killed both of them a long time ago."
    d2yourparents.answers = {
        { answer = "I'm sorry.", followUp = d2sorryaboutparents },
        { answer = "I understand.", followUp = d2hub }
    }

    d2whyleave.text = "Xinull is cruel and prone to outbursts of violence. I saw him kill a trusted underling for a trivial failure, and I realized that he lacked any sense of loyalty. Despite my years of service. Despite all of the blood I spilled for him... he could turn on me at any time. There were... other considerations as well."
    d2whyleave.answers = {
        { answer = "Did you enjoy fighting for him?", followUp = d2enjoyit },
        { answer = "What happened?", followUp = d2whathappened },
        { answer = "Was a consideration the woman you mentioned?", followUp = d2whoisshe }
    }

    d2whathappened.text = "I was getting ready to board an escape pod when they caught me. I was marooned in a remote asteroid belt. Fortunately, I found this ship. I repaired it enough to pilot it to civilization, where some people took pity on me and helped me patch together the remaining systems. From there, I was able to do some odd jobs and put a crew together."
    d2whathappened.followUp = d2hub

    d2hub.text = "What else do you want to know?"
    d2hub.answers = {
        { answer = "Is your name really Allison?", followUp = d2name },
        { answer = "Why do the pirates seem to know you?", followUp = d2knowyou },
        { answer = "Why do you hate the pirates so much?", followUp = d2whyhate },
        { answer = "Who is the woman you mentioned?", followUp = d2whoisshe },
        { answer = "How do you plan to kill Xinull?", followUp = d2whatstheplan },
        { answer = "No more questions.", followUp = d3 }
    }

    d2whatstheplan.text = "I'm not sure yet, but it's only a matter of time. With Gruznier gone his support will fracture. We need only wait and take advantage of the moment when it arrives."
    d2whatstheplan.followUp = d2hub

    d2sorryaboutparents.text = "Thank you, but I barely remember them. I hope they died painlessly."
    d2sorryaboutparents.answers = {
        { answer = "I understand.", followUp = d2hub }
    }

    d2enjoyit.text = "I did not. Killing for him felt... empty. Hollow. There's no purpose in spilling blood for enriching yourself. For pretending to be strong. Violence is only worthy if it means something. To protect your loved ones, or to cast down a man who shouldn't exist."
    d2enjoyit.answers = {
        { answer = "What happened?", followUp = d2whathappened }
    }

    d3.text = "Without you, none of this would have been possible. I realize that my methods are... brutal. I won't apologize for it, but thank you for your continued assistance regardless."
    d3.followUp = d4

    d4.text = "Until we meet again. I'll be in touch, Captain."
    d4.onEnd = vengeStory6_onPostGruznierFightDialogEnd

    local dialogTbl = {
        d0,
        d1,
        d2name,
        d2knowyou,
        d2whyhate,
        d2whoisshe,
        d2yourname,
        d2stillpirate,
        d2sorry,
        d2yourparents,
        d2sorryaboutparents,
        d2whyleave,
        d2enjoyit,
        d2whathappened,
        d2whatstheplan,
        d2hub,
        d3,
        d4
    }

    ESCCUtil.setTalkerTextColors(dialogTbl, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion