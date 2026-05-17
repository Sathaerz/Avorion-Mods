--[[
Jamming Out
- Attack a pirate shipyard to capture a Jammer ship.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Jamming Out"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "With Allison's help, you wiped out a group of Xinull's elite pirate raiders. However, at the end of the mission she said she would contact you with a plan to attack Xinull's base of operations. This must be it." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirate defenders", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Damage the jammer until it is under 20% hull", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Do not destroy the jammer", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Protect the Hijacking Ship while it boards the jammer", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Leave the sector", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.allisonFirstPhase3Spawn = false
mission.data.custom.allisonFirstPhaseChatterSent = false
mission.data.custom.phase4TorpedoBuffCounter = -1
mission.data.custom.phase4TorpResetTimer = 0
mission.data.custom.angryPirateWavesSpawned = 0
mission.data.custom.phase5DialogStarted = false

--endregion

--region #PHASE CALLS

--This is a fairly ticklish mission, so we'll do the player a favor and stop any xsotan fleets from showing up.
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    setGameMusic()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationEntered = function(x, y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

mission.globalPhase.onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/ac3slhighsign.ogg")
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    setGameMusic()

    local phaseIndexFuncTable = {
        nil, --Phase 1 has no location
        nil, --Phase 2 basically only spawns the sector
        function() --Phase 3 is cleaning up pirate defenders - allow player to leave / respawn.
            mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
            mission.data.timeLimitInDescription = true --Show the player how much time is left.
        end,
        function() --Phase 4 is the boarding phase - fail.
            vengeStory4_cleanUpAndFail(4)
        end,
        nil --Phase 5's objective is the player leaving the sector.
    }

    local phaseIdx = mission.internals.phaseIndex
    if phaseIndexFuncTable[phaseIdx] then
        phaseIndexFuncTable[phaseIdx]()
    end
end

mission.phases[1] = {} --Read mail phase
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.sySector = vengeStory4_getNextLocation()

    local x = mission.data.custom.sySector.x
    local y = mission.data.custom.sySector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    --Send mail to player
    local _player = Player()
    local _mail = Mail()
    _mail.text = Format("Hello again.\n\nThere's a base in this area of the galaxy that Xinull is operating out of. It won't be easy to eliminate - he found a stash of old UA tech and used it all without hesitation. I've got a plan. The first step is stealing a jammer. We should be able to find one docked at a nearby pirate shipyard. It's in (%1%:%2%). Go there.\n\nAllison", x, y)
    _mail.header = "Plan Phase One"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story4_mail"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story4_mail" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {} --Go to location phase
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.sySector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true

    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true

    if onServer() then
        local _player = Player()
        if _player:hasScript("events/alienattack.lua") then
            _player:removeScript("events/alienattack.lua")
            _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
        end
        vengeStory4_createObjectiveSector(x, y)
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/ac3slhighsign.ogg")
    nextPhase()
end

mission.phases[3] = {} --Clean up defenders / damage jammer phase - ends when objectives 4, 5, and 6 are completed
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].updateTargetLocationServer = function(timeStep)
    local objective4Complete = false
    local objective5Complete = false
    local objective6Complete = false

    local pirateCt = ESCCUtil.countEntitiesByValue("_vbmn4_initial_defender")
    if pirateCt ==  0 then
        objective4Complete = true
    end

    local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")
    if jammer and valid(jammer) then
        objective6Complete = true

        local jammerDurability = jammer.durability
        local jammerMaxDurability = jammer.maxDurability

        local ratio = jammerDurability / jammerMaxDurability
        if ratio <= 0.2 then
            objective5Complete = true
        end

        vengeStory4_setJammerFriendly(jammer)
    else
        vengeStory4_cleanUpAndFail(2) --If we hit this here, we don't know why it got blown up.
    end

    if objective4Complete then
        mission.data.description[4].fulfilled = true
        sync()
    end

    if objective5Complete then
        mission.data.description[5].fulfilled = true
        sync()
    end

    if objective4Complete and objective5Complete and objective6Complete then
        nextPhase()
    end
end

mission.phases[3].onEntityDestroyed = function(id, lastDamageInflictor)
    vengeStory4_handleDestroyedEntity(id)
end

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 5,
    callback = function()
        if atTargetLocation() and not mission.data.custom.allisonFirstPhase3Spawn then
            mission.data.custom.allisonFirstPhase3Spawn = true
            vengeStory4_spawnAllison(false)
            vengeStory4_spawnAdrasteiaWarship()
        end
    end,
    repeating = true
}

mission.phases[3].timers[2] = {
    time = 10,
    callback = function()
        local allisonCt = ESCCUtil.countEntitiesByValue("is_allison")
        if atTargetLocation() and allisonCt > 0 and not mission.data.custom.allisonFirstPhaseChatterSent then
            mission.data.custom.allisonFirstPhaseChatterSent = true
            VengeUtil.allisonChatter(nil, "Kill the defenders and damage the jammer. When that's finished, we'll send in a hijacking ship.")
        end
    end,
    repeating = true
}

mission.phases[3].timers[3] = {
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory4_spawnAllison(false)
            vengeStory4_spawnAdrasteiaWarship()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[4] = {} --Defend hijacking ship phase / ends when objective 7 is completed
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true --Should already be visible.
    mission.data.description[7].visible = true
end

mission.phases[4].onBeginServer = function()
    --Spawn the hijacking ship
    local hijackingShip = VengeUtil.spawnAdrasteiaHijackingShip(true) --May as well. The player fails when leaving the sector in this phase.

    --Order it to board the jammer
    local hijackAI = ShipAI(hijackingShip)
    local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")

    if jammer and valid(jammer) then --This should be true, but you never know!
        hijackAI:setBoard(jammer)
    else
        vengeStory4_cleanUpAndFail(2) --If we hit this here, we don't know why it got blown up.
    end

    --Send Allison chatter - try to spawn her first to make sure she is around.
    vengeStory4_spawnAllison(false)
    VengeUtil.allisonChatter(nil, "Hijacking ship inbound. Protect it while it boards the jammer.")
end

mission.phases[4].updateTargetLocationServer = function(timeStep)
    vengeStory4_setJammerFriendly(nil)
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    vengeStory4_handleDestroyedEntity(id)
end

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 10,
    callback = function()
        local friendlyFaction = VengeUtil.getFriendlyFaction()
        local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")

        if jammer and valid(jammer) and jammer.factionIndex == friendlyFaction.index then
            jammer:setValue("is_adrasteia", true)
            nextPhase()
        end
    end,
    repeating = true
}

mission.phases[4].timers[2] = {
    time = 50,
    callback = function()
        if atTargetLocation() then
            local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
            if pirateCt < 7 then
                mission.data.custom.phase4TorpedoBuffCounter = mission.data.custom.phase4TorpedoBuffCounter + 1
                vengeStory4_spawnPirateAttackWave(vengeStory4_onPirateAttackWaveFinished)
            end
        end
    end,
    repeating = true
}

mission.phases[4].timers[3] = {
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory4_spawnAllison(false)
            vengeStory4_spawnAdrasteiaWarship()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[5] = {} --Leave the sector phase / this phase ends when the player leaves the sector
mission.phases[5].timers = {}
mission.phases[5].onBegin = function()
    mission.data.description[6].fulfilled = true
    mission.data.description[7].fulfilled = true
    mission.data.description[8].visible = true
end

mission.phases[5].onBeginServer = function()
    --Send allison chatter
    VengeUtil.allisonChatter(nil, "We're done here. All ships departing. You should leave as well.")

    --Friendly ships depart
    vengeStory4_friendlyShipsDepart()
end

mission.phases[5].onTargetLocationLeft = function()
    mission.data.description[8].fulfilled = true
    mission.data.description[9].visible = true
end

mission.phases[5].onSectorArrivalConfirmed = function(x, y)
    if not atTargetLocation() then
        vengeStory4_spawnAllison(true)
    end
end

local vengeStory4_onPhase5DialogEnd = makeDialogServerCallback("vengeStory4_onPhase5DialogEnd", 5, function()
    vengeStory4_friendlyShipsDepart()
    vengeStory4_finishAndReward()
end)

--region #PHASE 5 TIMERS

if onServer() then

mission.phases[5].timers[1] = {
    time = 60,
    callback = function()
        if atTargetLocation() then
            local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
            if pirateCt < 20 then
                vengeStory4_spawnPirateAttackWave(vengeStory4_onAngryPirateAttackWaveFinished)
            end
        end
    end,
    repeating = true
}

mission.phases[5].timers[2] = {
    time = 5,
    callback = function()
        if not atTargetLocation() then
            local allisonCt = ESCCUtil.countEntitiesByValue("is_allison")

            if allisonCt > 0 and not mission.data.custom.phase5DialogStarted then
                mission.data.custom.phase5DialogStarted = true
                invokeClientFunction(Player(), "vengeStory4_onPhase5Dialog", mission.data.custom.allisonID)
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory4_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 255

    local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
    target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
    local _safetyBreakout = 0
    while target.x == x and target.y == y and _safetyBreakout <= 100 do
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
        _safetyBreakout = _safetyBreakout + 1
    end

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function vengeStory4_createObjectiveSector(x, y)
    local _player = Player()
    local _random = random()

    local generator = SectorGenerator(x, y)
    for _ = 1, 6 do
        generator:createSmallAsteroidField()
    end

    --Create a shipyard
    local look = _random:getVector(-100, 100)
    local up = _random:getVector(-100, 100)
    local pPos = vec3(0, 0, 0)

    local playerShip = Entity(_player.craftIndex)
    if playerShip then
        pPos = playerShip.translationf
    end

    local syPos = ESCCUtil.getVectorAtDistance(pPos, 2500, true)
    local syMatrix = MatrixLookUpPosition(look, up, syPos)

    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory4_onInitialDefendersFinished)

    local pirateShipyard = generator:createShipyard(pirateGenerator:getPirateFaction())
    pirateShipyard.position = syMatrix
    pirateShipyard:setValue("is_pirate", true)
    pirateShipyard:setValue("_vbmn4_pirate_shipyard", true)

    pirateShipyard:removeScript("consumer.lua")
    pirateShipyard:removeScript("backup.lua")
    pirateShipyard:removeScript("bulletinboard.lua")
    pirateShipyard:removeScript("missionbulletins.lua")
    pirateShipyard:removeScript("story/bulletins.lua")
    Sector():removeScript("traders.lua")

    Boarding(pirateShipyard).boardable = false

    ESCCUtil.multiplyOverallDurability(pirateShipyard, 10)

    --Don't remove cargo. The player can kill it for a bonus if they want.

    --Create 8 scattered defenders
    local pirateDefenderTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard", false)
    pirateGenerator:startBatch()

    for pIdx = 1, 8 do
        local pirateLook = _random:getVector(-100, 100)
        local pirateUp = _random:getVector(-100, 100)
        local piratePos = ESCCUtil.getVectorAtDistance(syPos, 1000, false)
        
        pirateGenerator:createScaledPirateByName(pirateDefenderTable[pIdx], MatrixLookUpPosition(pirateLook, pirateUp, piratePos))
    end

    pirateGenerator:endBatch()

    --Create a jammer
    local jammerGenerator = AsyncPirateGenerator(nil, vengeStory4_onJammerFinished)

    jammerGenerator:startBatch()

    jammerGenerator:createScaledJammer(syMatrix)

    jammerGenerator:endBatch()

    mission.data.custom.cleanUpSector = true
    Placer.resolveIntersections()
end

function vengeStory4_setJammerFriendly(jammer)
    if not jammer then
        jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")
    end

    if jammer and valid(jammer) then
            local jammerAI = ShipAI(jammer)

        jammerAI:setPassive()
        jammerAI:registerFriendFaction(Player().index)
        jammerAI:registerFriendFaction(VengeUtil.getFriendlyFaction().index)

        local shipsInSector = {Sector():getEntitiesByType(EntityType.Ship)}
        for _, ship in pairs(shipsInSector) do
            if ship.playerOrAllianceOwned then
                local shipAI = ShipAI(ship)
                shipAI:registerFriendEntity(jammer.id)
            end
        end
    end
end

function vengeStory4_onInitialDefendersFinished(generated)
    for _, p in pairs(generated) do
        p:setValue("_vbmn4_initial_defender", true)
        p:setValue("_vbmn4_adrasteia_priority_target", true)
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory4_onJammerFinished(generated)
    local jammer = generated[1]

    vengeStory4_setJammerFriendly(jammer)

    jammer:setValue("bDisableXAI", true) --Jammer AI handled by this mission.
    jammer:setValue("_vbmn4_jammer_objective", true)

    --Boy am I glad we don't have to worry about crew space for AI ships.
    jammer:addCrew(3000, CrewMan(CrewProfessionType.Security))

    Placer.resolveIntersections(generated)
end

function vengeStory4_spawnAllison(deleteOnLeft)
    local methodName = "Spawn Allison"

    local spawnAllison = true
    if mission.data.custom.allisonID then
        local allison = Entity(mission.data.custom.allisonID)
        if allison and valid(allison) and not allison:getValue("allison_withdrawing") then
            spawnAllison = false
        end
    end

    if spawnAllison then
        mission.Log(methodName, "No Allison in sector - spawning her in.")
        local allison = VengeUtil.spawnAllison(deleteOnLeft, false)
        local allisonAI = ShipAI(allison)

        local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")
        if jammer and valid(jammer) then
            allisonAI:registerFriendEntity(jammer.index)
        end

        allisonAI:setAggressive()
        allison:addScriptOnce("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = "_vbmn4_adrasteia_priority_target" })

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory4_spawnAdrasteiaWarship()
    local adrasteiaCruiserCt = ESCCUtil.countEntitiesByValue("is_adrasteia_cruiser")
    if adrasteiaCruiserCt == 0 then
        local adrasteiaCruiser = VengeUtil.spawnAdrasteiaWarship(false)
        local adrasteiaCruiserAI = ShipAI(adrasteiaCruiser)

        local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_jammer_objective")
        if jammer and valid(jammer) then
            adrasteiaCruiserAI:registerFriendEntity(jammer.index)
        end

        adrasteiaCruiserAI:setAggressive()
        adrasteiaCruiser:addScriptOnce("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = "_vbmn4_adrasteia_priority_target" })
    end
end

function vengeStory4_spawnPirateAttackWave(onFinishedFunc)
    local pirateGenerator = AsyncPirateGenerator(nil, onFinishedFunc)

    local pirateCt = 4
    if random():test(0.25) then
        pirateCt = pirateCt + 1
    end

    local pirateWave = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 4, "Standard", false)
    local piratePositions = pirateGenerator:getStandardPositions(pirateCt, 250) --_#DistAdj

    pirateGenerator:startBatch()

    for posIdx, p in pairs(pirateWave) do
        pirateGenerator:createScaledPirateByName(p, piratePositions[posIdx])
    end
    
    pirateGenerator:endBatch()
end

function vengeStory4_onPirateAttackWaveFinished(generated)
    local methodName = "On Pirate Attack Wave Finished"

    local targetScriptValue = "is_adrasteia_hijack_ship"

    for _, p in pairs(generated) do
        p:setValue("_vbmn4_adrasteia_priority_target", true)
        p:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = targetScriptValue } )
    end

    local torpDamageMultiplier = 1 + (math.max(0, mission.data.custom.phase4TorpedoBuffCounter) * 0.15)
    local tta = math.max(10, 30 - mission.data.custom.phase4TorpedoBuffCounter)
    local aaidf = 1 + math.max(0, (mission.data.custom.phase4TorpedoBuffCounter * 10))

    mission.Log(methodName, "Torpedo damage multiplier is " .. tostring(torpDamageMultiplier) .. " tta is " .. tostring(tta))

    local torpSlammerValues = {
        _TimeToActivate = tta,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = 1.25 * torpDamageMultiplier, --enhanced damage since this is in a lower tier area - subject to balancing pass.
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = targetScriptValue,
        _RangeFactor = 3,
        _AntiAiDurabilityFactor = aaidf
    }

    shuffle(random(), generated)

    for idx = 1, 2 do
        generated[idx]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        ESCCUtil.setBombardier(generated[idx])
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory4_onAngryPirateAttackWaveFinished(generated)
    mission.data.custom.angryPirateWavesSpawned = mission.data.custom.angryPirateWavesSpawned + 1

    for _, p in pairs(generated) do
        local angryDurabilityMultiplier = 1 + (mission.data.custom.angryPirateWavesSpawned * 0.5)

        local angryDamageMultiplier = 1 + (mission.data.custom.angryPirateWavesSpawned * 0.25)

        ESCCUtil.multiplyOverallDurability(p, angryDurabilityMultiplier)

        p.damageMultiplier = (p.damageMultiplier or 1) * angryDamageMultiplier

        p:setDropsLoot(false)
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory4_handleDestroyedEntity(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)
    local destroyerEntity = Entity(lastDamageInflictor)
    if destroyedEntity and valid(destroyedEntity) then
        if destroyedEntity:getValue("_vbmn4_jammer_objective") then
            local failReason = 2 --Assume someone else did it, unlesss...
            if destroyerEntity and valid(destroyerEntity) and destroyerEntity.playerOrAllianceOwned then
                failReason = 1 --The player did it.
            end
            vengeStory4_cleanUpAndFail(failReason)
        end

        if destroyedEntity:getValue("is_adrasteia_hijack_ship") then
            vengeStory4_cleanUpAndFail(3)
        end
    end
end

function vengeStory4_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeStory4_cleanUpAndFail(failReason)
    vengeStory4_friendlyShipsDepart()

    local pirateShipyard = ESCCUtil.getSingleEntityByValue(nil, "_vbmn4_pirate_shipyard")
    if pirateShipyard and valid(pirateShipyard) then
        CargoBay(pirateShipyard):clear()
    end

    local failReasonMailTable = {
        {
            text = Format("Hello again.\n\nYou destroyed the jammer. We needed that - the operation cannot proceed without it. I'll have to find another shipyard where one is laid up for repairs. I understand that Jammers are fragile, but be more careful when damaging the next one. I would suggest only using one or two of your weapons on it.\n\nAllison"),
            mailId = "_vbmn_story4_mailfail1"
        },
        {
            text = Format("Hello again.\n\nThe jammer was destroyed. We needed that - the operation cannot proceed without it. I'll have to find another shipyard where one is laid up for repairs. Jammers are fragile, so be careful about them getting caught in the crossfire. Don't inflict excessive damage on it when going in for the capture attempt.\n\nAllison"),
            mailId = "_vbmn_story4_mailfail2"
        },
        {
            text = Format("Hello again.\n\nWe lost the hijacking ship. The operation cannot proceed without a captured jammer, so that is a problem. I'll have to build another one, and find another crew for it. Those ships are quite expensive and difficult to replace. Make sure you kill the bombardiers more quickly next time. We'll do what we can to help, but you need to be on point as well.\n\nAllison"),
            mailid = "_vbmn_story4_mailfail3"
        },
        {
            text = Format("Hello again.\n\nYou left the sector. Were you not prepared to take on the pirates? I understand that an operation of this magnitude can be demanding, but I expected it to be easier than the previous sorties you've taken part in. Please make sure you are adquately prepared to complete the operation next time.\n\nAllison"),
            mailId = "_vbmn_story4_mailfail4"
        }
    }

    local _player = Player()
    local _mail = Mail()
    _mail.text = failReasonMailTable[failReason].text
    _mail.header = "Operation Failed"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = failReasonMailTable[failReason].mailid
    _player:addMail(_mail)

    fail()
end

function vengeStory4_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 3500000

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = baseReward, paymentMessage = "Earned %1% credits for hijacking a pirate jammer."}
    
    _player:setValue("_vengeancebmn_story_stage", 5)
    _player:setValue("encyclopedia_vbmn_jammer", true)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory4_onPhase5Dialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}

    d0.text = "Good job. The jammer will be necessary for the next part of the plan."
    d0.followUp = d1

    d1.text = "I think I can trust you. You'll handle the first part of the operation while I organize the fleet for the second."
    d1.followUp = d2

    d2.text = "Keep an eye out for my next request."
    d2.onEnd = vengeStory4_onPhase5DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion