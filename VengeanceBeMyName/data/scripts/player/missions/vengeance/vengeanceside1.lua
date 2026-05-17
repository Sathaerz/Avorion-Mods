--[[
Brute Iterum Occide
- Attack someone who has taken the mantle of the first boss.
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
mission._Name = "Brute Iterum Occide"

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
    { text = "Defeat the impostor Gruznier", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

mission.data.accomplishMessage = "The Spears of Adrasteia thank you. Here's your compensation."

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.allisonRespawnTimer = 0
mission.data.custom.inSectorPhase2 = false
mission.data.custom.phase2Timer = 0
mission.data.custom.phase5ChatTimer = 0
mission.data.custom.phase5ChatStarted = false

--region # INIT / DATA

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    vengeSide1_setLastMissionTime()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    vengeSide1_setLastMissionTime()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    vengeSide1_setLastMissionTime()
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
    mission.data.description[2].text = vengeSide1_formatDescription()
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }

    mission.data.custom.gruzPersonality = random():getInt(1, 4)
    local personalityTypes = {
        "Normal.",
        "Posh.",
        "Angry.",
        "The most oppressed class of all... a gamer."
    }
    mission.Log(methodName, "Gruznier personality is " .. personalityTypes[mission.data.custom.gruzPersonality])
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    local methodName = "Phase 1 On Target Location Entered"
    mission.Log(methodName, "Beginning...")
    mission.data.description[3].fulfilled = true

    if onServer() then
        vengeSide1_spawnAllison(true)
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    mission.data.custom.secondLocation = vengeSide1_getNextLocation()

    local sX = mission.data.custom.secondLocation.x
    local sY = mission.data.custom.secondLocation.y

    mission.data.description[4].arguments = { _X = sX, _Y = sY }

    sync()
    invokeClientFunction(Player(), "vengeSide1_onPhase1Dialog", mission.data.custom.allisonID, sX, sY)
end

local vengeSide1_onPhase1DialogEnd = makeDialogServerCallback("vengeSide1_onPhase1DialogEnd", 1, function()
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
        vengeSide1_spawnAllison(false)
        vengeSide1_createObjectiveSector()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    mission.data.custom.inSectorPhase2 = true

    local _player = Player()
    local _sector = Sector()

    --Set pirates to friendly so autoguns don't shoot - this includes Gruznier so we can just use the "is_pirate" tag.
    local pirates = { _sector:getEntitiesByScriptValue("is_pirate") }
    for _, pirate in pairs(pirates) do
        local pirateAI = ShipAI(pirate)
        pirateAI:registerFriendFaction(_player.index)
    end

    --Set Allison shield to invincible
    local allison = Entity(mission.data.custom.allisonID)
    if allison then
        allison.invincible = true
        local allisonShield = Shield(allison.index)
        allisonShield.invincible = true
    else
        print("WARNING - Phase 3 onTargetLocationArrivalConfirmed - Could not find Allison's ship.")
    end

    local gruznier = Entity(mission.data.custom.gruznierID)
    if gruznier then
        invokeClientFunction(_player, "vengeSide1_onBlossAnimation", gruznier.index)
    else
        print("WARNING - Phase 3 onTargetLocationArrivalConfirmed - Could not find Gruznier's ship")
    end
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

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginClient = function()
    local gruznier = Entity(mission.data.custom.gruznierID)
    if gruznier then
        vengeSide1_onGruzPreFightDialog(gruznier.index)
    else
        print("WARNING - Phase 3 onBeginClient - Could not find Gruznier's ship")
    end
end

local vengeSide1_onPreFightDialogEnd = makeDialogServerCallback("vengeSide1_onPreFightDialogEnd", 3, function()
    nextPhase()
end)

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBeginServer = function()
    local _sector = Sector()

    local allison = Entity(mission.data.custom.allisonID)
    if allison then
        local allisonAI = ShipAI(allison)
        
        allison.invincible = false
        local allisonShield = Shield(allison.index)
        allisonShield.invincible = false

        allisonAI:setAggressive()
    else
        print("WARNING - Phase 4 onBeginServer - Could not find Allison's ship.")
    end

    local gruz = Entity(mission.data.custom.gruznierID)
    if gruz then
        gruz.invincible = false
        local gruzShield = Shield(gruz.index)
        gruzShield.invincible = false
        VengeUtil.setGruznierAttack(gruz, true, mission.data.custom.gruzPersonality)
    else
        print("WARNING - Phase 4 onBeginServer - Could not find Gruznier's ship")
    end
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)

    if atTargetLocation() and destroyedEntity:getValue("is_gruznier") then
        local _player = Player()
        local gruznierKills = _player:getValue("_vbmn_gruznier_kills") or 1

        gruznierKills = gruznierKills + 1

        _player:setValue("_vbmn_gruznier_kills", gruznierKills)
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
        vengeSide1_spawnAllison(false)
    end
end

mission.phases[5] = {}
mission.phases[5].onBegin = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
end

mission.phases[5].onBeginServer = function()
    local _sector = Sector()
    local gruznierReinforcementGoons = { _sector:getEntitiesByScriptValue("is_pirate") }

    local lines = {
        "We lost Da Gruzier!",
        "Gruznier down!",
        "Get out of here! We're next!",
        "It's not worth it! Charge the hyperdrives!",
        "Oh my god! They killed Gruznier!",
        "RUN!",
        "We can't do this without Grznier! Retreat!",
        "We need to get out!",
        "Game over, man! Game over!",
        "Not like this!"
    }

    for _, p in pairs(gruznierReinforcementGoons) do
        if not p:getValue("is_gruznier") then
            _sector:broadcastChatMessage(p, ChatMessageType.Chatter, getRandomEntry(lines))
            p:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 8))
        end
    end

    vengeSide1_spawnAllison(false)
end

mission.phases[5].updateTargetLocationServer = function(timeStep)
    mission.data.custom.phase5ChatTimer = mission.data.custom.phase5ChatTimer + timeStep

    if mission.data.custom.phase5ChatTimer >= 10 and not mission.data.custom.phase5ChatStarted then
        mission.data.custom.phase5ChatStarted = true
        invokeClientFunction(Player(), "vengeSide1_onGruzPostFightDialog", mission.data.custom.allisonID)
    end
end

local vengeSide1_onPostFightDialogEnd = makeDialogServerCallback("vengeSide1_onPostFightDialogEnd", 5, function()
    vengeSide1_friendlyShipsDepart()
    vengeSide1_finishAndReward()
end)

--endregion

--region #SERVER CALLS

function vengeSide1_getNextLocation()
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

function vengeSide1_spawnAllison(deleteOnLeft)
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

function vengeSide1_createObjectiveSector()
    local _sector = Sector()
    local _player = Player()

    local gruznierKills = _player:getValue("_vbmn_gruznier_kills") or 1

    local x, y = _sector:getCoordinates()
    local pLevel = Balancing_GetPirateLevel(x, y)
    local pFaction = Galaxy():getPirateFaction(pLevel)

    local useLootFunc = 3

    local gruz = VengeUtil.spawnGruznier(pFaction, true, useLootFunc, gruznierKills)

    mission.data.custom.gruznierID = gruz.index

    gruz.invincible = true
    local gruzShield = Shield(gruz.index)
    gruzShield.invincible = true
end

function vengeSide1_setLastMissionTime()
    local _player = Player()
    local runTime = Server().unpausedRuntime

    _player:setValue("_vengeancebmn_last_side1", runTime)
end

function vengeSide1_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeSide1_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeSide1_onBlossAnimation(gruzID)
    startBossCameraAnimation(gruzID)
end

--endregion

--region #CLIENT DIALOG CALLS

function vengeSide1_onPhase1Dialog(allisonID, sX, sY)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    d0.text = "${_PLAYER}. We meet again." % { _PLAYER = Player().name }
    d0.followUp = d1

    d1.text = "I'm pleased to see you. Your presence will make this easier."
    d1.followUp = d2

    d2.text = "Gruznier was never a subtle man, and his impostor is carrying on the tradition. It was easy to track him to (${_X}:${_Y})." % { _X = sX, _Y = sY }
    d2.followUp = d3

    d3.text = "No need for a complicated plan this time. We'll attack together and take him out."
    d3.followUp = d4

    d4.text = "I'll meet you there. Let's get moving."
    d4.onEnd = vengeSide1_onPhase1DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeSide1_onGruzPreFightDialog(gruzID)
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

            d0.text = "You come. I expect this. Now, Gruznier kill you."
            d0.followUp = d1

            d1.text = "Hm. Not bad. You almost sound like him. I might even believe that you are him if I hadn't seen the body."
            d1.followup = d2

            d2.text = "I'll be killing you as well. I can't allow you to pick things up where he left off. Gruznier may not have been as dangerous as Xinull, but..."
            d2.followUp = d3

            d3.text = "... no loose ends. I won't allow the pirates here to become emboldened again."
            d3.followUp = d4

            d4.text = "You think you tough enough to kill me? Ha! I show you who more dangerous."
            d4.followUp = d5

            d5.text = "${_PLAYER}, let's get to work." % { _PLAYER = _player.name }
            d5.followUp = d6

            d6.text = "YOU KILL PREVIOUS GRUZNIER! NEW GRUZNIER KILL YOU!"
            d6.onEnd = vengeSide1_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d1, d2, d3, d5}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            return d0
        end,
        function() --Posh
            local d0 = {}
            local d1 = {}
            local d2 = {}
            local d3 = {}
            local d4 = {}
            local d5 = {}
            local d6 = {}
            local d7 = {}
            local d8 = {}

            d0.text = "Ah, Allison Vannier, I presume?"
            d0.followUp = d1

            d1.text = "According to my research, you are the one who vanquished my predecessor."
            d1.followUp = d2

            d2.text = "Nice to see someone familiar with my work."
            d2.followUp = d3

            d3.text = "I can't let your half-assed masquerade as Gruznier continue. You'll have to follow in his footsteps."
            d3.followUp = d4

            d4.text = "That means killing you, of course."
            d4.followUp = d5

            d5.text = "Oh? And you really think you have what it takes?"
            d5.followUp = d6

            d6.text = "The original Gruznier was a blunt object - you'll find me a more challenging trial to overcome."
            d6.followUp = d7

            d7.text = "I'm not too worried about it. You sound like too much of a fop to pose a serious threat. ${_PLAYER}, time to earn your pay."
            d7.followUp = d8

            d8.text = "Hmph, I'll make you eat those words! Have at you!"
            d8.onEnd = vengeSide1_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d2, d3, d4, d7}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            return d0
        end,
        function() --Angry
            local d0 = {}
            local d1 = {}
            local d2 = {}
            local d3 = {}
            local d4 = {}
            local d5 = {}
            local d6 = {}

            d0.text = "GRRRRAAAAGH! WHO DARES?"
            d0.followUp = d1

            d1.text = "My name is Allison Vannier. I'm here to kill you."
            d1.followUp = d2

            d2.text = "RRRRRRRRRRRR... YOU'LL TRY."
            d2.followUp = d3

            d3.text = "... You know, despite all of his talk about being tough, Gruznier was never particularly angry."
            d3.followUp = d4

            d4.text = "That said, I think I would have preferred this to his actual personality."
            d4.followUp = d5

            d5.text = "Not that it makes a difference. It's time, ${_PLAYER}" % { _PLAYER = _player.name }
            d5.followUp = d6

            d6.text = "RRRRRAAAAHHHHHH! GRUZNIER KILL YOU! KILL KILL KILL!"
            d6.onEnd = vengeSide1_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d1, d3, d4, d5}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

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

            d0.text = "Go away. I'm busy."
            d0.followUp = d1

            d1.text = "Awwww yeah! That's a 360 noscope, baby!"
            d1.followUp = d2

            d2.text = "You're gaming."
            d2.followUp = d3

            d3.text = "You stole the identity of the top henchman of the most feared pirate boss in this region of space, and you did it to game."
            d3.followUp = d4

            d4.text = "You bet your ass I did!"
            d4.followUp = d5

            d5.text = "Do you know how many people bothered me before I told them I was Da Gruz? Now, nobody interrupts me. I can play all the games I'd like!"
            d5.followUp = d6

            d6.text = "Unfortunately for you, this isn't a game. I cannot let you continue to impersonate Gruznier. I'll have to kill you."
            d6.followUp = d7

            d7.text = "${_PLAYER}, it's time." % { _PLAYER = _player.name }
            d7.followUp = d8

            d8.text = "ThIs IsN't A gAmE! Whatever! I guess I'll have to 360 noscope YOU next!"
            d8.onEnd = vengeSide1_onPreFightDialogEnd

            ESCCUtil.setTalkerTextColors({d2, d3, d6, d7}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

            return d0
        end
    }

    local useDialog = funcTable[mission.data.custom.gruzPersonality]()

    ScriptUI(gruzID):interactShowDialog(useDialog, false)
end

function vengeSide1_onGruzPostFightDialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    d0.text = "Good job. We killed Gruznier. Again."
    d0.followUp = d1

    d1.text = "I doubt this will be the last time we'll see an impostor pretend to be that brute."
    d1.followUp = d2

    d2.text = "Exhausting, but it is what it is."
    d2.followUp = d3

    d3.text = "I'll kill him as many times as I need to until the local pirates get the message."
    d3.followUp = d4

    d4.text = "Thanks again for your help. Stay safe out there, ${_PLAYER}." % { _PLAYER = Player().name }
    d4.onEnd = vengeSide1_onPostFightDialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion

--region #MAKEBULLETIN CALL

function vengeSide1_formatDescription()
    return "I'm looking for an independent captain to work with. There's a pirate in this region who calls himself Brute Gruznier. He's not the first - I killed the original with the help of another captain. However, this new Gruznier cannot be allowed to raid and pillage ships in this region as he pleases. I'm planning on killing him too. If you're up for some action, I'll pay you to help me take him out."
end

mission.makeBulletin = function(station)
    local methodName = "Make Bulletin"
    mission.Log(methodName, "Making Bulletin.")

    local target = {}
    --GET TARGET HERE:
    local x, y = Sector():getCoordinates()
    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 8, false)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    reward = 2500000

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = vengeSide1_formatDescription(),
        difficulty = "Extreme",
        reward = "¢${reward}",
        script = "missions/vengeance/vengeanceside1.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "I know where he's hiding. Meet me at \\s(%1%:%2%). We'll talk before moving in for the kill.",
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if not player:getValue("_vbmn_story_complete") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission.")
                return 0
            end
            if player:hasScript("vengeanceside1.lua") then
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
            reward = {credits = reward, paymentMessage = "Earned %1% credits for killing the impostor Brute Gruznier."}
        }},
    }

    return bulletin
end

--endregion