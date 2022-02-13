--[[
    Transfer Satellite
    NOTES:
        - You move a satellite via docking to another sector. Ez pz.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - None
    ROUGH OUTLINE
        - See notes. That's literally it.
    DANGER LEVEL
        1+ - The player has a 10% chance to be attacked by pirates when they drop off the satellite.
        - It is always 4 ships + 2 jammers
        - The ships will scale w/ threat level 
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

MissionUT = include("missionutility")
ESCCUtil = include("esccutil")

local PlanGenerator = include("plangenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Balancing = include ("galaxy")

mission._Debug = 0
mission._Name = "Transfer Satellite"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Dock the satellite to your ship", bulletPoint = true, fulfilled = false },
    { text = "Drop off the satellite in sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defeat the pirate ambush", bulletPoint = true, fulfilled = false, visible = false },
    { text = "The satellite must survive", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 30 * 60 --Player has 30 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "Thank you for transferring our satellite. A reward has been transferred into your account."
mission.data.failMessage = "You have failed. This was a simple task. How can we entrust you with something more consequential?"

local TransferSatellite_init = initialize
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
                .playerAttacked
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.playerAttacked =  false
            if _Data_in.playerAttacked == 10 then
                mission.Log(_MethodName, "Player is getting attacked.")
                mission.data.custom.playerAttacked = true
            end

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.description
            mission.data.description[2].arguments = {x = _X, y = _Y }

            _Data_in.reward.paymentMessage = "Earned %1% credits for transferring the satellite."

            --Run standard initialization
            TransferSatellite_init(_Data_in)
        else
            --Restoring
            TransferSatellite_init()
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
--Try to keep the timer calls outside of onBeginServer / onSectorEntered / onSectorArrivalConfirmed unless they are non-repeating and 30 seconds or less.

mission.globalPhase = {}
mission.globalPhase.onEntityDestroyed = function(id, lastDamageInflictor)
    local _DestroyedEntity = Entity(id)

    if _DestroyedEntity:getValue("_transfersatellite_objective") then
        failAndPunish()
    end
end

mission.phases[1] = {}
mission.phases[1].sectorCallbacks = {}
mission.phases[1].sectorCallbacks[1] = {
    name = "onEntityDocked",
    func = function(_DockerID, _DockeeID)
        local _DockedEntity = Entity(_DockeeID)

        if _DockedEntity:getValue("_transfersatellite_objective") then
            nextPhase()
        end
    end
}
mission.phases[1].onBeginServer = function()
    --Create the satellite
    local _Giver = Entity(mission.data.giver.id)
    local _Faction = Faction(mission.data.giver.factionIndex)

    local desc = EntityDescriptor()
    desc:addComponents(
       ComponentType.Plan,
       ComponentType.BspTree,
       ComponentType.Intersection,
       ComponentType.Asleep,
       ComponentType.DamageContributors,
       ComponentType.BoundingSphere,
       ComponentType.BoundingBox,
       ComponentType.Velocity,
       ComponentType.Physics,
       ComponentType.Scripts,
       ComponentType.ScriptCallback,
       ComponentType.Title,
       ComponentType.Owner,
       ComponentType.Durability,
       ComponentType.PlanMaxDurability,
       ComponentType.InteractionText,
       ComponentType.EnergySystem
       )

    local _SatellitePlan = PlanGenerator.makeStationPlan(_Faction)
    local _ScaleFactor = 15 / _SatellitePlan:getBoundingSphere().radius
    _SatellitePlan:scale(vec3(_ScaleFactor, _ScaleFactor, _ScaleFactor))
    _SatellitePlan.accumulatingHealth = true

    desc.position = getPositionInFront(_Giver, 20)
    desc:setMovePlan(_SatellitePlan)
    desc.factionIndex = _Faction.index

    local _Satellite = Sector():createEntity(desc)
    _Satellite:setValue("_transfersatellite_objective", true)
    _Satellite:setTitle("Satellite", {})
end

mission.phases[2] = {}
mission.phases[2].sectorCallbacks = {}
mission.phases[2].sectorCallbacks[1] = {
    name = "onEntityUndocked",
    func = function(_DockerID, _DockeeID)
        local _UndockedEntity = Entity(_DockeeID)
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        if _X == mission.data.location.x and _Y == mission.data.location.y then
            MissionUT.deleteOnPlayersLeft(_UndockedEntity)
            if _UndockedEntity:getValue("_transfersatellite_objective") then
                if mission.data.custom.playerAttacked then
                    nextPhase()
                else
                    finishAndReward()
                end
            end
        end
    end
}
mission.phases[2].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
end

mission.phases[3] = {}
mission.phases[3].timers = {}

--region #PHASE 3 TIMER CALLS

if onServer() then

mission.phases[3].timers[2] = {
    time = 10, 
    callback = function() 
        local _MethodName = "Phase 3 Timer 2 Callback"
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
        local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}
        mission.Log(_MethodName, "Number of pirates : " .. tostring(#_Pirates) .. " timer allowed to advance : " .. tostring(mission.data.custom.timerAdvance))
        if _X == mission.data.location.x and _Y == mission.data.location.y and mission.data.custom.timerAdvance and #_Pirates == 0 then
            finishAndReward()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[3].onBeginServer = function()
    --Start a 15 second timer to spawn pirates and update mission objectives.
    mission.phases[3].timers[1] = {
        time = 15,
        callback = function()
            local _MethodName = "Phase 3 Timer 1 Callback"
            mission.Log(_MethodName, "Beginning.")

            spawnPirateAmbush()
            mission.data.description[4].fulfilled = true
            mission.data.description[5].visible = true
            mission.data.description[6].visible = true
            sync()
        end,
        repeating = false
    }
end

--endregion

--region #SERVER CALLS

function getPositionInFront(craft, distance)

    local position = craft.position
    local right = position.right
    local dir = position.look
    local up = position.up
    local position = craft.translationf

    local pos = position + dir * (craft.radius + distance)

    return MatrixLookUpPosition(right, up, pos)
end

function spawnPirateAmbush()
    local _MethodName = "Spawn Pirate Ambush"
    mission.Log(_MethodName, "Beginning.")

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 4, "Standard", false)

    table.insert(waveTable, 0, "Jammer")
    table.insert(waveTable, "Jammer")

    local generator = AsyncPirateGenerator(nil, onPirateAmbushFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 200 --_#DistAdj
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onPirateAmbushFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)

    local _TauntingEnemy = _Generated[2]

    mission.data.custom.timerAdvance = true
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

function failAndPunish()
    local _MethodName = "Fail and Punish"
    mission.Log(_MethodName, "Running lose condition.")

    punish()
    fail()
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
        _FinalDescription = "We'd like to expand our survelliance network. We've got a satellite ready to deploy, but unfortunately we're not able to spare any ships to move it. If you can take it to sector (${x}:${y}) and drop it off, we'll pay you handsomely for it. It's not the most glamorous work, but it's easy money for an easy job. What do you say, captain?"
    elseif _DescriptionType == 2 then --Aggressive.
        _FinalDescription = "We need the ability to keep better track of a faction of pirates that has been a particular thorn in our side. To that end, we are deploying a spy satellite in sector (${x}:${y}). Unfortunately, we cannot spare the ships to move it. That's where you come in. We recognize that this may be seen as demeaning work, but it's an easy job. We will obviously pay you for your efforts."
    elseif _DescriptionType == 3 then --Peaceful.
        _FinalDescription = "We're scouting out new sectors to create a settlement in. Sector (${x}:${y}) looks particularly promising, but we would like to gather some more data before we actually commit to sending a group of colonists. We've put together a satellite that should be able to give us the data that we need, but unfortunately we don't have any ships to spare to move it. If you can move the satellite for us, we will pay you for your time."
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 12, 30, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)
    local _PlayerAttacked = _Rgen:getInt(1, 10)

    local _Difficulty = "Easy"
    if _DangerLevel == 10 then
        _Difficulty = "Medium"
    end
    
    local _Description = formatDescription(_Station)

    local _BaseReward = 37000
    --From 37000 to 40000
    for _ = 1, 3 do
        if _Rgen:getInt(1, 2) == 1 then
            _BaseReward = _BaseReward + 1000
        end
    end

    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()) --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission._Name,
        description = _Description,
        difficulty = "Easy",
        reward = "¢${reward}",
        script = "missions/transfersatellite.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you. Please drop the satellite off in sector \\s(%1%:%2%).",
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
            reward = {credits = reward, relations = 4000}, --This is a very easy mission unless you get attacked.
            punishment = {relations = 4000 },
            dangerLevel = _DangerLevel,
            description = _Description,
            playerAttacked = _PlayerAttacked
        }},
    }

    return bulletin
end

--endregion