--[[
    Story Mission 3.
    Order from Chaos
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Story Mission 2 Done
        - Cavaliers Rank 3
        - Pick up mission from a Scout (Not automatically given to the player)
    ROUGH OUTLINE
        - Player reads mail from Adriana
        - Player goes to location given by mail (this is the pirate sector)
        - Pirate Sector has a shipyard.
            - Remove cargo from all of the station.
        - Player destroys all of the stations. Mechanics are similar to The Unforgiving Blade, but gets no support from The Cavaliers.
            - This is because the player is a diversionary attack while The Cavaliers attack another sector.
        - After clearing out the pirate sector, the player reads a mail from Adriana.
        - Player goes to Adriana location.
        - Player gets to talk to Adriana - have a fairly extensive dialog tree.
            - Player has to tell Adriana that they've found avorion + a way past the barrier, and also offer to give the Cavaliers Avorion.
            - Dialog options aren't even available unless the player has Avorion, though, which will force them to repeat it until they do.
            - Good outcome unlocks mission 4 @ rank 4 (and removes this particular mission from scout lists)
            - Bad outcome changes nothing.
        - Use the supply mechanic.
        - 60 minute time limit.
    DANGER LEVEL
        - 5+ The mission starts at Danger Level 5. It is a fixed value since this is a non-repeatable* story mission.
            - Start with 12 standard defenders in the sector.
            - Pirates spawn in groups of 4 every minute. (7 max)
            - Danger level does not increase (unlike last mission) but supply mechanics are a thing this time so if the player ignores the freigthers they're in trouble.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes.
include("callable")
include("randomext")
include("structuredmission")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include("pirategenerator")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")

mission._Debug = 0
mission._Name = "Order From Chaos"

--region #INIT

local llte_storymission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Order From Chaos Begin...")

    if onServer()then
        if not _restoring then
            --Standard mission data.
            mission.data.brief = "Order from Chaos"
            mission.data.title = "Order from Chaos"
			mission.data.icon = "data/textures/icons/cavaliers.png"
			mission.data.priority = 9
            mission.data.description = { 
                "The Cavaliers have contacted you to request your help with another assault on a group of pirates.",
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false },
                --If any of these have an X / Y coordinate, they will be updated with the correct location when starting the appropriate phase.
                { text = "Destroy the pirate base in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Read Adriana's second mail", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Meet Adriana in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }
            }

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .pirateLevel
                .pirateBaseLocation
                .meetingLocation
                .builtMainSector
                .playerArrivedPhase2
                .shipyardid
                .goodEndAchieved
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.

            local missionReward = 750000

            missionData_in = {location = nil, reward = {credits = missionReward}}
    
            llte_storymission_init(missionData_in)
        else
            --Restoring
            llte_storymission_init()
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
mission.globalPhase.onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if mission.data.location then
        runFullSectorCleanup_llte()
    end
end

mission.globalPhase.onFail = function()
    --If there are any Cavaliers ships, they warp out.
    local _MethodName = "On Fail"
    mission.Log(_MethodName, "Beginning...")

    --Add a script to the mission location to nuke it if we are there, nuke it remotely otherwise.
    runFullSectorCleanup_llte()
    --Send fail mail.
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")

    local _Mail = Mail()
    local _PirateFaction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)
	_Mail.text = Format("%1% %2%,\n\nDespite our change in tactics, the pirates sent an overwhelming force to defend their base. We were forced to break off our attack due to the amount of losses we sustained.\nGet yourself some stronger weapons and shields, and I'll get to work on reorganizing the fleet for another assault. We will continue fighting to keep the peace we've built!\n\nEmpress Adriana Stahl", _Rank, _Player.name, _PirateFaction.name)
	_Mail.header = "Forced to Withdraw"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story3_mailfail"
	_Player:addMail(_Mail)
end

mission.globalPhase.onAccomplish = function()
    if mission.data.custom.goodEndAchieved then
        --Send a mail if the player got the good end. Don't send anything otherwise.
        local _Player = Player()
        local _Rank = _Player:getValue("_llte_cavaliers_rank")

        local _Mail = Mail()
        _Mail.text = Format("%1% %2%,\n\nThank you again for agreeing to give us some Avorion! We'll make sure we find a good use for it. Like I said earlier, look out for our scouts! They'll contact you with instructions on setting up a delivery. We look forward to hearing from you, %1%!\n\nEmpress Adriana Stahl", _Rank, _Player.name)
        _Mail.header = "Material Delivery"
        _Mail.sender = "Empress Adriana Stahl @TheCavaliers"
        _Mail.id = "_llte_story3_mailwin"
        _Player:addMail(_Mail)
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.pirateBaseLocation = getNextLocation(true)
    local _X, _Y = mission.data.custom.pirateBaseLocation.x, mission.data.custom.pirateBaseLocation.y
    --Use this to enable consistent pirates.
    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_X, _Y)
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Mail = Mail()
    local _PirateLevel = Player():getValue("_llte_pirate_faction_vengeance")
    local _Faction = Galaxy():getPirateFaction(_PirateLevel)

	_Mail.text = Format("%1% %2%,\n\nDespite our success against %3%, another pirate group is gathering in force. Apparently they learned nothing from what happened the first time they tried this. We will destroy them as well. However, I would like to change our tactical approach. Instead of a single, all-out assault, I would like you to start a diversionary attack against a smaller base they built in (%4%:%5%). Once you have started, I will lead an attack group against their main base.\n\nBetween our two attacks, we should crush them! It will be another message to those who wish to destroy the peace we've built.\n\nEmpress Adriana Stahl", _Rank, _Player.name, _Faction.name, _X, _Y)
	_Mail.header = "Cleaning House"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story3_mail1"
	_Player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_story3_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].triggers = {}
mission.phases[2].triggers[1] = {
    condition = function()
        if onClient() then
            return true
        end
        return mission.data.custom.playerArrivedPhase2 
    end,
    callback = function()
        if onServer() then
            local _Station = Entity(mission.data.custom.shipyardid)
            Sector():broadcastChatMessage(_Station, ChatMessageType.Chatter, "Cavaliers, here?! Kill them! Kill them!!!")
        end
    end,
    repeating = false
}
mission.phases[2].triggers[2] = {
    condition = function()
        local _MethodName = "Phase 2 Trigger 2"
        local _X, _Y = Sector():getCoordinates()
        if _X ~= mission.data.location.x or _Y ~= mission.data.location.y then
            mission.Log(_MethodName, "Not in mission area - not executing trigger.")
            return
        end

        local _Stations = ESCCUtil.countEntitiesByValue("_llte_story3_mainobjective")
        return mission.data.custom.builtMainSector and _Stations == 0
    end,
    callback = function()
        --Pirates flee & next phase.
        ESCCUtil.allPiratesDepart()
        mission.data.location = nil
        nextPhase()
    end,
    repeating = false
}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.data.location = mission.data.custom.pirateBaseLocation
    mission.data.description[2].fulfilled = true
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Entered"
    --Build main sector
    buildPirateSector(_X, _Y)
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.playerArrivedPhase2 = true
    mission.data.timeLimit = 1800
    mission.data.timeLimitInDescription = true
    sync()
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.data.custom.meetingLocation = getNextLocation(false)
    local _X, _Y = mission.data.custom.meetingLocation.x, mission.data.custom.meetingLocation.y
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    mission.data.timeLimit = nil
    mission.data.timeLimitInDescription = false

    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nThanks to your diversion, our attack was successful! We managed to crush the pirates. Great job keeping them busy!\nI'd like to talk to you about some matters. Come to (%3%:%4%), and I'll meet you there!\n\nEmpress Adriana Stahl", _Rank, _Player.name, _X, _Y)
	_Mail.header = "Let's talk!"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story3_mail2"
	_Player:addMail(_Mail)
end
mission.phases[3].onBeginClient = function()
    mission.data.timeLimit = nil
    mission.data.timeLimitInDescription = false
end

mission.phases[3].playerCallbacks = 
{
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_llte_story3_mail2" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.data.location = mission.data.custom.meetingLocation
    mission.data.description[4].fulfilled = true
    mission.data.description[5].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[5].visible = true
end

mission.phases[4].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 3 on Target Location Arrival Confirmed"
    local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress()
    _EmpressBlade:addScript("player/missions/empress/story/story3/lltestory3empressblade.lua")
end

--endregion

--region #SERVER CALLS

--region #SPAWN OBJECTS

function buildPirateSector(_X, _Y)
    local _MethodName = "Build Main Sector"
    
    if not mission.data.custom.builtMainSector then
        mission.Log(_MethodName, "Main sector not yet built - building it now.")
        local _Generator = SectorGenerator(_X, _Y)
        local _Rgen = ESCCUtil.getRand()
        --Add: Miltiary Outpost, Research Station, Shipyard and Repair Dock.
        local _Faction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)
        mission.Log(_MethodName, "Building sector for pirate level faction: " .. tostring(_Faction.name))
        local _Shipyard = _Generator:createShipyard(_Faction)
        _Shipyard.position = Matrix()
        mission.data.custom.shipyardid = _Shipyard.index
        local _Stations = { _Shipyard }
        for _, _Station in pairs(_Stations) do
            _Station:removeScript("consumer.lua")
            _Station:removeScript("backup.lua") --The delayed callback on this is dumb, and an unpredictable hazard zone in a story mission is no bueno
            _Station:setValue("is_pirate", true)
            _Station:setValue("_llte_story3_mainobjective", true)
            ShipUtility.addScalableArtilleryEquipment(_Station, 3.0, 1.0, false)
            local _StationBay = CargoBay(_Station)
            _StationBay:clear()

            local _StationAI = ShipAI(_Station)
            _StationAI:setAggressive()

            Boarding(_Station).boardable = false
        end
        Sector():removeScript("traders.lua")
        --Add: 1 large asteroid and 2 small asteroid fields.
        for _ = 1, 2 do
            _Generator:createSmallAsteroidField()
        end
        _Generator:createAsteroidField()
        --Add: 12 standard threat pirate defenders
        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 12, "Standard")
        local _CreatedPirateTable = {}

        for _, _Pirate in pairs(_PirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
        local _PirateLevel = Balancing_GetPirateLevel(_X, _Y)

        --Add: Defense Controller Script.
        local _DCD = {}
        _DCD._DefenseLeader = mission.data.custom.shipyardid
        _DCD._DefenderCycleTime = 90
        _DCD._DangerLevel = mission.data.custom.dangerLevel
        _DCD._MaxDefenders = 7
        _DCD._MaxDefendersSpawn = 4
        _DCD._DefenderHPThreshold = 0.5
        _DCD._DefenderOmicronThreshold = 0.5
        _DCD._ForceWaveAtThreshold = 0.8
        _DCD._ForcedDefenderDamageScale = 5
        _DCD._IsPirate = true
        _DCD._Factionid = _Shipyard.factionIndex
        _DCD._PirateLevel = _PirateLevel
        _DCD._UseLeaderSupply = true
        _DCD._SupplyPerLevel = 500
        _DCD._SupplyFactor = 0.1
        _DCD._LowTable = "High"

        Sector():addScript("sector/background/defensecontroller.lua", _DCD)

        local _SCD = {}
        _SCD._ShipmentLeader = mission.data.custom.shipyardid
        _SCD._ShipmentCycleTime = 120
        _SCD._DangerLevel = mission.data.custom.dangerLevel
        _SCD._IsPirate = true
        _SCD._Factionid = _Shipyard.factionIndex
        _SCD._PirateLevel = _PirateLevel
        _SCD._SupplyTransferPerCycle = 100
        _SCD._SupplyPerShip = 500
        _SCD._SupplierExtraScale = 8
        _SCD._SupplierHealthScale = 0.2

        Sector():addScript("sector/background/shipmentcontroller.lua", _SCD)

        mission.data.custom.builtMainSector = true
    end
end

--endregion

--region #DESPAWN OBJECTS

function runFullSectorCleanup_llte()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
    end
end

--endregion

function getNextLocation(_FirstLocation)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    if _FirstLocation then
        --Get a somewhat nearby sector. No need to go terribly to the barrier for this one in particular.
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, 165)
        target.x, target.y = MissionUT.getSector(_Nx, _Ny, 5, 10, false, false, false, false, false)
    else
        target.x, target.y = MissionUT.getSector(x, y, 3, 5, false, false, false, false, false)
    end

    return target
end

function finishAndReward(_GoodEnd)
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "Great job, " .. _Rank .. "!"
    }

    if _GoodEnd then
        mission.Log(_MethodName, "Good ending achieved - setting value.")
        mission.data.custom.goodEndAchieved = true
        _Player:setValue("_llte_story_3_accomplished", true)
    end

    --Increase reputation by 3
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + 3)
    _Player:sendChatMessage("Adriana Stahl", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " Here is your reward, as promised.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

--endregion

--region #CLIENT / SERVER CALLS

function goodEnd()
    local _MethodName = "Good End"
    
    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("goodEnd")
    else
        mission.Log(_MethodName, "Calling on Server")

        LLTEUtil.allCavaliersDepart()

        finishAndReward(true)
    end
end
callable(nil, "goodEnd")

function normalEnd()
    local _MethodName = "Normal End"
    
    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("normalEnd")
    else
        mission.Log(_MethodName, "Calling on Server")

        LLTEUtil.allCavaliersDepart()

        finishAndReward(false)
    end
end
callable(nil, "normalEnd")

--endregion