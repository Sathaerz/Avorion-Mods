package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include ("randomext")
include ("faction")

local Balancing = include("galaxy")
local Xsotan = include("story/xsotan")

mission._Debug = 0
mission._Name = "Collect Xsotan Bounty"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "${killedTargets} / ${targets} targets killed", bulletPoint = true, fulfilled = false },
}

mission.data.accomplishMessage = "Thank you for fulfilling the bounty contract. We transferred the reward to your account."

local XsotanBounty_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

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

        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { targets = tostring(mission.data.custom.targets) }
        mission.data.description[3].arguments = { targets = tostring(mission.data.custom.targets), killedTargets = "0" }
    end

    XsotanBounty_init(_Data_in)
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

    if (_DestroyedEntity.type == EntityType.Ship or _DestroyedEntity.type == EntityType.Station) and (_EntityDestroyer.type == EntityType.Ship or _EntityDestroyer.type == EntityType.Station) then
        mission.Log(_MethodName, "Both destroyer / destroyed were ships / stations - checking faction indexes.")
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

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALLS

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
        _FinalDescription = "We're looking for an enterprising captain to eliminate some Xsotan. All attempts at communicating with the strange ships have failed, and we cannot allow them to continue to wreak havoc on our trade routes and outlying sectors. ${targets} will be enough for the time being. We'll compensate you for each ship that you manage to take out."
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "The Xsotan have always been a real pain in our ass, and we're going to do something about it. Our military is otherwise engaged, so we're turning to independent captains to cull this menace. If you see a Xsotan, kill it. We'll pay you for each one that you destroy. You'll get paid once you slaughter ${targets} of them."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "Peace be with you captain. Unfortunately, we cannot say the same for the Xsotan. We're usually willing to tolerate their presence - but their tendency to attack our traders and miners cannot be ignored. When this happens there is a great loss of life, and we cannot allow this to continue. Please remove ${targets} of their ships - we will pay you for each one eliminated."
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"

    local _Rgen = random()
    local _X, _Y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)

    local _Description = formatDescription(_Station)

    local _DangerLevel = _Rgen:getInt(1, 10)
    --local _DangerLevel = 10
    local _MaxTargets = 22
    local _Difficulty = "Easy"
    local _Targets = _Rgen:getInt(5, _MaxTargets)

    local _BaseReward = 5500
    if _DangerLevel == 10 then
        _Targets = math.min(_Targets + 5, _MaxTargets) --Add a bias towards a higher target count, but don't push it over the maximum.
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * _Targets * Balancing.GetSectorRewardFactor(Sector():getCoordinates())

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
            targets = _Targets
        }},
    }

    return bulletin
end

--endregion