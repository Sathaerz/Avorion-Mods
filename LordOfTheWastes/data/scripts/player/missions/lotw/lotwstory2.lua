--[[
    Junkyard Dogs
    NOTES:
        - Keep track of how many transports the player has killed. Only give them loot the first time they kill each transport.
        - Give them good loot - lots of ore.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Have completed the first LOTW mission.
    ROUGH OUTLINE
        - Go to a sector, kill transports. Easy enough.
    DANGER LEVEL
        5 - Kill X pirate transports before Y escape. Gets easier if the player fucks it up.
        5 - A continual wing of 2 bandits and 1 pirate will spawn in the background.
        5 - Start spawning a marauder once the 2nd transport has been destroyed.
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

mission._Debug = 1
mission._Name = "Junkyard Dogs"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You received the following request from ${factionName}:" },
    { text = "The previous operation served as an adequate warning shot, but we need to take things a step further. Hitting their supply chain will provoke them to take further action to cover their losses. We've found a convoy running through (${location.x}:${location.y}) and we'd like you to take it out. You're welcome to keep anything you find in the cargo ships. Don't let too many escape. That defeats the entire point of the op." },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "(Recommended) Make sure your ship has at least 750 cargo space", bulletPoint = true, fulfilled = false },
    { text = "Destroy cargo ships - ${_DESTROYED}/3 Destroyed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many cargo ships escape - ${_ESCAPED}/${_MAXESCAPED} Escaped", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Meet the liason in sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Good work. We transferred the reward to your account. Be on the lookout for more opportunities in the future."

local LOTW_Mission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()

    if onServer() and not _restoring then
        local _Player = Player()
        local _FailureCt =_Player:getValue("_lotw_mission2_failures") or 0

        --[[=====================================================
            CUSTOM MISSION DATA SETUP:
        =========================================================]]
        mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
        mission.data.custom.destroyed = 0
        mission.data.custom.escaped = 0
        mission.data.custom.maxEscaped = 3 + (_FailureCt * 2)
        mission.data.custom.friendlyFaction = _Player:getValue("_lotw_faction")
        mission.data.custom.piratesSpawned = 0
        mission.data.custom.fulfilledCargoObjective = false --just so we avoid syncing every second.

        local missionReward = 100000

        missionData_in = {location = nil, reward = {credits = missionReward, relations = 12000, paymentMessage = "Earned %1% credits for destroying the pirate freighters."}}
    end

    LOTW_Mission_init(missionData_in)

    if onServer() and not _restoring then
        setMissionFactionData(_X, _Y) --Have to be sneaky about this. Normaly this SHOULD be set by the init function, but since it's not from a station it will get funky.
    end
end

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onFail = function()
    local _Player = Player()
    local _FailureCt =_Player:getValue("_lotw_mission2_failures") or 0
    _FailureCt = _FailureCt + 1
    _Player:setValue("_lotw_mission2_failures", _FailureCt)
end

mission.globalPhase.updateServer = function()
    local methodName = "Global Phase Update Server"

    if not mission.data.custom.fulfilledCargoObjective then --no need to check if we have fulfilled it
        mission.Log(methodName, "Checking cargo objective")

        --You can do this on any phase. You probably should do it on phase 1, buuuuut...
        local _player = Player()
        local craft = _player.craft
        if not craft then
            return
        end

        if craft.freeCargoSpace and craft.freeCargoSpace >= 750 then
            mission.data.description[4].fulfilled = true
            mission.data.custom.fulfilledCargoObjective = true

            sync()
        end
    end
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    local _Faction = Faction(mission.data.custom.friendlyFaction) --The phase is already set to 1 by the time we hit this, so it has to be done it this way.

    mission.data.location = getNextLocation()

    mission.data.custom.prx = mission.data.location.x --prx = prerender x
    mission.data.custom.pry = mission.data.location.y --pry = prerender y

    mission.data.description[1].arguments = { factionName = _Faction.name }
    mission.data.description[2].arguments = { x = mission.data.location.x, y = mission.data.location.y }
    mission.data.description[3].arguments = { x = mission.data.location.x, y = mission.data.location.y }
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed }
    mission.data.description[6].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true

    spawnBackgroundPirates()
end

mission.phases[2].onPreRenderHud = function()
    local x, y = Sector():getCoordinates()
    if x == mission.data.custom.prx and y == mission.data.custom.pry then
        onMarkDroppedOres()
    end
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")
    if Entity(_ID):getValue("_lotw_mission2_objective") then
        mission.Log(_MethodName, "Was an objective.")
        local _Player = Player()
        local _FreightersDestroyed = _Player:getValue("_lotw_mission2_freighterskilled") or 0
        _FreightersDestroyed = _FreightersDestroyed + 1
        _Player:setValue("_lotw_mission2_freighterskilled", _FreightersDestroyed)

        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
        mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed }

        mission.Log(_MethodName, "Number of freighters destroyed " .. tostring(mission.data.custom.destroyed))
        sync()
    end
end

--region #PHASE 2 TIMERS

if onServer() then

--Timer 1 = spawn background pirates
mission.phases[2].timers[1] = {
    time = 45,
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
            mission.data.description[6].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
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
            ESCCUtil.allPiratesDepart()
            fail()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[3] = {}
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[4].fulfilled = true --Doesn't matter anymore - either the player did it or they didn't.
    mission.data.description[5].fulfilled = true
    mission.data.description[6].fulfilled = true

    mission.data.location = getNextLocation()
    mission.data.description[7].arguments = { x = mission.data.location.x, y = mission.data.location.y }

    mission.data.description[7].visible = true

    local _Faction = Faction(mission.data.custom.friendlyFaction)
    Player():sendChatMessage(_Faction.name, 0, "We have a liason waiting for you in sector \\s(%1%:%2%). Please contact them there.", mission.data.location.x, mission.data.location.y)
end

mission.phases[3].onPreRenderHud = function()
    local x, y = Sector():getCoordinates()
    if x == mission.data.custom.prx and y == mission.data.custom.pry then
        --We don't want the markers going away just because the player beat the phase.
        onMarkDroppedOres()
    end
end

mission.phases[3].onTargetLocationArrivalConfirmed = function(x, y)
    spawnLiason()
end

--endregion

--region #SERVER CALLS

function setMissionFactionData(_X, _Y)
    local _MethodName = "Set Mission Faction Data"
    mission.Log(_MethodName, "Beginning...")
    --We're going to have to do some sneaky stuff w/ credits here.
    local _Faction = Faction(Player():getValue("_lotw_faction"))
    mission.data.giver = {}
    mission.data.giver.id = _Faction.index
    mission.data.giver.factionIndex = _Faction.index
    mission.data.giver.coordinates = { x = _X, y = _Y }
    mission.data.giver.baseTitle = _Faction.name
end

function getNextLocation()
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 10, false)

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
    
    local _BanditMaxCt = 2
    local _PirateMaxCt = 1
    local _MarauderMaxCt = 0
    if _Destroyed == 2 then
        _MarauderMaxCt = 1
    end

    local _BanditCt = 0
    local _PirateCt = 0
    local _MarauderCt = 0

    local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
    mission.Log(_MethodName, "Counting pirates " .. tostring(#_Pirates) .. " found")
    for _, _Pirate in pairs (_Pirates) do
        local _TArgs = _Pirate:getTitleArguments()
        for _, _TArg in pairs(_TArgs) do
            local _Title = _TArg
            if _Title == "Bandit" then
                mission.Log(_MethodName, "Bandit")
                _BanditCt = _BanditCt + 1
            end
            if _Title == "Pirate" then
                mission.Log(_MethodName, "Pirate")
                _PirateCt = _PirateCt + 1
            end
            if _Title == "Marauder" then
                mission.Log(_MethodName, "Marauder")
                _MarauderCt = _MarauderCt + 1
            end
        end
    end

    local _SpawnTable = {}
    if _BanditCt < _BanditMaxCt then
        local _SpawnCt = _BanditMaxCt - _BanditCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Bandit")
        end
    end
    if _PirateCt < _PirateMaxCt then
        local _SpawnCt = _PirateMaxCt - _PirateCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Pirate")
        end
    end
    if _MarauderCt < _MarauderMaxCt then
        local _SpawnCt = _MarauderMaxCt - _MarauderCt
        for _ = 1, _SpawnCt, 1 do
            table.insert(_SpawnTable, "Marauder")
        end
    end

    local generator = AsyncPirateGenerator(nil, onBackgroundPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    local pirate_positions = generator:getStandardPositions(#_SpawnTable, distance)
    for _, p in pairs(_SpawnTable) do
        mission.data.custom.piratesSpawned = mission.data.custom.piratesSpawned + 1
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onBackgroundPiratesFinished(_Generated)
    for _, _Pirate in pairs(_Generated) do
        if mission.data.custom.piratesSpawned > 10 then
            _Pirate:setDropsLoot(false)
        end
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function spawnPirateFreighter()
    --Check to see if there's an existing freighter.
    local _Freighters = {Sector():getEntitiesByScriptValue("_lotw_mission2_objective")}
    --If there is, delete it and increment the escaped counter.
    --Freighters will handle their own escape once shot.
    if #_Freighters > 0 then
        for _, _F in pairs(_Freighters) do
            _F:addScriptOnce("deletejumped.lua", 2)
            freighterEscaped()
        end
    end
    --Spawn a new freighter.
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _ShipGenerator = AsyncShipGenerator(nil, onPirateFreighterFinished)
    local _PirateGenerator = AsyncPirateGenerator(nil, nil)
    local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * 3
    local _Faction = _PirateGenerator:getPirateFaction()

    _ShipGenerator:startBatch()
    
    _ShipGenerator:createFreighterShip(_Faction, _ShipGenerator:getGenericPosition(), _Vol1)

    _ShipGenerator:endBatch()
end

function onPirateFreighterFinished(_Generated)
    local _Player = Player()
    local _FreightersDestroyed = _Player:getValue("_lotw_mission2_freighterskilled") or 0

    for _, _Ship in pairs(_Generated) do
        _Ship:setValue("_lotw_mission2_objective", true)
        _Ship:setValue("is_pirate", true)
        _Ship:setValue("is_civil", nil)
        _Ship:setValue("is_freighter", nil)
        _Ship:setValue("npc_chatter", nil)

        _Ship:removeScript("civilship.lua")
        _Ship:removeScript("dialogs/storyhints.lua")

        _Ship:addScriptOnce("player/missions/lotw/mission2/lotwfreighterm2.lua")

        local _Good = goods["Titanium Ore"]
        if _FreightersDestroyed <= 2 then
            _Ship:addAbsoluteBias(StatsBonuses.CargoHold, 10000)
            _Ship:addCargo(_Good:good(), 10000)
        else
            _Ship:setValue("_lotw_no_loot_drop", true)
        end

        local _ShipAI = ShipAI(_Ship)
        local _Position = _Ship.position
        _ShipAI:setFlyLinear(_Position.look * 10000, 0)
        _ShipAI:setPassiveShooting(true)
    end
end

function freighterEscaped()
    mission.data.custom.escaped = mission.data.custom.escaped + 1
    mission.data.description[6].arguments = { _ESCAPED = mission.data.custom.escaped, _MAXESCAPED = mission.data.custom.maxEscaped }
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
        _Ship:addScriptOnce("player/missions/lotw/mission2/lotwliasonm2.lua")
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

    local _Player = Player()
    _Player:setValue("_lotw_story_stage", 3)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onMarkDroppedOres()
    local methodName = "On Mark Dropped Ores"

    local _player = Player()
    if not _player then
        return
    end
    if _player.state == PlayerStateType.BuildCraft or _player.state == PlayerStateType.BuildTurret or _player.state == PlayerStateType.PhotoMode then
        return
    end

    local _sector = Sector()
    local renderer = UIRenderer()
    local color = Material(MaterialType.Titanium).color

    for _, entity in pairs({_sector:getEntitiesByComponent(ComponentType.CargoLoot)}) do
        local loot = CargoLoot(entity)
        if valid(entity) and loot:matches("Titanium Ore") then
            local indicator = TargetIndicator(entity)
            indicator.visuals = TargetIndicatorVisuals.Tilted
            indicator.color = color
            renderer:renderTargetIndicator(indicator);
        end
    end

    renderer:display()
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