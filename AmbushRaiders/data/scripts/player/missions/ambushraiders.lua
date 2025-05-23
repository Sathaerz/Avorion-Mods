--[[
    Rank 1 side mission.
    Ambush Pirate Raiders
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - N/A
    ROUGH OUTLINE
        - Player goes to designated location.
        - Player waits for a short period of time.
        - Pirates start jumping in after a short wait.
        - Player kills all of the pirates. That's it. This is a very straightforward mission.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - Pirates will use standard threat ships from the corresponding danger table.
            - There will be at least 3 waves of pirates.
            - All waves BUT the final wave will spawn @ half danger level.
        6 - [These conditions are present at danger level 6 and above]
            - +1 wave of pirates (4 waves total)
        10 - [These conditions are present at danger level 10]
            - +1 wave of pirates (5 waves total)
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Balancing = include ("galaxy")

mission._Debug = 0
mission._Name = "Ambush Pirate Raiders"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy the arriving pirates", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 30 * 60 --Player has 30 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

--Can't set mission.data.reward.paymentMessage here since we are using a custom init.
mission.data.accomplishMessage = "Thank you for taking care of those pirates! We've transferred a reward to your account."
mission.data.failMessage = "You have failed. The pirates have escaped."

local AmbushRaiders_init = initialize
function initialize(_Data_in)
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(methodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)

            --[[=====================================================
                CUSTOM MISSION DATA SETUP
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.waveDangerLevel = math.ceil(_Data_in.dangerLevel / 2)
            mission.data.custom.timerAdvance = false
            mission.data.custom.showedFirstUpdate = false
            mission.data.custom.timeInPhaseOne = 0

            --[[=====================================================
                MISSION DESCRIPTION SETUP:
            =========================================================]]
            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { x = _X, y = _Y }
            mission.data.description[3].arguments = { _X = _X, _Y = _Y }

            --Run standard initialization
            AmbushRaiders_init(_Data_in)
        else
            --Restoring
            AmbushRaiders_init()
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
--Try to keep the timer calls outside of onBeginServer / onSectorEntered / onSectorArrivalConfirmed unless they are non-repeating and 30 seconds or less.

mission.globalPhase.noBossEncountersTargetSector = true

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].triggers = {}
mission.phases[1].updateTargetLocationServer = function(timeStep)
    mission.data.custom.timeInPhaseOne = (mission.data.custom.timeInPhaseOne or 0) + timeStep
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    if not mission.data.custom.showedFirstUpdate then
        showMissionUpdated()
        mission.data.custom.showedFirstUpdate = true
    end
end

--region #PHASE 1 TRIGGERS

if onServer() then

mission.phases[1].triggers[1] = {
    condition = function()
        if atTargetLocation() and mission.data.custom.timeInPhaseOne >= 15 then
            return true
        else
            return false
        end
    end,
    callback = function()
        ambushRaiders_spawnPirateWave(false)
    end,
    repeating = false
}

end

--endregion

--region #PHASE 1 TIMERS

if onServer() then

mission.phases[1].timers[1] = {
    time = 10, 
    callback = function() 
        if ambushRaiders_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end
    
    --endregion

mission.phases[2] = {}
mission.phases[2].timers = {}

--region #PHASE 2 TIMERS

if onServer() then

mission.phases[2].timers[1] = {
    time = 10, 
    callback = function() 
        if ambushRaiders_allowPhaseAdvancement() then
            mission.data.custom.timerAdvance = false
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[2].onBeginServer = function()
    ambushRaiders_spawnPirateWave(false)
end

mission.phases[3] = {}
mission.phases[3].timers = {}

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 10, 
    callback = function() 
        if ambushRaiders_allowPhaseAdvancement() then
            if mission.data.custom.dangerLevel >= 6 then
                mission.data.custom.timerAdvance = false
                nextPhase()
            else
                ambushRaiders_finishAndReward()
            end
        end
    end,
    repeating = true 
}

end

--endregion

mission.phases[3].onBeginServer = function()
    local _LastWave = true

    if mission.data.custom.dangerLevel >= 6 then
        _LastWave = false
    end

    ambushRaiders_spawnPirateWave(_LastWave)
end

mission.phases[4] = {}
mission.phases[4].timers = {}

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 10, 
    callback = function() 
        if ambushRaiders_allowPhaseAdvancement() then
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.timerAdvance = false
                nextPhase()
            else
                ambushRaiders_finishAndReward()
            end
        end
    end,
    repeating = true 
}

end

--endregion

mission.phases[4].onBeginServer = function()
    local _LastWave = true

    if mission.data.custom.dangerLevel == 10 then
        _LastWave = false
    end

    ambushRaiders_spawnPirateWave(_LastWave)
end

mission.phases[5] = {}
mission.phases[5].timers = {}

--region #MISSION 5 TIMERS

if onServer() then

mission.phases[5].timers[1] = {
    time = 10, 
    callback = function() 
        --We always end here - this is the last possible wave.
        if ambushRaiders_allowPhaseAdvancement() then
            ambushRaiders_finishAndReward()
        end
    end,
    repeating = true 
}

end

--endregion

mission.phases[5].onBeginServer = function()
    --We only get here on danger level 10 - this is always the last wave, no matter what.
    ambushRaiders_spawnPirateWave(true)
end

--endregion

--region #SERVER CALLS

function ambushRaiders_spawnPirateWave(_LastWave) 
    local methodName = "Spawn Pirate Wave"
    mission.Log(methodName, "Beginning. Last wave is : " .. tostring(_LastWave))

    local _SpawnLevel = mission.data.custom.waveDangerLevel
    if _LastWave then
        _SpawnLevel = mission.data.custom.dangerLevel
    end

    local waveTable = ESCCUtil.getStandardWave(_SpawnLevel, 4, "Standard", false)

    local generator = AsyncPirateGenerator(nil, ambushRaiders_onPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 250 --_#DistAdj
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function ambushRaiders_onPiratesFinished(_Generated)
    local methodName = "On Pirates Generated (Server)"
    mission.Log(methodName, "Beginning - setting timerAdvance to true and adding buffs.")

    mission.data.custom.timerAdvance = true
    ambushRaiders_pirateTaunt()

    SpawnUtility.addEnemyBuffs(_Generated)
end

function ambushRaiders_allowPhaseAdvancement()
    local methodName = "Allow Phase Advancement"

    local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

    mission.Log(methodName, "At Target Location: " .. tostring(atTargetLocation()) .. " number of pirates : " .. tostring(pirateCt) .. " timer allowed to advance : " .. tostring(mission.data.custom.timerAdvance))

    if atTargetLocation() and pirateCt == 0 and mission.data.custom.timerAdvance then
        return true
    else
        return false
    end
end

function ambushRaiders_pirateTaunt()
    local methodName = "Pirate Taunt"
    mission.Log(methodName, "Beginning...")

    local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}

    if not mission.data.custom.firstWaveTaunt and #_Pirates > 0 then
        mission.Log(methodName, "Broadcasting Pirate Taunt to Sector")
        mission.Log(methodName, "Entity: " .. tostring(_Pirates[1].id))

        local _Lines = {
            "Who sold us out? We're going to kill you after we deal with this!",
            "... Who are you? How dare you interrupt!",
            "Well, I guess you'll be the first one we kill.",
            "How did you find us? No matter, we'll kill you and move on to better targets.",
            "You're a long way from home, aren't you?",
            "No one was supposed to be here.",
            "They said there'd be no witnesses - and there won't be.",
            "... Who the hell are you?",
            "Looks like we found a stray one."
        }

        Sector():broadcastChatMessage(_Pirates[1], ChatMessageType.Chatter, getRandomEntry(_Lines))
        mission.data.custom.firstWaveTaunt = true
    end
end

function ambushRaiders_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALL

function ambushRaiders_formatDescription()
    --"please help, nobody believes me" (DONE)
    --"please help, there's no time" (DONE)
    --"please help, they're after me" (DONE)
    local descriptionTable = {
        "Just a few hours ago, we picked up some subspace signals in (${x}:${y}). They were consistent with pirate signatures, so we left the sector right away. Unfortunately, since we left the sector immediately after picking them up, we can't prove that they belonged to pirates! We think that a pirate raid may be imminent on a nearby sector, but nobody that we've told believes us! Please help! You're our last hope of defeating these pirates before they attack an unsuspecting colony!",
        "We've received credible intelligence that a group of pirates is planning on raiding a nearby sector. Normally we'd do this by the book, but the raid is imminent - there's not enough time to alert the proper authorities. We're putting this request out to any independent captain who happens to see it. Please hurry! If you manage to stop these pirates in time, you could save hundreds of lives. If our sources are correct, they should be gathering in (${x}:${y}).",
        "We were minding our own business mining in a nearby sector when a bunch of pirates warped in! Obviously, we warped out immediately but... we think that they might still be after us! I swear we've been seeing pirate subspace signals on our radar ever since we left that sector. We think that they're going to be coming after us through (${x}:${y}) - please head there and attack them first! Please! I don't want to spend the rest of my life looking over my shoulder!"
    }

    if random():test(0.05) then
        --"please help, I don't want there to be any competition." (DONE)
        descriptionTable = {
            "There's a gang of pirate rabble that intends to attack a nearby sector. They're going to be mustering their strength in (${x}:${y}). Head there first and wipe them out. Why, you ask? Simple. I'd rather not have any comp-ah. I see what you did there. No. You should do it because killing pirates is its own reward. They'll drop turrets and systems, and in addition to that I'll pay you quite well for your efforts. Not a bad deal, wouldn't you say?"
        }
    end

    return getRandomEntry(descriptionTable)
end

mission.makeBulletin = function(_Station)
    local methodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _sector = Sector()

    local target = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 2, 15, insideBarrier)

    if not target.x or not target.y then
        mission.Log(methodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = random():getInt(1, 10)

    local _Difficulty = "Easy"
    if _DangerLevel >= 6 then
        _Difficulty = "Medium"
    end
    if _DangerLevel >= 9 then
        _Difficulty = "Difficult"
    end
    
    local _Description = ambushRaiders_formatDescription()

    local _BaseReward = 37000
    if _DangerLevel >= 5 then
        _BaseReward = _BaseReward + 1000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 2000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates()) --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission._Name,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/ambushraiders.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "They are gathering in \\s(%1%:%2%). Please destroy them.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = target,
            --This is such a common mission. It's like free the slaves all over again!
            reward = {credits = reward, relations = 4000, paymentMessage = "Earned %1% credits for eliminating raiders."}, 
            punishment = { relations = 4000 },
            dangerLevel = _DangerLevel,
            initialDesc = _Description
        }},
    }

    return bulletin
end

--endregion