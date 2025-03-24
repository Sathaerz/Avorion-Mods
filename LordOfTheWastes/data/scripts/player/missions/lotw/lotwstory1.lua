--[[
    Disrupt Pirate Attack
    NOTES:
        - First, easy mission for LOTW
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Take it off the mission board. It should be persistent like the black market mission.
    ROUGH OUTLINE
        - Go to a sector.
        - Pirates are there.
        - Kill them all. Very simple and straightforward.
    DANGER LEVEL
        5 - Kill 3 waves of 4 pirates each. Use weenie ships and add 1 raider in the final wave.
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
mission._Name = "Disrupt Pirate Attack"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy the first wave of pirates.", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the second wave of pirates.", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the third wave of pirates.", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Meet the liason in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }
}
--Can't set mission.data.reward.paymentMessage here since we are using a custom init.
mission.data.accomplishMessage = "Good work. We transferred the reward to your account. Be on the lookout for more opportunities in the future."

local LOTW_Mission_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .friendlyFaction
                .firstWaveTaunt
                .waveCounter
                .firstTimerAdvance
                .secondTimerAdvance
                .thirdTimerAdvance
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.friendlyFaction = _Giver.factionIndex

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = {x = _X, y = _Y, enemyName = mission.data.custom.enemyName }
            mission.data.description[3].arguments = { _X = _Y, _Y = _Y }

            --Run standard initialization
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

mission.globalPhase.noBossEncountersTargetSector = true --Probably going to happen anyways due to the distance from the core, but no sense in taking chances.
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    showMissionUpdated(mission._Name)
    spawnPirateWave(false, 1)
end

mission.phases[1].onSectorArrivalConfirmed = function(x, y)
    pirateTaunt()
end

--region #PHASE 1 TIMERS

if onServer() then

mission.phases[1].timers[1] = {
    time = 10, 
    callback = function() 
        local _MethodName = "Phase 1 Timer 1 Callback"
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}
        mission.Log(_MethodName, "Number of pirates : " .. tostring(#_Pirates) .. " timer allowed to advance : " .. tostring(mission.data.custom.firstTimerAdvance))
        if _X == mission.data.location.x and _Y == mission.data.location.y and mission.data.custom.firstTimerAdvance and #_Pirates == 0 then
            nextPhase()
        end
    end,
    repeating = true}

end

--endregion

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnStart = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true

    spawnPirateWave(false, 2)
end

--region #PHASE 2 TIMERS

if onServer() then
   
mission.phases[2].timers[1] = {
    time = 10, 
    callback = function() 
        local _MethodName = "Phase 2 Timer 1 Callback"
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}
        mission.Log(_MethodName, "Number of pirates : " .. tostring(#_Pirates) .. " timer allowed to advance : " .. tostring(mission.data.custom.secondTimerAdvance))
        if _X == mission.data.location.x and _Y == mission.data.location.y and mission.data.custom.secondTimerAdvance and #_Pirates == 0 then
            nextPhase()
        end
    end,
    repeating = true}

end

--endregion

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnStart = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true

    spawnPirateWave(true, 3)
end

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 10, 
    callback = function() 
        local _MethodName = "Phase 3 Timer 1 Callback"
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}
        mission.Log(_MethodName, "Number of pirates : " .. tostring(#_Pirates) .. " timer allowed to advance : " .. tostring(mission.data.custom.thirdTimerAdvance))
        if _X == mission.data.location.x and _Y == mission.data.location.y and mission.data.custom.thirdTimerAdvance and #_Pirates == 0 then
            nextPhase()
        end
    end,
    repeating = true}

end

--endregion

mission.phases[4] = {}
mission.phases[4].showUpdateOnStart = true
mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[6].fulfilled = true

    mission.data.location = getNextLocation()
    mission.data.description[7].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }

    mission.data.description[7].visible = true

    local _Faction = Faction(mission.data.custom.friendlyFaction)
    Player():sendChatMessage(_Faction.name, 0, "We have a liason waiting for you in sector \\s(%1%:%2%). Please contact them there.", mission.data.location.x, mission.data.location.y)
end

mission.phases[4].onTargetLocationEntered = function(x, y)
    --Spawn liason
    spawnLiason()
end

--endregion

--region #SERVER CALLS

function spawnPirateWave(_LastWave, _WaveNumber) 
    local _MethodName = "Spawn Pirate Wave"
    mission.Log(_MethodName, "Beginning...")

    local rgen = ESCCUtil.getRand()

    local waveTable = { "Bandit", "Bandit" }
    if _LastWave then
        --Add a pirate/marauder and a raider.
        if rgen:getInt(1, 2) == 1 then
            table.insert(waveTable, "Pirate")
        else
            table.insert(waveTable, "Marauder")
        end
        table.insert(waveTable, "Raider")
    else
        --Add a combination of pirates and maurauders.
        if rgen:getInt(1, 2) == 1 then
            table.insert(waveTable, "Pirate")
            if rgen:getInt(1, 2) == 1 then
                table.insert(waveTable, "Marauder")
            else
                table.insert(waveTable, "Pirate")
            end
        else
            table.insert(waveTable, "Marauder")
            table.insert(waveTable, "Pirate")
        end
    end

    mission.data.custom.waveCounter = _WaveNumber

    local generator = AsyncPirateGenerator(nil, onPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onPiratesFinished(_Generated)
    local _MethodName = "On Pirates Generated (Server)"
    local _WaveNumber = mission.data.custom.waveCounter
    mission.Log(_MethodName, "Beginning. Wave number is : " .. tostring(_WaveNumber))

    if _WaveNumber == 1 then
        mission.data.custom.firstTimerAdvance = true
    end

    if _WaveNumber == 2 then
        mission.data.custom.secondTimerAdvance = true
    end

    if _WaveNumber == 3 then
        mission.data.custom.thirdTimerAdvance = true
    end

    SpawnUtility.addEnemyBuffs(_Generated)
end

function pirateTaunt()
    local _MethodName = "Pirate Taunt"
    mission.Log(_MethodName, "Beginning...")

    local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}

    if not mission.data.custom.firstWaveTaunt and #_Pirates > 0 then
        mission.Log(_MethodName, "Broadcasting Pirate Taunt to Sector")
        mission.Log(_MethodName, "Entity: " .. tostring(_Pirates[1].id))

        local _Lines = {
            "... Who are you? How dare you interrupt!",
            "Well, I guess you'll be the first one we kill.",
            "You're a long way from home, aren't you?",
            "... Who the hell are you?",
            "Looks like we found a stray one."
        }

        Sector():broadcastChatMessage(_Pirates[1], ChatMessageType.Chatter, getRandomEntry(_Lines))
        mission.data.custom.firstWaveTaunt = true
    end
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
        _Ship:addScriptOnce("player/missions/lotw/mission1/lotwliasonm1.lua")
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

function getNextLocation()
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getSector(x, y, 2, 6, false, false, false, false, false)

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Faction = Faction(mission.data.custom.friendlyFaction)
    _Player:setValue("_lotw_story_stage", 2)
    _Player:setValue("_lotw_faction", _Faction.index)

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
        _FinalDescription = "We're looking for a hot-shot captain to take care of some pirate raiders that are gathering in a nearby sector. From what intelligence we can gather, they're getting together to attack a nearby system and that's something we'd rather avoid for obvious reasons. Don't worry, you'll be well compensated for your efforts."
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "A group of raiders think that they've escaped our notice. They are wrong. We've found their pathetic fleet, and we're ready to wipe it off the face of this galaxy. However - in what you'll agree is a magnanimous display - we've decided to offer outsider captains a crack at it first. You'll be compensated for your time and for the ships destroyed. Make an example of them."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "A group of pirate raiders are gathering nearby to launch an attack on one of our systems. We won't be able to shift enough defenses to the targeted system in time to meet the attack. So we're looking for some outside help to make up the difference. Please, many lives will be saved by your actions."
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local _Sector = Sector()
    local target = {}
    --GET TARGET HERE:
    local x, y = _Sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = 5
    
    local _Description = formatDescription(_Station)

    reward = ESCCUtil.clampToNearest(125000 + (50000 * Balancing.GetSectorRewardFactor(_Sector:getCoordinates())), 5000, "Up") --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = _Description,
        difficulty = "Easy",
        reward = "¢${reward}",
        script = "missions/lotw/lotwstory1.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The pirates are gathering in sector \\s(%1%:%2%). Please destroy them.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/lotw/lotwstory1.lua") or (player:getValue("_lotw_story_stage") or 0) > 1 then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission again.")
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
            reward = {credits = reward, relations = 12000, paymentMessage = "Earned %1% credits for destroying the pirate fleet."},
            initialDesc = _Description,
            dangerLevel = _DangerLevel
        }},
    }

    return bulletin
end

--endregion