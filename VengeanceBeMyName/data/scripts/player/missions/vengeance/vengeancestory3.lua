--[[
First Strike
- Attack a pirate group related to the pirate boss the main NPC wants to kill
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "First Strike"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "After smashing through a group of pirate raiders, your mysterious employer showed up and revealed her motives - her name is Allison and she wants to kill a pirate boss. She said she would send her next request soon. Given her goals, it's likely that she will want to kill more pirates." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the fleeing cargo ships", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.alphaWingValue = "_vbmn3_alpha_wing"
mission.data.custom.betaWingValue = "_vbmn3_beta_wing"
mission.data.custom.transportValue = "_vbmn3_loot_target"
mission.data.custom.alphaWingKilled = 0
mission.data.custom.betaWingKilled = 0
mission.data.custom.transportsKilled = 0
mission.data.custom.transportTimer = 0
mission.data.custom.phase3DialogStarted = false
mission.data.custom.sentPhase3AllisonChatter = false
mission.data.custom.setAdrasteiaShipsAggressive = false
mission.data.custom.phase4DialogStarted = false

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

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
    setCustomMusic("data/music/vengeance/mw2gblsearchanddestroy.ogg")
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    setGameMusic()
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.fightSector = vengeStory3_getNextLocation()

    local x = mission.data.custom.fightSector.x
    local y = mission.data.custom.fightSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    --Send mail to player
    local _player = Player()
    local _mail = Mail()
    _mail.text = Format("Hello again.\n\nXinull's raid is happening soon. I have no intent of letting it go off without a hitch. We're going to ambush his group and kill every last one of them. I managed to get my hands on one of his men, and he said they'd be preparing their forces in (%1%:%2%). Go there.\n\nAllison", x, y)
    _mail.header = "The Raid"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story3_mail"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story3_mail" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    mission.data.location = mission.data.custom.fightSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if onServer() then
        vengeStory3_createObjectiveSector(x, y)
        vengeStory3_spawnAllison()
        vengeStory3_spawnAdrasteiaWarships()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/mw2gblsearchanddestroy.ogg")
    nextPhase()
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].triggers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onEntityDestroyed = function(id, lastDamageInflictor)
    if atTargetLocation() then
        local destroyedEntity = Entity(id)
        if destroyedEntity and valid(destroyedEntity) then
            if destroyedEntity:getValue(mission.data.custom.alphaWingValue) then
                mission.data.custom.alphaWingKilled = mission.data.custom.alphaWingKilled + 1
            end

            if destroyedEntity:getValue(mission.data.custom.betaWingValue) then
                mission.data.custom.betaWingKilled = mission.data.custom.betaWingKilled + 1
            end

            if destroyedEntity:getValue(mission.data.custom.transportValue) then
                mission.data.custom.transportsKilled = mission.data.custom.transportsKilled + 1

                local _player = Player()
                local _vbmn3_loot_transports_killed = (_player:getValue("_vbmn3_loot_transports_killed") or 0) + 1
                _player:setValue("_vbmn3_loot_transports_killed", _vbmn3_loot_transports_killed)
            end
        end
    end
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    if mission.data.custom.setAdrasteiaShipsAggressive then
        mission.data.custom.transportTimer = mission.data.custom.transportTimer + timeStep
    end
end

local vengeStory3_onPhase3DialogEnd = makeDialogServerCallback("vengeStory3_onPhase3DialogEnd", 3, function()
    mission.data.custom.setAdrasteiaShipsAggressive = true

    local pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    for _, pirate in pairs(pirates) do
        local pirateAI = ShipAI(pirate)

        pirateAI:clearFriendFactions()
        pirateAI:clearFriendEntities()

        pirate.invincible = false
        local pirateShield = Shield(pirate.index)
        if pirateShield then
            pirateShield.invincible = false
        end

        if not pirate:getValue(mission.data.custom.transportValue) then
            pirateAI:setAggressive()
        end
    end

    local friendlyWarships = { Sector():getEntitiesByScriptValue("is_adrasteia_ship") } --This includes Allison's ship.
    for _, warship in pairs(friendlyWarships) do
        local warshipAI = ShipAI(warship)
        warshipAI:setAggressive()

        if warship:hasScript("torpedoslammer.lua") then
            warship:invokeFunction("torpedoslammer.lua", "resetTimeToActive", 0)
        end
    end

    local pirateFreighters = { Sector():getEntitiesByScriptValue(mission.data.custom.transportValue) }
    local _random = random()
    for _, freighter in pairs(pirateFreighters) do
        local dir = _random:getDirection()

        local freighterAI = ShipAI(freighter)
        freighterAI:setFlyLinear(dir * 20000, 0)
        freighterAI:setPassiveShooting(true)
    end

    mission.data.description[5].visible = true
    sync()
end)

--region #PHASE 3 TIMERS 

if onServer() then

mission.phases[3].timers[1] = {
    time = 3,
    callback = function()
        if atTargetLocation() and not mission.data.custom.phase3DialogStarted then
            mission.data.custom.phase3DialogStarted = true

            local _sector = Sector()

            local ships = { _sector:getEntitiesByType(EntityType.Ship) }
            for _, ship in pairs(ships) do
                if ship.playerOrAllianceOwned then
                    local ai = ShipAI(ship)
                    ai:stop()
                end
            end

            local pirates = { _sector:getEntitiesByScriptValue("_vbmn3_initial_pirates") }
            local pirate = getRandomEntry(pirates)
            invokeClientFunction(Player(), "vengeStory3_onPhase3Dialog", pirate.index)
        end
    end,
    repeating = true
}

mission.phases[3].timers[2] = {
    time = 30,
    callback = function()
        if atTargetLocation() then
            vengeStory3_spawnPirateAttackWave()
        end
    end,
    repeating = true
}

mission.phases[3].timers[3] = {
    time = 180,
    callback = function()
        if atTargetLocation() then
            vengeStory3_spawnAllison() --The support warhips don't spawn and there's a bonus for saving them.
        end
    end,
    repeating = true
}

end

--endregion

--region #PHASE 3 TRIGGERS

if onServer() then

mission.phases[3].triggers[1] = {
    condition = function()
        local transportCt = ESCCUtil.countEntitiesByValue(mission.data.custom.transportValue)
        if atTargetLocation() and transportCt == 0 then
            return true
        else
            return false
        end
    end,
    callback = function()
        mission.data.description[5].fulfilled = true
        sync()
    end,
    repeating = false
}

mission.phases[3].triggers[2] = {
    condition = function()
        return mission.data.custom.transportTimer > 60
    end,
    callback = function()
        local transports = { Sector():getEntitiesByScriptValue(mission.data.custom.transportValue) }
        for _, transport in pairs(transports) do
            transport:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
        end
    end,
    repeating = false
}

mission.phases[3].triggers[3] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        if atTargetLocation() and mission.data.custom.alphaWingKilled >= 16 and mission.data.custom.betaWingKilled >= 16 and pirateCt == 0 then
            return true
        else
            return false
        end
    end,
    callback = function()
        nextPhase()
    end,
    repeating = false
}

end

--endregion

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].fulfilled = true --This should already be fulfilled but no harm in setting it again.
    mission.data.description[6].visible = true
end

mission.phases[4].onBeginServer = function()
    vengeStory3_spawnAllison() --Just in case she withdrew.
end

local vengeStory3_onPhase4DialogEnd = makeDialogServerCallback("vengeStory3_onPhase4DialogEnd", 4, function()
    vengeStory3_friendlyShipsDepart()
    vengeStory3_finishAndReward()
end)

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 5,
    callback = function()
        if not mission.data.custom.phase4DialogStarted then
            mission.data.custom.phase4DialogStarted = true
            local adrasteiaShipsAlive = ESCCUtil.countEntitiesByValue("is_adrasteia")
            invokeClientFunction(Player(), "vengeStory3_onPhase4Dialog", mission.data.custom.allisonID, adrasteiaShipsAlive)
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory3_getNextLocation()
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 260

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

function vengeStory3_createObjectiveSector(x, y)
    local _player = Player()
    local _random = random()

    local generator = SectorGenerator(x, y)
    for _ = 1, 4 do
        generator:createSmallAsteroidField()
    end

    --Create 2 container fields
    for _ = 1, 2 do
        generator:createContainerField(nil, nil, nil, nil, nil, 0)
    end

    --Create 2 clusters of 5 pirate ships for 10 total.
    local craft = Entity(_player.craftIndex)
    local basePos = vec3(0, 0, 0)

    if craft then
        basePos = craft.translationf
    end

    for _ = 1, 2 do
        local clusterPos = ESCCUtil.getVectorAtDistance(basePos, _random:getInt(2000, 2500), true)
        vengestory3_createPirateCluster(clusterPos)
    end

    --Create 3 mini loot goons
    local pirateGenerator = AsyncPirateGenerator(nil, nil)
    local shipGenerator = AsyncShipGenerator(nil, vengeStory3_onInitialPirateFreightersFinished)
    local shipVol = Balancing_GetSectorShipVolume(x, y) * 3
    local pirateFaction = pirateGenerator:getPirateFaction()

    shipGenerator:startBatch()

    for _ = 1, 3 do
        shipGenerator:createFreighterShip(pirateFaction, shipGenerator:getGenericPosition(), shipVol)
    end

    shipGenerator:endBatch()

    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true
end

function vengestory3_createPirateCluster(pos)
    local _random = random()

    --Get a table of ships.
    local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 5, "Standard", false)

    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory3_onInitialPiratesFinished)

    pirateGenerator:startBatch()

    for _, p in pairs(pirateTable) do
        local dir = _random:getDirection()
        local pos2 = pos + (dir * _random:getInt(250, 400))
        local look = _random:getVector(-100, 100)
        local up = _random:getVector(-100, 100)

        pirateGenerator:createScaledPirateByName(p, MatrixLookUpPosition(look, up, pos2))
    end

    pirateGenerator:endBatch()    
end

function vengeStory3_onInitialPiratesFinished(generated)
    for _, pirate in pairs(generated) do
        local pirateAI = ShipAI(pirate)
        pirateAI:setPassive()
        pirateAI:registerFriendFaction(Player().index)

        pirate.invincible = true
        local pirateShield = Shield(pirate.index)
        if pirateShield then
            pirateShield.invincible = true
        end

        pirate:setValue("bDisableXAI", true) --AI is handled by this mission.
        pirate:setValue("_vbmn3_initial_pirates", true)
    end

    SpawnUtility.addEnemyBuffs(generated)

    Placer.resolveIntersections(generated)
end

function vengeStory3_onInitialPirateFreightersFinished(generated)
    for _, ship in pairs(generated) do
        ESCCUtil.removeCivilScripts(ship)
        ESCCUtil.multiplyOverallDurability(ship, 6)

        local freighterAI = ShipAI(ship)
        freighterAI:setPassive()
        freighterAI:registerFriendFaction(Player().index)

        ship.invincible = true
        local shipShield = Shield(ship.index)
        if shipShield then
            shipShield.invincible = true
        end

        ship:setValue("bDisableXAI", true) --AI is handled by this mission.
        ship:setValue("is_pirate", true)
        ship:setValue(mission.data.custom.transportValue, true)
    end

    shuffle(random(), generated)
    local addLootTo = 3 - (Player():getValue("_vbmn3_loot_transports_killed") or 0) --anti loot farming value

    for idx = 1, addLootTo do
        local ship = generated[idx]
        if ship then
            ship:addScript("player/missions/vengeance/story3/vengeance3loottransport.lua")
        end
    end
end

function vengeStory3_spawnAllison()
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
        local allison = VengeUtil.spawnAllison(false, false)
        local allisonAI = ShipAI(allison)

        if mission.data.custom.setAdrasteiaShipsAggressive then
            allisonAI:setAggressive()
        end

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory3_spawnAdrasteiaWarships()
    --Spawn 2 cruisers and a missile cruiser
    local adrasteiaCruiserCt = ESCCUtil.countEntitiesByValue("is_adrasteia_cruiser")
    if adrasteiaCruiserCt < 2 then
        local spawnCt = 2 - adrasteiaCruiserCt
        for _ = 1, spawnCt do
            VengeUtil.spawnAdrasteiaWarship(false)
        end
    end

    local adrasteiaMissileCt = ESCCUtil.countEntitiesByValue("is_adrasteia_missile_ship")
    if adrasteiaMissileCt == 0 then
        local missileShip = VengeUtil.spawnAdrasteiaMissileShip(false)
        if not mission.data.custom.setAdrasteiaShipsAggressive then
            missileShip:invokeFunction("torpedoslammer.lua", "resetTimeToActive", math.huge)
        end
    end
end

function vengeStory3_spawnPirateAttackWave()
    local spawnFunc = function(wingOnSpawnFunc)
        local wingCt = 4
        if random():test(0.25) then
            wingCt = wingCt + 1
        end

        local wingSpawnTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, wingCt, "Standard", false)
        local wingGenerator = AsyncPirateGenerator(nil, wingOnSpawnFunc)

        local wingPositions = wingGenerator:getStandardPositions(wingCt, 250) --_#DistAdj

        wingGenerator:startBatch()

        for posIdx, p in pairs(wingSpawnTable) do
            wingGenerator:createScaledPirateByName(p, wingPositions[posIdx])
        end

        wingGenerator:endBatch()
    end

    local initialPirateCt = ESCCUtil.countEntitiesByValue("_vbmn3_initial_pirates")
    local spawnedPirates = false
    if initialPirateCt == 0 then

        local alphaPirateCt = ESCCUtil.countEntitiesByValue(mission.data.custom.alphaWingValue)
        if alphaPirateCt == 0 and mission.data.custom.alphaWingKilled < 16 then
            spawnedPirates = true
            spawnFunc(vengeStory3_onPirateAlphaWingFinished)
        end

        local betaPirateCt = ESCCUtil.countEntitiesByValue(mission.data.custom.betaWingValue)
        if betaPirateCt == 0 and mission.data.custom.betaWingKilled < 16 then
            spawnedPirates = true
            spawnFunc(vengeStory3_onPirateBetaWingFinished)
        end

        if spawnedPirates and not mission.data.custom.sentPhase3AllisonChatter then
            mission.data.custom.sentPhase3AllisonChatter = true
            VengeUtil.allisonChatter(nil, "Figures there'd be more. You've seen bombardiers before, right? Kill them first.")
        end
    end
end

function vengeStory3_onPirateAlphaWingFinished(generated)
    --Attacks the player
    for _, p in pairs(generated) do
        p:setValue(mission.data.custom.alphaWingValue, true)
        p:addScript("ai/priorityattacker.lua", { _TargetPriority = 2 }) --2 = player

        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25  --Xinull goon boost.
    end

    shuffle(random(), generated)

    local torpSlammerValues = {
        _TimeToActivate = 15,
        _ROF = 8,
        _UpAdjust = false,
        _DamageFactor = 2.5, --The pirate ships aren't a huge threat here, so we make them a bit spicier.
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 7 --Random player ship
    }

    generated[1]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
    ESCCUtil.setBombardier(generated[1])

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory3_onPirateBetaWingFinished(generated)
    --Attacks allison / allies
    local targetScriptValue = "is_adrasteia_ship"

    for _, p in pairs(generated) do
        p:setValue(mission.data.custom.betaWingValue, true)
        p:addScript("ai/priorityattacker.lua", { _TargetPriority = 1, _TargetTag = targetScriptValue })

        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25
    end

    shuffle(random(), generated)

    local torpSlammerValues = {
        _TimeToActivate = 30,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = 1.25,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = targetScriptValue,
        _RangeFactor = 3
    }

    for idx = 1, 2 do
        generated[idx]:addScriptOnce("torpedoslammer.lua", torpSlammerValues)
        ESCCUtil.setBombardier(generated[idx])
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory3_friendlyShipsDepart()
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function vengeStory3_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 3000000

    local gotBonus = false

    local perTransportBonus = 100000
    if mission.data.custom.transportsKilled == 3 then
        perTransportBonus = 150000
    end
    local transportBonus = perTransportBonus * mission.data.custom.transportsKilled
    if transportBonus > 0 then
        gotBonus = true
    end

    mission.Log(methodName, "transport bonus is " .. tostring(transportBonus))

    local adrasteiaShipsAlive = ESCCUtil.countEntitiesByValue("is_adrasteia")
    local adrasteiaShipsAliveBonus = 1.0 + ((adrasteiaShipsAlive - 1) * 0.1)
    if adrasteiaShipsAliveBonus > 1.0 then
        gotBonus = true
    end

    local totalCreditReward = (baseReward + transportBonus) * adrasteiaShipsAliveBonus

    mission.Log(methodName, "Final reward is " .. tostring(totalCreditReward))

    local pmtMessage = "Earned %1% credits for defeating Xinull's raid."
    if gotBonus then
        pmtMessage = pmtMessage .. " This includes a bonus for excellent work."
    end

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = totalCreditReward, paymentMessage = pmtMessage}

    _player:setValue("_vengeancebmn_story_stage", 4)
    
    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory3_onPhase3Dialog(pirateID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}

    d0.text = "Well, well. If it isn't little Allison."
    d0.followUp = d1

    d1.text = "All grown up now, are we? Do you think you can take us on?"
    d1.followUp = d2

    d2.text = "This is the end of the line for you. You know that, right?"
    d2.followUp = d3

    d3.text = "We're always ready to die. Are you?"
    d3.followUp = d4

    d4.text = "As if scum like you could kill me."
    d4.followUp = d5

    d5.text = "You overestimate yourself."
    d5.followUp = d6

    d6.text = "Enough talking. I'd rather listen to your dying screams. All ships, attack!"
    d6.onEnd = vengeStory3_onPhase3DialogEnd

    ESCCUtil.setTalkerTextColors({d2, d4, d6}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(pirateID):interactShowDialog(d0, false)
end

function vengeStory3_onPhase4Dialog(allisonID, adrasteiaShipsAlive)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local dwhy1 = {}
    local dwhy2 = {}
    local dnext1 = {}
    local dnext2 = {}
    local d3 = {}

    if adrasteiaShipsAlive > 2 then
        d0.text = "I was impressed after your last performance, but you clearly know your way around the battlefield."
    else
        d0.text = "Well done."
    end
    d0.followUp = d1

    d1.text = "Steel yourself for the battles ahead. This won't be the last time we face Xinull's goons."
    d1.answers = {
        { answer = "I will.", followUp = d2 },
        { answer = "Why were there so many of them?", followUp = dwhy1 },
        { answer = "What's next?", followUp = dnext1 }
    }

    d2.text = "Good."
    d2.followUp = d3

    dwhy1.text = "What do you mean? This is normal."
    dwhy1.answers = {
        { answer = "I've never seen this many pirates attack a sector.", followUp = dwhy2 }
    }

    dwhy2.text = "They typically gather in a large group and then branch out and hit multiple sectors at once. Keeps faction forces guessing, and makes it more likely that they can sneak a high value target in the noise."
    dwhy2.answers = {
        { answer = "That makes sense.", followUp = d3  },
        { answer = "So what's next?", followUp = dnext1 }
    }

    dnext1.text = "Xinull has a base he's operating from. We're going to go after it."
    dnext1.answers = {
        { answer = "Got it.", followUp = d3 },
        { answer = "What's the plan?", followUp = dnext2 }
    }

    dnext2.text = "Not finished yet. I'll contact you when I've got something more solid."
    dnext2.followUp = d3

    d3.text = "Keep an eye out for my next request."
    d3.onEnd = vengeStory3_onPhase4DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, dwhy1, dwhy2, dnext1, dnext2, d3}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion