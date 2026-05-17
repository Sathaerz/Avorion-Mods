--[[
Pirate Recon
- Bulletin board mission - scout out a pirate fleet from within an asteroid field
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local SectorNameGenerator = include("sectornamegenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Pirate Recon"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "You received the following request from the ${sectorName} ${giverTitle}:" },
    { text = "..." }, --Placeholder
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Establish a cover story", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Do not jump another ship into the sector", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Listen in on the pirate transmissions", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Avoid detection", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Leave the sector before you are noticed", bulletPoint = true, fulfilled = false, visible = false }
}

mission.data.accomplishMessage = "Huh, well done. Most captains can't handle a stealth job - guess you're a cut above the rest. Here's your reward. I'll send my next request shortly."

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.failMessageSent = false --Don't spam fail messages.
mission.data.custom.proximityWarningSent = false
mission.data.custom.proximityTimer = 0
mission.data.custom.maxProximityTimer = 16
mission.data.custom.droneWarningSent = false
mission.data.custom.droneTimer = 0
mission.data.custom.phase2ShipHighlightRange = 3000 --30 km
mission.data.custom.phase2ShipUrgentHighlightRange = 2000 --20 km
mission.data.custom.allowedToLeaveSector = false
mission.data.custom.dialogTimer = 0
mission.data.custom.transmissionTable = {
    { 
        text = "You missed out on an incredible raid last cycle. We stole so many particle accelerators.", time = 40, sent = false 
    },
    { 
        text = "Everyone wants to steal gold and diamonds, but the real value is in processors.", time = 59, sent = false 
    },
    { 
        text = "That damn security team shot ${_NAME}. I TOLD you boarding that ship was a mistake!", time = 78, sent = false, 
        format = true, 
        formatFunc = function()
            local lang = Language(Seed(random():getFloat(0.0, 1000000.0)))
            return { _NAME = lang:getName() }
        end 
    },
    {
        text = "And I found out that ${_NAME} had a 5th ace hidden up ${_GENDER1} sleeve. So I shot ${_GENDER2} ${_SHOT} times in the ${_BODYPART}.", time = 97, sent = false,
        format = true,
        formatFunc = function()
            local _random = random()
            
            local lang = Language(Seed(_random:getFloat(0.0, 1000000.0)))

            local genders = {
                { g1 = "his", g2 = "him" },
                { g1 = "her", g2 = "her" },
                { g1 = "their", g2 = "them" },
                { g1 = "its", g2 = "it" }
            }
            local gender = getRandomEntry(genders)

            local shot = _random:getInt(3, 10)

            local bodyparts = { "chest", "head", "face", "tendril", "throat", "neck", "hand", "foot" }

            return { _NAME = lang:getName(), _GENDER1 = gender.g1, _GENDER2 = gender.g2, _SHOT = tostring(shot), _BODYPART = getRandomEntry(bodyparts) }
        end
    },
    {
        text = "I love chasing down stray merchants, but it's annoying when they jump into a heavily defended sector...", time = 116, sent = false
    },
    {
        text = "... and the legends say that the ship is still patrolling ${_SECTOR} to this day. If you see the red lightning, it's already too late.", time = 135, sent = false,
        format = true,
        formatFunc = function()
            local _random = random()
            local x = _random:getInt(-499, 499)
            local y = _random:getInt(-499, 499)
            local serverSeed = Server().seed

            return { _SECTOR = SectorNameGenerator.generateSectorName(x, y, 0, serverSeed) }
        end
    },
    {
        text = "We can do whatever we want! As pirates, we're free.", time = 154, sent = false
    },
    {
        text = "You think you can beat ME in a drinking contest? Ha! As if! ${_NAME}, get the grog!", time = 173, sent = false,
        format = true,
        formatFunc = function()
            local lang = Language(Seed(random():getFloat(0.0, 1000000.0)))
            return { _NAME = lang:getName() }
        end
    },
    {
        text = "What do we do when the piggies start getting froggy?", time = 192, sent = false, doNotClearScriptValue = true
    },
    {
        text = "Draxx them sklounst!", time = 195, sent = false, doNotClearScriptValue = true
    },
    {
        text = "Hypothetical them in the clavicle!", time = 198, sent = false, doNotClearScriptValue = true
    },
    { 
        text = "Fireboard those motherjammers!", time = 201, sent = false, doNotClearScriptValue = true
    },
    {
        text = "- You drive a hard bargain. Okay, ${_CREDITS} credits, but that's my final offer!", time = 211, sent = false,
        format = true,
        formatFunc = function()
            return { _CREDITS = createMonetaryString(random():getInt(100000, 1000000))}
        end
    },
    {
        text = "Have you ever punched a hole in a ship's crew quarters before? There's just... something majestic about watching the bodies tumble out.", time = 230, sent = false
    },
    {
        text = "... and he rammed his ship straight through the enemy's hull. That's why they call him Brute Gruznier.", time = 249, sent = false
    },
    {
        text = "We found some refugees hiding in the cargo bays. Spaced them, of course. Not like they were good for anything other than eating our food.", time = 268, sent = false
    },
    {
        text = "Boss Xinull wasn't too happy about how that last raid went. We lost a ton of ships and barely got any loot...", time = 287, sent = false
    },
    {
        text = "... well he says we're going to do another raid in a few cycles. Patch your hulls and make sure you stock up on torpedoes.", time = 306, sent = false, advancePhase = true
    }
}
mission.data.custom.sentLastTransmissionScriptValue = "_vbmn1_sent_last_transmission"

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.sectorCallbacks = {}

mission.globalPhase.onAbandon = function()
    setGameMusic()
    vengeStory1_piratesAggroOnFail()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    setGameMusic()
    vengeStory1_piratesAggroOnFail()
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

mission.globalPhase.updateTargetLocationServer = function(timeStep)
    local _sector = Sector()
    local _player = Player()
    local playerShips = 0

    local ships = { _sector:getEntitiesByType(EntityType.Ship) }
    for _, s in pairs(ships) do
        if s.playerOrAllianceOwned then
            playerShips = playerShips + 1
        end
    end

    local craft = Entity(_player.craftIndex)
    if craft.type == EntityType.Drone then
        mission.data.custom.droneTimer = mission.data.custom.droneTimer + timeStep

        if mission.data.custom.droneTimer >= 2 and not mission.data.custom.droneWarningSent then
            _player:sendChatMessage("", ChatMessageType.Information, "Get back in your ship. Your drone can't pick up the pirate transmissions.")
            mission.data.custom.droneWarningSent = true
        end

        if mission.data.custom.droneTimer >= 5 then
            vengeStory1_sendFailMessageAndFail("You'll need a ship for this! Your drone won't be able to pick up their transmissions.")
        end
    else
        mission.data.custom.droneTimer = 0
        mission.data.custom.droneWarningSent = false
    end

    if playerShips > 1 then
        vengeStory1_sendFailMessageAndFail("Don't bring in multiple ships! You need to keep a low profile.")
    end
    if playerShips == 0 then
        vengeStory1_sendFailMessageAndFail("You'll need a ship for this! Your drone won't be able to pick up their transmissions.")
    end
end

mission.globalPhase.onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)
    local destroyerEntity = Entity(lastDamageInflictor)

    if destroyedEntity and valid(destroyedEntity) and destroyedEntity:getValue("_vbmn1_pirate") and destroyerEntity.playerOrAllianceOwned then
        vengeStory1_sendFailMessageAndFail("Don't start any fights! You need to keep a low profile.")
    end
end

--No time limit to get to the sector, but we fail immediately on leaving.
mission.globalPhase.onTargetLocationLeft = function(_X, _Y)
    if mission.data.custom.allowedToLeaveSector then
        vengeStory1_finishAndReward()
    else
        fail()
    end
end

--region #GLOBALPHASE SECTOR CALLBACKS

mission.globalPhase.sectorCallbacks[1] = {
    name = "onDamaged",
    func = function(objectIndex, amount, inflictor, damageSource, damageType)
        local damagedEntity = Entity(objectIndex)
        local inflictorEntity = Entity(inflictor)

        --Don't fail the mission if a pirate bonks an asteroid.
        if inflictorEntity and valid(inflictorEntity) and inflictorEntity.playerOrAllianceOwned and damagedEntity:getValue("_vbmn1_pirate") then
            vengeStory1_sendFailMessageAndFail("Don't start any fights! You need to keep a low profile.")
        end
    end
}

mission.globalPhase.sectorCallbacks[2] = {
    name = "vbmnStory1WarnPicket",
    func = function()
        Player():sendChatMessage("", ChatMessageType.Information, "The picket ship has spotted you. Break line of sight with its scanning beam before it finishes scanning your ship.")
    end
}

mission.globalPhase.sectorCallbacks[3] = {
    name = "vbmnStory1FailPicket",
    func = function()
        vengeStory1_sendFailMessageAndFail("Don't let the picket ship scan you! Your cover is blown!")
    end
}

--endregion

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBegin = function()
    local giver = Entity(mission.data.giver.id)

    mission.data.description[1].arguments = { sectorName = Sector().name, giverTitle = giver.translatedTitle }
    mission.data.description[2].text = vengeStory1_formatDescription()
    mission.data.description[2].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    local methodName = "Phase 1 On Target Location Entered"
    mission.Log(methodName, "Running...")
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true

    if onServer() then
        local _player = Player()
        if _player:hasScript("events/alienattack.lua") then
            _player:removeScript("events/alienattack.lua")
            _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
        end
        vengeStory1_createObjectiveSector(x, y)
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    setCustomMusic("data/music/vengeance/averyalexandercovert.ogg")

    mission.phases[1].timers[1] = {
        time = 2,
        callback = function()
            local pirates = { Sector():getEntitiesByScriptValue("_vbmn1_cluster_pirate") }
            local challengePirate = getRandomEntry(pirates)

            invokeClientFunction(Player(), "vengeStory1_onChallengeDialog", challengePirate.id)
        end,
        repeating = false
    }
end

local vengeStory1_onChallengeDialogEndBad = makeDialogServerCallback("vengeStory1_onChallengeDialogEndBad", 1, function()
    fail()
end)

local vengeStory1_onChallengeDialogEndBad2 = makeDialogServerCallback("vengeStory1_onChallengeDialogEndBad2", 1, function()
    Player():setValue("encyclopedia_vbmn_nescient", true)
    fail()
end)

local vengeStory1_onChallengeDialogEndGood = makeDialogServerCallback("vengeStory1_onChallengeDialogEndGood", 1, function()
    nextPhase()
end)

local vengeStory1_onChallengeDialogEndGood2 = makeDialogServerCallback("vengeStory1_onChallengeDialogEndGood2", 1, function()
    Player():setValue("encyclopedia_vbmn_nescient", true)    
    nextPhase()
end)

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = false --We handle this manually.
mission.phases[2].updateInterval = 0.25 --Update more quickly than usual.
mission.phases[2].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[6].visible = true
    mission.data.description[7].visible = true
end

mission.phases[2].onBeginServer = function()
    --Allison tells the player good job.
    Player():sendChatMessage("Unknown Source", ChatMessageType.Normal, "Good job. You're in. Wasn't sure if you could handle that. Make sure to keep an asteroid between you and that picket ship - don't let it get a lock on you or they'll know you're listening in.")

    --Activate the picket ship.
    local pickets = { Sector():getEntitiesByScriptValue("_vbmn1_picket_ship") }
    local piratePicket = pickets[1]
    piratePicket:invokeFunction("vengeance1picket.lua", "resetTimeToActive", 30)
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 2 Update Target Location Server"
    mission.data.custom.dialogTimer = mission.data.custom.dialogTimer + timeStep

    local _sector = Sector()
    local _player = Player()
    
    --Handle proximity warnings.
    vengeStory1_handleProximity(_sector, _player, timeStep)

    --Handle transmissions.
    for _, transmission in pairs(mission.data.custom.transmissionTable) do
        if mission.data.custom.dialogTimer >= transmission.time and not transmission.sent then
            --Get pirate table
            local transmissionPirate = vengeStory1_getNextTransmissionPirate(_sector)

            if not transmission.doNotClearScriptValue then
                vengeStory1_clearTransmissionScriptValue(_sector)
            end

            if transmission.format then
                local formatArgs = transmission.formatFunc()
                _sector:broadcastChatMessage(transmissionPirate, ChatMessageType.Chatter, transmission.text % formatArgs)
            else
                _sector:broadcastChatMessage(transmissionPirate, ChatMessageType.Chatter, transmission.text)
            end
            transmissionPirate:setValue(mission.data.custom.sentLastTransmissionScriptValue, true) --Avoid sending a transmission from the same ship twice in a row.
            transmission.sent = true

            if transmission.advancePhase then
                mission.Log(methodName, "Advancing phase.")
                nextPhase()
            end
        end
    end
end

mission.phases[2].onPreRenderHud = function()
    vengeStory1_onPreRenderHud()
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].updateInterval = 0.25 --Update more quickly than usual.
mission.phases[3].updateTargetLocationServer = function(timeStep)
    --Handle proximity warnings.
    vengeStory1_handleProximity(Sector(), Player(), timeStep)
end

mission.phases[3].onPreRenderHud = function()
    vengeStory1_onPreRenderHud()
end

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 5, 
    callback = function() 
        Player():sendChatMessage("Unknown Source", ChatMessageType.Normal, "There it is. That was the information I was looking for. You're good to leave now - get out of there before they get suspicious!")
        
        mission.data.custom.allowedToLeaveSector = true

        mission.data.description[6].fulfilled = true
        mission.data.description[8].visible = true

        showMissionUpdated()

        sync()
    end,
    repeating = false --We fail the mission if we leave the sector before this timer so we don't need to worry about this going off with the player in another sector.
}

mission.phases[3].timers[2] = {
    time = 20, 
    callback = function()
        local _sector = Sector()
        local transmissionPirate = vengeStory1_getNextTransmissionPirate(_sector)

        _sector:broadcastChatMessage(transmissionPirate, ChatMessageType.Chatter, "That new ship has been quiet for a while. How do we know it's not listening in? It could be a spy...")
        transmissionPirate:setValue(mission.data.custom.sentLastTransmissionScriptValue, true)
    end,
    repeating = false --We don't need to worry about this going off if the player is in another sector, since they win.
}

mission.phases[3].timers[3] = {
    time = 30, 
    callback = function()
        local _sector = Sector()
        local transmissionPirate = vengeStory1_getNextTransmissionPirate(_sector)

        _sector:broadcastChatMessage(transmissionPirate, ChatMessageType.Chatter, "May as well kill them, just to be safe. Power up those weapons, boys and girls!")
        transmissionPirate:setValue(mission.data.custom.sentLastTransmissionScriptValue, true)
    end,
    repeating = false --We don't need to worry about this going off if the player is in another sector, since they win.
}

mission.phases[3].timers[4] = {
    time = 40, 
    callback = function()
        vengeStory1_piratesAggroOnFail()
        fail()
    end,
    repeating = false --We don't need to worry about this going off if the player is in another sector, since they win.
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory1_createObjectiveSector(x, y)
    local _player = Player()
    local _random = random()

    local generator = SectorGenerator(x, y)    
    --create heavy asteroid fields
    for _ = 1, 6 do
        generator:createAsteroidField()
    end

    for _ = 1, 5 do
        generator:createSmallAsteroidField()
    end
    
    --create a few small clusters of pirate ships. Make them all at least 20 km from where the player's ship is.
    local craft = Entity(_player.craftIndex)
    local basePos = vec3(0, 0, 0)

    if craft then
        basePos = craft.translationf
    end

    for _ = 1, 4 do
        local clusterPos = ESCCUtil.getVectorAtDistance(basePos, _random:getInt(2000, 4000), true)
        vengeStory1_createPirateCluster(clusterPos)
    end

    --create picket ship
    local picketGenerator = AsyncPirateGenerator(nil, vengeStory1_onPiratePicketFinished)

    picketGenerator:startBatch()

    picketGenerator:createScaledRaider(picketGenerator:getGenericPosition())

    picketGenerator:endBatch()

    mission.data.custom.cleanUpSector = true
end

function vengeStory1_createPirateCluster(pos)
    local _random = random()

    --Get a table of ships.
    local pirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 4, "Standard", false)

    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory1_onPirateClusterFinished)

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

function vengeStory1_onPirateClusterFinished(generated)
    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)

    for _, p in pairs(generated) do
        local pirateAI = ShipAI(p)
        pirateAI:setPassive()

        --Make them extremely dangerous - even more so than usual. You're here to spy on them, not fight them!
        ESCCUtil.multiplyOverallDurability(p, 50)
        p.damageMultiplier = (p.damageMultiplier or 1) * 50

        p:setValue("bDisableXAI", true) --AI is handled by this mission.
        p:setValue("_vbmn1_pirate", true)
        p:setValue("_vbmn1_cluster_pirate", true)
    end
end

function vengeStory1_onPiratePicketFinished(generated)
    local piratePicket = generated[1]

    piratePicket.title = "Picket Ship"
    ESCCUtil.replaceIcon(piratePicket, "data/textures/icons/pixel/patrol.png")

    piratePicket:setValue("bDisableXAI", true) --AI is handled by patrolpeacefully script.
    piratePicket:setValue("_vbmn1_pirate", true)
    piratePicket:setValue("_vbmn1_picket_ship", true)
    piratePicket:addScriptOnce("ai/patrolpeacefully.lua")

    local vbmnPicketValues = {
        _TimeToActive = math.huge,
        _pindex = Player().index,
        _MaxAlertTime = mission.data.custom.maxProximityTimer
    }

    piratePicket:addScriptOnce("player/missions/vengeance/story1/vengeance1picket.lua", vbmnPicketValues)
    piratePicket:addMultiplier(StatsBonuses.Velocity, 1.5)
    piratePicket:addMultiplier(StatsBonuses.Acceleration, 1.25)    
end

function vengeStory1_getNextTransmissionPirate(_sector)
    local pirateTable = { _sector:getEntitiesByScriptValue("_vbmn1_cluster_pirate") }
    local finalPirateTable = {}

    for _, p in pairs(pirateTable) do
        if not p:getValue(mission.data.custom.sentLastTransmissionScriptValue) then
            table.insert(finalPirateTable, p)
        end
    end

    return getRandomEntry(finalPirateTable)
end

function vengeStory1_clearTransmissionScriptValue(_sector)
    local pirateTable = { _sector:getEntitiesByScriptValue("_vbmn1_pirate") }

    for _, p in pairs(pirateTable) do
        p:setValue(mission.data.custom.sentLastTransmissionScriptValue, nil)
    end
end

function vengeStory1_handleProximity(_sector, _player, timeStep)
    local chameleonScriptPath = "internal/dlc/blackmarket/systems/badcargowarningsystem.lua"
    
    local pirateTable = { _sector:getEntitiesByScriptValue("_vbmn1_cluster_pirate") }
    local pCraft = Entity(_player.craftIndex)

    local incrementProximityTimer = false
    for _, p in pairs(pirateTable) do
        local susDistance = 2000
        if pCraft:hasScript(chameleonScriptPath) then
            local ret, detectionRangeFactor = pCraft:invokeFunction(chameleonScriptPath, "getDetectionRangeFactor")
            if ret == 0 then
                susDistance = susDistance * detectionRangeFactor
            end
        end

        if pCraft:getNearestDistance(p) < susDistance then
            if not mission.data.custom.proximityWarningSent then
                _player:sendChatMessage("", ChatMessageType.Information, "Your ship ${_PLAYERSHIP} is too close to the pirate ${_ENEMYTITLE} ${_ENEMYSHIP}. Move 20 km away before it can scan you." % { _PLAYERSHIP = pCraft.name, _ENEMYTITLE = p.translatedTitle, _ENEMYSHIP = p.name})
                mission.data.custom.proximityWarningSent = true
            end
            p:setValue("_vbmn1_sus_alert", true)
            incrementProximityTimer = true
        else
            p:setValue("_vbmn1_sus_alert", nil)
        end
    end

    if incrementProximityTimer then
        mission.data.custom.proximityTimer = mission.data.custom.proximityTimer + timeStep
        sync()
    else
        mission.data.custom.proximityWarningSent = false
        mission.data.custom.proximityTimer = 0
    end

    if mission.data.custom.proximityTimer >= mission.data.custom.maxProximityTimer then
        vengeStory1_sendFailMessageAndFail("Your cover is blown! Don't get too close to the enemy ships!")
    end 
end

--The first time I've had so many faliure conditions on a mission that I've needed a helper function for this.
function vengeStory1_sendFailMessageAndFail(msg)
    if not mission.data.custom.failMessageSent then
        Player():sendChatMessage("Unknown Source", ChatMessageType.Normal, msg)
        mission.data.custom.failMessageSent = true
    end
    fail()
end

function vengeStory1_piratesAggroOnFail()
    --Set any pirates in the sector to aggressive.
    local pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    for _, p in pairs(pirates) do
        if p:hasScript("vengeance1picket.lua") then
            p:invokeFunction("vengeance1picket.lua", "setKillSwitch")
        end
        local pirateAI = ShipAI(p)
        pirateAI:setAggressive()
    end
end

--Win condition
function vengeStory1_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()
    _player:setValue("_vengeancebmn_story_stage", 2)
    _player:setValue("encyclopedia_vbmn_pirates", true)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory1_onPreRenderHud()
    local player = Player()
    if not player then return end

    local _Ship = Entity(player.craftIndex)

    if not _Ship then
        return
    end

    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()
    local _sector = Sector()

    local pirateClusterShips = { _sector:getEntitiesByScriptValue("_vbmn1_cluster_pirate") }

    for _, ship in pairs(pirateClusterShips) do
        local dist = ship:getNearestDistance(_Ship)
        if dist <= mission.data.custom.phase2ShipHighlightRange then
            local rColor = 255
            local bColor = 0
            local gColor = 127
            if dist <= mission.data.custom.phase2ShipUrgentHighlightRange then
                gColor = 0
            end

            local warningColor = ESCCUtil.getSaneColor(rColor, gColor, bColor)

            local v2, size = renderer:calculateEntityTargeter(ship)

            renderer:renderEntityTargeter(ship, warningColor, size * 1.25)
            renderer:renderEntityArrow(ship, 30, 10, 250, warningColor)

            if ship:getValue("_vbmn1_sus_alert") then
                local timeUntilAlert = mission.data.custom.maxProximityTimer - mission.data.custom.proximityTimer

                local rect = Rect(v2.x - size, v2.y + (size * 0.75), v2.x + size, v2.y + size)
                drawTextRect(string.format("Time until alerted: %02d:%05.2f", 0, math.max(0.1, timeUntilAlert)), rect, 0, 0, ColorRGB(1.0, 1.0, 1.0), 10, false, false, 2)
            end
        end
    end

    local picketShips = { _sector:getEntitiesByScriptValue("_vbmn1_picket_ship") }
    for _, ship in pairs(picketShips) do
        local warningColor = ESCCUtil.getSaneColor(255, 0, 0)

        local _, size = renderer:calculateEntityTargeter(ship)

        renderer:renderEntityTargeter(ship, warningColor, size * 1.25)
        renderer:renderEntityArrow(ship, 30, 10, 250, warningColor)
    end

    renderer:display()
end

function vengeStory1_onChallengeDialog(pirateID)
    local d0 = {}
    local d1 = {}
    local d1a = {}
    local d1b = {}
    local d1realCrime = {}
    local d1wussCrime = {}
    local d1c = {}
    local d1d = {}
    local d1e = {}
    local d2 = {}
    local d3 = {}
    local d3hostage = {}
    local d3recharge = {}
    local d3hostageok = {}
    local d3hostagebad = {}
    local d3a = {}
    local d4 = {}
    local d4a = {}
    local d4b = {}
    local d5 = {}
    local dsecureChannel1 = {}
    local dsecureChannel2 = {}
    local dsecureChannel3 = {}
    local dsecureChannel4 = {}
    local dsecureChannel5 = {}
    local dsecureChannel6 = {}

    d0.text = "Well, well, well. What have we here?"
    d0.answers = {
        { answer = "Um. Your new friend?", followUp = d1 },
        { answer = "Your newest recruit! Reporting for duty!", followUp = d2 },
        { answer = "I don't want to be here...", followUp = d3 }
    }
    
    local foundArtifacts = MissionUT.detectFoundArtifacts(Player())
    if foundArtifacts[3] then
        table.insert(d0.answers, { answer = "It's okay. Swoks sent me.", followUp = d4 })
    end

    table.insert(d0.answers, { answer = "Nobody, goodbye.", followUp = d5 })

    --"Um. Your new friend?" branch

    d1.text = "Friend? We don't make friends around here. What's your angle?"
    d1.answers = {
        { answer = "I want to be a pirate.", followUp = d1b },
        { answer = "I'm on the run.", followUp = d1a }
    }
    
    d1a.text = "On the run, huh? What dd you do to get kicked out of polite society?"
    d1a.answers = {
        { answer = "I blackmailed a politican from a nearby faction.", followUp = d1wussCrime },
        { answer = "I slaughtered the crew of a civilian ship.", followUp = d1realCrime }
    }

    d1b.text = "You WANT to be a pirate? Let me let you in on a little secret. Nobody here WANTS to be a pirate. The only reason we're here is because we did something. Something that made it so nobody looked at us the same way anymore. We couldn't function in society, so now we're here on the margins. You're either an opportunist or a fool. Either way, you're dead."
    d1b.onEnd = vengeStory1_onChallengeDialogEndBad

    d1realCrime.text = "HA! Now that's hardcore. Maybe you'll fit in with our little band of misfits after all. How did it feel, hearing their screams and their pleas for mercy as you butchered them?"
    d1realCrime.answers = {
        { answer = "It was a rush. I've never felt more alive.", followUp = d1c },
        { answer = "I felt nothing. It was just business.", followUp = d1d },
        { answer = "It was horrifying. I'm still learning to live with it.", followUp = d1e }
    }

    d1c.text = "Holy shit! You must be some sort of psycho. Killing is all well and good, but we don't need rabid dogs like you around here attracting attention. You kill one of those faction ships, and it's only a matter of time before they come sniffing. Alright, everyone! Time to put this captain down."
    d1c.onEnd = vengeStory1_onChallengeDialogEndBad

    d1d.text = "Just business? That's how it should be. Sure, we kill people - lots of people, even. Sometimes we enjoy it. But at the end of the day, that's all it is. Business. Welcome aboard, Captain. We think you'll fit in just fine. Stay out of the way until you can learn the ropes."
    d1d.followUp = dsecureChannel1

    d1e.text = "A little soft, aren't you? You're not going to hack it here with a pathetic attitude like that. It's only a matter of time before you let your conscience get the better of you. Don't worry, we'll kill you now and save you from your own guilt."
    d1e.onEnd = vengeStory1_onChallengeDialogEndBad

    d1wussCrime.text = "Really? That's it. What a weak crime - in some places, that may as well be legal. We don't need soft scum like you around. Time to die, Captain."
    d1wussCrime.onEnd = vengeStory1_onChallengeDialogEndBad

    --"Your newest recruit! Reporting for duty!" branch. Well, "branch" - this one is short.

    d2.text = "Earnest one, aren't you? Nobody talks like that around here. Did you roll out of the newest Military Outpost looking for an internship? Kill this idiot."
    d2.onEnd = vengeStory1_onChallengeDialogEndBad

    --"I don't want to be here..." branch

    d3.text = "Is that so? You can leave, or you can die. You may not be the one making that decision, though..."
    d3.answers = {
        { answer = "Wait!", followUp = d3a }
    }

    d3a.text = "Well... we're waiting."
    d3a.answers = {
        { answer = "My family is being held hostage.", followUp = d3hostage },
        { answer = "I had a nav error. Can I stay while my hyperspace engine recharges?", followUp = d3recharge }
    }

    d3hostage.text = "Ha! Just like those idiots running that freighter caravan we strongarmed last week. Some cowboy captain blew up our shipyard and freed them, though. Bah! I'm still pissed about that. You don't have a bulletin out for your rescue, do you?"
    d3hostage.answers = {
        { answer = "No, I don't.", followUp = d3hostagebad },
        { answer = "They were taken yesterday.", followUp = d3hostageok }
    }

    d3hostageok.text = "Heh. Is that so? Maybe we'll get a few days out of you yet. Alright, everyone! We can let the new maggot stick around for now. Keep your head down, maggot, and take a cue from us real pirates. If you can make it a few cycles without dying, maybe you'll learn something."
    d3hostageok.followUp = dsecureChannel1

    d3hostagebad.text = "How do you know that? Do you know how many people you interact with on a regular basis? How can you be so sure that one of them won't miss you and put up a bounty? No. We can't take that kind of risk. Time to die, Captain."
    d3hostagebad.onEnd = vengeStory1_onChallengeDialogEndBad

    d3recharge.text = "Sure. You can stay. We're going to loot your ship and laugh at your dying screams as we vent you from the nearest airlock. That should give you plenty of time for your hyperspace drive to recharge, right?"
    d3recharge.onEnd = vengeStory1_onChallengeDialogEndBad

    --"It's okay. Swoks sent me." branch

    d4.text = "Swoks? That loser? Listen kid, I don't know how you do things out in the Iron Wastes, but we're real pirates doing real pirating here."
    d4.answers = {
        { answer = "You don't understand.", followUp = d4a }
    }

    d4a.text = "What's there to understand? Swoks may fancy himself some pirate boss, but he has no authority out here. As his lackey, you have nothing. Get out of here before we turn you to space dust."
    d4a.answers = {
        { answer = "Swoks is dead. I AM Swoks.", followUp = d4b }
    }

    d4b.text = "Oh, you're the new Swoks? Well why didn't you say so! We'll show you a thing or two about how real pirates operate, kid! Just stay out of our way until you learn the ropes."
    d4b.followUp = dsecureChannel1

    --"Nobody, goodbye." branch. Well, "branch" - this one is also short.

    d5.text = "Nobody, huh? We've been hearing about a wanted captain joining up with us. Didn't know they'd be such a pussy. Kill them."
    d5.onEnd = vengeStory1_onChallengeDialogEndBad

    dsecureChannel1.text = "Oh yes. One more thing before you go."
    dsecureChannel1.answers = {
        { answer = "What is it?", followUp = dsecureChannel2 }
    }

    local genders = {
        { g1 = "he", g2 = "his" },
        { g1 = "she", g2 = "her" },
        { g1 = "they", g2 = "their" },
        { g1 = "it", g2 = "its" }
    }
    local selectedGender = getRandomEntry(genders)

    dsecureChannel2.text = "Stay off the secure channels. Those are only for the initiated. The last captain we caught monitoring us... well, let's just say that ${_GENDER} sucked vacuum in front of ${_GENDER2} whole crew. Smile." % { _GENDER = selectedGender.g1, _GENDER2 = selectedGender.g2 }
    dsecureChannel2.answers = {
        { answer = "Um. Understood.", followUp = dsecureChannel3 },
        { answer = "Did you just say 'smile' out loud?", followUp = dsecureChannel4 }
    }

    dsecureChannel3.text = "Good. I'm glad that you do. Now scram. We have important matters to discuss."
    dsecureChannel3.onEnd = vengeStory1_onChallengeDialogEndGood

    dsecureChannel4.text = "I did. What are you going to do about it?"
    dsecureChannel4.answers = {
        { answer = "Nothing.", followUp = dsecureChannel5 },
        { answer = "I'll kill you, you nescient bastard.", followUp = dsecureChannel6 }
    }

    dsecureChannel5.text = "Good. now scram. We have important matters to discuss. Smile."
    dsecureChannel5.onEnd = vengeStory1_onChallengeDialogEndGood2

    dsecureChannel6.text = "Really. After everything else, that's the hill you want to die on? Well, we'll be happy to oblige."
    dsecureChannel6.onEnd = vengeStory1_onChallengeDialogEndBad2


    ScriptUI(pirateID):interactShowDialog(d0, false)
end

--endregion

--region #MAKEBULLETIN CALL

function vengeStory1_formatDescription()
    return "Listen up! I'm looking for a partner to work with. This is going to be a long-term, multi-part job. Ideally, you'll be able to handle yourself in a fight, but I also want someone who can manage some sneaking around as well. We'll start things off with a simple recon job. There's a group of pirates gathering in (${_X}:${_Y}), and I want to know more about them. Get in, listen in to their transmissions, and get out. Keep a low profile and avoid any fights. If you don't screw it up, I'll contact you with your reward and more details."
end

mission.makeBulletin = function(station)
    local methodName = "Make Bulletin"
    mission.Log(methodName, "Making Bulletin.")

    local target = {}
    local x, y = Sector():getCoordinates()
    target.x, target.y = MissionUT.getEmptySector(x, y, 4, 10, false)

    if not target.x or not target.y then
        mission.Log(methodName, "Target.x or Target.y not set - returning nil.")
        return
    end
 
    reward = ESCCUtil.clampToNearest(300000 * Balancing.GetSectorRewardFactor(x, y), 5000, "Up")

    local bulletin = {
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = vengeStory1_formatDescription(),
        difficulty = "Medium",
        reward = "¢${reward}",
        script = "missions/vengeance/vengeancestory1.lua",
        formatArguments = {_X = target.x, _Y = target.y, reward = createMonetaryString(reward)},
        msg = "The pirates are in \\s(%1%:%2%). Go there and report back.",
        giverTitle = station.title,
        giverTitleArgs = station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/vengeance/vengeancestory1.lua") 
               or player:getValue("_vengeancebmn_story_stage") > 1 then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission again.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments._X, self.formatArguments._Y)
        ]],

        --data that's important to the mission
        arguments = {{
            giver = station.index,
            location = target,
            reward = {credits = reward, paymentMessage = "Earned %1% credits for spying on the pirates."}
        }},
    }

    return bulletin
end

--endregion