--[[
    Hunt The Hunters
    - Bounty hunt missions for bounty hunters, lol.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

local EventUT = include("eventutility")

mission._Debug = 0
mission._Name = "Hunt The Hunters"

--region #INIT

--Standard mission data
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "${killedTargets} / ${targets} headhunters killed", bulletPoint = true, fulfilled = false },
}

mission.data.accomplishMessage = "Thank you for fulfilling the bounty contract. We transferred the reward to your account."

local huntTheHunters_init = initialize
function initialize(dataIn, bulletinIn)
    local methodName = "Initialize"
    mission.Log(methodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(methodName, "Calling on server - dangerLevel : " .. tostring(dataIn.dangerLevel))

        local _sector = Sector()
        local _giver = Entity(dataIn.giver)
        --[[=====================================================
            CUSTOM MISSION DATA:
        =========================================================]]
        mission.data.custom.dangerLevel = dataIn.dangerLevel
        mission.data.custom.insideBarrier = dataIn.insideBarrier
        mission.data.custom.targets = dataIn.targets
        mission.data.custom.killedTargets = 0
        mission.data.custom.sentTauntThisSector = false

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _sector.name, giverTitle = _giver.translatedTitle }
        mission.data.description[2].text = dataIn.initialDesc
        mission.data.description[3].arguments = { targets = tostring(mission.data.custom.targets), killedTargets = "0" }
    end

    huntTheHunters_init(dataIn, bulletinIn)
end

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].triggers = {}
mission.phases[1].onEntityDestroyed = function(id, lastDamageInflictor)
    local methodName = "Phase 1 On Entity Destroyed"
    local destroyedEntity = Entity(id)
    local entityDestroyer = Entity(lastDamageInflictor)

    if not entityDestroyer or not valid(entityDestroyer) or not destroyedEntity or not valid(destroyedEntity) then
        mission.Log(methodName, "Destroyed entity / destroyer entity is null - returning.")
        return
    end

    if(destroyedEntity.type == EntityType.Ship or destroyedEntity.type == EntityType.Station) and (entityDestroyer.type == EntityType.Ship or entityDestroyer.type == EntityType.Station) then
        mission.Log(methodName, "Both destroyer / destroyed entity were ships / stations - checking faction indexes.")
        local headhunterFaction = huntTheHunters_getHeadHunterFaction()
        local destroyerFactionIndex = entityDestroyer.factionIndex
        local targetFactionIndex = headhunterFaction.index
        local _player = Player()
        local pIndex = _player.index

        if destroyedEntity.factionIndex == targetFactionIndex and (destroyerFactionIndex == pIndex or (_player.allianceIndex and destroyerFactionIndex == _player.allianceIndex)) then
            mission.data.custom.killedTargets = mission.data.custom.killedTargets + 1
            mission.data.description[3].arguments.killedTargets = mission.data.custom.killedTargets
            sync()
        end
    end
end

mission.phases[1].updateServer = function(timeStep)
    local methodName = "Phase 1 Update"
    if mission.data.custom.dangerLevel >= 8 then
        local hunterBonus = 1.25
        if mission.data.custom.dangerLevel == 9 then
            hunterBonus = 1.5
        end
        if mission.data.custom.dangerLevel == 10 then
            hunterBonus = 2.0
        end

        local _sector = Sector()
        local _player = Player()
        local headhunterFaction = huntTheHunters_getHeadHunterFaction()
        local rawHeadhunters = { _sector:getEntitiesByFaction(headhunterFaction.index) } --This gets things like turrets, etc. back.
        local headhunters = {}

        for _, hunterEntity in pairs(rawHeadhunters) do
            if hunterEntity.type == EntityType.Ship or hunterEntity.type == EntityType.Station then
                table.insert(headhunters, hunterEntity)
            end
        end

        local targetScriptValue = "huntthehunters_applied_bonus"
        local sendTaunt = false

        if #headhunters > 0 then
            for _, hunter in pairs(headhunters) do
                if not hunter:getValue(targetScriptValue) then
                    mission.Log(methodName, "Hunter " .. tostring(hunter.name) .. " does not have script value.")
                    sendTaunt = true
                    break
                end
            end
        end

        if sendTaunt then
            mission.Log(methodName, "Danger 8+ and at least 1 hunter does not have bounty hunter danger buff - adding buff and sending taunt.")
        
            if not mission.data.custom.sentTauntThisSector then
                huntTheHunters_sendTaunt()
                mission.data.custom.sentTauntThisSector = true
            end
        end

        for _, hunter in pairs(headhunters) do
            if not hunter:getValue(targetScriptValue) then
                hunter.damageMultiplier = (hunter.damageMultiplier or 1) * hunterBonus

                local hunterDurabilityBonus = hunterBonus

                local hunterShields = Shield(hunter)
                if hunterShields then
                    hunterShields.maxDurabilityFactor = (hunterShields.maxDurabilityFactor or 1) * hunterDurabilityBonus
                else
                    hunterDurabilityBonus = hunterDurabilityBonus * 2
                end

                local hunterDurability = Durability(hunter)
                if hunterDurability then
                    hunterDurability.maxDurabilityFactor = (hunterDurability.maxDurabilityFactor or 1) * hunterDurabilityBonus
                end

                invokeClientFunction(_player, "huntTheHunters_playBuffAnimation", hunter, random():getDirection())

                hunter:setValue(targetScriptValue, true)
            end
        end
    end
end

mission.phases[1].onSectorEntered = function(x, y)
    mission.data.custom.sentTauntThisSector = false
end

--region #PHASE 1 TRIGGER CALLS

if onServer() then

mission.phases[1].triggers[1] = {
    condition = function()
        local methodName = "Phase 1 Trigger 1 Condition"
        return mission.data.custom.killedTargets >= mission.data.custom.targets
    end,
    callback = function()
        local methodName = "Phase 1 Trigger 1 Callback"
        huntTheHunters_finishAndReward()
    end,
    repeating = false    
}
    
end

--endregion

--endregion

--region #SERVER CALLS

function huntTheHunters_getHeadHunterFaction()
    local x, y = Sector():getCoordinates()

    return EventUT.getHeadhunterFaction(x, y)
end

function huntTheHunters_sendTaunt()
    local _sector = Sector()
    local headhunterFaction = huntTheHunters_getHeadHunterFaction()
    local headhunters = { _sector:getEntitiesByFaction(headhunterFaction.index) }

    local taunts = {
        "Kill us?! No. No... we kill YOU!",
        "So this is the fool who took a contract out on us? Kill them.",
        "Take a contract on us, will you? Hope you're ready to die.",
        "Just a job? Not anymore - you made it personal.",
        "Prepare yourself.",
        "Don't bother with a funeral for this one - just dump the bodies in space."
    }

   _sector:broadcastChatMessage(getRandomEntry(headhunters), ChatMessageType.Chatter, getRandomEntry(taunts)) 
end

function huntTheHunters_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    --Give the player a bonus if they have to deal with stronger hunters.
    if mission.data.custom.dangerLevel >= 8 then
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " This includes a bonus."
        mission.data.reward.credits = mission.data.reward.credits * 1.2
    end

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

--this makes it so that only the person with the mission can see the animations, but I don't think it's worth coding an entire entity script just for some vfx
function huntTheHunters_playBuffAnimation(entity, direction)
    Sector():createHyperspaceJumpAnimation(entity, direction, ColorRGB(1.0, 0.0, 0.0), 0.2)
end

--endregion

--region #MAKEBULLETIN CALLS

function huntTheHunters_formatDescription(station)
    local descriptionTable = {
        "Boy, those bounty huhters, huh? Strutting around, thinking they own the galaxy. I think they're getting a little too big for their britches, don't you? It's time someone taught them a lesson. I want you to eradicate ${targets} of their ships or stations. That'll teach them a lesson they'll be sure to remember. As if that's not sweet enough, we'll pay. Get to it, captain.",
        "The Galactic Bounty Hunters Guild enjoys nearly unfettered access to faction space, and is allowed to chase their targets with impunity. It would be a real shame if someone were to impede that process, wouldn't it? In case it's not obvious, we'd like you to do exactly that. Get rid of ${targets} of their ships or stations. We will pay you for your efforts.",
        "Last week, one of my friends perished when a member of the headhunter guild decided to take the contract on his head. It's personal now. I'm gonna waste some of those fools, but I'd appreciate some help. Kill ${targets} of their ships or stations, and my buddy can rest easier knowing that we've spaced enough of that scum to fill a cargo hold of graves. Here's my offer - take it or leave it.",
        "Do you have any idea how much money the bounty hunter guild gets paid to track down and kill targets? It's insane, captain. I'm looking to start up a little rival enterprise, but those fools need to be taken down a peg first. If you can get rid of ${targets} of their ships or stations, I'll have a good shot at setting up shop. Obviously, I'll be paying you for this. You in?"
    }

    return getRandomEntry(descriptionTable)
end

mission.makeBulletin = function(station)
    local methodName = "Make Bulletin"

    local _random = random()
    local _sector = Sector()

    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    local missionDescription = huntTheHunters_formatDescription(station)

    local dangerLevel = _random:getInt(1, 10)
    local maxTargets = 22
    local missionDifficulty = "Difficult"
    local missionTargets = _random:getInt(5, maxTargets)

    local baseReward = 11000
    if dangerLevel == 10 then
        missionTargets = math.min(missionTargets + 5, maxTargets)
    end
    if insideBarrier then
        baseReward = baseReward * 2
    end

    reward = baseReward * missionTargets * Balancing_GetSectorRewardFactor(_sector:getCoordinates())

    local bulletin = {
        brief = mission.data.brief,
        title = mission.data.title,
        description = missionDescription,
        difficulty = missionDifficulty,
        reward = "¢${reward}",
        script = "missions/huntthehunters.lua",
        formatArguments = { targets = tostring(missionTargets), reward = createMonetaryString(reward) },
        msg = "Thank you! We'll send your reward when the you've taught those hunters a lesson.",
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/huntthehunters.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional headhunter bounty contracts! Abandon your current one or complete it.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg)
        ]],

        --data that's important for the mission
        arguments = {{
            giver = station.index,
            location = nil,
            reward = { credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for killing bounty hunters." },
            dangerLevel = dangerLevel,
            initialDesc = missionDescription,
            targets = missionTargets
        }}
    }

    return bulletin
end

--endregion