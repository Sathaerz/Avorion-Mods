--[[
Vengeance Be My Name
- Attack and kill the main pirate guy.
- Xinull's gimmick - always active frenzy script, shoot block that spawns on him to reset his damage multiplier. Need to figure out how to add block to plan.
- Also has a torpslammer that fires a torpedo at a random target and switches targets every cycle. Drunken torpedo launcher.
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
mission._Name = "Vengeance Be My Name"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "No fortress. No lieutenants. No men. No food. No water. Xinull has nothing left but his life. She'll be coming for that next." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Await further instructions", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Kill Xinull", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.allisonRespawnTimer = 0
mission.data.custom.allisonWeaknessBlockTauntSent = false
mission.data.custom.inSectorPhase2 = false
mission.data.custom.phase2Timer = 0
mission.data.custom.phase5ChatTimer = 0
mission.data.custom.phase5ChatStarted = false

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
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.xinullSector = vengeStory9_getNextLocation()

    local x = mission.data.custom.xinullSector.x
    local y = mission.data.custom.xinullSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    local _player = Player()
    local _mail = Mail()

    _mail.text = Format("Hello again, Captain.\n\nXinull is exposed. You'll find him in sector (%1%:%2%). My captains are resupplying, but we won't need their help. I'll meet you there. We put an end to this now.\n\nAllison", x, y)
    _mail.header = "It's time"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story9_mail1"
    _player:addMail(_mail)    
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story9_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    local methodName = "Phase 2 On Begin"
    mission.Log(methodName, "Beginning...")

    mission.data.location = mission.data.custom.xinullSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if onServer() then
        vengeStory9_spawnAllison()
        vengeStory9_spawnXinull()
        vengeStory9_spawnFirstLackeyWave()

        --Stop all of the player ships so they don't ambush him and kill him while dialog is ongoing.
        local ships = { Sector():getEntitiesByType(EntityType.Ship) }
        for _, ship in pairs(ships) do
            if ship.playerOrAllianceOwned then
                local ai = ShipAI(ship)
                ai:stop()
            end
        end

        local _player = Player()
        if _player:hasScript("events/alienattack.lua") then
            _player:removeScript("events/alienattack.lua")
            _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
        end
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/ac2kinglear.ogg")
    mission.data.custom.inSectorPhase2 = true

    local _player = Player()
    local _sector = Sector()

    --Set pirates to friendly so autoguns don't shoot
    local pirates = { _sector:getEntitiesByScriptValue("is_pirate") }
    for _, pirate in pairs(pirates) do
        local pirateAI = ShipAI(pirate)
        pirateAI:registerFriendFaction(_player.index)
    end

    --Set Allison shield to invincible
    local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")
    allison.invincible = true
    local allisonShield = Shield(allison.index)
    allisonShield.invincible = true

    local xinull = ESCCUtil.getSingleEntityByValue(_sector, "is_xinull")
    invokeClientFunction(_player, "vengeStory9_onPhase2CutScene", xinull.index)
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 2 Update Location"
    --Need to limit this to start only after sector arrival confirmed or it will tick from onLocationEntered.
    if mission.data.custom.inSectorPhase2 then
        mission.data.custom.phase2Timer = mission.data.custom.phase2Timer + timeStep
    end
    
    if mission.data.custom.phase2Timer >= 6 then
        mission.Log(methodName, "Advancing to phase 3.")
        nextPhase()
    end
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginClient = function()
    local xinull = ESCCUtil.getSingleEntityByValue(nil, "is_xinull")
    vengeStory9_xinullPreFightDialog(xinull.index)
end

local vengeStory9_onPreFightDialogEnd = makeDialogServerCallback("vengeStory9_onPreFightDialogEnd", 3, function()
    nextPhase()
end)

mission.phases[4] = {} --Kill Xinull phase
mission.phases[4].sectorCallbacks = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[4].onBeginServer = function()
    setGameMusic()

    local _sector = Sector()

    local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")
    local allisonAI = ShipAI(allison)

    allison.invincible = false
    local allisonShield = Shield(allison.index)
    allisonShield.invincible = false

    allisonAI:setAggressive()

    local pirateLackeys = { _sector:getEntitiesByScriptValue("_vbmn9_xinull_lackey_wave") }
    for _, p in pairs(pirateLackeys) do
        local pirateAI = ShipAI(p)
        pirateAI:setAggressive()
        pirateAI:clearFriendFactions()
        pirateAI:clearFriendEntities()

        p.invincible = false
        local pShield = Shield(p.index)
        if pShield then
            pShield.invincible = false
        end
    end

    local xinull = ESCCUtil.getSingleEntityByValue(_sector, "is_xinull")
    xinull.invincible = false
    local xinullShield = Shield(xinull.index)
    xinullShield.invincible = false
    VengeUtil.setXinullAttack(xinull, false, 1)
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)

    if atTargetLocation() and destroyedEntity:getValue("is_xinull") then
        local _player = Player()
        _player:setValue("_vbmn6_killed_xinull", true)
        _player:setValue("_vbmn_xinull_kills", 1)
        nextPhase()
    end
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    local allison = Entity(mission.data.custom.allisonID)
    if not allison or not valid(allison) then
        mission.data.custom.allisonRespawnTimer = mission.data.custom.allisonRespawnTimer + timeStep
    else
        mission.data.custom.allisonRespawnTimer = 0
    end

    if mission.data.custom.allisonRespawnTimer >= 180 then
        vengeStory9_spawnAllison()
    end
end

--region #PHASE 4 SECTOR CALLBACKS

if onServer() then

mission.phases[4].sectorCallbacks[1] = {
    name = "vbmn_xinull_first_used_meathook",
    func = function()
        local methodName = "Phase 4 Custom Callback 1"
        mission.Log(methodName, "Calling.")

        VengeUtil.allisonChatter(nil, "What is that?! I've never seen anything like it.")
    end
}

mission.phases[4].sectorCallbacks[2] = {
    name = "vbmn_xinull_added_weakness_block",
    func = function()
        local methodName = "Phase 4 Custom Callback 2"
        mission.Log(methodName, "Calling.")

        local _sector = Sector()
        local _player = Player()
        local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")

        if not mission.data.custom.allisonWeaknessBlockTauntSent then
            mission.data.custom.allisonWeaknessBlockTauntSent = true
            if allison then
                VengeUtil.allisonChatter(_sector, "His ship appears to have a major weak spot. If you can hit it, it will seriously damage his ship's systems.")
            else
                _player:sendChatMessage("", ChatMessageType.Information, "Your ship's systems detect a major weak spot in Xinull's ship. Shoot it to damage his ship's systems.")
            end
        else
            if allison then
                VengeUtil.allisonChatter(_sector, "The weakness in his ship is back. I'd suggest targeting it, Captain.")
            else
                _player:sendChatMessage("", ChatMessageType.Information, "Your ship's systems detect another weak spot in Xinull's ship.")
            end
        end
    end
}

mission.phases[4].sectorCallbacks[3] = {
    name = "vbmn_xinull_first_ate_ally",
    func = function()
        local methodName = "Phase 4 Custom Callback 3"
        mission.Log(methodName, "Calling.")

        local _sector = Sector()
        local _player = Player()
        local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")
        
        if allison then
            VengeUtil.allisonChatter(_sector, "He can consume his own allies?! That is... disturbing. I'd suggest denying him the opportunity.")
        else
            _player:sendChatMessage("", ChatMessageType.Information, "Xinull can consume his allies to power up his ship. Destroy them first to deny him the opportunity.")
        end
    end
}

mission.phases[4].sectorCallbacks[4] = {
    name = "vbmn_xinull_first_recharged_shields",
    func = function()
        local methodName = "Phase 4 Custom Callback 4"
        mission.Log(methodName, "Calling.")

        local _sector = Sector()
        local _player = Player()
        local allison = ESCCUtil.getSingleEntityByValue(_sector, "is_allison")

        if allison then
            VengeUtil.allisonChatter(_sector, "Whatever tech he installed on his ship can recharge his shields! If you hit that weak spot it should disrupt the process.")
        else
            _player:sendMessage("", ChatMessageType.Information, "Xinull's shields are recharging. Destroy the weak spot on his ship to disrupt this process.")
        end
    end
}

end

--endregion

mission.phases[5] = {} --Post xinull kill phase
mission.phases[5].onBegin = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
end

mission.phases[5].onBeginServer = function()
    local _sector = Sector()
    local xinullReinforcementGoons = { _sector:getEntitiesByScriptValue("is_pirate") }

    local lines = {
        "He's dead?! He's dead!",
        "We're free!",
        "The money isn't worth it! We're out!",
        "Oh my god! They killed Xinull!",
        "We're next! Charge the hyperdrives!",
        "I can't believe he's gone!",
        "Run away!",
        "We can't take firepower of that magnitude!",
        "Game over, man! Game over!",
        "It's over..."
    }

    for _, p in pairs(xinullReinforcementGoons) do
        if not p:getValue("is_xinull") then
            _sector:broadcastChatMessage(p, ChatMessageType.Chatter, getRandomEntry(lines))
            p:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 8))
        end
    end

    vengeStory9_spawnAllison() --Spawn Allison if she isn't here.
end

mission.phases[5].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase5ChatTimer = mission.data.custom.phase5ChatTimer + timeStep

    if mission.data.custom.phase5ChatTimer >= 10 and not mission.data.custom.phase5ChatStarted then
        mission.data.custom.phase5ChatStarted = true
        invokeClientFunction(Player(), "vengeStory9_xinullPostFightDialog", mission.data.custom.allisonID)
    end
end

local vengeStory9_onPostFightDialogEnd = makeDialogServerCallback("vengeStory9_onPostFightDialogEnd", 5, function()
    vengeStory9_friendlyShipsDepart()
    vengeStory9_finishAndReward()
end)

--endregion

--region #SERVER CALLS

function vengeStory9_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 220
    local minRad = 6
    local maxRad = 10

    local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
    target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)
    local _safetyBreakout = 0
    while target.x == x and target.y == y and _safetyBreakout <= 100 do
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)
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

function vengeStory9_spawnXinull()
    local _sector = Sector()

    local x, y = _sector:getCoordinates()
    local pLevel = Balancing_GetPirateLevel(x, y)
    local pFaction = Galaxy():getPirateFaction(pLevel)

    local useLootFunc = 1
    if Player():getValue("_vbmn9_killed_xinull") then
        useLootFunc = 2
    end

    local xinull = VengeUtil.spawnXinull(pFaction, useLootFunc, 0)

    --Make his hull / shield invincible so Allison can't shoot him down with PDCs.
    xinull.invincible = true
    local xinullShield = Shield(xinull.index)
    xinullShield.invincible = true
end

function vengeStory9_spawnAllison()
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

        if mission.internals.phaseIndex > 3 then
            local allisonAI = ShipAI(allison)
            allisonAI:setAggressive()
        end

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory9_spawnFirstLackeyWave()
    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory9_onFirstLackeyWaveFinished)
    local pirateTable = ESCCUtil.getStandardWave(8, 4, "Low", false)
    local piratePositions = pirateGenerator:getStandardPositions(4, 250) --_#DistAdj

    pirateGenerator:startBatch()

    for posIdx, p in pairs(pirateTable) do
        pirateGenerator:createScaledPirateByName(p, piratePositions[posIdx])
    end

    pirateGenerator:endBatch()
end

function vengeStory9_onFirstLackeyWaveFinished(generated)
    for _, p in pairs(generated) do
        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 --Xinull goon boost
        p:addScriptOnce("player/missions/vengeance/story9/vengeance9rally.lua")

        local pirateAI = ShipAI(p)
        pirateAI:setPassive() --Activate when combat starts.

        p:setValue("_vbmn9_xinull_lackey_wave", true)

        p.invincible = true
        local pShield = Shield(p.index)
        if pShield then
            pShield.invincible = true
        end
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory9_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeStory9_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. Thank you for everything, ${_PLAYER}." % { _PLAYER = _player.name }
    local baseReward = 10000000

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = baseReward, paymentMessage = "Earned %1% credits for killing Xinull." }

    local runTime = Server().unpausedRuntime

    _player:setValue("_vengeancebmn_story_stage", 10)
    _player:setValue("_vbmn_story_complete", true)
    _player:setValue("_vengeancebmn_last_side1", runTime)
    _player:setValue("_vengeancebmn_last_side2", runTime)
    _player:setValue("encyclopedia_vbmn_xinull", true)
    _player:setValue("encyclopedia_vbmn_allison2", true)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    local _mail = Mail()

    local exmtcs = SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), random():createSeed())
    _mail:addItem(exmtcs)

    --Deliberately picked 15100 to give the player a good hyperspace booster without the +cooldown time.
    local exhyp = SystemUpgradeTemplate("data/scripts/systems/hyperspacebooster.lua", Rarity(RarityType.Exotic), Seed(15100))
    _mail:addItem(exhyp)

    _mail.text = Format("Hello, ${_PLAYERNAME}.\n\nI found these while my crew was sweeping Xinull's ship. I thought you might be able to make use of them on your journey. Thank you once again for your help, and safe travels.\n\nAllison Vannier" % {_PLAYERNAME = _player.name})
    _mail.header = "A Parting Gift"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story9_mail2"
    _player:addMail(_mail)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory9_onPhase2CutScene(xinullID)
    startBossCameraAnimation(xinullID)
end

function vengeStory9_xinullPreFightDialog(xinullID)
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
    local routeA1 = {}
    local routeA2 = {}
    local routeA3 = {}
    local routeB1 = {}
    local routeB2 = {}
    local routeB3 = {}
    local routeC1Funny = {}
    local routeC1 = {}
    local routeC2 = {}
    local routeC3 = {}
    local routeC4 = {}
    local routeC5 = {}
    local routeC6 = {}

    local _player = Player()
    local player5CrimeComplaint = _player:getValue("_vbmn5_complained_about_crimes")
    local player6CrimeComplaint = _player:getValue("_vbmn6_complained_about_crimes")
    local player8CrimeComplaint = _player:getValue("_vbmn8_complained_about_crimes")

    d0.text = "Allison Vannier. Its been far too long. So good to see you again."
    d0.followUp = d1

    d1.text = "... You have lackeys still."
    d1.followUp = d2

    d2.text = "I thought I had killed them all."
    d2.followUp = d3

    d3.text = "I made a few concessions, called in a few favors. You'd be surprised just how many pirates in these sectors want to see you dead."
    d3.followUp = d4

    d4.text = "Tch. It's good to see you as well. I'll sleep much easier with two bullets in your skull."
    d4.followUp = d5

    d5.text = "How rude! I made you the woman you are today."
    d5.followUp = d6

    d6.text = "Indeed. Vengeance be my name. You won't have a grave - I'll thank you by spacing your lifeless corpse."
    d6.followUp = d7

    d7.text = "It was never our intention to leave you there, you know. We only wanted to teach you a lesson. Gruznier and I returned later. Imagine our surprise when you were nowhere to be found."
    d7.followUp = d8

    d8.text = "Things don't have to end this way! You are clearly quite capable. Join me again. Between my resources and your ruthlessness... the galaxy would be ours to plunder! No faction would be able to stand before our might."
    d8.followUp = d9

    d9.text = "I don't care."
    d9.followUp = d10

    d10.text = "Bah. Fine. How boring. What about you? Her lackey."
    d10.answers = {
        { answer = "She's paying me a handsome sum to kill you.", followUp = routeA1 },
        { answer = "Killing pirate scum is good.", followUp = routeB1 },
    }
    if player5CrimeComplaint and player6CrimeComplaint and player8CrimeComplaint then
        table.insert(d10.answers, { answer = "Do we have to kill him? We've committed so many war crimes I can barely keep up.", followUp = routeC1Funny })
    else
        table.insert(d10.answers, { answer = "Do we have to kill him? We've committed so many war crimes I can barely keep up.", followUp = routeC1 })
    end

    --======================================================================================
    --She's paying me a handsome sum to kill you.
    --======================================================================================
    routeA1.text = "Is that so? I don't suppose I could offer you 5 million Credits for my pathetic life and ship?"
    routeA1.followUp = routeA2

    routeA2.text = "Not enough. I'm paying ${_PLAYER} twice that amount for your head." % { _PLAYER = _player.name }
    routeA2.followUp = routeA3

    routeA3.text = "A man has to try. Very well, then. Prepare yourselves!"
    routeA3.onEnd = vengeStory9_onPreFightDialogEnd

    --======================================================================================
    --Killing pirate scum is good.
    --======================================================================================
    routeB1.text = "An idealogue, huh? I suppose there's no reasoning with you, then."
    routeB1.followUp = routeB2

    routeB2.text = "Rabid dogs, the both of you."
    routeB2.followUp = routeB3

    routeB3.text = "I'm going to put you down. Prepare yourselves!"
    routeB3.onEnd = vengeStory9_onPreFightDialogEnd

    --======================================================================================
    --Do we have to kill him? We've committed so many war crimes I can barely keep up.
    --======================================================================================
    --If I were a dev, there'd be an achievement for this. Alas, I am not.
    routeC1Funny.text = "Not everything is a war crime, ${_PLAYER}. I swear to the Old Earth Gods I-" % { _PLAYER = _player.name }
    routeC1Funny.followUp = routeC1

    routeC1.text = "Ew."
    routeC1.followUp = routeC2

    routeC2.text = "Soft-hearted weaklings like you disgust me."
    routeC2.followUp = routeC3

    routeC3.text = "I'll kill you. Just like I-"
    routeC3.followUp = routeC4

    routeC4.text = "Don't say it."
    routeC4.followUp = routeC5

    routeC5.text = "Oho? Has she not told you about that, lackey? About her-"
    routeC5.followUp = routeC6

    routeC6.text = "YOU'RE NOT FIT TO SAY HER NAME! DIE."
    routeC6.onEnd = vengeStory9_onPreFightDialogEnd

    ESCCUtil.setTalkerTextColors({d1, d2, d4, d6, d9, routeA2, routeC4, routeC6, routeC1Funny}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ESCCUtil.setTextColors({d0, d3, d5, d7, d8, d10, routeA1, routeA3, routeB1, routeB2, routeB3, routeC1, routeC2, routeC3, routeC5}, MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

    ScriptUI(xinullID):interactShowDialog(d0, false)
end

function vengeStory9_xinullPostFightDialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4_howdidyouknow1 = {}
    local d4_howdidyouknow2 = {}
    local d4_howdidyouknow3 = {}
    local d4_howdidyouknow4 = {}
    local d4_howdidyouknow5 = {}
    local d4_whoisshe1 = {}
    local d4_whoisshe2 = {}
    local d4_whoisshe3 = {}
    local d4_whoisshe4 = {}
    local d4_whoisshe5 = {}
    local d4_whoisshe6 = {}
    local d4_whoisshe7 = {}
    local d4_whoisshe8 = {}
    local d4_whoisshe9 = {}
    local d4_whyspears1 = {}
    local d4_whyspears2 = {}
    local d4_whyspears3 = {}
    local d4_whyspears4 = {}
    local d4_whyspears5 = {}
    local d4_whyspears6 = {}
    local d4_whatwascrewlike1 = {}
    local d4_whatwascrewlike2 = {}
    local d4_whatwascrewlike3 = {}
    local d4_whatwascrewlike4 = {}
    local d4_whatwascrewlike5 = {}
    local d4_whatwascrewlike6 = {}
    local d4_whatwascrewlike7 = {}
    local d4_whatwascrewlike8 = {}
    local d4_whatnow1 = {}
    local d4_whatnow2 = {}
    local d4_whatnow3 = {}
    local d4_whatnow4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}
    local d9 = {}

    local _player = Player()
    local player5CrimeComplaint = _player:getValue("_vbmn5_complained_about_crimes")
    local player6CrimeComplaint = _player:getValue("_vbmn6_complained_about_crimes")
    local player8CrimeComplaint = _player:getValue("_vbmn8_complained_about_crimes")

    d0.text = "It's over."
    d0.followUp = d1

    d1.text = "We... won."
    d1.followUp = d2

    d2.text = "This was just as much your fight as mine, and you've fulfilled your end of the bargain perfectly. Thank you."
    d2.followUp = d3

    d3.text = "It feels like a weight has been lifted from my shoulders. One I was barely cognizant of carrying. If you have any questions about my past, I think I can talk about it now. After everything that you've done for me, you deserve to know."
    d3.answers = {
        { answer = "How did you know Xinull?", followUp = d4_howdidyouknow1 },
        { answer = "Who was the other woman?", followUp = d4_whoisshe1 },
        { answer = "Why Spears of Adrasteia?", followUp = d4_whyspears1 }
    }

    --How do you know Xinull?
    d4_howdidyouknow1.text = "I wasn't always a pirate. Or... whatever I am now."
    d4_howdidyouknow1.followUp = d4_howdidyouknow2

    d4_howdidyouknow2.text = "I was once an ordinary citizen of the galactic order, such that it is."
    d4_howdidyouknow2.followUp = d4_howdidyouknow3

    d4_howdidyouknow3.text = "When I was much younger, Xinull attacked the liner that my family was traveling on. Unbeknownst to all of us, it had a considerable stash of noble metals on board. He killed just about everyone, including my mother and father."
    d4_howdidyouknow3.followUp = d4_howdidyouknow4

    d4_howdidyouknow4.text = "I don't know why he decided to spare me. For his own amusement? To prove something to himself? As an experiment? I think it was for all three reasons. He decided to mold me into a pirate as ruthless as himself."
    d4_howdidyouknow4.followUp = d4_howdidyouknow5

    d4_howdidyouknow5.text = "Heh. I suppose it worked. I don't feel any regrets for all of the people I've killed along the way to this moment."
    d4_howdidyouknow5.followUp = d5

    --Who was the other woman?
    d4_whoisshe1.text = "That's a long story with a tragic end."
    d4_whoisshe1.followUp = d4_whoisshe2

    d4_whoisshe2.text = "Still, I promised I would tell it. And so I shall."
    d4_whoisshe2.followUp = d4_whoisshe3

    d4_whoisshe3.text = "Her name was Lislyn. She was a survivor of one of our raids. Just like Xinull decided to take me under his wing, so I decided to take her under mine."
    d4_whoisshe3.followUp = d4_whoisshe4

    d4_whoisshe4.text = "There was just one problem. I was tired. Tired of all of the fighting. Tired of the killing. I wanted out. Maybe she made me soft. I don't know."
    d4_whoisshe4.followUp = d4_whoisshe5

    d4_whoisshe5.text = "She was also plainly unsuited for the life of a pirate. Every day she killed I heard her sobbing herself to sleep at night."
    d4_whoisshe5.followUp = d4_whoisshe6

    d4_whoisshe6.text = "And so, I decided that we would escape. But Xinull and Gruznier caught us. They needed to make an example - to show the rest of their crew that there was no leaving. I think they also sensed my weakness. They had a way of seeing such things."
    d4_whoisshe6.followUp = d4_whoisshe7

    d4_whoisshe7.text = "They shot her right in front of me, then marooned me in the middle of an asteroid belt."
    d4_whoisshe7.followUp = d4_whoisshe8

    d4_whoisshe8.text = "Perhaps Xinull was being honest and they did intend to come back for me after all. I didn't know that. I couldn't. I found this ship - it was a wreck. I repaired it as much as I could, and flew it back to civilized space."
    d4_whoisshe8.followUp = d4_whoisshe9

    d4_whoisshe9.text = "Ever since then, I've been focused on one thing - killing both of them for what they did. For my family. For Lislyn."
    d4_whoisshe9.followUp = d5

    --Why spears?
    d4_whyspears1.text = "Adrasteia was a goddess from an ancient planet known as Earth."
    d4_whyspears1.followUp = d4_whyspears2

    d4_whyspears2.text = "She was charged by Rhea - one of the titans - to nurture Zeus and protect him from his father."
    d4_whyspears2.followUp = d4_whyspears3

    d4_whyspears3.text = "In time, she was worshipped in tandem with Nemesis, the goddess of divine retribution. Her name came to be associated with inevitable fate, pressing necessity, and the inability of escaping punishment."
    d4_whyspears3.followUp = d4_whyspears4

    d4_whyspears4.text = "And thus it would be so for Xinull. His fate was sealed the moment I found some other captains willing to work with me. There are plenty of people in this galaxy who have lost something, and who are willing to spill some blood on account of it."
    d4_whyspears4.followUp = d4_whyspears5

    d4_whyspears5.text = "We would not just be the tip of the spear against the pirate scum plaguing the galaxy - we would be the spear itself."
    d4_whyspears5.followUp = d4_whyspears6

    d4_whyspears6.text = "So we became the Spears of Adrasteia."
    d4_whyspears6.followUp = d5

    --What was Xinull's crew like?
    d4_whatwascrewlike1.text = "In a word, exhausting."
    d4_whatwascrewlike1.followUp = d4_whatwascrewlike2

    d4_whatwascrewlike2.text = "You heard him. He enjoyed talking like some sort of gentleman pirate, but the truth is that he was a bloodthirsty killer."
    d4_whatwascrewlike2.followUp = d4_whatwascrewlike3

    d4_whatwascrewlike3.text = "It was commonplace for him to execute subordinates who don't carry out commands to his liking. It was also common for him to simply... kill subordinates for no reason."
    d4_whatwascrewlike3.followUp = d4_whatwascrewlike4

    d4_whatwascrewlike4.text = "He brutally massacred crews of civilian ships."
    d4_whatwascrewlike4.followUp = d4_whatwascrewlike5

    d4_whatwascrewlike5.text = "So why did anyone follow him? The pay was good, if you could survive. I think some of the people hoped they get lost in the shuffle. Collect a fat share of the blood money without having to risk your own skin."
    d4_whatwascrewlike5.followUp = d4_whatwascrewlike6

    d4_whatwascrewlike6.text = "As his pet project, I had no such luck. I suppose I also had the advantage of him having a vested interest in my survival... Still, it was only a matter of time before he would kill me as well. You can't trust someone who treats lives so carelessly."
    d4_whatwascrewlike6.followUp = d4_whatwascrewlike7

    d4_whatwascrewlike7.text = "Ruthlessness was a... necessity. I've done some terrible things. I doubt I'd be welcomed back into polite society."
    d4_whatwascrewlike7.followUp = d4_whatwascrewlike8

    d4_whatwascrewlike8.text = "Oh well. I don't think I'm missing much. An ordinary life never suited me."
    d4_whatwascrewlike8.followUp = d5

    --What will you do now?
    d4_whatnow1.text = "I don't know."
    d4_whatnow1.followUp = d4_whatnow2

    d4_whatnow2.text = "I suppose we'll find other pirates to kill. The tide of miscreants is endless. The only question is how much blood you're willing to spill."
    d4_whatnow2.followUp = d4_whatnow3

    d4_whatnow3.text = "Perhaps we'll use less brutal tactics for our future endeavors."
    d4_whatnow3.followUp = d4_whatnow4

    d4_whatnow4.text = "After all, it's not personal this time. It's just business."
    d4_whatnow4.followUp = d5

    d5.text = "Do you have any other questions?"
    d5.answers = {
        { answer = "How did you know Xinull?", followUp = d4_howdidyouknow1 },
        { answer = "Who was the other woman?", followUp = d4_whoisshe1 },
        { answer = "Why Spears of Adrasteia?", followUp = d4_whyspears1 },
        { answer = "What was being part of Xinull's crew like?", followUp = d4_whatwascrewlike1 },
        { answer = "What will you do from here?", followUp = d4_whatnow1 },
        { answer = "No other questions.", followUp = d6 }
    }

    d6.text = "This is where we part ways, then."
    d6.followUp = d7

    if player5CrimeComplaint and player6CrimeComplaint and player8CrimeComplaint then
        d7.text = "Thanks again for your help. It is rare to see another professional at work... even if they complain too much about war crimes."
    else
        d7.text = "Thanks again for your help. It is rare to see another professional at work."
    end
    d7.followUp = d8

    d8.text = "I'll send you the money for Xinull's head. My crew will ensure he drifts among the stars forevermore."
    d8.followUp = d9

    d9.text = "Perhaps we'll meet again someday. Don't get yourself killed out there, ${_PLAYER}. It's a dangerous galaxy." % { _PLAYER = _player.name }
    d9.onEnd = vengeStory9_onPostFightDialogEnd

    local dialogTbl = {
        d0,
        d1,
        d2,
        d3,
        d4_howdidyouknow1,
        d4_howdidyouknow2,
        d4_howdidyouknow3,
        d4_howdidyouknow4,
        d4_howdidyouknow5,
        d4_whoisshe1,
        d4_whoisshe2,
        d4_whoisshe3,
        d4_whoisshe4,
        d4_whoisshe5,
        d4_whoisshe6,
        d4_whoisshe7,
        d4_whoisshe8,
        d4_whoisshe9,
        d4_whyspears1,
        d4_whyspears2,
        d4_whyspears3,
        d4_whyspears4,
        d4_whyspears5,
        d4_whyspears6,
        d4_whatwascrewlike1,
        d4_whatwascrewlike2,
        d4_whatwascrewlike3,
        d4_whatwascrewlike4,
        d4_whatwascrewlike5,
        d4_whatwascrewlike6,
        d4_whatwascrewlike7,
        d4_whatwascrewlike8,
        d4_whatnow1,
        d4_whatnow2,
        d4_whatnow3,
        d4_whatnow4,
        d5,
        d6,
        d7,
        d8,
        d9
    }

    ESCCUtil.setTalkerTextColors(dialogTbl, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion