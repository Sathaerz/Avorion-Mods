--[[
    Rank 4 side mission.
    Deliver Advanced Materials
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Player must have successfully completed story mission 3 (destroyed pirates + good end allowing for mission 4 - this also has a soft requirement of rank 3)
        - Player must have found Avorion
        - Player must own one of their own Resource Depots
    ROUGH OUTLINE
        - Player goes to their nearest resource depot (must be player or alliance owned)
        - Player creates Avorion shipment for the price of 5000 avo.
        - Player is then contacted by The Cavaliers to meet at a specific point.
        - Player then meets The Cavalier contact and hands over the Avorion
        - Base payout is 35.8 * 3 * 5000 (Price for selling Avo to your own resource depot * 3 * 5000, since you are delivering 5000 avo)
        - Multiply this by sector richness. This may lead to some absurd payouts but I think that's okay.
    DANGER LEVEL
        1+ - 
        6 - [These conditions are present at danger level 6 and above]
            - 10% chance per danger level (max 50% at level 10) that pirates manage to execute a MITM attack vs. the player and send them a set of bad coordinates
            - Create and use high threat table to spawn an attack similar to a fake distress signal.
        10 - [These conditions are present at danger level 10]
            - Pirate ambush includes an extra mothership, along with two jammers.
            - 2nd wave of 5 pirates jumps in once the mothership is at 50% HP or lower.
            - Yes, it is completely possible that we get DL 10, don't roll the attack, and the player gets a free extra rep. That's totally fine. It's okay to throw the player a bone.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run other includes.
include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local PirateGenerator = include("pirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Deliver Advanced Materials"

--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "Initialize"
    
    if onServer() then
        if not _restoring then
            local _Name = "The Cavaliers" 
            local _Faction = Galaxy():findFaction(_Name)

            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            mission.data.brief = "Deliver Advanced Materials"
            mission.data.title = "Deliver Advanced Materials"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "The Cavaliers have contacted you and asked you to deliver them advanced materials.",
                { text = "Travel to a Resource Depot owned by you, your alliance, or a faction that you are allied with", bulletPoint = true, fulfilled = false },
                { text = "Construct and pick up the Advanced Material Shipment", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Read the mail from The Cavaliers", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Deliver the Shipment to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
                { text = "You appear to have been ambushed. Escape from the attacking pirates or destroy them", bulletPoint = true, fulfilled = false, visible = false},
                { text = "Read the second mail from The Cavaliers", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Deliver the Shipment to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Transfer the Shipment to the ${_SHIP}", bulletPoint = true, fulfilled = false, visible = false }
            }

            local _Rgen = ESCCUtil.getRand()

            --35.8 is how many credits you get for selling Avorion to your own resource depot.
            --2 is the standard multiplier for "we need resources now!" missions. We want more than that.
            --5000 is the amount of Avorion that the player needs to pay to complete the mission.
            local _RewardBase = 35.8 * 3 * 5000
            local _InitialMessage = "Thank you! We'll contact you when we're ready to pick up the materials."
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .cavaliersindex
                .playerIsAttacked
                .deliveryLocation
                .commanderName
                .createdPirates
                .runAddShipment
                .freightername
            =========================================================]]
            mission.data.custom.dangerLevel = _Rgen:getInt(1, 10)
            mission.data.custom.cavaliersindex = _Faction.index
            mission.data.custom.playerIsAttacked = false

            if mission.data.custom.dangerLevel >= 6 then
                local _PctChance = mission.data.custom.dangerLevel - 5
                local _Dice = _Rgen:getInt(1, 10)
                if _Dice <= _PctChance then
                    mission.Log(_MethodName, tostring(_Dice) .. " is <= than " .. tostring(_PctChance) .. " Player is getting attacked by pirates.")
                    mission.data.custom.playerIsAttacked = true
                else
                    mission.Log(_MethodName, "Player is not getting attacked.")
                end
            end

            local _SectorFactor = Balancing.GetSectorRichnessFactor(Sector():getCoordinates())
            local _SectorFactor = math.max(_SectorFactor / 2, 1)
            mission.Log(_MethodName, "Sector factor is: " .. tostring(_SectorFactor))
            local missionReward = ESCCUtil.clampToNearest(_RewardBase * _SectorFactor, 5000, "Up")

            mission.Log(_MethodName, "Mission payout is " .. tostring(missionReward))

            missionData_in = {location = nil, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, _InitialMessage)
        else
            --Restoring
            llte_sidemission_init()
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

mission.globalPhase = {}
mission.globalPhase.timers = {}
mission.globalPhase.onSectorEntered = function(_X, _Y)
    local _MethodName = "Global Phase On Target Location Entered"
    if mission.data.custom.runAddShipment then
        --Runs adding shipments whenever we enter a sector after phase 2 is entered. This is done just in case the player loses the shipment somehow.
        addShipmentScript()
    end
end

mission.phases[1] = {}
mission.phases[1].triggers = {}
mission.phases[1].triggers[1] = {
    condition = function()
        local _MethodName = "Phase 1 Trigger 1 Condition"
        --Needs to be a trigger that is checked constantly, because the player could accept the mission inside a sector that has a resource depot that
        --meets the conditions in it.
        local _Stations = {Sector():getEntitiesByType(EntityType.Station)}
        local _Return = false
        for _, _Station in pairs(_Stations) do
            local _Player = Player()
            local _HasRefinery = _Station:hasScript("refinery.lua")
            local _OwnedByPlayer = _Station.factionIndex == _Player.index or _Station.factionIndex == _Player.allianceIndex
            local _AlliedDepot = _OwnedByPlayer
    
            if not _OwnedByPlayer then
                --Check to see if the player (NOT the player's alliance) has an alliance with this faction. If they do, this depot is acceptable.
                local _Faction = Faction(_Station.factionIndex)
                local _Relation = _Player:getRelation(_Faction.index)
                _AlliedDepot = _Relation.status == RelationStatus.Allies
            end

            if _HasRefinery and _AlliedDepot then
                _Return = true
            end
        end

        return _Return
    end,
    callback = function()
        nextPhase()
    end,
    repeating = false
}
mission.phases[1].showUpdateOnEnd = true

mission.phases[2] = {}
mission.phases[2].playerEntityCallbacks = {}
mission.phases[2].playerEntityCallbacks[1] = {
    name = "onCargoChanged",
    func = function(_ObjectIndex, _Delta, _Good)
        --This, on the other hand, we can do with a callback.
        if _Good.name == "Avorion Shipment" and _Delta > 0 then
            nextPhase()
        end
    end
}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
    addShipmentScript()
    mission.data.custom.runAddShipment = true
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.custom.deliveryLocation = getNextLocation(true)
    mission.data.custom.commanderName = LLTEUtil.getHumanFullName()

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _CommanderName = mission.data.custom.commanderName
    local _X, _Y = mission.data.custom.deliveryLocation.x, mission.data.custom.deliveryLocation.y

    mission.Log(_MethodName, "Args - rank : " .. tostring(_Rank) .. " name : " .. tostring(_Player.name) .. " _X : " .. tostring(_X) .. " _Y : " .. tostring(_Y) .. " Commander : " .. tostring(_CommanderName))

    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nWe're ready to pick up the shipment whenever you're ready to deliver it. Bring it to (%3%:%4%) and we'll meet you there.\nLong live the Empress!\n\nCommander %5%", _Rank, _Player.name, _X, _Y, _CommanderName)
	_Mail.header = "Pickup Location"
	_Mail.sender = Format("Commander %1% @TheCavaliers", _CommanderName)
	_Mail.id = "_llte_side6_mail1"
	_Player:addMail(_Mail)
end

mission.phases[3].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_side6_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[4] = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].noBossEncountersTargetSector = true
mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.deliveryLocation
    mission.data.description[4].fulfilled = true
    mission.data.description[5].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[5].visible = true
end

mission.phases[4].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 4 On Target Location Entered"
    if mission.data.custom.playerIsAttacked then
        mission.Log(_MethodName, "Player is getting attacked - moving to next phase and spawning pirates.")
        --Spawn pirates.
        nextPhase()
    else
        mission.Log(_MethodName, "Player is not getting attacked - spawning Cavaliers.")
        --Spawn Cavaliers
        spawnCavaliers()
    end
end

mission.phases[5] = {}
mission.phases[5].triggers = {}
mission.phases[5].triggers[1] = {
    condition = function()
        return mission.data.custom.createdPirates and ESCCUtil.countEntitiesByValue("is_pirate") == 0
    end,
    callback = function()
        nextPhase()
    end,
    repeating = false
}
mission.phases[5].showUpdateOnEnd = true
mission.phases[5].onBeginServer = function()
    local _MethodName = "Phase 5 On Begin Server"
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
    spawnPirates()
    if mission.data.custom.dangerLevel == 10 then
        mission.phases[5].triggers[2] = {
            condition = function()
                local _MotherShipTable = {Sector():getEntitiesByScriptValue("is_mothership")}

                if #_MotherShipTable == 0 then
                    return true
                else
                    local _MotherShip = _MotherShipTable[1]
                    if _MotherShip then
                        local _Ratio = _MotherShip.durability / _MotherShip.maxDurability

                        return _Ratio <= 0.5
                    end
                end

                return false
            end,
            callback = function()
                spawnSecondPirateWave()
            end,
            repeating = false
        }
    end
end

mission.phases[6] = {}
mission.phases[6].showUpdateOnEnd = true
mission.phases[6].onBeginServer = function()
    local _MethodName = "Phase 6 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[6].fulfilled = true
    mission.data.description[7].visible = true
    mission.data.custom.secondDeliveryLocation = getNextLocation(false)

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _CommanderName = mission.data.custom.commanderName
    local _RealCommanderName = LLTEUtil.getHumanFullName()
    local _X, _Y = mission.data.custom.deliveryLocation.x, mission.data.custom.deliveryLocation.y
    local _MX, _MY = mission.data.custom.secondDeliveryLocation.x, mission.data.custom.secondDeliveryLocation.y

    local _Mail = Mail()
	_Mail.text = Format("%1% %2%!\n\nIt recently came to my attention that you recieved a communication from a '%5%' concerning a shipment of Avorion. This is troubling - I've checked our records, and %5% has never been affiliated with The Cavaliers. DO NOT GO TO (%3%:%4%) - repeat - DO NOT GO TO (%3%:%4%)!!!\n\nBring the shipment to (%6%:%7%) instead.\nLong live the Empress!\n\nCommander %8%", _Rank, _Player.name, _X, _Y, _CommanderName, _MX, _MY, _RealCommanderName)
	_Mail.header = Format("Attn: %1% - DISREGARD Previous Mail", _Player.name)
	_Mail.sender = Format("Commander %1% @TheCavaliers", _RealCommanderName)
	_Mail.id = "_llte_side6_mail2"
	_Player:addMail(_Mail)
end

mission.phases[6].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_side6_mail2" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[7] = {}
mission.phases[7].showUpdateOnEnd = true
mission.phases[7].onBeginServer = function()
    local _MethodName = "Phase 7 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.secondDeliveryLocation
    mission.data.description[7].fulfilled = true
    mission.data.description[8].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[8].visible = true
end

mission.phases[7].onTargetLocationEntered = function(_X, _Y)
    spawnCavaliers()
end

--endregion

--region #SERVER CALLS

function spawnPirates()
    local _MethodName = "Spawn Pirates"
    if not mission.data.custom.createdPirates then
        --Spawn 7 pirates.
        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 7, "High")
        local _CreatedPirateTable = {}
        --If danger level is 10, spawn 2 jammers and a mothership.
        if mission.data.custom.dangerLevel == 10 then
            table.insert(_PirateTable, "Jammer")
            table.insert(_PirateTable, "Jammer")
            table.insert(_PirateTable, "Boss")
        end

        shuffle(random(), _PirateTable)

        for _, _P in pairs(_PirateTable) do
            local _NextPirate = PirateGenerator.createPirateByName(_P, PirateGenerator.getGenericPosition())
            _NextPirate:addScript("player/missions/empress/side/side6/llteside6pirate.lua")
            if _P == "Boss" then
                _NextPirate:setValue("is_mothership", true)
            end
            table.insert(_CreatedPirateTable, _NextPirate)
        end
        _CreatedPirateTable[1]:addScript("player/missions/empress/side/side6/llteside6ambushleader.lua")

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
        mission.data.custom.createdPirates = true
    end
end

function spawnSecondPirateWave()
    local _MethodName = "Spawn Second Pirate Wave"
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 5, "High")

    shuffle(random(), _PirateTable)

    local _Generator = AsyncPirateGenerator(nil, onSecondWaveFinished)
    _Generator.pirateLevel = PirateGenerator.pirateLevel

    _Generator:startBatch()

    local posCounter = 1
    local distance = 250 --_#DistAdj

    local pirate_positions = _Generator:getStandardPositions(#_PirateTable, distance)
    for _, _P in pairs(_PirateTable) do
        _Generator:createScaledPirateByName(_P, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    _Generator:endBatch()
end

function onSecondWaveFinished(_Generated)
    local _MethodName = "On Pirates Generated (Server)"
    mission.Log(_MethodName, "Beginning...")

    SpawnUtility.addEnemyBuffs(_Generated)

    mission.Log(_MethodName, "Broadcasting Pirate Taunt to Sector")
    mission.Log(_MethodName, "Entity: " .. tostring(_Generated[1].name))

    local _Lines = {
        "You're a long way from home, aren't you?",
        "We'll tear you to pieces!",
        "All ships, weapons to full! Engage! Engage! Engage!",
        "Kill them all! Hahahaha!"
    }

    Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(_Lines))
end

function addShipmentScript()
    local _MethodName = "Add Shipment Script"
    mission.Log(_MethodName, "Beginning...")
    local _Stations = {Sector():getEntitiesByType(EntityType.Station)}
    for _, _Station in pairs(_Stations) do
        mission.Log(_MethodName, "Checking " .. tostring(_Station.name))
        local _Player = Player()
        local _HasRefinery = _Station:hasScript("refinery.lua")
        local _OwnedByPlayer = _Station.factionIndex == _Player.index or _Station.factionIndex == _Player.allianceIndex
        local _HasGetShipment = _Station:hasScript("llteside6getshipment.lua")
        local _AlliedDepot = _OwnedByPlayer

        if not _OwnedByPlayer then
            --Check to see if the player (NOT the player's alliance) has an alliance with this faction. If they do, this depot is acceptable.
            local _Faction = Faction(_Station.factionIndex)
            local _Relation = _Player:getRelation(_Faction.index)
            _AlliedDepot = _Relation.status == RelationStatus.Allies
        end

        mission.Log(_MethodName, "Has refinery: " .. tostring(_HasRefinery) .. " | Allied to Player: " .. tostring(_AlliedDepot) .. " | Has Get Shipment: " .. tostring(_HasGetShipment))

        if _HasRefinery and _AlliedDepot and not _HasGetShipment then
            _Station:addScriptOnce("player/missions/empress/side/side6/llteside6buildshipment.lua")
        end
    end
end

function spawnCavaliers()
    --Make defenders
    local shipGenerator = AsyncShipGenerator(nil, onDefendersFinished)
    local _Faction = Faction(mission.data.custom.cavaliersindex)
    local _X, _Y = Sector():getCoordinates()

    shipGenerator:startBatch()

    shipGenerator:createDefender(_Faction, shipGenerator:getGenericPosition())
    shipGenerator:createDefender(_Faction, shipGenerator:getGenericPosition())

    shipGenerator:endBatch()

    --Make the freighter.
    local cavFreighterVolume = Balancing_GetSectorShipVolume(_X, _Y) * 8
    local shipGenerator2 = AsyncShipGenerator(nil, onFreighterFinished)

    shipGenerator2:startBatch()

    shipGenerator2:createFreighterShip(_Faction, shipGenerator2:getGenericPosition(), cavFreighterVolume)

    shipGenerator2:endBatch()
end

function onFreighterFinished(_Generated)
    local _MethodName = "On Freighter Finished"
    mission.Log(_MethodName, "Beginning...")

    for _, ship in pairs(_Generated) do
        ship.name = LLTEUtil.getFreighterName()
        ship.title = "Cavaliers " .. ship.title
        ship:removeScript("civilship.lua")
        ship:removeScript("dialogs/storyhints.lua")
        ship:setValue("_llte_escort_mission_freighter", true)
        ship:setValue("is_civil", nil)
        ship:setValue("npc_chatter", nil)
        ship:setValue("is_freighter", nil)
        ship:setValue("is_cavaliers", true)
        ship:addScript("ai/withdrawatlowhealth.lua", 0.8, 1, 1, 0.02)
        ship:addScript("player/missions/empress/side/side6/llteside6giveshipment.lua")
        MissionUT.deleteOnPlayersLeft(ship)

        mission.data.custom.freightername = ship.name
    end

    mission.data.description[5].fulfilled = true
    mission.data.description[8].fulfilled = true
    mission.data.description[9].arguments = { _SHIP = mission.data.custom.freightername }
    mission.data.description[9].visible = true

    sync()
end

function onDefendersFinished(_Generated)
    local _MethodName = "On Defenders Finished"
    mission.Log(_MethodName, "Beginning...")

    for _, ship in pairs(_Generated) do
        ship.title = "Cavaliers " .. ship.title
        ship:removeScript("antismuggle.lua")
        ship:setValue("npc_chatter", nil)
        ship:setValue("is_cavaliers", true)
        ship:addScript("ai/withdrawatlowhealth.lua", 0.8, 1, 1, 0.02)
        MissionUT.deleteOnPlayersLeft(ship)
    end
end

function getNextLocation(_FirstLocation)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}
    local _inBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    local _stayInBarrier = false --Go outside the barrier by default, but if we're already inside we don't care anymore.
    if _inBarrier then
        _stayInBarrier = nil
    end

    if _FirstLocation then
        --Get a sector that's a ways away from where we are now.
        target.x, target.y = MissionUT.getSector(x, y, 12, 20, false, false, false, false, _stayInBarrier)
    else
        target.x, target.y = MissionUT.getSector(x, y, 3, 5, false, false, false, false, _stayInBarrier)
    end

    return target
end

function finishMission()
    local _MethodName = "Finish Mission"
    if onClient() then
        mission.Log(_MethodName, "Calling on [Client]")
        mission.Log(_MethodName, "Invoking on Server")

        invokeServerFunction("finishMission")
    else
        mission.Log(_MethodName, "Calling on [Server]")

        local _Ships = {Sector():getEntitiesByScriptValue("is_cavaliers")}
        local _Rgen = ESCCUtil.getRand()
        for _, _S in pairs(_Ships) do
            _S:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(4, 8))
        end
        finishAndReward()
    end
end
callable(nil, "finishMission")

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "The Empress will be pleased to hear of this.",
        "Thank you for making the galaxy safer.",
        "Your support is appreciated, as always.",
        "Amazing work, " .. _Player.name .. "!",
        "Great job, " .. _Rank .. "!"
    }

    _Player:setValue("_llte_cavaliers_have_avorion", true)
    local _Strength = _Player:getValue("_llte_cavaliers_strength") or 0
    _Strength = math.min(_Strength + 1, 5)
    _Player:setValue("_llte_cavaliers_strength", _Strength)    

    local _RepReward = 4
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end

    --Increase reputation by 4 (5 @ 10 danger)
    mission.data.reward.paymentMessage = "Earned %1% credits for delivering the materials."
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + _RepReward)
    _Player:sendChatMessage("The Cavaliers", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion