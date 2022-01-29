--[[
    Wrecking Havoc
    NOTES:
        - All of the wrecks in each sector are automatically tagged with "wreckinghavoc_invalidredemption" on initialization of the scrapyard script.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        None
    ROUGH OUTLINE
        - Player gets a half hour to drop off as many wreckages as possible in the scrapyard sector. Doesn't matter where they come from.
        - Reward is based on volume of wreckages dropped in the scrapyard sector.
        - Use Bubbet's suggestion for repair dock code for a reward. (i.e. block plan value)
        - Maybe give the player a free salvage license when they finish too?
    DANGER LEVEL
        N/A - No inherent danger level involved. It is entirely up to the player how they obtain the wreckages.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

mission._Debug = 0
mission._Name = "Wrecking Havoc"
mission._Tag = "wreckinghavoc_invalidredemption"

--region #INIT

--Standard mission data.
mission.data.brief = "Wrecking Havoc"
mission.data.title = "Wrecking Havoc"
mission.data.icon = "data/textures/icons/scrap-metal.png"
mission.data.description = {
    "", --Placeholder
    "", --Placeholder
    { text = "Drop Wreckages off in sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Wreckages dropped off: ${dropped}", bulletPoint = true, fulfilled = false }
}
mission.data.timeLimit = 30 * 60 --Player has 30 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.
--Can't set mission.data.reward.paymentMessage here since we are using a custom init.
mission.data.accomplishMessage = "Thank you for the wreckages. We transferred the reward to your account."

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].sectorCallbacks = {}
mission.phases[1].sectorCallbacks[1] = {
    name = "onEntityUndocked",
    func = function(_DockerID, _DockeeID)
        local _MethodName = "Phase 1 Entity Undocked"
        if onClient() then
            mission.Log(_MethodName, "Not on server - ignore this callback.")
            return
        end

        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        if _X ~= mission.data.location.x or _Y ~= mission.data.location.y then
            mission.Log(_MethodName, "Not in target scrapyard sector - ignore this callback.")
            return
        end
        
        mission.Log(_MethodName, "Entity " .. tostring(_DockeeID) .. " was undocked from " .. tostring(_DockerID))
        local _Entity = Entity(_DockeeID)
        if _Entity.type == EntityType.Wreckage then
            if not _Entity:getValue(mission._Tag) then
                mission.data.custom.wreckagesDropped = mission.data.custom.wreckagesDropped + 1

                mission.Log(_MethodName, "Entity " .. tostring(_DockeeID) .. " is a wreckage and has not yet been redeemed.")
                local _Plan = _Entity:getMovePlan()
                local _Velocity = Velocity(_Entity)

                Sector():deleteEntity(_Entity) --Clean up old entity.
    
                local _PlanValue = getFullShipValue(_Plan)

                local _ActualWreck = _Sector:createWreckage(_Plan, _Entity.position)
                local _WreckVelocity = Velocity(_ActualWreck)
                _ActualWreck:setValue(mission._Tag, true)
                _WreckVelocity:addVelocity(_Velocity.velocityf)

                if _PlanValue > 0 then
                    mission.data.reward.credits = mission.data.reward.credits + _PlanValue
                    mission.data.reward.relations = mission.data.reward.relations + 150
                    mission.Log(_MethodName, "Added value of plan (" .. tostring(_PlanValue) .. ") to reward. Total reward is now : " .. tostring(mission.data.reward.credits) .. " credits for " .. tostring(mission.data.custom.wreckagesDropped) .. " wrecks.")
                    mission.data.reward.paymentMessage = "Earned %1% credits for dropping off " .. tostring(mission.data.custom.wreckagesDropped) .. " wreckages."
                else
                    mission.Log(_MethodName, "Plan value was 0 and was not counted towards total.")
                end
            else
                mission.Log(_MethodName, "Entity " .. tostring(_DockeeID) .. " is a wreckage, but not a valid redemption target.")
            end
        end

        mission.data.description[4].arguments = { dropped = mission.data.custom.wreckagesDropped }
        sync()
    end
}
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    local _Giver = Entity(mission.data.giver.id)
    local _Sector = Sector()

    mission.data.custom.wreckagesDropped = 0

    mission.data.description[1] = "You recieved the following request from the " .. _Sector.name .. " " .. _Giver.translatedTitle .. ":"
    mission.data.description[2] = formatDescription(_Giver)
    mission.data.description[4].arguments = { dropped = mission.data.custom.wreckagesDropped }
    --Tag all wrecks already in the sector that aren't docked to the player ship. We actually do need to do this here in case the player doesn't have the other mod.
    
    local _Ships = {_Sector:getEntitiesByType(EntityType.Ship)}
    local _Wrecks = {_Sector:getEntitiesByType(EntityType.Wreckage)}

    mission.Log(_MethodName, "Tagging all wrecks except for docked wreckages.")
    local _DockedWreckIDs = {}
    for _, _Ship in pairs(_Ships) do
        --Get clamps of ships that don't belong to the scrapyard.
        if _Ship.factionIndex ~= _Giver.factionIndex then
            local _Clamps = DockingClamps(_Ship)
            if _Clamps then
                --Get docked entities in clamps
                local _DockedEntities = {_Clamps:getDockedEntities()}
                --Don't bother checking if there are 0 docked entities.
                if #_DockedEntities > 0 then
                    for _, _DockedID in pairs(_DockedEntities) do
                        if Entity(_DockedID).type == EntityType.Wreckage then
                            _DockedWreckIDs[tostring(_DockedID)] = true
                        end
                    end
                end
            end
        end
    end

    for _, _Wreck in pairs(_Wrecks) do
        local _WreckIndex = tostring(_Wreck.id)
        local _Wreck = Entity(_Wreck.id)
        if not _DockedWreckIDs[_WreckIndex] or not _Wreck:hasComponent(ComponentType.MoneyDropper) then
            _Wreck:setValue(mission._Tag, true)
        end
    end

    mission.internals.fulfilled = true --This mission will succeed at the end, and not fail. The only question is how much money the player gets.
end
mission.phases[1].onAccomplish = function()
    --The mission only accomplishes when the time runs out and doesn't reward
    reward()
end

--endregion

--region #SERVER CALLS

function getFullShipValue(_Plan)
    local _PlanValue = _Plan:getMoneyValue()
    local _ResValue = {_Plan:getResourceValue()}

    for _MAT, _VAL in pairs(_ResValue) do
        _PlanValue = _PlanValue + (Material(_MAT - 1).costFactor * _VAL * 10)
    end

    --Return the full value. We'll use it or modify it accordingly elsewhere.
    return _PlanValue
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
        _FinalDescription = "To any enterprising captains out there, we're running shorter on wrecakges than we'd like. That's where you come in. We're willing to pay a premium for any extra wreckages you can deliver to this sector. No need for anything fancy when you drop the wrecks off. Just undock them in this sector and we'll keep count of them for you. Good luck!"
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "We are looking for additional wreckages to be dropped off in this scrapyard. Obviously, we are capable of destroying pirates and Xsotan ourselves, but they've learned to fear us and we're unable to hunt down as many as we'd like. That is where you come in. We want you to destroy ships and drop off their wreckages here for our use. Of course, you'll be rewarded. Get to it."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "We need additional wreckages! Our salvaging operations can't keep up with the demand and our military isn't powerful enough to destroy all of the pirate and Xsotan ships that we'd need. We're willing to pay you to bring extra wreckages to this sector. Just drop them off and we'll take care of everything else! Thank you so much for your time!"
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local target = {}
    target.x, target.y = Sector():getCoordinates()

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end
    
    local _Description = formatDescription(_Station)

    reward = 0

    local bulletin =
    {
        -- data for the bulletin board
        brief = "Wrecking Havoc",
        description = _Description,
        difficulty = "Variable", --Depends on how you get the wreckages.
        reward = "Variable",
        script = "missions/wreckinghavoc.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you for your patronage! We'll pay you based on how many wreckages you can bring back to us.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/wreckinghavoc.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional salvage contracts! Abandon your current one or complete it.")
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
            giver = _Station.index,
            location = target,
            reward = {credits = reward, relations = 0},
            description = _Description
        }},
    }

    return bulletin
end

--endregion