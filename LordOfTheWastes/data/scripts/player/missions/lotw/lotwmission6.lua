--[[
    Junkyard Dogs (Redux)
    NOTES:
        - Only the last transport gives loot. Make it a lil bigger than the story one tho.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Complete the 5th LOTW mission + get it off bulletin board
    ROUGH OUTLINE
        - Go to a sector, kill transports. Easy enough.
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
include("goodsindex")

ESCCUtil = include("esccutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Junkyard Dogs (Redux)"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" },
    { text = "..." },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy cargo ships - ${_DESTROYED}/3 Destroyed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many cargo ships escape - ${_ESCAPED}/${_MAXESCAPED} Escaped", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Meet the liason in sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false, visible = false }
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
                .friendlyFaction
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
            mission.data.custom.friendlyFaction = _Giver.factionIndex
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

mission.phases[1] = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].noPlayerEventsTargetSector = true
mission.phases[1].noLocalPlayerEventsTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}

--region #PHASE 2 TIMERS

if onServer() then

--Timer 1 = spawn background pirates
mission.phases[2].timers[1] = {
    time = mission.data.custom.pirateSpawnTimer or 45,
    callback = function()
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        if _X == mission.data.location.x and _Y == mission.data.location.y then
            spawnBackgroundPirates()
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
            spawnPirateFreighter()
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
            nextPhase()
        end
        if mission.data.custom.escaped >= mission.data.custom.maxEscaped then
            fail()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].noPlayerEventsTargetSector = true
mission.phases[2].noLocalPlayerEventsTargetSector = true
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { _DESTROYED = mission.data.custom.destroyed }
    mission.data.description[5].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    spawnBackgroundPirates()
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")
    if Entity(_ID):getValue("_lotw_mission6_objective") then
        mission.Log(_MethodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
        mission.data.description[4].arguments = { _DESTROYED = mission.data.custom.destroyed }

        mission.Log(_MethodName, "Number of freighters destroyed " .. tostring(mission.data.custom.destroyed))
        sync()
    end
end

mission.phases[3] = {}
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].noPlayerEventsTargetSector = true
mission.phases[3].noLocalPlayerEventsTargetSector = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[4].fulfilled = true
    mission.data.description[5].fulfilled = true

    mission.data.location = getNextLocation()
    mission.data.description[6].arguments = { x = mission.data.location.x, y = mission.data.location.y }

    mission.data.description[6].visible = true

    local _Faction = Faction(mission.data.custom.friendlyFaction)
    Player():sendChatMessage(_Faction.name, 0, "We have a liason waiting for you in sector \\s(%1%:%2%). Please contact them there.", mission.data.location.x, mission.data.location.y)
end

mission.phases[3].onTargetLocationEntered = function(x, y)
    spawnLiason()
end

--endregion

--region #SERVER CALLS

function getNextLocation()
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, false)

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function spawnBackgroundPirates()
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

        local generator = AsyncPirateGenerator(nil, onBackgroundPiratesFinished)

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

function onBackgroundPiratesFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)
end

function spawnPirateFreighter()
    --Check to see if there's an existing freighter.
    local _Freighters = {Sector():getEntitiesByScriptValue("_lotw_mission2_objective")}
    --If there is, delete it and increment the escaped counter.
    --Freighters will handle their own escape once shot.
    if #_Freighters > 0 then
        for _, _F in pairs(_Freighters) do
            _F:addScriptOnce("deletejumped.lua")
            freighterEscaped()
        end
    end
    --Spawn a new freighter.
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _ShipGenerator = AsyncShipGenerator(nil, onPirateFreighterFinished)
    local _PirateGenerator = AsyncPirateGenerator(nil, nil)
    local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * 3.5
    local _Faction = _PirateGenerator:getPirateFaction()

    _ShipGenerator:startBatch()
    
    _ShipGenerator:createFreighterShip(_Faction, _ShipGenerator:getGenericPosition(), _Vol1)

    _ShipGenerator:endBatch()
end

function onPirateFreighterFinished(_Generated)
    for _, _Ship in pairs(_Generated) do
        _Ship:setValue("_lotw_mission6_objective", true)
        _Ship:setValue("is_pirate", true)
        _Ship:setValue("is_civil", nil)
        _Ship:setValue("is_freighter", nil)
        _Ship:setValue("npc_chatter", nil)

        _Ship:removeScript("civilship.lua")
        _Ship:removeScript("dialogs/storyhints.lua")

        _Ship:addScriptOnce("player/missions/lotw/mission2/lotwfreighterm2.lua")

        local _Good = goods["Titanium Ore"]
        if mission.data.custom.destroyed < 2 then
            _Ship:setValue("_lotw_no_loot_drop", true)
        else
            _Ship:addCargo(_Good:good(), 10000)
        end

        MissionUT.deleteOnPlayersLeft(_Ship)

        local _ShipAI = ShipAI(_Ship)
        local _Position = _Ship.position
        _ShipAI:setFlyLinear(_Position.look * 10000, 0)
    end
end

function freighterEscaped()
    mission.data.custom.escaped = mission.data.custom.escaped + 1
    mission.data.description[5].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
    sync()
end

function spawnLiason()
    local _MethodName = "Spawn Relief Defenders"
    mission.Log(_MethodName, "Beginning...")
    --Spawn background corvettes.
    local shipGenerator = AsyncShipGenerator(nil, onFactionShipsFinished)
    local faction = Faction(mission.data.custom.friendlyFaction)

    if not faction or faction.isPlayer or faction.isAlliance then
        print("ERROR - COULD NOT FIND MISSION FACTION")
        terminate()
        return
    end

    shipGenerator:startBatch()

    shipGenerator:createDefender(faction, shipGenerator:getGenericPosition())
    shipGenerator:createDefender(faction, shipGenerator:getGenericPosition())

    shipGenerator:endBatch()

    local liasonGenerator = AsyncShipGenerator(nil, onLiasonShipFinished)

    liasonGenerator:startBatch()

    liasonGenerator:createDefender(faction, liasonGenerator:getGenericPosition())

    liasonGenerator:endBatch()
end

function onLiasonShipFinished(_Generated)
    for _, _Ship in pairs(_Generated) do
        local _Faction = Faction(_Ship.factionIndex)
        local _ShipAI = ShipAI(_Ship)

        MissionUT.deleteOnPlayersLeft(_Ship)
        _Ship:removeScript("patrol.lua")
        _Ship:removeScript("antismuggle.lua")
        _Ship:addScriptOnce("player/missions/lotw/mission6/lotwliasonm6.lua")
        _ShipAI:setIdle()

        _Ship.title = tostring(_Faction.name) .. " Military Liason"
    end
end

function onFactionShipsFinished(_Generated)
    for _, _Ship in pairs(_Generated) do
        _Ship:removeScript("antismuggle.lua") --Need to get in the habit of doing this b/c the player may have stolen shit.
        MissionUT.deleteOnPlayersLeft(_Ship)
    end  
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #CLIENT / SERVER CALLS

function contactedLiason()
    local _MethodName = "Contacted Liason"

    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("contactedLiason")
    else
        mission.Log(_MethodName, "Calling on Server")

        --Get the player's current ship and unsteal all ore goods in it.
        local _PlayerShip = Entity(Player().craft.id)
        for _Good, _Amount in pairs(_PlayerShip:getCargos()) do
            if (string.find(_Good.name, "Ore") or string.find(_Good.name, "ore")) and _Good.stolen then
                local _Purified = copy(_Good)
                _Purified.stolen = false
                _PlayerShip:removeCargo(_Good, _Amount)
                _PlayerShip:addCargo(_Purified, _Amount)
            end
        end

        finishAndReward()
    end
end
callable(nil, "contactedLiason")

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
        _FinalDescription = "Our intel division has once again detected a squadron of pirate transports moving through our territory. We'll pay you handsomely to take them out, as always. Let us know if you're interested in this opportunity. You'll find them in sector (${x}:${y})."
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "Some pirate scum thinks they can pull one over on us and move some transports through our territory. We would normally deal with this insolence ourselves, but our military is engaged elsewhere and destroying them would spread us too thin. Get to sector (${x}:${y}) and kill all of them."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "We've heard rumors of a caravan of pirate transports moving through our territory. We cannot muster an adequate military response for this, and so we're turning to independent captains for help. Please neutralize the convoy in sector (${x}:${y}). You will be rewarded for doing so."
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
    
    local _Description = formatDescription(_Station)

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
        difficulty = "Medium",
        reward = "¢${reward}",
        script = "missions/lotw/lotwmission6.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The pirates are operating in sector \\s(%1%:%2%). Please destroy them.",
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
            reward = {credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for destroying the pirate freighters."},
            initialDesc = _Description,
            dangerLevel = _DangerLevel
        }},
    }

    return bulletin
end

--endregion