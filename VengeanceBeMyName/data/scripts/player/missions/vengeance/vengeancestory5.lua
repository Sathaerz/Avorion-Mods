--[[
Blockbuster
- Destroy 2 jamming installations, and then destroy a military outpost with a large fleet guarding it.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
VengeUtil = include("vbmnutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local PirateGenerator = include("pirategenerator")
local ShipUtility = include ("shiputility")
local PlanGenerator = include("plangenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Blockbuster"

--region # INIT / DATA

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/firing-ship.png"
mission.data.priority = 9
mission.data.description = {
    { text = "You helped Allison capture a pirate Jammer from a nearby shipyard. Afterwards, she informed you that you would take point for the second phase of the operation." },
    { text = "Read Allison's mail", bulletPoint = true, fulfilled = false }, 
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Head to sector (${_X2}:${_Y2})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Do not jump another ship into the sector", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirate communications relays - ${_COMMKILLED} / 2 destroyed", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Do not let the pirates contact the fortress", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Protect the Jammer", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Protect the Adarasteia Missile Cruisers", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Don't lose too many Cruisers - ${_CSRLOST} / 3 lost", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the pirate Arms Fortress", bulletPoint = true, fulfiled = false, visible = false },
    { text = "Clean up the pirate remnants", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Talk to Allison", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 8 --Key everything off of danger 8.
mission.data.custom.weakPirateDangerLevel = 6 --Used for comm relay groups / jammer attack waves later in the mission
mission.data.custom.commsRelaysKilled = 0
mission.data.custom.phase4E2EProximityWarningSent = false
mission.data.custom.phase4PlayerProximityTimer = 0
mission.data.custom.phase4PlayerProximityWarningSent = false
mission.data.custom.phase4DamageSusAlertSent = false
mission.data.custom.phase5AttackEvents = false
mission.data.custom.phase5AttackTimer = 0
mission.data.custom.phase5AttackChatter1Sent = false
mission.data.custom.phase5AttackChatter2Sent = false
mission.data.custom.phase5AttackChatter3Sent = false
mission.data.custom.allowPhase5EndgameDialog = false
mission.data.custom.phase5EndgameDialogTimer = 0
mission.data.custom.missileShipsLost = 0
mission.data.custom.phase5PirateWaveCounter = -1
mission.data.custom.phase5PirateTorpWaveBuffCounter = -1
--Tweak as needed for balance.
mission.data.custom.playerProximityDistance = 1500
mission.data.custom.armsFortGroupProximityDistance = 1500
mission.data.custom.e2eProximityMaxTimer = 16
mission.data.custom.playerProximityMaxTimer = 16
mission.data.custom.damageSusAlertMaxTime = 16
mission.data.custom.commRelayActivateTime = 40

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.globalPhase.onAbandon = function()
    vengeStory5_piratesAggro()

    --Friendly ships depart
    vengeStory5_friendlyShipsDepart(true)

    --Set fail music
    local armsFort = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_arms_fortress")
    if armsFort and valid(armsFort) then
        invokeClientFunction(Player(), "vengeStory5_armsFortSetFailureMusic", armsFort.index)
        CargoBay(armsFort):clear()
        vengeStory5_addDefenseController(armsFort, Sector())
    end

    --Don't send fail mail. Music cleanup is np since we are not using custom music for this one.

    --Set sector cleanup
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    setGameMusic()
    
    --Fail once we are in the main sector.
    local phaseIndexFuncTable = {
        nil, --Phase 1 has no location
        nil, --Phase 2 is meeting with Allison.
        nil, --Phase 3 basically only spawns the sector
        function() --Phase 4 is the stealth phase - fail.
            vengeStory5_sendFailMail(2)
            fail()
        end,
        function() --Phase 5 is the attack phase - fail.
            vengeStory5_sendFailMail(2)
            fail()
        end
    }

    local phaseIdx = mission.internals.phaseIndex
    if phaseIndexFuncTable[phaseIdx] then
        phaseIndexFuncTable[phaseIdx]()
    end
end

mission.phases[1] = {} --Read mail phase
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBegin = function()
    mission.data.description[6].arguments = { _COMMKILLED = mission.data.custom.commsRelaysKilled }
    mission.data.description[10].arguments = { _CSRLOST = mission.data.custom.missileShipsLost }
end

mission.phases[1].onBeginServer = function()
    local methodName = "Phase 1 On Begin Server"
    mission.Log(methodName, "Starting...")

    mission.data.custom.meetSector = vengeStory5_getNextLocation(true)

    if not mission.data.custom.meetSector then
        print("WARNING! Could not find suitable sector in 210 - 290 distance.")
        terminate()
        return
    end

    local x = mission.data.custom.meetSector.x
    local y = mission.data.custom.meetSector.y

    mission.data.description[3].arguments = { _X = x, _Y = y }

    sync()

    local _player = Player()
    local _mail = Mail()
    _mail.text = Format("Hello again.\n\nIt's time. Meet in me in sector (%1%:%2%). I'll explain the plan over short-wave radio. There's too much at stake to risk a third party reading this mail.\n\nAllison", x, y)
    _mail.header = "Plan Phase Two"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story5_mail1"
    _player:addMail(_mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(playerIndex, mailIndex)
			if onServer() then
				local _mail = Player():getMail(mailIndex)
				if _mail.id == "_vbmn_story5_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {} --Talk to Allison phase
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    local methodName = "Phase 2 On Begin"
    mission.Log(methodName, "Starting...")

    mission.data.location = mission.data.custom.meetSector

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(x, y)
    if onServer() then
        vengeStory5_removeXsotanEvent()
        vengeStory5_spawnAllison()
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(x, y)
    invokeClientFunction(Player(), "vengeStory5_onPhase2Dialog", mission.data.custom.allisonID)
end

local vengeStory5_onPhase2DialogEnd = makeDialogServerCallback("vengeStory5_onPhase2DialogEnd", 2, function()
    mission.data.custom.opSector = vengeStory5_getNextLocation(false)

    local x = mission.data.custom.opSector.x
    local y = mission.data.custom.opSector.y

    mission.data.description[4].arguments = { _X2 = x, _Y2 = y }

    local allison = Entity(mission.data.custom.allisonID)
    if allison and valid(allison) then
        allison:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end

    Player():setValue("_vbmn5_heardplan", true)

    nextPhase()
end)

mission.phases[3] = {} --Go to location phase
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBegin = function()
    local methodName = "Phase 3 On Begin"
    mission.Log(methodName, "Beginning...")

    mission.data.location = mission.data.custom.opSector

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
end

mission.phases[3].onTargetLocationEntered = function(x, y)
    if onServer() then
        vengeStory5_removeXsotanEvent()
        vengeStory5_createObjectiveSector(x, y)
    end
end

mission.phases[3].onTargetLocationArrivalConfirmed = function(x, y)
    nextPhase()
end

mission.phases[4] = {} --Sneaky phase - destroy comm arrays / pirate groups with only one ship available
mission.phases[4].timers = {}
mission.phases[4].triggers = {}
mission.phases[4].sectorCallbacks = {}
mission.phases[4].updateInterval = 0.25 --Update more quickly than usual.
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true
    mission.data.description[7].visible = true
    mission.data.description[8].visible = true
end

mission.phases[4].onBeginServer = function()
    vengeStory5_spawnAdrasteiaJammer()
end

mission.phases[4].onEntityDestroyed = function(id, lastDamageInflictor)
    local destroyedEntity = Entity(id)
    
    if destroyedEntity and valid(destroyedEntity) then
        if destroyedEntity:getValue("_vbmn5_objective_jammer") then
            vengeStory5_handleFailure(1)
        end

        local killedCommsRelay = false
        if destroyedEntity:getValue("_vbmn5_comm_relay1") or destroyedEntity:getValue("_vbmn5_comm_relay2") then
            killedCommsRelay = true
        end

        --There are a lot of branching paths depending on what value it has.
        if destroyedEntity:getValue("_vbmn5_comm_relay_1_group") then
            vengeStory5_handleCommRelayGroupActivated("_vbmn5_comm_relay_1_group")
        end

        if destroyedEntity:getValue("_vbmn5_comm_relay_2_group") then
            vengeStory5_handleCommRelayGroupActivated("_vbmn5_comm_relay_2_group")
        end

        if killedCommsRelay then
            mission.data.custom.commsRelaysKilled = mission.data.custom.commsRelaysKilled + 1
            mission.data.description[6].arguments = { _COMMKILLED = mission.data.custom.commsRelaysKilled }
            sync()
        end

        if destroyedEntity:getValue("_vbmn5_arms_fort_group") or destroyedEntity:getValue("_vbmn5_arms_fortress") then
            vengeStory5_handleFailure(7)
        end
    end
end

--========================
--HANDLES PROXIMITY / DAMAGE SUS ALERTS
--========================
mission.phases[4].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 4 Update Target Location Server"
    --mission.Log(methodName, "Running...") --Be careful about enabling this due to spam.
    local _sector = Sector()
    local _player = Player()

    --Check enemy <=> enemy proximity
    local proximityCheckEntities = { _sector:getEntitiesByScriptValue("_vbmn5_proximity_check") }
    local proximityCheckAgainstEntities = { _sector:getEntitiesByScriptValue("_vbmn5_arms_fort_group") }
    local incrementE2EProximity = false
    local incrementPlayerProximity = false
    local incrementDamageSusAlert = false
    local e2eHighestProximityTimer = 0 --If this ever goes over the max value, the mission is failed.
    local highestDmgSusAlertTimer = 0 --If this goes above the max value, the ship alerts its group.

    for _, proxCheck in pairs(proximityCheckEntities) do
        for _, proxCheckAgainst in pairs(proximityCheckAgainstEntities) do
            --mission.Log(methodName, "Checking distance of " .. proxCheck.name .. " against " .. proxCheckAgainst.name) --Be careful about enabling this due to spam.
            local dist = proxCheck:getNearestDistance(proxCheckAgainst)

            if dist < mission.data.custom.armsFortGroupProximityDistance then
                if not mission.data.custom.phase4E2EProximityWarningSent then
                    mission.data.custom.phase4E2EProximityWarningSent = true
                    _player:sendChatMessage("", ChatMessageType.Information, "The pirate ${_ENEMYTITLE} ${_ENEMYSHIP} has contacted the arms fortress group. Destroy it before it can alert them!" % {_ENEMYTITLE = proxCheck.translatedTitle, _ENEMYSHIP = proxCheck.name})
                end
                incrementE2EProximity = true
                local newProxTimerValue = (proxCheck:getValue("_vbmn5_enemy_proximity_timer") or 0) + timeStep
                proxCheck:setValue("_vbmn5_enemy_proximity_timer", newProxTimerValue)
                if newProxTimerValue > e2eHighestProximityTimer then
                    e2eHighestProximityTimer = newProxTimerValue
                end
                break --only once per outer loop.
            end
        end
    end

    --Check enemy <=> player proximity. Unlike mission 1 you do not fail the mission, but the enemies will get spooked and run for the arms fort group.
    local playerCraft = Entity(_player.craftIndex)
    local commRelayGroup = nil --Set to a string value indicating which group is closest.
    if playerCraft then
        --It is highly, highly unlikely that the player is in proximity with both comms groups. Just assume they're too close to the first comm group and go with that.
        local p2eProximityCheckAgainstEntities = { _sector:getEntitiesByScriptValue("_vbmn5_check_comm_relay_player_proximity") }
        for _, proxCheckAgainst in pairs(p2eProximityCheckAgainstEntities) do
            if not proxCheckAgainst:getValue("_vbmn5_orders_sent") then
                local playerShipName = playerCraft.name
                local enemyTitle = proxCheckAgainst.translatedTitle
                local enemyName =  proxCheckAgainst.name

                --========================
                --HANDLE PROXIMITY CHECK
                --========================
                local dist = playerCraft:getNearestDistance(proxCheckAgainst)

                if dist < mission.data.custom.playerProximityDistance then
                    if not mission.data.custom.phase4PlayerProximityWarningSent then
                        mission.data.custom.phase4PlayerProximityWarningSent = true
                        _player:sendChatMessage("", ChatMessageType.Information, "Your ship ${_PLAYERSHIP} is too close to the pirate ${_ENEMYTITLE} ${_ENEMYSHIP}! Move 15km away or it will alert its group!" % { _PLAYERSHIP = playerShipName, _ENEMYTITLE = enemyTitle, _ENEMYSHIP = enemyName})
                    end
                    incrementPlayerProximity = true
                    commRelayGroup = proxCheckAgainst:getValue("_vbmn5_comm_relay_alert_group")
                    proxCheckAgainst:setValue("_vbmn5_sus_alert", true)
                else
                    proxCheckAgainst:setValue("_vbmn5_sus_alert", nil)
                end

                --========================
                --HANDLE DAMAGE SUS CHECK
                --========================
                local dura = proxCheckAgainst.durability
                local maxDura = proxCheckAgainst.maxDurability
                local hpRatio = dura / maxDura
                if hpRatio < 0.5 then
                    if not mission.data.custom.phase4DamageSusAlertSent then
                        mission.data.custom.phase4DamageSusAlertSent = true
                        _player:sendChatMessage("", ChatMessageType.Information, "The pirate ${_ENEMYTITLE} ${_ENEMYSHIP} is damaged! It will alert its group soon." % { _ENEMYTITLE = enemyTitle, _ENEMYSHIP = enemyName})
                    end
                    local dmgSusAlertTime = (proxCheckAgainst:getValue("_vbmn5_damage_sus_alert") or 0) + timeStep

                    if dmgSusAlertTime > highestDmgSusAlertTimer then
                        highestDmgSusAlertTimer = dmgSusAlertTime
                    end

                    proxCheckAgainst:setValue("_vbmn5_damage_sus_alert", dmgSusAlertTime)
                    incrementDamageSusAlert = true
                    commRelayGroup = proxCheckAgainst:getValue("_vbmn5_comm_relay_alert_group")
                end
            else
                --Clear sus alerts.
                proxCheckAgainst:setValue("_vbmn5_damage_sus_alert", nil)
                proxCheckAgainst:setValue("_vbmn5_sus_alert", nil)
            end
        end
    end

    if not incrementE2EProximity then
        mission.data.custom.phase4E2EProximityWarningSent = false
    end

    if e2eHighestProximityTimer > mission.data.custom.e2eProximityMaxTimer then
        mission.Log(methodName, "highest e2e prox timer is " .. tostring(e2eHighestProximityTimer) .. " failing.")
        vengeStory5_handleFailure(3)
    end

    if incrementPlayerProximity then
        mission.data.custom.phase4PlayerProximityTimer = mission.data.custom.phase4PlayerProximityTimer + timeStep
        sync()
    else
        mission.data.custom.phase4PlayerProximityTimer = 0
        mission.data.custom.phase4PlayerProximityWarningSent = false
    end

    if not incrementDamageSusAlert then
        mission.data.custom.phase4DamageSusAlertSent = false
    end

    if mission.data.custom.phase4PlayerProximityTimer > mission.data.custom.playerProximityMaxTimer then
        if commRelayGroup then --should be not nil but we check just to make sure
            mission.Log(methodName, "Alerting commRelayGroup " .. commRelayGroup)
            vengeStory5_handleCommRelayGroupActivated(commRelayGroup)
        end
    end

    if highestDmgSusAlertTimer > mission.data.custom.damageSusAlertMaxTime then
        if commRelayGroup then --should be not nil but we check just to make sure
            mission.Log(methodName, "Alerting commRelayGroup " .. commRelayGroup)
            vengeStory5_handleCommRelayGroupActivated(commRelayGroup)
        end
    end
end

mission.phases[4].onPreRenderHud = function()
    local _MethodName = "Phase 4 On Pre Render Hud"

    local player = Player()
    local _sector = Sector()

    if not player then return end

    local _Ship = Entity(player.craftIndex)

    if not _Ship then
        return
    end

    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    local markProximityShips = { _sector:getEntitiesByScriptValue("_vbmn5_enemy_proximity_timer") }
    local markActiveCommRelay = { _sector:getEntitiesByScriptValue("_vbmn5_time_until_relay_active") }
    local markPlayerProxShips = { _sector:getEntitiesByScriptValue("_vbmn5_sus_alert") }
    local markDamagedShips = { _sector:getEntitiesByScriptValue("_vbmn5_damage_sus_alert") }

    for _, ship in pairs(markProximityShips) do
        local timeUntilContact = mission.data.custom.e2eProximityMaxTimer - ship:getValue("_vbmn5_enemy_proximity_timer")
        vengeStory5_markWithTimeUntil(renderer, ship, "Time until contact: %02d:%05.2f", timeUntilContact)
    end

    for _, relay in pairs(markActiveCommRelay) do
        vengeStory5_markWithTimeUntil(renderer, relay, "Time until activated: %02d:%05.2f", relay:getValue("_vbmn5_time_until_relay_active"))
    end

    for _, dmgSusShip in pairs(markDamagedShips) do
        local timeUntilAlerted = mission.data.custom.damageSusAlertMaxTime - dmgSusShip:getValue("_vbmn5_damage_sus_alert")
        vengeStory5_markWithTimeUntil(renderer, dmgSusShip, "Time until alerted: %02d:%05.2f", timeUntilAlerted)
    end

    for _, susShip in pairs(markPlayerProxShips) do
        --Proximity check clears sus alert value.
        if not susShip:getValue("_vbmn5_damage_sus_alert") then --dmg sus takes precendent.
            local timeUntilAlerted = mission.data.custom.playerProximityMaxTimer - mission.data.custom.phase4PlayerProximityTimer
            vengeStory5_markWithTimeUntil(renderer, susShip, "Time until alerted: %02d:%05.2f", timeUntilAlerted)
        end
    end

    renderer:display()
end

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 15,
    callback = function()
        vengeStory5_sendCommRelay1Chatter("Long range communications are down?!")
    end,
    repeating = false
}

mission.phases[4].timers[2] = {
    time = 25,
    callback = function()
        vengeStory5_sendCommRelay1Chatter("There's nothing on the scanners, though...?")
    end,
    repeating = false
}

mission.phases[4].timers[3] = {
    time = 35,
    callback = function()
        vengeStory5_sendCommRelay1Chatter("We'll work to restore comms. Keep an eye out for anything suspicious in the meantime.")
    end,
    repeating = false
}

mission.phases[4].timers[4] = {
    time = 10,
    callback = function()
        if mission.data.description[6].fulfilled and mission.data.description[7].fulfilled then
            nextPhase()
        end
    end,
    repeating = true
}

end

--endregion

--region #PHASE 4 TRIGGERS

if onServer() then

mission.phases[4].triggers[1] = {
    condition = function()
        local commsCt = ESCCUtil.countEntitiesByValue("_vbmn5_comms_relay_objective")
        return commsCt == 0
    end,
    callback = function()
        mission.data.description[6].fulfilled = true
        sync()
    end,
    repeating = false
}

mission.phases[4].triggers[2] = {
    condition = function()
        local commsRelayEnemyCt = 0
        commsRelayEnemyCt = commsRelayEnemyCt + ESCCUtil.countEntitiesByValue("_vbmn5_comm_relay_1_group")
        commsRelayEnemyCt = commsRelayEnemyCt + ESCCUtil.countEntitiesByValue("_vbmn5_comm_relay_2_group")

        return commsRelayEnemyCt == 0
    end,
    callback = function()
        mission.data.description[7].fulfilled = true
        sync()
    end,
    repeating = false
}

mission.phases[4].triggers[3] = {
    condition = function()
        local _sector = Sector()
        local shipEntities = { _sector:getEntitiesByType(EntityType.Ship) }
        local playerShipCt = 0
        for _, s in pairs(shipEntities) do
            if s.playerOrAllianceOwned then
                playerShipCt = playerShipCt + 1
            end
        end

        if playerShipCt > 1 then
            return true
        end
    end,
    callback = function()
        vengeStory5_handleFailure(4)
    end,
    repeating = false
}

end

--endregion

--region #PHASE 4 SECTOR CALLBACKS

mission.phases[4].sectorCallbacks[1] = {
    name = "vbmnStory5FailCommRelayActivation",
    func = function()
        vengeStory5_handleFailure(5)
    end
}

mission.phases[4].sectorCallbacks[2] = {
    name = "onDamaged",
    func = function(objectIndex, amount, inflictor, damageSource, damageType)
        local damagedEntity = Entity(objectIndex)
        local inflictorEntity = Entity(inflictor)

        if inflictorEntity and valid(inflictorEntity) and inflictorEntity.playerOrAllianceOwned and damagedEntity:getValue("_vbmn5_arms_fortress") then
            vengeStory5_handleFailure(7)
        end
    end
}

--endregion

mission.phases[5] = {} --Destroy arms fort phase
mission.phases[5].timers = {}
mission.phases[5].triggers = {}
mission.phases[5].onBegin = function()
    local methodName = "Phase 5 On Begin"
    mission.Log(methodName, "Starting...")

    mission.data.description[5].fulfilled = true
    mission.data.description[9].visible = true
    mission.data.description[10].visible = true
    mission.data.description[11].visible = true
end

mission.phases[5].onBeginServer = function()
    vengeStory5_spawnAllison()
    invokeClientFunction(Player(), "vengeStory5_onPhase5Dialog1", mission.data.custom.allisonID)
end

mission.phases[5].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 5 Update Target Location Server"
    local friendlyMissileShips = { Sector():getEntitiesByScriptValue("is_adrasteia_missile_ship") }
    for _, ship in pairs(friendlyMissileShips) do
        local vbmn5missileShipTimer = (ship:getValue("_vbmn5_missile_ship_timer") or 0) + timeStep

        if not ship:getValue("_vbmn5_barrage_mode_set") then
            if vbmn5missileShipTimer > 90 then
                ship:setValue("_vbmn5_barrage_mode_set", true)
                ship:invokeFunction("torpedoslammer.lua", "setBarrageMode", 3, 0.5)

                local lines = {
                    "Preparations complete. Barrage mode set.",
                    "All tubes firing!",
                    "Torpedoes locked and loaded!",
                    "Fire! Fire! Fire!",
                    "I've always wanted to see this...",
                    "Launch the missiles now!!!",
                    "All tubes finished loading! Fire!"
                }

                Sector():broadcastChatMessage(ship, ChatMessageType.Chatter, getRandomEntry(lines))
            end
        end

        if not ship:getValue("_vbmn5_torpedo_output_increase") then
            if vbmn5missileShipTimer > 180 then
                ship:setValue("_vbmn5_torpedo_output_increase", true)
                ship:invokeFunction("torpedoslammer.lua", "incrementDamageFactor", 2)
                ship:invokeFunction("torpedoslammer.lua", "incrementShockwaveFactor", 3)

                local lines = {
                    "Capacitors at full charge! Increasing torpedo output.",
                    "Kill every last one of them!",
                    "Loading heavy station-buster warheads...",
                    "Overkill? No such thing.",
                    "Burn it all down.",
                    "You'll pay for what you've done!",
                    "Purging all scum from this sector."
                }

                Sector():broadcastChatMessage(ship, ChatMessageType.Chatter, getRandomEntry(lines))
            end
        end

        --No lines this time, just quietly increase damage output.
        if not ship:getValue("_vbmn5_torpedo_output_increase2") then
            if vbmn5missileShipTimer > 270 then
                ship:setValue("_vbmn5_torpedo_output_increase2", true)
                ship:invokeFunction("torpedoslammer.lua", "incrementDamageFactor", 1)
            end
        end

        if not ship:getValue("_vbmn5_torpedo_output_increase3") then
            if vbmn5missileShipTimer > 540 then
                ship:setValue("_vbmn5_torpedo_output_increase3", true)
                ship:invokeFunction("torpedoslammer.lua", "incrementDamageFactor", 1)
            end
        end

        ship:setValue("_vbmn5_missile_ship_timer", vbmn5missileShipTimer)
    end

    if mission.data.custom.phase5AttackEvents then
        mission.data.custom.phase5AttackTimer = mission.data.custom.phase5AttackTimer + timeStep

        if mission.data.custom.phase5AttackTimer >= 50 and not mission.data.custom.phase5AttackChatter1Sent then
            local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_objective_jammer")
            --we can safely assume the jammer is alive because if it dies we fail.

            VengeUtil.allisonChatter(nil, "That APD is a real problem. Jammer ${_JAMMER} - Can you get rid of it?" % { _JAMMER = jammer.name })
            mission.data.custom.phase5AttackChatter1Sent = true
        end

        if mission.data.custom.phase5AttackTimer >= 65 and not mission.data.custom.phase5AttackChatter2Sent then
            local _sector = Sector()
            local jammer = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_objective_jammer")
            --we can safely assume the jammer is alive because if it dies we fail.
            _sector:broadcastChatMessage(jammer, ChatMessageType.Chatter, "Yes ma'am. Tuning ECM field...")
            local armsFort = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_arms_fortress")
            if armsFort and valid(armsFort) then
                armsFort:removeScript("absolutepointdefense.lua")
            end
            mission.data.custom.phase5AttackChatter2Sent = true
        end

        if mission.data.custom.phase5AttackTimer >= 75 and not mission.data.custom.phase5AttackChatter3Sent then
            local _sector = Sector()
            VengeUtil.allisonChatter(nil, "They'll have no choice but to scurry from under their safety blanket now. ${_PLAYERNAME}, kill them." % { _PLAYERNAME = Player().name })
            local armsFortPirates = { _sector:getEntitiesByScriptValue("_vbmn5_arms_fort_group") }
            for _, p in pairs(armsFortPirates) do
                local pirateAI = ShipAI(p)
                pirateAI:setAggressive() --They can go after whoever they want.
            end
            mission.data.custom.phase5AttackChatter3Sent = true
        end
    end

    if mission.data.custom.allowPhase5EndgameDialog then
        mission.data.custom.phase5EndgameDialogTimer = mission.data.custom.phase5EndgameDialogTimer + timeStep
    end
end

mission.phases[5].onEntityDestroyed = function(id, lastDamageInflictor)
    local methodName = "Phase 5 On Entity Destroyed"

    local destroyedEntity = Entity(id)
    
    if destroyedEntity and valid(destroyedEntity) then
        if destroyedEntity:getValue("_vbmn5_objective_jammer") then
            vengeStory5_handleFailure(1)
        end

        if destroyedEntity:getValue("is_adrasteia_missile_ship") then

            mission.data.custom.missileShipsLost = mission.data.custom.missileShipsLost + 1
            mission.data.description[10].arguments = { _CSRLOST = mission.data.custom.missileShipsLost }
            mission.Log(methodName, "Pirates successfully destroyed missile ship. Resetting torp slammer buff.")
            mission.data.custom.phase5PirateTorpWaveBuffCounter = -1 --Reset new torp slammers.
            sync()

            if mission.data.custom.missileShipsLost >= 3 then
                vengeStory5_handleFailure(6)
            end
        end
    end
end

local vengeStory5_onPhase5Dialog1End = makeDialogServerCallback("vengeStory5_onPhase5Dialog1End", 5, function()
    mission.data.custom.phase5AttackEvents = true
    local armsFort = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_arms_fortress")
    if armsFort and valid(armsFort) then
        invokeClientFunction(Player(), "vengeStory5_armsFortSetAttackMusic", armsFort.index)
    end
    vengeStory5_spawnAdrasteiaMissileShip()
end)

local vengeStory5_onPhase5Dialog2End = makeDialogServerCallback("vengeStory5_onPhase5Dialog2End", 5, function()
    vengeStory5_friendlyShipsDepart(true)
    vengeStory5_finishAndReward()
end)

local vengeStory5_phase5Dialog2HoldYouToIt = makeDialogServerCallback("vengeStory5_phase5Dialog2HoldYouToIt", 5, function()
    Player():setValue("_vbmn5_hold_you_to_it", true)
end)

local vengeStory5_phase5Dialog2CrimeComplaint = makeDialogServerCallback("vengeStory5_phase5Dialog2CrimeComplaint", 5, function()
    Player():setValue("_vbmn5_complained_about_crimes", true)
end)

--region #PHASE 5 TIMERS

if onServer() then

mission.phases[5].timers[1] = {
    time = 120,
    callback = function()
        local methodName = "Phase 5 Timer 1"
        if mission.data.custom.phase5AttackEvents then
            mission.Log(methodName, "Phase 5 attack events allowed - spawning missile ship if applicable.")
            vengeStory5_spawnAdrasteiaMissileShip()
        end
    end,
    repeating = true
}

mission.phases[5].timers[2] = {
    time = 60,
    callback = function()
        local methodName = "Phase 5 Timer 2"
        if mission.data.custom.phase5AttackEvents then
            mission.Log(methodName, "Phase 5 attack events allowed.")
            local wavePirateCt = ESCCUtil.countEntitiesByValue("_vbmn5_pirate_attack_wave")
            if wavePirateCt < 6 then
                mission.Log(methodName, "Less than 6 wave pirates present - spawning wave.")
                --2 possible sub-waves spawn. We increment the value here so that it only ticks up once. 
                --This is also why the value starts at -1 - the first wave will set it to 0
                mission.data.custom.phase5PirateWaveCounter = mission.data.custom.phase5PirateWaveCounter + 1
                mission.data.custom.phase5PirateTorpWaveBuffCounter = mission.data.custom.phase5PirateTorpWaveBuffCounter + 1
                vengeStory5_spawnPirateAttackWave()
            end
        end
    end,
    repeating = true
}

mission.phases[5].timers[3] = {
    time = 180,
    callback = function()
        local methodName = "Phase 5 Timer 3"
        if mission.data.custom.phase5AttackEvents then
            mission.Log(methodName, "Phase 5 attack events allowed - spawning Allison.")
            vengeStory5_spawnAllison(true)
        end
    end,   
    repeating = true
}

end

--endregion

--region #PHASE 5 TRIGGERS

if onServer() then

mission.phases[5].triggers[1] = {
    condition = function()
        local armsFortCt = ESCCUtil.countEntitiesByValue("_vbmn5_arms_fortress")
        return armsFortCt == 0
    end,
    callback = function()
        mission.data.description[8].fulfilled = true
        mission.data.description[9].fulfilled = true
        mission.data.description[10].fulfilled = true
        mission.data.description[11].fulfilled = true
        mission.data.description[12].visible = true

        mission.data.custom.phase5AttackEvents = false --Turn off p5 attack events.

        sync()
    end,
    repeating = false
}

mission.phases[5].triggers[2] = {
    condition = function()
        local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")
        return pirateCt == 0
    end,
    callback = function()
        mission.data.description[12].fulfilled = true
        mission.data.description[13].visible = true

        mission.data.custom.allowPhase5EndgameDialog = true

        vengeStory5_friendlyShipsDepart(false)
        vengeStory5_spawnAllison() --Just in case she's currently out of sector.

        sync()
    end,
    repeating = false
}

mission.phases[5].triggers[3] = {
    condition = function()
        return mission.data.custom.phase5EndgameDialogTimer >= 10 --allow the player to bask in their accomplishment for a bit.
    end,
    callback = function()
        invokeClientFunction(Player(), "vengeStory5_onPhase5Dialog2", mission.data.custom.allisonID)
    end,
    repeating = false
}

end

--endregion

--endregion

--region #SERVER CALLS

function vengeStory5_getNextLocation(useBlockRing)
    local methodName = "Get Next Location"
    
    mission.Log(methodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local targetDist = 250
    local minDist = 242
    local maxDist = 258
    local minRad, maxRad = 5, 8 --most are 6/12 but we're going 5/8 here to try and keep the distances tighter.

    if useBlockRing then
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, targetDist)
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false) 

        local _safetyBreakout = 0
        while target.x == x and target.y == y and _safetyBreakout <= 100 do
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, minRad, maxRad, false)
            _safetyBreakout = _safetyBreakout + 1
        end
    else
        target.x, target.y = MissionUT.getEmptySector(x, y, minRad, maxRad, false)

        --Enforce distance constraint
        local dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
        if dist < minDist or dist > maxDist then
            mission.Log(methodName, "Distance constraint violated (" .. tostring(dist) .. ")")
            local safetyBreakout = 0
            while (dist < minDist or dist > maxDist) and safetyBreakout < 100 do
                if safetyBreakout % 10 == 0 then
                    mission.Log(methodName, "Attempt " .. tostring(safetyBreakout) .. " to find a valid sector.")
                end
                target.x, target.y = MissionUT.getEmptySector(x, y, minRad, maxRad, false)
                dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
            end
        end
    end

    --Nil check
    if not target or not target.x or not target.y then
        mission.Log(methodName, "Could not find a suitable mission location (no empty location found). Terminating script.")
        terminate()
        return
    end

    --Distance constraint check
    local dist = ESCCUtil.getDistanceToCenter(target.x, target.y)
    if dist < minDist or dist > maxDist then
        mission.Log(methodName, "Could not find a suitable mission location (distance constraint violated). Terminating script.")
        terminate()
        return
    end

    mission.Log(methodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))

    return target
end

function vengeStory5_removeXsotanEvent()
    local _player = Player()
    if _player:hasScript("events/alienattack.lua") then
        _player:removeScript("events/alienattack.lua")
        _player:sendChatMessage("", 3, "The subspace signals abruptly fade from your sensors.")
    end
end

function vengeStory5_createObjectiveSector(x, y)
    local methodName = "Create Objective Sector"
    mission.Log(methodName, "Starting")

    --The most complicated objective sector we've ever done. :D
    local _random = random()
    local _player = Player()
    local _sector = Sector()

    local generator = SectorGenerator(x, y)

    local startPosition = vec3(0, 0, 0)

    local playerShip = Entity(_player.craftIndex)
    if playerShip then
        startPosition = playerShip.translationf
    end

    --The complexity mostly comes from here.
    local dir = _random:getDirection()
    local armsFortPosition = startPosition + (dir * 5000)
    local armsFortMatrix = MatrixLookUpPosition(_random:getDirection(), _random:getDirection(), armsFortPosition)

    local pirateGenerator = AsyncPirateGenerator(nil, nil)

    local rotationAxis = vec3(1, 0, 0)
    mission.Log(methodName, "Rotation axis is " .. tostring(rotationAxis))
    local commRelay1Matrix = rotate(armsFortMatrix, 55, rotationAxis)
    local commRelay2Matrix = rotate(armsFortMatrix, 235, rotationAxis)

    local enemyPirateFaction = pirateGenerator:getPirateFaction()

    --========================
    --CREATE ARMS FORTRESS
    --========================
    local armsFortress = generator:createMilitaryBase(enemyPirateFaction)
    armsFortress.position = armsFortMatrix
    armsFortress:setValue("is_pirate", true)
    armsFortress:setValue("_vbmn5_arms_fortress", true)

    armsFortress:removeScript("consumer.lua")
    armsFortress:removeScript("backup.lua")
    armsFortress:removeScript("bulletinboard.lua")
    armsFortress:removeScript("missionbulletins.lua")
    armsFortress:removeScript("story/bulletins.lua")
    _sector:removeScript("traders.lua")

    --Remove boarding / prevent Xavorion faction swap
    Boarding(armsFortress).boardable = false
    armsFortress:addAbsoluteBias(StatsBonuses.DefenseWeapons, 1000)

    --Remove all of its other turrets
    local armsFortressTurrets = { armsFortress:getTurrets() }
    for _, turret in pairs(armsFortressTurrets) do
        _sector:deleteEntity(turret)
    end

    mission.Log(methodName, "Adding Arms Fortress Weapons")
    --Most of the time ShipUtility.addSpecificScalableWeapon works fine, but sometimes we get pirate factions that do not have cannons available.
    local afTurretsCt = Balancing_GetEnemySectorTurrets(_sector:getCoordinates()) * 6 + 2
    local afTurretSeed = SectorSeed(x, y)
    local afTurretGenerator = SectorTurretGenerator(afTurretSeed)
    afTurretGenerator.maxRarity = Rarity(RarityType.Rare)
    afTurretGenerator.coaxialAllowed = false

    local afCannonTurret = afTurretGenerator:generate(x, y, 0, nil, WeaponType.Cannon)
    afCannonTurret:setRange(2250)

    ShipUtility.addTurretsToCraft(armsFortress, afCannonTurret, afTurretsCt)

    armsFortress:setDropsAttachedTurrets(false) --Don't drop the cannons we've futzed with.

    --Add some special loot. Nothing too crazy, just some uncommon+ cannons. No legendaries.
    local afLoot = Loot(armsFortress)
    for cidx = 1, 5 do
        local rewardTurretGenerator = SectorTurretGenerator(_random:getInt(1, 20000))
        rewardTurretGenerator.minRarity = Rarity(RarityType.Uncommon)
        rewardTurretGenerator.maxRarity = Rarity(RarityType.Exotic)
        afLoot:insert(InventoryTurret(rewardTurretGenerator:generate(x, y, 0, nil, WeaponType.Cannon)))
    end

    mission.Log(methodName, "Setting title and adding scripts to arms fortress.")
    armsFortress.title = "Arms Fortress"
    armsFortress:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
    armsFortress:addScriptOnce("player/missions/vengeance/story5/vengeance5armsfort.lua")
    armsFortress:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    --Oh hey, it's been a while since we've seen this bad boy
    local apdValues = {
        _ROF = 0.25,
        _TargetTorps = true,
        _TargetFighters = true,
        _TorpDamage = 16,
        _FighterDamage = 16,
        _RangeFactor = 12,
        _MaximumTargets = 16
    }

    armsFortress:addScriptOnce("absolutepointdefense.lua", apdValues)

    armsFortress:removeCrew(10000, CrewMan(CrewProfessionType.Pilot)) --Don't do fighters, no matter what material it's made from.

    local armsFortressAI = ShipAI(armsFortress)
    armsFortressAI:setAggressive()

    armsFortress.damageMultiplier = (armsFortress.damageMultiplier or 1) * 700 --Kill anything within 20km.

    ESCCUtil.multiplyOverallDurability(armsFortress, 120) --This thing is super beefy.

    --========================
    --CREATE COMM RELAY FUNC
    --========================
    local commRelayFunc = function(commRelayPosition, commRelayScriptValue)
        local minDist = 4000
        local safeIterations = 100
        --If commRelay1 / commRelay2 are still too close to the arms fort (within 40km) - jiggle them a bit until they're out of reach.

        local commRelayVecPosition = commRelayPosition.position --commRelayPosition is a matrix.

        local commRelayDistance = distance(armsFortPosition, commRelayVecPosition)
        if commRelayDistance < minDist then
            mission.Log(methodName, "Comm relay is too close - jiggling")
            local safetyBreakout = 0
            while commRelayDistance < minDist and safetyBreakout < safeIterations do
                local newPosition = ESCCUtil.getVectorAtDistance(commRelayVecPosition, 500, true)
                if distance(armsFortPosition, newPosition) > commRelayDistance then
                    commRelayVecPosition = newPosition
                    commRelayDistance = distance(armsFortPosition, commRelayVecPosition)
                end
                safetyBreakout = safetyBreakout + 1
            end

            commRelay1Matrix.position = commRelayVecPosition
        end

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
           ComponentType.Name,
           ComponentType.Title,
           ComponentType.Owner,
           ComponentType.Durability,
           ComponentType.PlanMaxDurability,
           ComponentType.InteractionText,
           ComponentType.EnergySystem,
           ComponentType.WreckageCreator,
           ComponentType.ShipAI
           )

        local stationPlan, _, _, _ = PlanGenerator.makeStationPlan(enemyPirateFaction)

        stationPlan.accumulatingHealth = true
        local scaleFactor = 0.75
        stationPlan:scale(vec3(scaleFactor, scaleFactor, scaleFactor))

        desc.position = commRelayPosition
        desc:setMovePlan(stationPlan)
        desc.factionIndex = enemyPirateFaction.index

        local commRelay = _sector:createEntity(desc)
        commRelay:setValue(commRelayScriptValue, true)
        commRelay:setValue("is_pirate", true)
        commRelay:setValue("_ESCC_bypass_hazard", true) --Just in case
        commRelay:setValue("_vbmn5_comms_relay_objective", true)
        commRelay:setTitle("Communications Relay", {})

        Physics(commRelay).driftDecrease = 0.2

        --Prevent Xavorion faction switch.
        commRelay:addAbsoluteBias(StatsBonuses.DefenseWeapons, 1000)

        return commRelay
    end

    --========================
    --CREATE COMM RELAY 1
    --========================
    local commRelay1 = commRelayFunc(commRelay1Matrix, "_vbmn5_comm_relay1")
    commRelay1.name = "Relay Alpha"
    commRelay1:setValue("_vbmn5_comm_relay_1_group", true)
    commRelay1:setValue("_vbmn5_check_comm_relay_player_proximity", true)

    --========================
    --CREATE COMM RELAY 2
    --========================
    local commRelay2 = commRelayFunc(commRelay2Matrix, "_vbmn5_comm_relay2")
    commRelay2.name = "Relay Beta"
    commRelay2:setValue("_vbmn5_comm_relay_2_group", true)
    commRelay2:setValue("_vbmn5_check_comm_relay_player_proximity", true)

    --========================
    --CREATE DEFENDER GROUPS
    --========================
    mission.Log(methodName, "Creating defender groups.")
    --Arms fortress group.
    local armsFortGroupGenerator = AsyncPirateGenerator(nil, vengeStory5_onArmsFortGroupFinished)

    local armsFortTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 8, "Standard", false)

    armsFortGroupGenerator:startBatch()

    for idx = 1, 8 do
        local look = _random:getDirection()
        local up = _random:getDirection()
        local position = ESCCUtil.getVectorAtDistance(armsFortPosition, 500, false)

        armsFortGroupGenerator:createScaledPirateByName(armsFortTable[idx], MatrixLookUpPosition(look, up, position))
    end

    armsFortGroupGenerator:endBatch()

    --Comm relay 1 group.
    local commRelay1Position = commRelay1.translationf
    local commRelayThreatTable = "Standard"
    local commRelay1Generator = AsyncPirateGenerator(nil, vengeStory5_onCommRelay1GroupFinished)

    local commRelay1Table = ESCCUtil.getStandardWave(mission.data.custom.weakPirateDangerLevel, 5, commRelayThreatTable, false)

    commRelay1Generator:startBatch()

    for idx = 1, 5 do
        local look = _random:getDirection()
        local up = _random:getDirection()
        local position = ESCCUtil.getVectorAtDistance(commRelay1Position, 500, false)

        commRelay1Generator:createScaledPirateByName(commRelay1Table[idx], MatrixLookUpPosition(look, up, position))
    end

    commRelay1Generator:endBatch()

    --Comm relay 2 group.
    local commRelay2Position = commRelay2.translationf
    local commRelay2Generator = AsyncPirateGenerator(nil, vengeStory5_onCommRelay2GroupFinished)

    local commRelay2Table = ESCCUtil.getStandardWave(mission.data.custom.weakPirateDangerLevel, 5, commRelayThreatTable, false)

    commRelay2Generator:startBatch()

    for idx = 1, 5 do
        local look = _random:getDirection()
        local up = _random:getDirection()
        local position = ESCCUtil.getVectorAtDistance(commRelay2Position, 500, false)

        commRelay2Generator:createScaledPirateByName(commRelay2Table[idx], MatrixLookUpPosition(look, up, position))
    end

    commRelay2Generator:endBatch()

    --========================
    --CREATE ASTEROID FIELDS
    --========================
    mission.Log(methodName, "Creating asteroid fields.")
    for _ = 1, 6 do
        generator:createSmallAsteroidField()
    end

    generator:createAsteroidField()

    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true
end

function vengeStory5_spawnAllison()
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
        local allison = VengeUtil.spawnAllison(true, false) --She always deletes whenever the player leaves the sector this mission.

        if mission.internals.phaseIndex ~= 2 then
            allison:addScriptOnce("player/missions/vengeance/story5/vengeance5adrasteiaai.lua")
        end

        mission.data.custom.allisonID = allison.index
    end
end

function vengeStory5_onArmsFortGroupFinished(generated)
    local methodName = "On Arms Fort Pirate Group Finished"
    mission.Log(methodName, "Arms Fort group finished!")

    for _, p in pairs(generated) do
        local pirateAI = ShipAI(p)
        pirateAI:setPassive()

        p:setValue("bDisableXAI", true) --AI handled by this mission.
        p:setValue("_vbmn5_arms_fort_group", true)
        p:setValue("_vbmn5_pirate", true)

        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 --Xinull goon boost.
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory5_onCommRelay1GroupFinished(generated)
    local methodName = "On Comm Relay 1 Group Finished"
    mission.Log(methodName, "Comm Relay 1 group finished!")
    vengeStory5_handleCommRelayGroupFinished(generated, "_vbmn5_comm_relay_1_group", "_vbmn5_comm_relay_1_pirate")
end

function vengeStory5_onCommRelay2GroupFinished(generated)
    local methodName = "On Comm Relay 2 Group Finished"
    mission.Log(methodName, "Comm Relay 2 group finished!")
    vengeStory5_handleCommRelayGroupFinished(generated, "_vbmn5_comm_relay_2_group", "_vbmn5_comm_relay_2_pirate")
end

function vengeStory5_handleCommRelayGroupFinished(generated, scriptValue, scriptValue2)
    for _, p in pairs(generated) do
        local pirateAI = ShipAI(p)
        pirateAI:setPassive()

        p:setValue("bDisableXAI", true) --AI handled by this mission.
        --Various script values we'll need to choreography.
        p:setValue(scriptValue, true)
        p:setValue(scriptValue2, true)
        p:setValue("_vbmn5_pirate", true)
        p:setValue("_vbmn5_check_comm_relay_player_proximity", true)
        p:setValue("_vbmn5_comm_relay_alert_group", scriptValue)
    end

    local jammerAttacker = getRandomEntry(generated)
    jammerAttacker:setValue("_vbmn5_comm_relay_group_attack_jammer", true)

    for _, p in pairs(generated) do
        if not p:getValue("_vbmn5_comm_relay_group_attack_jammer") then
            p:addMultiplier(StatsBonuses.Velocity, 1.375) --Make the ones that run for the arms fortress a little faster.
        end
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

function vengeStory5_spawnAdrasteiaJammer()
    local _player = Player()
    local _random = random()

    local playerShip = Entity(_player.craftIndex)

    local jammerPosition = vec3(0, 0, 0)
    if playerShip then
        jammerPosition = ESCCUtil.getVectorAtDistance(playerShip.translationf, 250, false)
    end

    local jammerMatrix = MatrixLookUpPosition(_random:getDirection(), _random:getDirection(), jammerPosition)

    local friendlyJammer = PirateGenerator.createScaledJammer(jammerMatrix)
    friendlyJammer.factionIndex = VengeUtil.getFriendlyFaction().index

    Boarding(friendlyJammer).boardable = false

    friendlyJammer:removeScript("blocker.lua")
    friendlyJammer:setValue("_vbmn5_objective_jammer", true)
    friendlyJammer:setValue("is_pirate", nil)
    friendlyJammer:setValue("_ESCC_bypass_hazard", true)
    friendlyJammer:setValue("is_adrasteia", true)
    friendlyJammer:addScriptOnce("player/missions/vengeance/story5/vengeance5jammerhealer.lua") --heal when there are no pirates present to prevent surprise jammer death on pirates jumping in.

    local jammerAI = ShipAI(friendlyJammer)
    jammerAI:setFollow(playerShip, false)
    --jammerAI:setPassiveShooting(true) --The jammer SHOULD defend itself but there would be nothing as crappy as a surprise mass driver kill

    ESCCUtil.multiplyOverallDurability(friendlyJammer, 3.5)

    Sector():broadcastChatMessage(friendlyJammer, ChatMessageType.Chatter, "Jammer on station. Keep us safe, and we'll keep you in the shadows.")
end

function vengeStory5_sendCommRelay1Chatter(chatter)
    local _sector = Sector()
    local commRelay1Pirates = { _sector:getEntitiesByScriptValue("_vbmn5_comm_relay_1_group") }

    _sector:broadcastChatMessage(getRandomEntry(commRelay1Pirates), ChatMessageType.Chatter, chatter)
end

function vengeStory5_handleCommRelayGroupActivated(commRelayGroup)
    local _sector = Sector()
    local _random = random()

    local commRelayGroupValues = {
        _vbmn5_comm_relay_1_group = { pirateValue = "_vbmn5_comm_relay_1_pirate", relayValue = "_vbmn5_comm_relay1" },
        _vbmn5_comm_relay_2_group = { pirateValue = "_vbmn5_comm_relay_2_pirate", relayValue = "_vbmn5_comm_relay2" }
    }

    local pirateScriptValue = commRelayGroupValues[commRelayGroup].pirateValue
    local commsRelayScriptValue = commRelayGroupValues[commRelayGroup].relayValue

    local commRelayPirates = { _sector:getEntitiesByScriptValue(pirateScriptValue) }

    local friendlyJammer = ESCCUtil.getSingleEntityByValue(_sector, "_vbmn5_objective_jammer")
    local armsFortress = ESCCUtil.getSingleEntityByValue(_sector, "_vbmn5_arms_fortress")
    local sentChatter = false

    --Handle pirates.
    for _, p in pairs(commRelayPirates) do
        if not p:getValue("_vbmn5_orders_sent") then
            local pirateAI = ShipAI(p)

            if p:getValue("_vbmn5_comm_relay_group_attack_jammer") then
                pirateAI:setAttack(friendlyJammer)
            else
                p:setValue("_vbmn5_proximity_check", true)

                pirateAI:setFlyLinear(armsFortress.translationf, 100, false)
                pirateAI:setPassiveShooting(true)
                if _random:test(0.5) then
                    if not sentChatter then
                        sentChatter = true

                        local messages = {
                            "Run away!",
                            "We're under attack!",
                            "Sound the alarm!",
                            "Alert the arms fortress!"
                        }

                        _sector:broadcastChatMessage(p, ChatMessageType.Chatter, getRandomEntry(messages))
                    end
                end
            end
        end

        p:setValue("_vbmn5_orders_sent", true)
    end

    --Handle comm relay
    local commsRelay = ESCCUtil.getSingleEntityByValue(_sector, commsRelayScriptValue)
    if commsRelay and valid (commsRelay) then
        --Do something here.
        commsRelay:setValue("_vbmn5_orders_sent", true)
        commsRelay:addScriptOnce("player/missions/vengeance/story5/vengeance5commrelayactivate.lua", { timeToActivate = mission.data.custom.commRelayActivateTime })
    end
end

function vengeStory5_spawnAdrasteiaMissileShip()
    local missileShipCt = ESCCUtil.countEntitiesByValue("is_adrasteia_missile_ship")
    local armsFortScriptValue = "_vbmn5_arms_fortress"

    if missileShipCt < 2 then
        local missileShip = VengeUtil.spawnAdrasteiaMissileShip(true) --May as well, mission fails immediately if you leave the sector.
        
        if missileShip:hasScript("torpedoslammer.lua") then
            while missileShip:hasScript("torpedoslammer.lua") do
                missileShip:removeScript("torpedoslammer.lua")
            end 
        end

        local newTorpSlammerValues = {
            _TimeToActive = 30,
            _ROF = 4,
            _UpAdjust = false,
            _DamageFactor = 3,
            _ForwardAdjustFactor = 1.5,
            _PreferWarheadType = 2, --Neutron
            _PreferSecondaryWarheadType = 3, --Fusion
            _TargetPriority = 2, --Target script value
            _TargetTag = armsFortScriptValue,
            _ReachFactor = 20
        }

        missileShip:addScript("torpedoslammer.lua", newTorpSlammerValues)

        local armsFort = ESCCUtil.getSingleEntityByValue(nil, armsFortScriptValue)
        if armsFort and valid(armsFort) then
            local missileShipAI = ShipAI(missileShip)
            missileShipAI:setIdle()
            missileShipAI:setPassiveShooting(true)
            missileShipAI:setFlyLinear(armsFort.translationf, 3250, false)
        end
    end
end

function vengeStory5_spawnPirateAttackWave()
    --Spawn a normal 4-count wave of pirates
    local pirateWaveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 4, "Standard", false)
    local sneakyPirateWaveTable = {}
    local pirateCt = 4
    local addSneakWave = false

    --50% chance to spawn a single extra one-ship wave that goes after the jammer.
    if random():test(0.5) then
        sneakyPirateWaveTable = ESCCUtil.getStandardWave(mission.data.custom.weakPirateDangerLevel, 1, "Standard", false)
        pirateCt = pirateCt + 1
        addSneakWave = true
    end

    local pirateGenerator = AsyncPirateGenerator(nil, vengeStory5_onPirateAttackWaveFinished)
    local piratePositions = pirateGenerator:getStandardPositions(pirateCt, 250) --_#DistAdj

    pirateGenerator:startBatch()

    for posIdx, p in pairs(pirateWaveTable) do
        pirateGenerator:createScaledPirateByName(p, piratePositions[posIdx])
    end

    pirateGenerator:endBatch()

    if addSneakWave then
        local sneakPirateGenerator = AsyncPirateGenerator(nil, vengeStory5_onPirateSneakAttackWaveFinished)
        
        sneakPirateGenerator:startBatch()

        sneakPirateGenerator:createScaledPirateByName(sneakyPirateWaveTable[1], piratePositions[5])

        sneakPirateGenerator:endBatch()
    end
end

function vengeStory5_onPirateAttackWaveFinished(generated)
    local methodName = "On Pirate Attack Wave Finished"

    local priorityVals = {
        _TargetPriority = 1,
        _TargetTag = "is_adrasteia_missile_ship"
    }

    local waveMultiplier = 1 + (math.max(0, mission.data.custom.phase5PirateWaveCounter) * 0.05)
    
    for _, p in pairs(generated) do
        p:addScript("ai/priorityattacker.lua", priorityVals)
        
        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 * waveMultiplier --Xinull goon boost.

        ESCCUtil.multiplyOverallDurability(p, waveMultiplier)

        p:setValue("_vbmn5_pirate", true)
    end

    local torpDamageMultiplier = 1 + (math.max(0, mission.data.custom.phase5PirateTorpWaveBuffCounter) * 0.15)
    local tta = math.max(10, 30 - mission.data.custom.phase5PirateTorpWaveBuffCounter)
    local aaidf = 1 + math.max(0, (mission.data.custom.phase5PirateTorpWaveBuffCounter * 10))

    mission.Log(methodName, "Torp damage multiplier is " .. tostring(torpDamageMultiplier) .. " tta is " .. tostring(tta) .. " anti ai durability is ".. tostring(aaidf))

    local torpSlammerValues = {
        _TimeToActivate = tta,
        _DurabilityFactor = 8,
        _ROF = 6,
        _UpAdjust = false,
        _DamageFactor = 1.25 * torpDamageMultiplier,
        _ForwardAdjustFactor = 2,
        _PreferWarheadType = 1, --Nuclear
        _TargetPriority = 2, --Target tag
        _TargetTag = "is_adrasteia_missile_ship",
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

function vengeStory5_onPirateSneakAttackWaveFinished(generated)
    local priorityVals = {
        _TargetPriority = 1,
        _TargetTag = "_vbmn5_objective_jammer"
    }

    local waveMultiplier = 1 + (math.max(0, mission.data.custom.phase5PirateWaveCounter) * 0.05)

    for _, p in pairs(generated) do
        p:addScript("ai/priorityattacker.lua", priorityVals)

        p.damageMultiplier = (p.damageMultiplier or 1) * waveMultiplier

        ESCCUtil.multiplyOverallDurability(p, waveMultiplier)

        p:setValue("_vbmn5_pirate", true)
    end
    --Can't add buffs - the jammer is fairly fragile.
    Placer.resolveIntersections(generated)
end

function vengeStory5_handleFailure(failReason)
    --Set any pirates in the sector to aggressive.
    vengeStory5_piratesAggro()

    --Friendly ships depart
    vengeStory5_friendlyShipsDepart(true)

    --Set fail music and clear arms fort cargo
    local armsFort = ESCCUtil.getSingleEntityByValue(nil, "_vbmn5_arms_fortress")
    if armsFort and valid(armsFort) then
        invokeClientFunction(Player(), "vengeStory5_armsFortSetFailureMusic", armsFort.index)
        CargoBay(armsFort):clear()
        vengeStory5_addDefenseController(armsFort, Sector())
    end

    --Send fail mail
    vengeStory5_sendFailMail(failReason)

    --Fail
    fail()
end

function vengeStory5_piratesAggro()
    local pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    for _, p in pairs(pirates) do
        local pirateAI = ShipAI(p)
        pirateAI:setAggressive()
    end
end

function vengeStory5_addDefenseController(armsFort, _sector)
    local x, y = _sector:getCoordinates()

    local defControlValues = {
        _DefenseLeader = armsFort.index,
        _DefenderCycleTime = 60,
        _DangerLevel = mission.data.custom.dangerLevel,
        _MaxDefenders = 12,
        _AllDefenderDamageScale = 2,
        _MaxDefendersSpawn = 6,
        _DefenderDistance = 5000,
        _LowTable = "High",
        _IsPirate = true,
        _Factionid = armsFort.factionIndex,
        _PirateLevel = Balancing_GetPirateLevel(x, y),
        _DefenderHPThreshold = 0.5,
        _DefenderOmicronThreshold = 0.5,
        _PreventLootDrop = true
    }

    _sector:addScriptOnce("sector/background/defensecontroller.lua", defControlValues)
end

function vengeStory5_friendlyShipsDepart(allisonDeparts)
    local friendlyShips = { Sector():getEntitiesByScriptValue("is_adrasteia") }
    for _, ship in pairs(friendlyShips) do
        local addScript = false --Assume false

        if ship:getValue("is_allison") then
            if allisonDeparts then
                addScript = true
            end
        else
            addScript = true
        end

        if addScript then
            ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
        end
    end
end

function vengeStory5_sendFailMail(failReason)
    --FAIL REASONS
    --1 - lost jammer
    --2 - left the sector
    --3 - pirates alerted arms fort
    --4 - player jumped in too many ships
    --5 - comm relays activate
    --6 - too many missile cruisers lost
    --7 - player attacked arms fortress before phase 5

    local failReasonMailTable = {
        { --lost jammer
            text = Format("Hello again.\n\nThe jammer was destroyed. Unfortunately it is vital to the operation and we cannot continue without it. We'll have to capture another one before we try to attack the fortress again. You need not concern yourself with that - after going over the initial raid I believe my captains have an adequate understanding of what needs to be done.\n\nI will contact you when we are ready to attack again.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail1"
        },
        { --left the sector
            text = Format("Hello again.\n\nYou left the sector. Were you not prepared to take on the fortress? While I understand that an operation of this magnitude can be demanding, I expected you to be better prepared. I'll contact you when we're ready to make our next attack. In the meantime, I would suggest resupplying your torpedo bays.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail2"
        },
        { --arms fort alerted
            text = Format("Hello again.\n\nThe pirates alerted the arms fortress, and pirate reinforcements flooded the sector. We'll have to wait for them to leave before we try to assault the fortress again. If you are having trouble killing the pirates before they're able to contact the fortress, I would suggest using long-range weapons like rockets or cannons, or torpedoes.\n\nI will contact you when we are ready to attack again.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail3"
        },
        { --too many ships jumped in
            text = Format("Hello again.\n\nYou moved too many ships into the sector too early. Remember that the jammer can only cover one ship at a time, and we need to make sure both communications relays are destroyed before we move in additional ships so it can focus on jamming long-range communications from the Arms Foretress. If you are having trouble accomplishing the objectives with a single ship, I would suggest visiting some turret factories.\n\nI will contact you when we are ready to attack again.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail4"
        },
        { --comm relay activates
            text = Format("Hello again.\n\nOne of the communications relays was activated, and pirate reinforcements flooded the sector. We'll have to wait for them to leave before we try to assault the fortress again. If you are having trouble killing the relays before they activate, I would suggest either visiting a turret factory or using torpedoes. You can also deliberately alert a group to separate them from the relay if there is an anti-torpedo ship present.\n\nI will contact you when we are ready to attack again.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail5"
        },
        { --too many missile cruisers lost
            text = Format("Hello again.\n\nUnfortunately, we lost too many missile cruisers to continue our assault on the fortress. We're a small fleet and we don't have the same level of resources as factions or larger pirate groups. I'll let you know when we're ready to make our next assault. In the meantime, I would suggest getting some more combat ships ready - remember that after the comm relays are destroyed you may deploy as many ships as you wish to the threatre.\n\nAllison"),
            mailID = "_vbmn_story5_mailfail6"
        },
        { --player attacks arms fortress before phase 5
            text = Format("Hello again.\n\nThe arms fortress was alerted before we could commence the main thrust of our assault. Please refrain from attacking the pirates around the fortress - or the fortress itself - until both relays are destroyed and the accompanying pirates are killed.\n\nI will contact you when we are ready to attack again.\n\nAllison."),
            mailID = "_vbmn_story5_mailfail7"
        }
    }

    local _player = Player()
    local _mail = Mail()
    _mail.text = failReasonMailTable[failReason].text
    _mail.header = "Operation Failed"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = failReasonMailTable[failReason].mailid
    _player:addMail(_mail)
end

function vengeStory5_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    local _player = Player()

    local accomplishMessage = "Here's your reward. I'll send my next request shortly."
    local baseReward = 4000000

    _player:sendChatMessage("Allison", ChatMessageType.Normal, accomplishMessage)
    mission.data.reward = { credits = baseReward, paymentMessage = "Earned %1% credits for destroying the pirate arms fortress."}
    
    _player:setValue("_vengeancebmn_story_stage", 6)
    _player:setValue("encyclopedia_vbmn_hijacking", true)

    VengeUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function vengeStory5_armsFortSetFailureMusic(armsFortID)
    Entity(armsFortID):invokeFunction("vengeance5armsfort.lua", "setFailureTrack")
end

function vengeStory5_armsFortSetAttackMusic(armsFortID)
    Entity(armsFortID):invokeFunction("vengeance5armsfort.lua", "setPhaseTwoTrack")
end

function vengeStory5_markWithTimeUntil(renderer, _entity, alertStringFmt, timeUntilAlert)
        local warningColor = ESCCUtil.getSaneColor(255, 0, 0)

        local v2, size = renderer:calculateEntityTargeter(_entity)

        renderer:renderEntityTargeter(_entity, warningColor, size * 1.25)
        renderer:renderEntityArrow(_entity, 30, 10, 250, warningColor)

        local rect = Rect(v2.x - size, v2.y + (size * 0.75), v2.x + size, v2.y + size)
        drawTextRect(string.format(alertStringFmt, 0, math.max(0.1, timeUntilAlert)), rect, 0, 0, ColorRGB(1.0, 1.0, 1.0), 10, false, false, 2)
end

function vengeStory5_onPhase2Dialog(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d3shortcut = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d7whatif = {}
    local d8 = {}
    local d9 = {}

    local playerHeardPlan = Player():getValue("_vbmn5_heardplan")

    d0.text = "You're here. Good."
    d0.followUp = d1

    d1.text = "Xinull's base is an old military outpost that he turned into a fortress - he also has two communication relays. The fortress is armed with insurmountably powerful cannons, and he can use the relays to call in help from halfway across the galaxy."
    d1.followUp = d2

    d2.text = "But with the jammer, we have an opening."
    d2.answers = {
        { answer = "What's the opening?", followUp = d3 }
    }

    if playerHeardPlan then
        table.insert(d2.answers, { answer = "We've gone over this before.", followUp = d3shortcut })
    end

    d3shortcut.text = "Understood. We'll get moving, then."
    d3shortcut.followUp = d8

    d3.text = "We can use the jammer to block your radio and infrared signatures, as well as block local transmissions. From there, you can take out the communication relays before they realize that there's a threat. Once the relays are gone, the jammer can block the remainder of outbound communications. I'll bring in some missile cruisers and we can burn the fortress to the ground."
    d3.followUp = d4

    d4.text = "... Metaphorically speaking. There's no 'ground' in space."
    d4.followUp = d5

    d5.text = "You'll go in first with the jammer. It will only be able to cover one of your ships, so you can't bring in more until the relays have been eliminated. You'll need to destroy the relays, and then kill any pirates protecting them before they can get into short-wave radio range and inform the remainder of the group."
    d5.answers = {
        { answer = "This sounds complicated.", followUp = d6 },
        { answer = "Why not attack with overwhelming force?", followUp = d7 },
        { answer = "I understand. Let's get moving.", followUp = d8 }
    }

    d6.text = "It is, but it will work."
    d6.answers = {
        { answer = "I understand.", followUp = d8 },
        { answer = "Why not attack with overwhelming force?", followUp = d7 }
    }

    d7.text = "Too many reinforcements. He has all of the pirates in this region of the galaxy at his command. They fear him and will answer his call for help."
    d7.answers = {
        { answer = "What if we fail? Will he fortify the sector?", followUp = d7whatif },
        { answer = "I got it.", followUp = d8 }
    }

    d7whatif.text = "No. Too much political capital to permanently reinforce his pet fortress, and it would make him look weak. We'll wait a few cycles and attack again."
    d7.answers = {
        { answer = "Got it.", followUp = d8 }
    }

    d8.text = "Remember - the jammer can only cover one ship. You need to make sure the pirates don't inform the other pirates of your presence. Make sure to kill the communication relays first - they can punch through the jammer's ECM. You have full operational discretion - resolve the situation how you see fit."
    d8.followUp = d9

    d9.text = "Good luck. When you're finished, I'll begin the second phase. Here are the coordinates of the fortress."
    d9.onEnd = vengeStory5_onPhase2DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d3shortcut, d4, d5, d6, d7, d7whatif, d8, d9}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeStory5_onPhase5Dialog1(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    
    d0.text = "Excellent work, Captain. I knew I could trust you."
    d0.followUp = d1

    d1.text = "Time to finish this. The cruisers are en route. Protect them while they do their job."
    d1.followUp = d2

    d2.text = "This sector will burn."
    d2.onEnd = vengeStory5_onPhase5Dialog1End

    ESCCUtil.setTalkerTextColors({d0, d1, d2}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

function vengeStory5_onPhase5Dialog2(allisonID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d2hate = {}
    local d2crime = {}
    local d2refuse = {}
    local d2lost = {}
    local d3 = {}
    local d3kindred = {}
    local d3ido = {}
    local d3why = {}
    local d3isee = {}
    local d3mercenary = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}

    d0.text = "That's the last of them. We did it."
    d0.followUp = d1

    d1.text = "I'll deal with any survivors."
    d1.answers = {
        { answer = "Understood.", followUp = d3 },
        { answer = "What do you mean by 'deal with'?", followUp = d2 }
    }

    d2.text = "Kill them, of course."
    d2.answers = {
        { answer = "Why do you hate them so much?", followUp = d2hate },
        { answer = "Isn't that a war crime?", followUp = d2crime }
    }

    d2hate.text = "You wouldn't understand. Or maybe you would. Either way, it's not something I want to discuss right now. Would ruin the mood."
    d2hate.answers = {
        { answer = "After everything we've done, I think you should tell me.", followUp = d2refuse },
        { answer = "You're right, we should be celebrating!", followUp = d3 }
    }

    d2crime.text = "It is not. They are outlaws, unbound by the laws governing galactic conflicts."
    d2crime.answers = {
        { answer = "Still, it's a little cruel isn't it? They already lost.", followUp = d2lost },
        { answer = "Why do you hate them so much?", followUp = d2hate }
    }

    d2refuse.text = "I will. I promise. But not today."
    d2refuse.answers = {
        { answer = "I'll hold you to it.", onSelect = vengeStory5_phase5Dialog2HoldYouToIt, followUp = d3 }
    }

    d2lost.text = "Tch. Haven't you seen them slaughtering defenseless merchant crews? Pillaging and butchering caravans of traders? Save your empathy for people who deserve it - it's wasted on these scum."
    d2lost.answers = {
        { answer = "Why do you hate them so much?", onSelect = vengeStory5_phase5Dialog2CrimeComplaint, followUp = d2hate }
    }

    d3.text = "To watch your enemy's forces crumble... to see their burning wreckages tumbling through space throwing out bodies, water, and oxygen... there's nothing quite like it. Even after so many battles it still hasn't lost its thrill for me."
    d3.answers = {
        { answer = "I know. I feel the same way.", followUp = d3kindred },
        { answer = "You really hate them, don't you?", followUp = d3ido },
        { answer = "I actually don't enjoy killing.", followUp = d3mercenary }
    }

    d3kindred.text = "It's good to see a kindred spirit on the battlefield. Don't worry, Captain - we're not done yet. There will be plenty more battles on the road ahead."
    d3kindred.answers = {
        { answer = "So, what's next?", followUp = d4 }
    }

    d3ido.text = "I do."
    d3ido.answers = {
        { answer = "Why?", followUp = d3why },
        { answer = "I see.", followUp = d3isee }
    }

    d3why.text = "We'll discuss it later. It's not a conversation for right now."
    d3why.answers = {
        { answer = "Fine. What's next?", followUp = d4 }
    }

    d3isee.text = "Perhaps, perhaps not. But you will one day."
    d3isee.answers = {
        { answer = "We'll see about that. So what's next?", followUp = d4 }
    }

    d3mercenary.text = "So you're in this for the money? I prefer to avoid dealing with mercenaries, but if you keep delivering results like this I'll keep my complaints to a minimum."
    d3mercenary.answers = {
        { answer = "So, what's next?", followUp = d4 }
    }

    d4.text = "This isn't the end of Xinull's influence in this area. Not by a long shot. But his main base of operations is crippled. With it, he'll lose the capacity to carry out raids with impunity, and the followers on his periphery will slowly desert him as he loses his sway."
    d4.followUp = d5

    d5.text = "Next, we're going to hit him where it really hurts. Losing his fortress is business. But this is personal, and we're going to make it personal for him too. I'll send you the next part of the plan soon."
    d5.followUp = d6

    d6.text = "I suppose this is the part where I tell you to stay safe. But if you can handle a job like that, I think I can trust you to survive. Until we next meet, Captain."
    d6.onEnd = vengeStory5_onPhase5Dialog2End

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d2hate, d2crime, d2refuse, d2lost, d3, d3kindred, d3ido, d3why, d3isee, d3mercenary, d4, d5, d6}, "Allison", VengeUtil.getDialogAllisonTalkerColor(), VengeUtil.getDialogAllisonTextColor())

    ScriptUI(allisonID):interactShowDialog(d0, false)
end

--endregion

--I think this may be the record for the most lines of code in my missions! Woo!