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
local EventUT = include("eventutility")

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
mission.data.timeLimit = 60 * 60 * 4 --You got 4 hours.
mission.data.timeLimitInDescription = true --Show the player how much time is left.
mission.data.failMessage = "The bounty contract has expired. Thank you for your hard work."

mission.data.accomplishMessage = "Thank you for fulfilling the bounty contract. We transferred the reward to your account."

local PirateBounty_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() then
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
                .timePassed
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.pirateFaction = _Data_in.targetFaction
            mission.data.custom.targets = _Data_in.targets
            mission.data.custom.killedTargets = 0
            mission.data.custom.timePassed = 0

            local _TargetFaction = Faction(mission.data.custom.pirateFaction)

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { targets = tostring(mission.data.custom.targets), targetFaction = _TargetFaction.name }
            mission.data.description[3].arguments = { targetFaction = _TargetFaction.name, targets = tostring(mission.data.custom.targets), killedTargets = "0" }

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

if onServer() then

mission.phases[1].triggers[1] = {
    condition = function()
        local _MethodName = "Phase 1 Trigger 1 Condition"
        return mission.data.custom.killedTargets >= mission.data.custom.targets
    end,
    callback = function()
        local _MethodName = "Phase 1 Trigger 1 Callback"
        finishAndReward()
    end,
    repeating = false    
}

end

mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 On Entity Destroyed"
    local _DestroyedEntity = Entity(_ID)
    local _EntityDestroyer = Entity(_LastDamageInflictor)

    if not _EntityDestroyer or not valid(_EntityDestroyer) or not _DestroyedEntity or not valid(_DestroyedEntity) then
        mission.Log(_MethodName, "Destroyed entity / destroyer entity is null - returning.")
        return
    end

    if (_DestroyedEntity.type == EntityType.Ship or _DestroyedEntity.type == EntityType.Station) and (_EntityDestroyer.type == EntityType.Ship or _EntityDestroyer.type == EntityType.Station) then
        mission.Log(_MethodName, "Both destroyer / destroyed were ships / stations - checking faction indexes.")
        local _dfindex = _EntityDestroyer.factionIndex -- "destroyer faction" index
        local _pfindex = mission.data.custom.pirateFaction -- "pirate faction" index
        local _player = Player()
        local _pindex = _player.index

        if _DestroyedEntity.factionIndex == _pfindex and (_dfindex == _pindex or (_player.allianceIndex and _dfindex == _player.allianceIndex)) then
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

            local _TimePassed = mission.data.custom.timePassed
            local _Hours = math.max(math.floor(_TimePassed / 3600), 1)

            _HunterChance = _HunterChance * _Hours --cuts spawn rate by doubling the denominator on hour 2, tripling on hour 3. The mission expires afer hour 4 so it is irrelevant.

            mission.Log(_MethodName, "No pirates found. Calcuating headhunter chance as 1 in " .. tostring(_HunterChance))
            local _SpawnHunters = _Rgen:getInt(1, _HunterChance) == 1

            local _Player = Player()
            local _HX, _HY = _Player:getHomeSectorCoordinates()
            if _X == _HX and _Y == _HY then
                _SpawnHunters = false
                mission.Log(_MethodName, "Don't spawn headhunters in the player's home sector.")
            end

            if not EventUT.persecutorEventAllowed() then
                _SpawnHunters = false
                mission.Log(_MethodName, "Event utility says no persecutor event - setting hunter spawn to false.")
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

mission.phases[1].update = function(_TimeStep)
    mission.data.custom.timePassed = (mission.data.custom.timePassed or 0) + _TimeStep
end

--endregion

--region #SERVER CALLS

function getHeadHunterFaction()
    local _X, _Y = Sector():getCoordinates()

    return EventUT.getHeadhunterFaction(_X, _Y)
end

function spawnHunters()
    local _MethodName = "Spawn Hunters"
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
    local _MethodName = "On Hunters Finished"
    local _Player = Player()

    for _, _Ship in pairs(_Generated) do
        local _AI = ShipAI(_Ship)
        _AI:setAggressive()
        _AI:registerEnemyFaction(_Player.index)
        _AI:registerFriendFaction(mission.data.custom.pirateFaction) --Very unlikely that this comes into play.
        if _Player.allianceIndex then
            _AI:registerEnemyFaction(_Player.allianceIndex)
        end

        _Ship:setValue("secret_contractor", mission.data.custom.pirateFaction)
        MissionUT.deleteOnPlayersLeft(_Ship)
        _Ship:setValue("is_persecutor", true)

        mission.Log(_MethodName, "Ship title is " .. _Ship.title)

        if string.match(_Ship.title, "Persecutor") then
            _Ship.title = "Bounty Hunter"%_T
        end
    end

    local note = makeHeadHunterNote(Player(), Faction(mission.data.custom.pirateFaction))
    Loot(_Generated[1]):insert(note)

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

    _Player:sendChatMessage(_Generated[1], ChatMessageType.Chatter, getRandomEntry(headhunterMessages) % {player = _Player.name})
end

function makeHeadHunterNote(player, huntingFaction)
    local x, y = Sector():getCoordinates()
    local money = round(math.max(50000, 500000 * Balancing_GetSectorRichnessFactor(x, y)) / 10000) * 10000
    local reward = "¢${money}" % {money = createMonetaryString(money)}
    local shipName = "Unknown"%_t

    local craft = player.craft
    if valid(craft) then
        if craft.name and craft.name ~= "" then
            shipName = craft.name
        end
    end

    local note = VanillaInventoryItem()
    note.name = "Bounty Chip"%_t
    note.price = 1000

    local rarity = Rarity(RarityType.Common)
    note.rarity = rarity
    note:setValue("subtype", "BountyChip")
    note.icon = "data/textures/icons/bounty-chip.png"
    note.iconColor = rarity.color
    note.stackable = true

    local tooltip = Tooltip()
    tooltip.icon = note.icon
    tooltip.rarity = rarity

    local title = note.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = note.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Reward"%_t
    line.icon = "data/textures/icons/cash.png"
    line.iconColor = ColorRGB(1, 1, 1)
    line.rtext = reward
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Target"%_t
    line.rtext = "${faction:"..player.index.."}"
    line.icon = "data/textures/icons/player.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Ship"%_t
    line.rtext = shipName
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(1, 1, 1)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Target is wanted dead."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = "Reward requires proof of ship destruction."%_t
    tooltip:addLine(line)

    local line = TooltipLine(20, 14)
    line.ltext = " - ${faction:"..huntingFaction.index.."}"
    tooltip:addLine(line)


    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 14)
    line.ltext = "Looks like someone made some enemies."%_t
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    note:setTooltip(tooltip)

    return note
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

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    local descriptionTable = {
        "To any captains out there with a some combat experience - we'd like you to take on ${targetFaction} for us. We've had a lot of problems with them attacking freighters and other civilian targets, and we'd like you to put a stop to it. Destroying ${targets} of their ships or stations should be enough. You'll be compensated for your work.",
        "Listen up Captain! ${targetFaction} Need to be cut down a notch. We could easily destroy them ourselves, but our military is committed elsewhere and we cannot afford to split our forces. To that end, we're willing to pay you to hunt down ${targets} ships or stations belonging to ${targetFaction}. We don't care how or where you find them, as long as you get rid of them.",
        "Peace be with you, captain. Our diplomatic efforts have failed, and ${targetFaction} are running rampant in our sectors. We regret that it has come to this, but we need you to destroy ${targets} of their ships or stations. There's a reward in it for you as well. Please. If we don't put a stop to ${targetFaction} soon, there's no telling how much damage they'll cause."
    }

    return descriptionTable[descriptionType]
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
    --local _DangerLevel = 10
    local _MaxTargets = 22
    local _Difficulty = "Easy"
    local _Targets = _Rgen:getInt(5, _MaxTargets)

    local _BaseReward = 5500
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 1000
        _Targets = math.min(_Targets + 5, _MaxTargets) --Add a bias towards a higher target count, but don't push it over the maximum.
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * _Targets * Balancing.GetSectorRewardFactor(Sector():getCoordinates())

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
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional pirate bounty contracts! Abandon your current one or complete it.")
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
            reward = {credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for collecting the bounty on " .. _TargetFaction.name .. "."},
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            targetFaction = _TargetFaction.index,
            targets = _Targets
        }},
    }

    return bulletin
end

--endregion