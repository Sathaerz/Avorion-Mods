--[[
    Loot and Scoot (Redux)
    NOTES:
        - Only the last transport gives loot.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Complete the 5th LOTW mission + get it off bulletin board
    ROUGH OUTLINE
        - Go to a sector, kill even more transports. Easy enough.
    DANGER LEVEL
        5 - Kill 3 pirate transports before Y escape. Y is 3/5, 2/8 and 1/10
        5 - Only the last transport has loot to prevent abuse.
        ? - A continual wing of 3 standard danger level ESCC pirates will spawn in the background.
        ? - Start spawning a 4th once the 2nd transport has been destroyed.
        10 - The 4th pirate will always spawn from the start, and the pirates refresh 5 seconds faster.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Loot and Scoot (Redux)"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" },
    { text = "..." },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy loot transports - ${_DESTROYED}/3 Destroyed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many loot transports escape - ${_ESCAPED}/${_MAXESCAPED} Escaped", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Good work. We transferred the reward to your account."

local LOTW_Mission_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)

            mission.data.location = _Data_in.location
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .destroyed
                .escaped
                .maxEscaped
                .pirateSpawnTimer
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.destroyed = 0
            mission.data.custom.escaped = 0
            local _MaxEscaped = 3
            if mission.data.custom.dangerLevel >= 8 then
                _MaxEscaped = 2
            elseif mission.data.custom.dangerLevel == 10 then
                _MaxEscaped = 1
            end
            mission.data.custom.maxEscaped = _MaxEscaped
            local _SpawnTimer = 45
            if mission.data.custom.dangerLevel == 10 then
                _SpawnTimer = 35
            end
            mission.data.custom.pirateSpawnTimer = _SpawnTimer

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = {x = mission.data.location.x, y = mission.data.location.y }
            mission.data.description[3].arguments = {x = mission.data.location.x, y = mission.data.location.y } --Not sure if this is needed but eh

            LOTW_Mission_init(_Data_in)
        else
            --Restoring
            LOTW_Mission_init()
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

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    lotwSide2_setLastMissionTime()
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { _DESTROYED = mission.data.custom.destroyed }
    mission.data.description[5].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    lotwSide2_spawnBackgroundPirates()
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")
    if Entity(_ID):getValue("_lotw_side2_objective") then
        mission.Log(_MethodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
        mission.data.description[4].arguments = { _DESTROYED = mission.data.custom.destroyed }

        mission.Log(_MethodName, "Number of freighters destroyed " .. tostring(mission.data.custom.destroyed))
        sync()
    end
end

--region #PHASE 2 TIMERS

if onServer() then

--Timer 1 = spawn background pirates
mission.phases[2].timers[1] = {
    time = mission.data.custom.pirateSpawnTimer or 45,
    callback = function()
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        if _X == mission.data.location.x and _Y == mission.data.location.y then
            lotwSide2_spawnBackgroundPirates()
        end
    end,
    repeating = true
}
--Timer 2 = spawn loot goons
mission.phases[2].timers[2] = {
    time = 90,
    callback = function()
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        if _X == mission.data.location.x and _Y == mission.data.location.y then
            lotwSide2_spawnPirateFreighter()
        end
    end,
    repeating = true
}
--Timer 3 = soft fail timer
mission.phases[2].timers[3] = {
    time = 90, 
    callback = function() 
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        if _X ~= mission.data.location.x or _Y ~= mission.data.location.y then
            mission.data.custom.escaped = mission.data.custom.escaped + 1
            mission.data.description[5].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
            sync()
        end
    end,
    repeating = true
}
--Timer 4 = advancement / objective timer
mission.phases[2].timers[4] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 1 Timer 4 Callback"
        mission.Log(_MethodName, "Beginning...")
        mission.Log(_MethodName, "Number of freighters destroyed " .. tostring(mission.data.custom.destroyed))
        if mission.data.custom.destroyed >= 3 then
            ESCCUtil.allPiratesDepart()
            lotwSide2_finishAndReward()
        end
        if mission.data.custom.escaped >= mission.data.custom.maxEscaped then
            ESCCUtil.allPiratesDepart()
            lotwSide2_setLastMissionTime()
            fail()
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function lotwSide2_spawnBackgroundPirates()
    local _MethodName = "Spawn Background Pirates"
    mission.Log(_MethodName, "Beginning...")

    local _Destroyed = mission.data.custom.destroyed
    local _DangerLevel = mission.data.custom.dangerLevel 

    local _PirateMaxCt = 3
    if _DangerLevel == 10 or _Destroyed == 2 then
        _PirateMaxCt = 4
    end

    local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
    local _PirateCt = #_Pirates

    local _PiratesToSpawn = _PirateMaxCt - _PirateCt
    
    if _PiratesToSpawn > 0 then
        local _SpawnTable = ESCCUtil.getStandardWave(_DangerLevel, _PiratesToSpawn, "Standard")

        local generator = AsyncPirateGenerator(nil, lotwSide2_onBackgroundPiratesFinished)

        generator:startBatch()
    
        local posCounter = 1
        local distance = 100
        local pirate_positions = generator:getStandardPositions(#_SpawnTable, distance)
        for _, p in pairs(_SpawnTable) do
            generator:createScaledPirateByName(p, pirate_positions[posCounter])
            posCounter = posCounter + 1
        end
    
        generator:endBatch()
    end
end

function lotwSide2_onBackgroundPiratesFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)
end

function lotwSide2_spawnPirateFreighter()
    --Check to see if there's an existing freighter.
    local _Freighters = {Sector():getEntitiesByScriptValue("_lotw_side2_objective")}
    --If there is, delete it and increment the escaped counter.
    --Freighters will handle their own escape once shot.
    if #_Freighters > 0 then
        for _, _F in pairs(_Freighters) do
            _F:addScriptOnce("deletejumped.lua", 2)
            lotwSide2_freighterEscaped()
        end
    end
    --Spawn a new freighter.
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _ShipGenerator = AsyncShipGenerator(nil, lotwSide2_onPirateFreighterFinished)
    local _PirateGenerator = AsyncPirateGenerator(nil, nil)
    local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * 3
    local _Faction = _PirateGenerator:getPirateFaction()

    _ShipGenerator:startBatch()
    
    _ShipGenerator:createFreighterShip(_Faction, _ShipGenerator:getGenericPosition(), _Vol1)

    _ShipGenerator:endBatch()
end

function lotwSide2_onPirateFreighterFinished(_Generated)
    for _, _Ship in pairs(_Generated) do
        _Ship:setTitle("${toughness}${title}", {toughness = "", title = "Pirate Loot Transporter"})

        _Ship:setValue("_lotw_side2_objective", true)
        _Ship:setValue("is_pirate", true)
        _Ship:setValue("is_civil", nil)
        _Ship:setValue("is_freighter", nil)
        _Ship:setValue("npc_chatter", nil)

        _Ship:removeScript("civilship.lua")
        _Ship:removeScript("dialogs/storyhints.lua")

        local _AddLoot = true

        if mission.data.custom.destroyed < 2 then
            _Ship:setValue("_lotw_no_loot_drop", true)
            _AddLoot = false
        end

        _Ship:addScriptOnce("player/missions/lotw/mission3/lotwfreighterm3.lua", _AddLoot, false, true, mission.data.custom.dangerLevel)

        local _ShipAI = ShipAI(_Ship)
        local _Position = _Ship.position
        _ShipAI:setFlyLinear(_Position.look * 20000, 0)
        _ShipAI:setPassiveShooting(true)
    end
end

function lotwSide2_freighterEscaped()
    mission.data.custom.escaped = mission.data.custom.escaped + 1
    mission.data.description[5].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
    sync()
end

function lotwSide2_setLastMissionTime()
    local runTime = Server().unpausedRuntime
    Player():setValue("_lotw_last_side2", runTime) 
end

function lotwSide2_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    lotwSide2_setLastMissionTime()

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALL

function lotwSide2_formatDescription(_Station)
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
        _FinalDescription = "We've noticed an increase in the amount of pirate movement in the local sectors. That's usually a good indication that they're moving systems and weapons around. We'd like to hire you to take them out. They are located in sector (${x}:${y}). Obviously you'll be well paid for your efforts, and you're welcome to keep the hardware - we just don't want them using it against us."
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "Pirates have been moving weapons and systems through our territory more frequently as of late. It is an inconvenience at best, but one that we'd rather not suffer if we don't have to. That's where you come in. They are operating in sector (${x}:${y}). Kill them. The spoils are yours for the taking."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "Our spies have picked up a group of loot transports moving through nearby sectors. We have a limited military capacity and cannot afford to use it on dealing with this threat. Please help us deal with the intrusion in sector (${x}:${y}). You may keep anything you find while undertaking the operation."
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local _Rgen = ESCCUtil.getRand()
    local _Sector = Sector()
    local target = {}
    --GET TARGET HERE:
    local x, y = _Sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 6, 12, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)

    local _Difficulty = "Easy"
    if _DangerLevel >= 6 then
        _Difficulty = "Medium"
    end
    if _DangerLevel >= 9 then
        _Difficulty = "Difficult"
    end
    
    local _Description = lotwSide2_formatDescription(_Station)

    local _DangerCash = 25000
    if _DangerLevel >= 5 then
        _DangerCash = 27500
    elseif _DangerLevel == 10 then
        _DangerCash = 30000
    end

    reward = 100000 + (_DangerCash * Balancing.GetSectorRewardFactor(_Sector:getCoordinates())) --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/lotw/lotwside2.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The pirates are operating in sector \\s(%1%:%2%). Please destroy them.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if not player:getValue("_lotw_story_complete") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission.")
                return 0
            end
            if player:hasScript("lotwside2.lua") then
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
            giver = _Station.index,
            location = target,
            reward = {credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for destroying the pirate freighters."},
            initialDesc = _Description,
            dangerLevel = _DangerLevel
        }},
    }

    return bulletin
end

--endregion