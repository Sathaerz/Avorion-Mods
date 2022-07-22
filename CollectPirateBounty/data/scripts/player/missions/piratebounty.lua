--[[
    Ambush Pirate Raiders
    NOTES:
        - Copy of the first side mission from Long Live The Empress - mission bulletin edition.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        None
    ROUGH OUTLINE
        - Go to a sector.
        - After a few seconds, pirate raiders start to show up.
        - Kill them all. Very simple and straightforward.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - N/A
        8 - [These conditions are present at danger level 8 and above]
            - 25% chance to be attacked by a group of headhunters after each jump as long as you have this mission active.
            - Headhunter group is the Galactic Headhunter Faction and not the Pirates, so does not count towards bounty.
        10 - [These conditions are present at danger level 10]
            - Chance of headhunter attack is 50%
            - Headhunters have 2 extra ships.  
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include ("randomext")
include ("faction")

ESCCUtil = include("esccutil")

local AsyncShipGenerator = include("asyncshipgenerator")
local Placer = include ("placer")
local Balancing = include("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Collect Pirate Bounty"

--region #INIT

--Standard mission data.
mission.data.brief = "Collect Pirate Bounty"
mission.data.title = "Collect Pirate Bounty"
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "${killedTargets} / ${targets} targets killed", bulletPoint = true, fulfilled = false },
}

mission.data.accomplishMessage = "Thank you for fulfilling the bounty contract. We transferred the reward to your account."

local PirateBounty_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel) .. " - enemy : " .. tostring(_Data_in.targetFaction))

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .pirateFaction
                .targets
                .killedTargets
                .blockHunters
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.pirateFaction = _Data_in.targetFaction
            mission.data.custom.targets = _Data_in.targets
            mission.data.custom.killedTargets = 0

            local _TargetFaction = Faction(mission.data.custom.pirateFaction)

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { targets = tostring(mission.data.custom.targets), targetFaction = _TargetFaction.name }
            mission.data.description[3].arguments = { targetFaction = _TargetFaction.name, targets = tostring(mission.data.custom.targets), killedTargets = "0" }

            _Data_in.reward.paymentMessage = "Earned %1% credits for collecting the bounty on " .. _TargetFaction.name .. "."

            --Run standard initialization
            PirateBounty_init(_Data_in)
        else
            --Restoring
            PirateBounty_init()
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

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].triggers = {}
mission.phases[1].triggers[1] = {
    condition = function()
        local _MethodName = "Phase 1 Trigger 1 Condition"

        if onServer() then
            return mission.data.custom.killedTargets >= mission.data.custom.targets
        else
            return true
        end
    end,
    callback = function()
        local _MethodName = "Phase 1 Trigger 1 Callback"
        
        if onServer() then
            finishAndReward()
        end
    end,
    repeating = false    
}
mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 On Entity Destroyed"
    local _DestroyedEntity = Entity(_ID)
    local _EntityDestroyer = Entity(_LastDamageInflictor)

    if (_DestroyedEntity.type == EntityType.Ship or _DestroyedEntity.type == EntityType.Station) and (_EntityDestroyer.type == EntityType.Ship or _EntityDestroyer.type == EntityType.Station) then
        mission.Log(_MethodName, "Both destroyer / destroyed were ships / stations - checking faction indexes.")
        if _DestroyedEntity.factionIndex == mission.data.custom.pirateFaction and _EntityDestroyer.factionIndex == Player().index then
            mission.data.custom.killedTargets = mission.data.custom.killedTargets + 1
            mission.data.description[3].arguments.killedTargets = mission.data.custom.killedTargets
            sync()
        end
    end
end

mission.phases[1].onSectorArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 1 On Sector Arrival Confirmed"
    if mission.data.custom.dangerLevel >= 8 then
        
        local _PirateCount = ESCCUtil.countEntitiesByValue("is_pirate")

        if _PirateCount == 0 then
            local _Rgen = ESCCUtil.getRand()
            local _HunterChance = 4
            if mission.data.custom.dangerLevel == 10 then
                --50% chance instead of 25%
                _HunterChance = 2
            end
            mission.Log(_MethodName, "No pirates found. Calcuating headhunter chance as 1 in " .. tostring(_HunterChance))
            local _SpawnHunters = _Rgen:getInt(1, _HunterChance) == 1

            local _Player = Player()
            local _HX, _HY = _Player:getHomeSectorCoordinates()
            if _X == _HX and _Y == _HY then
                _SpawnHunters = false
                mission.Log(_MethodName, "Don't spawn headhunters in the player's home sector.")
            end

            if mission.data.custom.blockHunters then
                mission.Log(_MethodName, "Headhunters have spawned recently. Blocking spawn.")
                mission.data.custom.blockHunters = false
            else
                if _SpawnHunters then
                    mission.data.custom.blockHunters = true
                    mission.Log(_MethodName, "Spawning headhunters.")
                    mission.phases[1].timers[1] = {
                        time = 5, 
                        callback = function() spawnHunters() end, 
                        repeating = false
                    }
                end
            end
        end
    end
end

--endregion

--region #SERVER CALLS

function getHeadHunterFaction()
    local name = "The Galactic Headhunters Guild"%_T

    local galaxy = Galaxy()
    local faction = galaxy:findFaction(name)
    if faction == nil then
        faction = galaxy:createFaction(name, 0, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true

        SetFactionTrait(faction, "aggressive"%_T, "peaceful"%_T, 0.6)
        SetFactionTrait(faction, "careful"%_T, "brave"%_T, 0.75)
        SetFactionTrait(faction, "greedy"%_T, "generous"%_T, 0.75)
        SetFactionTrait(faction, "opportunistic"%_T, "honorable"%_T, 1.0)
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    -- set home sector to wherever it's needed to avoid head hunters being completely over the top
    local x, y = Sector():getCoordinates()
    faction:setHomeSectorCoordinates(x, y)

    return faction
end

function spawnHunters()
    local _HeadHunterFaction = getHeadHunterFaction()
    local _Rgen = ESCCUtil.getRand()

    local _HunterGenerator = AsyncShipGenerator(nil, onHuntersFinished)
    _HunterGenerator:startBatch()
    
    local _Volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())
    local _HunterPositions = _HunterGenerator:getStandardPositions(200, 6)
    local _RandomExtraVolume = _Rgen:getInt(1, 3) - 1

    local _BlockerPosition = 4
    if mission.data.custom.dangerLevel == 10 then
        _BlockerPosition = 6
    end

    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[1], _Volume * 4)
    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[2], _Volume * 4)
    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[3], _Volume * 4)
    if mission.data.custom.dangerLevel == 10 then
        _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[4], _Volume * (4 + _RandomExtraVolume))
        _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[5], _Volume * (4 + _RandomExtraVolume))
    end
    _HunterGenerator:createBlockerShip(_HeadHunterFaction, _HunterPositions[_BlockerPosition], _Volume * 2)

    _HunterGenerator:endBatch()
end

function onHuntersFinished(_Generated)
    local _Player = Player()

    for _, _Ship in pairs(_Generated) do
        local _AI = ShipAI(_Ship)
        _AI:setAggressive()
        _AI:registerEnemyFaction(_Player.index)
        _AI:registerFriendFaction(mission.data.custom.targetFaction) --Very unlikely that this comes into play.

        _Ship:setValue("secret_contractor", mission.data.custom.targetFaction)
        MissionUT.deleteOnPlayersLeft(_Ship)
        _Ship:setValue("is_persecutor", true)

        if string.match(_Ship.title, "Persecutor") then
            _Ship.title = "Head Hunter"%_T
        end
    end

    Placer.resolveIntersections(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)

    local headhunterMessages =
    {
        "This is ${player}! That's the one our client wants!"%_T,
        "Found you, ${player}. Let's shoot them down and get our money. Make it quick."%_T,
        "There they are. Alright, ${player} it's nothing personal, it's just a job."%_T,
        "Did you think they'd make this easy for you?",
        "Time to die, ${player}."
    }

    _Player:sendChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(headhunterMessages) % {player = _Player.name})
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALL

function formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _FinalDescription = ""
    if _DescriptionType == 1 then --Neutral.
        _FinalDescription = "To any captains out there with a some combat experience - we'd like you to take on ${targetFaction} for us. We've had a lot of problems with them attacking freighters and other civilian targets, and we'd like you to put a stop to it. Destroying ${targets} of their ships or stations should be enough. You'll be compensated for your work."
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "Listen up captain! ${targetFaction} Need to be cut down a notch. We could easily destroy them ourselves, but our military is committed elsewhere and we cannot afford to split our forces. To that end, we're willing to pay you to hunt down ${targets} ships or stations belonging to ${targetFaction}. We don't care how or where you find them, as long as you get rid of them."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "We need help. Our diplomatic efforts have failed, and ${targetFaction} have been running rampant in our sectors. We regret that it has come to this, but we need you to destroy ${targets} of their ships or stations. There's a reward in it for you as well. Please. If we don't put a stop to ${targetFaction} soon, there's no telling how much damage they'll cause."
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"

    local _Rgen = ESCCUtil.getRand()
    local _X, _Y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)

    local _PirateLevel = Balancing_GetPirateLevel(_X, _Y)
    local _TargetFaction = Galaxy():getPirateFaction(_PirateLevel)
    --No target sector. Just take it and keep it.
    
    local _Description = formatDescription(_Station)

    local _DangerLevel = _Rgen:getInt(1, 10)
    local _Difficulty = "Easy"
    local _Targets = _Rgen:getInt(5, 25)

    local _BaseReward = 4000
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 1000
        _Targets = math.min(_Targets + 5, 25) --Add a bias towards a higher target count, but don't push it over the maximum.
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end
    local _Version = GameVersion()
    if _Version.major > 1 then
        _BaseReward = _BaseReward * 1.33
    end

    reward = _BaseReward * _Targets * Balancing.GetSectorRichnessFactor(Sector():getCoordinates())

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Collect Pirate Bounty",
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/piratebounty.lua",
        formatArguments = {targetFaction = _TargetFaction.name, targets = tostring(_Targets), reward = createMonetaryString(reward)},
        msg = "Thank you! We'll send your reward when the pirates have been destroyed.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/piratebounty.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional bounty contracts! Abandon your current one or complete it.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = nil,
            reward = {credits = reward, relations = 6000},
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            targetFaction = _TargetFaction.index,
            targets = _Targets
        }},
    }

    return bulletin
end

--endregion