--[[
The Swoks Method
- Attack someone who has taken on the mantle of the 2nd boss.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "The Swoks Method"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" },
    { text = "..." }, --Placeholder
    { text = "Meet Allison in (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defeat the impostor Xinull", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

mission.data.accomplishMessage = "The Spears of Adrasteia thank you. Here's your compensation."

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.allisonRespawnTimer = 0
mission.data.custom.allisonWeaknessBlockTauntSent = false
mission.data.custom.inSectorPhase2 = false
mission.data.custom.phase2Timer = 0
mission.data.custom.phase5ChatTimer = 0
mission.data.custom.phase5ChatStarted = false

--region # INIT / DATA

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    setGameMusic()
    vengeSide2_setLastMissionTime()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    setGameMusic()
    vengeSide2_setLastMissionTime()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    setGameMusic()
    vengeSide2_setLastMissionTime()
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
mission.phases[1].onBegin = function()
    local methodName = "Phase 1 On Begin"
    local giver = Entity(mission.data.giver.id)

    mission.data.description[1].arguments = { sectorName = Sector().name, giverTitle = giver.translatedTitle }
    mission.data.description[2].text = vengeSide2_formatDescription()
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }

    mission.data.custom.xinullPersonality = random():getInt(1, 4)
    local personalityTypes = {
        "Normal.",
        "Cringe Pirate.",
        "Cynical.",
        "The most oppressed of all Xinulls... a gamer."
    }
    mission.Log(methodName, "Xinull personality is " .. personalityTypes[mission.data.custom.xinullPersonality])
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    local methodName = "Phase 1 On Target Location Entered"
    mission.Log(methodName, "Beginning...")
    mission.data.description[3].fulfilled = true

    if onServer() then
        vengeSide2_spawnAllison(true)
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    mission.data.custom.secondLocation = vengeSide2_getNextLocation()

    local sX = mission.data.custom.secondLocation.x
    local sY = mission.data.custom.secondLocation.y

    mission.data.description[4].arguments = { _X = sX, _Y = sY }

    sync()
    invokeClientFunction(Player(), "vengeSide2_onPhase1Dialog", mission.data.custom.allisonID, sX, sY)
end

local vengeSide2_onPhase1DialogEnd = makeDialogServerCallback("vengeSide2_onPhase1DialogEnd", 1, function()
    local allison = Entity(mission.data.custom.allisonID)
    allison:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))

    nextPhase()
end)

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.secondLocation
    
    mission.data.description[4].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true

    if onServer() then
        vengeSide2_spawnAllison(false)
        vengeSide2_createObjectiveSector()
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
    invokeClientFunction(_player, "vengeSide2_onBossAnimation", xinull.index)
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 2 Update Location"
    --Need to limit this to start only after sector arrival confirmed or it will tick from onLocationEntered.
    if mission.data.custom.inSectorPhase2 then
        mission.data.custom.phase2Timer = mission.data.custom.phase2Timer + timeStep
    end
    
    if mission.data.custom.phase2Timer >= 5 then
        mission.Log(methodName, "Advancing to phase 3.")
        nextPhase()
    end
end

mission.phases[3] = {} --Chat with Xinull phase
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginClient = function()
    local xinull = ESCCUtil.getSingleEntityByValue(nil, "is_xinull")
    vengeSide2_onXinullPreFightDialog(xinull.index)
end

local vengeSide2_onPreFightDialogEnd = makeDialogServerCallback("vengeSide2_onPreFightDialogEnd", 3, function()
    nextPhase()
end)

mission.phases[4] = {} --Kill Xinull phase
mission.phases[4].sectorCallbacks = {}
mission.phases[4].showUpdateOnEnd = true
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
    VengeUtil.setXinullAttack(xinull, true, mission.data.custom.xinullPersonality)
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)

    if atTargetLocation() and destroyedEntity:getValue("is_xinull") then
        local _player = Player()
        local xinullKills = _player:getValue("_vbmn_xinull_kills") or 1

        xinullKills = xinullKills + 1

        _player:setValue("_vbmn_xinull_kills", xinullKills)
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
        vengeSide2_spawnAllison(false)
    end
end

--region #PHASE 4 SECTOR CALLBACKS

if onServer() then

mission.phases[4].sectorCallbacks[1] = {
    name = "vbmn_xinull_first_used_meathook",
    func = function()
        local methodName = "Phase 4 Custom Callback 1"
        mission.Log(methodName, "Calling.")

        VengeUtil.allisonChatter(nil, "There's the meathook again. Target the ships he's pulling in to shut it down.")
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
            VengeUtil.allisonChatter(_sector, "Don't let him consume his allies, or he'll get impossibly strong.")
        else
            _player:sendChatMessage("", ChatMessageType.Information, "Don't let Xinull consume his allies, or his damage will ramp up quickly.")
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
            VengeUtil.allisonChatter(_sector, "Remember to destroy the weak spot quickly, or his shields will recharge.")
        else
            _player:sendMessage("", ChatMessageType.Information, "Quickly destroying the weak spot on Xinull's ship will prevent his shields from recharging.")
        end
    end
}

end

--endregion

mission.phases[5] = {} --Talk to Allison and wrap up phase
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

    vengeSide2_spawnAllison(false) --Spawn Allison if she isn't here.
end

mission.phases[5].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase5ChatTimer = mission.data.custom.phase5ChatTimer + timeStep

    if mission.data.custom.phase5ChatTimer >= 10 and not mission.data.custom.phase5ChatStarted then
        mission.data.custom.phase5ChatStarted = true
        invokeClientFunction(Player(), "vengeSide2_onXinullPostFightDialog", mission.data.custom.allisonID)
    end
end

local vengeSide2_onPostFightDialogEnd = makeDialogServerCallback("vengeSide2_onPostFightDialogEnd", 5, function()
    vengeSide2_friendlyShipsDepart()
    vengeSide2_finishAndReward()
end)

--endregion

--region #SERVER CALLS

function vengeSide2_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 8, false)

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function vengeSide2_spawnAllison(deleteOnLeft)
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

        if mission.internals.phaseIndex > 3 then
            local allisonAI = ShipAI(allison)
            allisonAI:setAggressive()
        end

        mission.data.custom.allisonID = allison.index
    end
end

function vengeSide2_createObjectiveSector()
    local _sector = Sector()
    local _player = Player()

    local xinullKills = _player:getValue("_vbmn_xinull_kills") or 1

    local x, y = _sector:getCoordinates()
    local pLevel = Balancing_GetPirateLevel(x, y)
    local pFaction = Galaxy():getPirateFaction(pLevel)

    local useLootFunc = 3 --Repeatable mission func

    local xinull = VengeUtil.spawnXinull(pFaction, useLootFunc, xinullKills)

    --Make his hull / shield invincible so Allison can't shoot him down with PDCs.
    xinull.invincible = true
    local xinullShield = Shield(xinull.index)
    xinullShield.invincible = true

    local pirateGenerator = AsyncPirateGenerator(nil, vengeSide2_firstLackeyWaveFinished)
    local pirateTable = ESCCUtil.getStandardWave(8, 4, "Standard", false)
    local piratePositions = pirateGenerator:getStandardPositions(4, 250) --_#DistAdj

    pirateGenerator:startBatch()

    for posIdx, p in pairs(pirateTable) do
        pirateGenerator:createScaledPirateByName(p, piratePositions[posIdx])
    end

    pirateGenerator:endBatch()
end

function vengeSide2_firstLackeyWaveFinished(generated)
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

function vengeSide2_setLastMissionTime()
    local _player = Player()
    local runTime = Server().unpausedRuntime

    _player:setValue("_vengeancebmn_last_side2", runTime)
end

function vengeSide2_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeSide2_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeSide2_onBossAnimation(xinullID)
    startBossCameraAnimation(xinullID)
end

--endregion

--region #CLIENT DIALOG CALLS

function vengeSide2_onPhase1Dialog(allisonID, sX, sY)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    d0.text = "${_PLAYER}. We meet again." % { _PLAYER = Player().name }
    d0.followUp = d1

    d1.text = "I'm pleased to see you. Your presence will make this easier."
    d1.followUp = d2

    d2.text = "Our impostor isn't nearly as good at hiding as the original. I've tracked him to (${_X}:${_Y})." % { _X = sX, _Y = sY }
    d2.followUp = d3

    d3.text = "You know what to do."
    d3.followUp = d4

    d4.text = "I'll meet you there. Let's get moving."
    d4.onEnd = vengeSide2_onPhase1DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeSide2_onXinullPreFightDialog(xinullID)
    local _player = Player()

    local funcTable = {
        function() --Normal
            local d0 = {}
            local d1 = {}
            local d2 = {}
            local d3 = {}
            local d4 = {}
            local d5 = {}
            local d6 = {}

            d0.text = "Ah, you must be Allison. I should have expected you to show up eventually."
            d0.followUp = d1

            d1.text = "You should have. I won't allow you to do this - especially not after all the trouble I went through to kill the original."
            d1.followUp = d2

            d2.text = "To allow someone else to take up his mantle would be untenable. Even a shadow of his old influence would leave thousands dead. And for what?"
            d2.followUp = d3

            d3.text = "So you can get a few credits richer? So you can feel the thrill of butchering some innocents? No. Instead, you die."
            d3.followUp = d4

            d4.text = "That's a shame. I was hoping I could persuade you to join me. It wouldn't be like the old days anymore - new Xinull, new leaf."
            d4.followUp = d5

            d5.text = "That means nothing. If the entire tree is rotten, a single leaf matters not. It must be felled. ${_PLAYER}, get ready." % { _PLAYER = _player.name }
            d5.followUp = d6

            d6.text = "A pity. I suppose I'll have to succeed where my predecessor failed!"
            d6.onEnd = vengeSide2_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d1, d2, d3, d5}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            ESCCUtil.setTextColors({d0, d4, d6}, MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

            return d0
        end,
        function() --Cringe Pirate
            local d0 = {}
            local d1 = {}
            local d2 = {}
            local d3 = {}
            local d4 = {}
            local d5 = {}
            local d6 = {}

            d0.text = "Ahoy there! Who might ye be?"
            d0.followUp = d1

            d1.text = "Oh god."
            d1.followUp = d2

            d2.text = "What? Ye've never seen a pirate before?"
            d2.followUp = d3

            d3.text = "I have, but not one that talks so... stupidly."
            d3.followUp = d4

            d4.text = "I had a whole speech prepared about how nobody could be allowed to take the mantle of Xinull, but forget it. You are too pathetic to be allowed to live."
            d4.followUp = d5

            d5.text = "${_PLAYER}, kill him." % {_PLAYER = _player.name}
            d5.followUp = d6

            d6.text = "Scurvy dog! I'll run ye through, scallywag!"
            d6.onEnd = vengeSide2_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d1, d3, d4, d5}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            ESCCUtil.setTextColors({d0, d2, d6}, MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

            return d0
        end,
        function() --Cynical
            local d0 = {}
            local d1 = {}
            local d2 = {}
            local d3 = {}
            local d4 = {}
            local d5 = {}
            local d6 = {}
            local d7 = {}

            d0.text = "Sigh. Great. This is the last thing I needed."
            d0.followUp = d1

            d1.text = "What, for me to show up? You should have expected that."
            d1.followUp = d2

            d2.text = "I guess. I was hoping you'd be too busy to care."
            d2.followUp = d3

            d3.text = "Why are you even doing this? Your heart clearly isn't in it."
            d3.followUp = d4

            d4.text = "Thought I could scare some people, make a few credits."
            d4.followUp = d5

            d5.text = "I can't allow that. Even a shadow of Xinull's influence could result in thousands dead. Maybe you won't kill them yourself, but your followers will."
            d5.followUp = d6

            d6.text = "Time to die. ${_PLAYER}, let's get to work." % {_PLAYER = _player.name}
            d6.followUp = d7

            d7.text = "Ugh, fine. Well, I paid a ton of money for this ship. I guess it's time to see what it can do."
            d7.onEnd = vengeSide2_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d1, d3, d5, d6}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            ESCCUtil.setTextColors({d0, d2, d4, d7}, MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

            return d0
        end,
        function() --Gamer
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

            d0.text = "Huh? Who're you?"
            d0.followUp = d1

            d1.text = "Go away. I'm busy."
            d1.followUp = d2

            d2.text = "Just one more pull, and I'l get that SSR for sure..."
            d2.followUp = d3

            d3.text = "Really. You're... gaming?"
            d3.followUp = d4

            d4.text = "I said I'm busy! Get outta here!"
            d4.followUp = d5

            d5.text = "You claimed the name of the most notorious pirate in this region of space... so you could game."
            d5.followUp = d6

            d6.text = "Yeah. What's it to you?"
            d6.followUp = d7

            d7.text = "I won't allow you to do that. Xinull's shadow could mean thousands of deaths and widespread destruction. To do that for the sake of something so trivial is... abhorrent. This is the end of the line for you."
            d7.followUp = d8

            d8.text = "Get ready, ${_PLAYER}." % {_PLAYER = _player.name}
            d8.followUp = d9

            d9.text = "You think you're hot stuff huh? Well my KDA ratio is better than yours, and I'll prove it by turning both of you into space dust!"
            d9.onEnd = vengeSide2_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d3, d5, d7, d8}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            ESCCUtil.setTextColors({d0, d1, d2, d4, d6, d9}, MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

            return d0
        end
    }

    local useDialog = funcTable[mission.data.custom.xinullPersonality]()

    ScriptUI(xinullID):interactShowDialog(useDialog, false)
end

function vengeSide2_onXinullPostFightDialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    d0.text = "Well done. Xinull lies dead. Again."
    d0.followUp = d1

    d1.text = "I doubt this is the last time we'll see an impostor rise to claim the throne."
    d1.followUp = d2

    d2.text = "How exhausting."
    d2.followUp = d3

    d3.text = "Still, nothing worth doing is easy. I'll kill him as many times as it takes. Eventually, his successors will get the idea."
    d3.followUp = d4

    d4.text = "Stay safe out there, ${_PLAYER}." % { _PLAYER = Player().name }
    d4.onEnd = vengeSide2_onPostFightDialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion

--region #MAKEBULLETIN CALL

function vengeSide2_formatDescription()
    return "In this region, there used to be a notorious pirate named Xinull. He's dead now, and his body is floating out there among the stars - but some fool has decided to hide behind his name and use it to build up some influence in this area. I won't allow it. Not after I went through all the trouble I did to kill the original. I'm looking for an independent captain to help me take him out. I will pay you for your efforts."
end

mission.makeBulletin = function(station)
    local methodName = "Make Bulletin"
    mission.Log(methodName, "Making Bulletin.")

    local target = {}
    --GET TARGET HERE:
    local x, y = Sector():getCoordinates()
    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 8, false)

    if not target.x or not target.y then
        mission.Log(methodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    reward = 5500000

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = vengeSide2_formatDescription(),
        difficulty = "Extreme",
        reward = "¢${reward}",
        script = "missions/vengeance/vengeanceside2.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "He's not nearly as sneaky as the original. Meet me at \\s(%1%:%2%). We'll talk before moving in for the kill.",
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if not player:getValue("_vbmn_story_complete") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission.")
                return 0
            end
            if player:hasScript("vengeanceside2.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission again!")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = station.index,
            location = target,
            reward = {credits = reward, paymentMessage = "Earned %1% credits for killing the impostor Xinull."}
        }},
    }

    return bulletin
end

--endregion