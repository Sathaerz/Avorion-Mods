package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include ("randomext")
include ("faction")

ESCCUtil = include("esccutil")

local Balancing = include("galaxy")
local Xsotan = include("story/xsotan")
local AsyncShipGenerator = include("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Collect Xsotan Bounty"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "${killedTargets} / ${targets} targets killed", bulletPoint = true, fulfilled = false },
    { text = "${barrierHint}", bulletPoint = true, fulfilled = false }
}

mission.data.accomplishMessage = "Thank you for fulfilling the bounty contract. We transferred the reward to your account."

local XsotanBounty_init = initialize
function initialize(_Data_in)
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(methodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

        local _Sector = Sector()
        local _Giver = Entity(_Data_in.giver)
        --[[=====================================================
            CUSTOM MISSION DATA:
            .dangerLevel
            .targets
            .killedTargets
        =========================================================]]
        mission.data.custom.dangerLevel = _Data_in.dangerLevel
        mission.data.custom.targets = _Data_in.targets
        mission.data.custom.killedTargets = 0
        mission.data.custom.inBarrier = _Data_in.insideBarrier
        mission.data.custom.canSpawnSpecialXsotan = true
        if mission.data.custom.inBarrier then
            local _KilledGuardian = Player():getValue("wormhole_guardian_destroyed")
            if _KilledGuardian then
                mission.Log(methodName, "Player killed guardian. Setting joker mode.")
                mission.data.custom.killedGuardian = true
            end
        end

        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { targets = tostring(mission.data.custom.targets) }
        mission.data.description[3].arguments = { targets = tostring(mission.data.custom.targets), killedTargets = "0" }
        if mission.data.custom.inBarrier then
            mission.data.description[4].arguments = { barrierHint = "Only Xsotan killed inside the barrier count." }
        else
            mission.data.description[4].arguments = { barrierHint = "Only Xsotan killed outside the barrier count." }
        end
    end

    XsotanBounty_init(_Data_in)
end

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].triggers = {}
mission.phases[1].onSectorEntered = function(x, y)
    mission.data.custom.canSpawnSpecialXsotan = true
end

--region #PHASE 1 TIMER CALLS

if onServer() then

mission.phases[1].timers[1] = {
    time = 300, --every 5 minutes.
    callback = function()
        local methodName = "Phase 1 Timer 1 Callback"

        if mission.data.custom.dangerLevel >= 8 and mission.data.custom.canSpawnSpecialXsotan then
            mission.Log(methodName, "Checking to see if a Xsotan should spawn")
            local xsotanCt = ESCCUtil.countEntitiesByValue("is_xsotan")

            if xsotanCt > 0 then
                local odds = 0.25
                local vol = 1.0
                if mission.data.custom.dangerLevel == 10 then
                    odds = 0.5
                    vol = 1.5
                end
                if mission.data.custom.killedGuardian then
                    --First, check to see what sector we're in.
                    local x, y = Sector():getCoordinates()
                    if MissionUT.checkSectorInsideBarrier(x, y) then
                        --If we're inside the barrier and killed the guardian, the Xsotan are twice as likely to spawn and twice as big.
                        odds = odds * 2
                        vol = vol * 2
                    end
                end

                local _random = random()
    
                if _random:test(odds) then
                    mission.Log(methodName, "Spawning Xostan")
                    local generator = AsyncShipGenerator(nil, nil)
                    local xsotanFunction = getRandomEntry(Xsotan.getSpecialXsotanFunctions(generator:getGenericPosition(), vol))

                    local xsotan = xsotanFunction()
                    SpawnUtility.addEnemyBuffs({xsotan})

                    mission.data.custom.canSpawnSpecialXsotan = false --Don't make multiple special Xsotan per sector. Unless...
                    if mission.data.custom.killedGuardian and _random:test(0.25) then
                        missin.data.custom.canSpawnSpecialXsotan = true
                    end
                else
                    mission.Log(methodName, "Random test failed - not spawning.")
                end
            else
                mission.Log(methodName, "No Xsotan present - not spawning.")
            end
        end
    end,
    repeating = true
}

end

--endregion

--region #PHASE 1 TRIGGER CALLS

if onServer() then

mission.phases[1].triggers[1] = {
    condition = function()
        local methodName = "Phase 1 Trigger 1 Condition"
        return mission.data.custom.killedTargets >= mission.data.custom.targets
    end,
    callback = function()
        local methodName = "Phase 1 Trigger 1 Callback"
        collectXsotanBounty_finishAndReward()
    end,
    repeating = false    
}

end

--endregion

mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local methodName = "Phase 1 On Entity Destroyed"
    local _DestroyedEntity = Entity(_ID)
    local _EntityDestroyer = Entity(_LastDamageInflictor)

    local x, y = Sector():getCoordinates()
    local insideBarrierOK = false
    if mission.data.custom.inBarrier == MissionUT.checkSectorInsideBarrier(x, y) then
        insideBarrierOK = true
    end

    if not _EntityDestroyer or not valid(_EntityDestroyer) or not _DestroyedEntity or not valid(_DestroyedEntity) then
        mission.Log(methodName, "Destroyed entity / destroyer entity is null - returning.")
        return
    end

    if insideBarrierOK and (_DestroyedEntity.type == EntityType.Ship or _DestroyedEntity.type == EntityType.Station) and (_EntityDestroyer.type == EntityType.Ship or _EntityDestroyer.type == EntityType.Station) then
        mission.Log(methodName, "Both destroyer / destroyed were ships / stations - checking faction indexes.")
        local _dfindex = _EntityDestroyer.factionIndex -- "destroyer faction" index
        local _xfindex = Xsotan.getFaction().index -- xsotan faction index
        local _player = Player()
        local _pindex = _player.index

        if _DestroyedEntity.factionIndex == _xfindex and (_dfindex == _pindex or (_player.allianceIndex and _dfindex == _player.allianceIndex)) then
            mission.data.custom.killedTargets = mission.data.custom.killedTargets + 1
            mission.data.description[3].arguments.killedTargets = mission.data.custom.killedTargets
            sync()
        end
    end
end

--endregion

--region #SERVER CALLS

function collectXsotanBounty_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    if mission.data.custom.dangerLevel >= 8 then
        mission.data.reward.credits = mission.data.reward.credits * 1.2

        if mission.data.custom.killedGuardian then
            mission.data.reward.credits = mission.data.reward.credits * 3
        end

        mission.data.reward.relations = mission.data.reward.relations + 2000
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " This includes a bonus."
    end

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALLS

function collectXsotanBounty_formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    local descriptionTable = {
        "We're looking for an enterprising captain to eliminate some Xsotan. All attempts at communicating with the strange ships have failed, and we cannot allow them to continue to wreak havoc on our trade routes and outlying sectors. ${targets} will be enough for the time being. We'll compensate you for each ship that you manage to take out.",
        "The Xsotan have always been a real pain in our ass, and we're going to do something about it. Our military is otherwise engaged, so we're turning to independent captains to cull this menace. If you see a Xsotan, kill it. We'll pay you for each one that you destroy. You'll get paid once you slaughter ${targets} of them.",
        "Peace be with you Captain. Unfortunately, we cannot say the same for the Xsotan. We're usually willing to tolerate their presence - but their tendency to attack our traders and miners cannot be ignored. When this happens there is a great loss of life, and we cannot allow this to continue. Please remove ${targets} of their ships - we will pay you for each one eliminated."
    }

    return descriptionTable[descriptionType]
end

mission.makeBulletin = function(_Station)
    local methodName = "Make Bulletin"

    local _random = random()
    local _sector = Sector()

    local _X, _Y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)

    local _Description = collectXsotanBounty_formatDescription(_Station)

    local _DangerLevel = _random:getInt(1, 10)
    local _MaxTargets = 22
    local _Difficulty = "Easy"
    local _Targets = _random:getInt(5, _MaxTargets)

    local _BaseReward = 5500
    if _DangerLevel == 10 then
        _Targets = math.min(_Targets + 5, _MaxTargets) --Add a bias towards a higher target count, but don't push it over the maximum.
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * _Targets * Balancing.GetSectorRewardFactor(_sector:getCoordinates())

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Collect Xsotan Bounty",
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/xsotanbounty.lua",
        formatArguments = {targets = tostring(_Targets), reward = createMonetaryString(reward)},
        msg = "Thank you! We'll send your reward when the Xsotan have been destroyed.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/xsotanbounty.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional Xsotan bounty contracts! Abandon your current one or complete it.")
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
            reward = {credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for collecting the Xsotan bounty."},
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            targets = _Targets,
            insideBarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion