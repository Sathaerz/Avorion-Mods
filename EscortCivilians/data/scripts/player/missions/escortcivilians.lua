--[[
    Escort Civilian Transports
    NOTES:
        - Transports jump out after 100 seconds.
        - Gives a massive amount of rep. Enjoy.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - None.
    ROUGH OUTLINE
        - Go to location, defend civil transports. Use typical ESCC mission structure.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - Alpha Pirates will use standard threat ships from the corresponding danger table.
            - Beta Pirates will use low threat ships from the corresponding danger table.
            - Beta Pirates get a slower increase in danger level than alpha, and cap at 0.7 - no pillagers for them!
            - Alpha wing is 3 pirates, Beta wing is 3 pirates - Alpha attacks everyone / beta goes after transports. Beta has 2x slammers.
            - After 2 transports escape, turn to 4/4.
            - 3 Transports need to escape.
            - Losting 3 transports fails.
            - Pirates spawn every 45 seconds.
            - Transports spawn every 90 seconds.
        6+ - [These conditions are present at danger level 6 and above]
            - Beta Pirates will use standard threat ships.
            - Losing 2 transports fails.
        10 - [These conditions are present at danger level 10]
            - Pirates spawn slightly faster
            - Alpha Pirates will use high threat ships.
            - 4 Transports need to escape.
            - Pirates spawn every 35 seconds.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Escort Civilian Transports"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Defend the civilian transports until they warp out - ${_ESCORTED}/${_MAXESCORTED} Escorted", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't let too many transports be destroyed - ${_DESTROYED}/${_MAXDESTROYED} Lost", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 10 * 60 --Player has 10 minutes to head to the sector. Take the time limit off when the player arrives.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

--Can't set mission.data.reward.paymentMessage here since we are using a custom init.
mission.data.accomplishMessage = "Thank you. You've saved thousands of lives today. We transferred the reward to your account."
mission.data.abandonMessage = "We're disappointed you decided to abandon this contract. Many of our transports cannot re-route. Thousands will die."
mission.data.failMessage = "The transports have been destroyed. Thousands of lives have been lost because of your failure."

local EscortCivilians_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel) .. " - pirates : " .. tostring(_Data_in.pirates) .. " - enemy : " .. tostring(_Data_in.enemyFaction))

            local _Rgen = ESCCUtil.getRand()
            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)

            --Emergency breakout just in case the player somehow got this from a player faction.
            if _Giver.playerOrAllianceOwned then
                print("ERROR: Mission from player faction - aborting.")
                terminate()
                return
            end
            --[[=====================================================
                CUSTOM MISSION DATA SETUP:
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.friendlyFaction = _Giver.factionIndex
            mission.data.custom.escorted = 0
            mission.data.custom.destroyed = 0
            mission.data.custom.timePassed = 0
            mission.data.custom.piratesSpawned = 0

            if not mission.data.custom.friendlyFaction then
                print("ERROR: Friendly faction is nil - aborting.")
                terminate()
                return
            end

            local _MaxEscort = 3
            local _MaxDestroyed = 3
            local _PirateSpawnTimer = 45
            local _AlphaThreat = "Standard"
            local _BetaThreat = "Low"

            --Set values based on danger level.
            if mission.data.custom.dangerLevel >= 6 then
                _MaxEscort = _MaxEscort + 1
                _BetaThreat = "Standard"
            end
            if mission.data.custom.dangerLevel == 10 then
                _MaxDestroyed = _MaxDestroyed - 1
                _PirateSpawnTimer = 40
                _AlphaThreat = "High"
            end

            mission.data.custom.maxDestroyed = _MaxDestroyed
            mission.data.custom.maxEscorted = _MaxEscort
            mission.data.custom.pirateSpawnTimer = _PirateSpawnTimer
            mission.data.custom.alphaWingThreat = _AlphaThreat
            mission.data.custom.betaWingThreat = _BetaThreat

            --[[=====================================================
                MISSION DESCRIPTION SETUP:
            =========================================================]]
            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { x = _X, y = _Y }
            mission.data.description[3].arguments = { _X = _X, _Y = _Y }

            --Run standard initialization
            EscortCivilians_init(_Data_in)
        else
            --Restoring
            EscortCivilians_init()
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

mission.globalPhase.timers = {}

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    if mission.data.custom.destroyed == 0 then
        mission.data.punishment.relations = mission.data.punishment.relations / 2
        punish()
    else
        punish()
    end

    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
            escortCivilians_transportsDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        if atTargetLocation() then
            ESCCUtil.allPiratesDepart()
        end
        runFullSectorCleanup(false)
    end
end

--region #GLOBALPHASE TIMERS

if onServer() then

mission.globalPhase.timers[1] = {
    time = 130, 
    callback = function() 
        local _MethodName = "Global Phase Timer 1"
        mission.Log(_MethodName, "Beginning...")

        mission.data.custom.timePassed = (mission.data.custom.timePassed or 0) + 130

        --Give the player a 5 minute grace period.
        if mission.data.custom.timePassed >= 300 and not atTargetLocation() then
            mission.data.custom.destroyed = mission.data.custom.destroyed + 1
            mission.Log(_MethodName, "Not on location - incrementing destroyed to : " .. tostring(mission.data.custom.destroyed))

            if mission.data.custom.destroyed >= mission.data.custom.maxDestroyed then
                escortCivilians_failAndPunish()
            end

            mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
            mission.data.abandonMessage = mission.data.failMessage

            sync()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false 
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
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
            escortCivilians_spawnBackgroundPirates()
        end
    end,
    repeating = true
}

--Timer 8 = set timer 2 to spawn transports - timers 5, 6, and 7 are spoken for in the spawn transports call
mission.phases[2].timers[8] = {
    time = 30,
    callback = function()
        escortCivilians_spawnCivilTransport()
        mission.phases[2].timers[2] = {
            time = 130,
            callback = function()
                local _Sector = Sector()
                local _X, _Y = _Sector:getCoordinates()
                if _X == mission.data.location.x and _Y == mission.data.location.y then
                    escortCivilians_spawnCivilTransport()
                end
            end,
            repeating = true
        }
    end,
    repeating = false
}

--Timer 3 moved to global phase.
--Timer 4 = advancement / objective timer
mission.phases[2].timers[4] = {
    time = 10,
    callback = function()
        local _MethodName = "Phase 1 Timer 4 Callback"
        mission.Log(_MethodName, "Beginning...")
        if mission.data.custom.escorted >= mission.data.custom.maxEscorted then
            ESCCUtil.allPiratesDepart()
            escortCivilians_finishAndReward()
        end
        if mission.data.custom.destroyed >= mission.data.custom.maxDestroyed then
            escortCivilians_failAndPunish()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[2].onBeginServer = function()
    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { _ESCORTED = mission.data.custom.escorted, _MAXESCORTED = mission.data.custom.maxEscorted }
    mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    escortCivilians_spawnBackgroundPirates()
end

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")
    if Entity(_ID):getValue("_escortcivilians_defendobjective") then
        mission.Log(_MethodName, "Was an objective.")
        mission.data.custom.destroyed = mission.data.custom.destroyed + 1
        mission.data.description[5].arguments = { _DESTROYED = mission.data.custom.destroyed, _MAXDESTROYED = mission.data.custom.maxDestroyed }
        mission.data.abandonMessage = mission.data.failMessage

        mission.Log(_MethodName, "Number of transports destroyed " .. tostring(mission.data.custom.destroyed))
        sync()
    end
end

--endregion

--region #SERVER CALLS

function escortCivilians_spawnCivilTransport()
    --Check to see if there's an existing transport.
    local _Transports = {Sector():getEntitiesByScriptValue("_escortcivilians_defendobjective")}
    --If there is, delete it and increment the escaped counter. (This is good for the player!)
    --This technically shouldn't happen due to the transport script, but...
    if #_Transports > 0 then
        for _, _F in pairs(_Transports) do
            _F:addScriptOnce("deletejumped.lua")
            escortCivilians_civilTransportEscaped()
        end
    end
    --Spawn a new freighter.
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _ShipGenerator = AsyncShipGenerator(nil, escortCivilians_onCivilTransportFinished)
    local _Vol1 = Balancing_GetSectorShipVolume(_X, _Y) * 16
    local _Faction = Faction(mission.data.custom.friendlyFaction)

    _ShipGenerator:startBatch()
    
    _ShipGenerator:createCivilTransportShip(_Faction, _ShipGenerator:getGenericPosition(), _Vol1)

    _ShipGenerator:endBatch()
end

function escortCivilians_onCivilTransportFinished(_Generated)
    local _Ship = _Generated[1]

    --Multiply durability so the ship isn't instakilled.
    local _Dura = Durability(_Ship)
    if _Dura then
        _Dura.maxDurabilityFactor = _Dura.maxDurabilityFactor * 3
    end

    _Ship:setValue("_escortcivilians_defendobjective", true)

    local _ShipAI = ShipAI(_Ship)
    local _Position = _Ship.position
    _ShipAI:setFlyLinear(_Position.look * 10000, 0)

    --Have it send a message.
    Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, "Transport here. Protect us while our hyperdrive recharges!")

    --Set timer for escape so we don't need a script.
    mission.phases[2].timers[5] = {
        time = 100,
        callback = function()
            local _Transports = {Sector():getEntitiesByScriptValue("_escortcivilians_defendobjective")}
            --If there is, delete it and increment the escaped counter.
            --This technically shouldn't happen due to the transport script, but...
            if #_Transports > 0 then
                for _, _F in pairs(_Transports) do
                    _F:addScriptOnce("deletejumped.lua")
                    escortCivilians_civilTransportEscaped()
                end
            end
        end,
        repeating = false
    }
    --Set a 2nd timer for it to send a message @ 30 seconds.
    mission.phases[2].timers[6] = {
        time = 70,
        callback = function()
            local _Transports = {Sector():getEntitiesByScriptValue("_escortcivilians_defendobjective")}
            if #_Transports > 0 then
                Sector():broadcastChatMessage(_Transports[1], ChatMessageType.Chatter, "Our hyperdrive will be recharged in 30 seconds!")
            end
        end,
        repeating = false
    }
    --Set a 3rd timer for it to send a message @ 10 seconds.
    mission.phases[2].timers[7] = {
        time = 90,
        callback = function()
            local _Transports = {Sector():getEntitiesByScriptValue("_escortcivilians_defendobjective")}
            if #_Transports > 0 then
                Sector():broadcastChatMessage(_Transports[1], ChatMessageType.Chatter, "Our hyperdrive will be back up in 10 seconds! Almost there!")
            end
        end,
        repeating = false
    }
end

function escortCivilians_civilTransportEscaped()
    mission.data.custom.escorted = mission.data.custom.escorted + 1
    mission.data.description[4].arguments = { _ESCORTED = mission.data.custom.escorted, _MAXESCORTED = mission.data.custom.maxEscorted }
    sync()
end

function escortCivilians_transportsDepart()
    local methodName = "Transports Depart"
    mission.Log(methodName, "Running.")

    local transports = {Sector():getEntitiesByScriptValue("_escortcivilians_defendobjective")}

    for _, transport in pairs(transports) do
        transport:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function escortCivilians_getWingSpawnTables(_WingScriptValue)
    local _MethodName = "Get Wing Spawn Table"
    mission.Log(_MethodName, "Beginning...")

    local _Escorted = mission.data.custom.escorted
    local _Danger = mission.data.custom.dangerLevel

    local _MaxCt = 3
    if _Escorted >= 2 then
        _MaxCt = 4
    end

    local _Pirates = {Sector():getEntitiesByScriptValue(_WingScriptValue)}
    local _Ct = #_Pirates

    local _SpawnCt = _MaxCt - _Ct
    local _SpawnDanger = _Danger

    local _Threat = "Standard"
    if _WingScriptValue == "_escortcivilians_alpha_wing" then
        _Threat = mission.data.custom.alphaWingThreat
    else
        _Threat = mission.data.custom.betaWingThreat
        _SpawnDanger = math.ceil(_Danger * 0.7) --Increase more slowly and cap at 7, so we don't get the table with Pillagers.
    end

    local _SpawnTable = {}
    if _SpawnCt > 0 then
        _SpawnTable = ESCCUtil.getStandardWave(_SpawnDanger, _SpawnCt, _Threat, false)
    end

    return _SpawnTable
end

function escortCivilians_spawnBackgroundPirates()
    local _MethodName = "Spawn Background Pirates"
    mission.Log(_MethodName, "Beginning...")

    local _AlphaSpawnTable = escortCivilians_getWingSpawnTables("_escortcivilians_alpha_wing")
    local generator = AsyncPirateGenerator(nil, escortCivilians_onAlphaBackgroundPiratesFinished)

    local distance = 250 --_#DistAdj

    generator:startBatch()

    local posCounter = 1
    local pirate_positions = generator:getStandardPositions(#_AlphaSpawnTable, distance)
    for _, p in pairs(_AlphaSpawnTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()

    local _BetaSpawnTable = escortCivilians_getWingSpawnTables("_escortcivilians_beta_wing")
    generator = AsyncPirateGenerator(nil, escortCivilians_onBetaBackgroundPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local pirate_positions = generator:getStandardPositions(#_BetaSpawnTable, distance)
    for _, p in pairs(_BetaSpawnTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function escortCivilians_onAlphaBackgroundPiratesFinished(_Generated)
    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_escortcivilians_alpha_wing", true)

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local _PiratesSpawned = mission.data.custom.piratesSpawned + 1
        local _Factor = 2
        if _PiratesSpawned >= 20 then
            _Factor = 3
        end
        if _PiratesSpawned % _Factor ~= 0 then
            _Pirate:setDropsLoot(false)
        end
        mission.data.custom.piratesSpawned = _PiratesSpawned
    end
    SpawnUtility.addEnemyBuffs(_Generated)
end

function escortCivilians_onBetaBackgroundPiratesFinished(_Generated)
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()

    local _SlamCtMax = 1
    local _Slammers = {Sector():getEntitiesByScript("torpedoslammer.lua")}
    local _SlamCt = #_Slammers
    local _SlamAdded = 0

    local _DmgFactor = 8
    local _TorpROF = 8
    if MissionUT.checkSectorInsideBarrier(_X, _Y) then
        _DmgFactor = 10
        _TorpROF = 6
    end

    local _TorpAccelFactor = 1
    local _TorpVelocityFactor = 1
    local _TorpTurningSpeedFactor = 1
    local _TorpDurabilityFactor = 10
    if mission.data.custom.dangerLevel == 10 then
        _TorpAccelFactor = 1.5
        _TorpVelocityFactor = 1.5
        _TorpTurningSpeedFactor = 1.5
        _TorpDurabilityFactor = 20
    end

    local _TorpSlammerValues = {
        _TimeToActive = 30,
        _ROF = _TorpROF,
        _UpAdjust = false,
        _DamageFactor = _DmgFactor,
        _DurabilityFactor = _TorpDurabilityFactor,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2,
        _TargetTag = "_escortcivilians_defendobjective",
        _AccelFactor = _TorpAccelFactor,
        _VelocityFactor = _TorpVelocityFactor,
        _TurningSpeedFactor = _TorpTurningSpeedFactor
    }

    --Increase damage @ low difficulties because the weenie ships barely pose a threat to the transports.
    local pirateDamageFactor = 1
    if mission.data.custom.dangerLevel <= 5 then
        pirateDamageFactor = 2
    end

    for _, _Pirate in pairs(_Generated) do
        _Pirate:setValue("_escortcivilians_beta_wing", true)
        _Pirate:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = "_escortcivilians_defendobjective" })

        --This is for performance reasons, so there aren't dozens and dozens of items scattered around the sector.
        local _PiratesSpawned = mission.data.custom.piratesSpawned + 1
        local _Factor = 2
        if _PiratesSpawned >= 20 then
            _Factor = 3
        end
        if _PiratesSpawned % _Factor ~= 0 then
            _Pirate:setDropsLoot(false)
        end

        _Pirate.damageMultiplier = (_Pirate.damageMultiplier or 1) * pirateDamageFactor

        mission.data.custom.piratesSpawned = _PiratesSpawned

        --Add torpedo slammer scripts if necessary.
        if _SlamCt + _SlamAdded < _SlamCtMax then
            ESCCUtil.setBombardier(_Pirate)
            
            _Pirate:addScript("torpedoslammer.lua", _TorpSlammerValues)

            _SlamAdded = _SlamAdded + 1
        end
    end
    
    SpawnUtility.addEnemyBuffs(_Generated)
end

function escortCivilians_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    if mission.data.custom.destroyed == 0 then --give players a bonus if they don't lose any transports.
        mission.data.reward.paymentMessage = mission.data.reward.paymentMessage .. " This includes a bonus for no losses."
        mission.data.reward.credits = mission.data.reward.credits * 1.25
    end

    reward()
    accomplish()
end

function escortCivilians_failAndPunish()
    local _MethodName = "Fail and Punish"
    mission.Log(_MethodName, "Running lose condition.")

    punish()
    fail()
end

--endregion

--region #MAKEBULLETIN CALL

function escortCivilians_formatDescription(_Station, _DangerValue)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    local descriptionTable = {
        "We're establishing a new colony, and to that end we'll need to relocate a number of our civilians to run it. Unfortunately, it's a good distance away and our transports will have to make multiple jumps to get there. We've received word that a group of pirates plans to attack them when they travel through (${x}:${y}). We'll pay you if you're able to protect the convoy while it travels through that sector.", --Neutral
        "We are establishing a forward operating base in another sector to deal with a particularly irritating pirate menace. We will need civilians to staff it, so we are moving a convoy of transports to the area to supply the personnel. The pirate scum seem to have gotten wind of this and plan to attack the convoy when it travels through (${x}:${y}). We cannot shift our military out of position to deal with this - they are busy dealing with the pirates. Keep our civilians safe. Leave no pirate survivors.", --Aggressive
        "We have suffered from a disaster in one of our sectors, and need to relocate a number of civilians to another colony fit for habitation. In order to make the transit, they need to travel through (${x}:${y}). Our spies have received information that pirates intend to attack the convoy as it moves through this sector. Our military is busy cleaning up the disaster and is unable to help. Please protect our people while they are vulnerable." --Peaceful
    }

    local finalDescription = descriptionTable[descriptionType]
 
    if _DangerValue >= 8 then
        finalDescription = finalDescription .. "\n\nWe anticipate the pirate attack to be quite intense. Come prepared."
    end

    return finalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 2, 15, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)
    
    local _Description = escortCivilians_formatDescription(_Station, _DangerLevel)

    local _Difficulty = "Medium"
    if _DangerLevel >= 5 then
        _Difficulty = "Difficult"
    end
    if _DangerLevel >= 8 then
        _Difficulty = "Extreme"
    end

    local _BaseReward = 73000
    if _DangerLevel >= 5 then
        _BaseReward = _BaseReward + 5000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 12000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRewardFactor(Sector():getCoordinates()) --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission._Name,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/escortcivilians.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The transports will be reaching \\s(%1%:%2%) soon. Please hurry.",
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
            reward = {credits = reward, relations = 1000, paymentMessage = "Earned %1% credits for escorting civilians."}, --Why is this so low? Becasue you get a ton of extra rep from killing the pirates w/ the civil transports active.
            punishment = {relations = 16000}, --This is so high for the same reason the above is so low.
            dangerLevel = _DangerLevel,
            initialDesc = _Description
        }},
    }

    return bulletin
end

--endregion