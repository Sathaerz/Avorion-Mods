--[[
    MISSION 5: Scipio's Triumph
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
HorizonUtil = include("horizonutil")

local SectorGenerator = include ("SectorGenerator")
local PirateGenerator = include("pirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Scipio's Triumph"

--region #INIT / DATA

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/snowflake-2.png"
mission.data.priority = 9
mission.data.description = {
    { text = "You have successfully stolen a battleship belonging to Horizon Keepers, LTD. Varlance has said that he will contact you when he finds something actionable in its data banks." },
    { text = "Read Varlance's mail", bulletPoint = true, fulfilled = false },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Protect the Frostbite AWACS", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the Horizon defenders", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Damage the Horizon installation", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Defeat the Horizon fleet", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Clean up", bulletPoint = true, fulfilled = false, visible = false }
}

--Custom data that we'll want.
mission.data.custom.dangerLevel = 10 --Key everything off of danger 10.
mission.data.custom.phase3Timer1 = 0
mission.data.custom.phase3AWACSOrderSent = false
mission.data.custom.awacsRewardBonus = true
mission.data.custom.phase3DialogAllowed = false
mission.data.custom.varlanceP4ChatterSent = false
mission.data.custom.waveNumber = 1

--endregion

--region #PHASE CALLS

mission.globalPhase.timers = {}

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.onAbandon = function()
    if mission.data.location then
        if atTargetLocation() then
            frostbiteDeparts()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    if mission.data.location then
        if atTargetLocation() then
            frostbiteDeparts()
        end
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.globalPhase.onTargetLocationEntered = function(_X, _Y)
    mission.data.timeLimit = nil 
    mission.data.timeLimitInDescription = false
end

mission.globalPhase.onTargetLocationLeft = function(_X, _Y)
    mission.data.timeLimit = mission.internals.timePassed + (5 * 60) --Player has 5 minutes to head back to the sector.
    mission.data.timeLimitInDescription = true --Show the player how much time is left.
end

--region #GLOBALPHASE TIMERS

if onServer() then

mission.globalPhase.timers[1] = {
    time = 180, --He doesn't have the resources of Adriana, can't respawn as quickly.
    callback = function()
        local _MethodName = "Global Phase Timer 1 Callback"

        if atTargetLocation() then
            mission.Log(_MethodName, "On Location - respawning Varlance if needed.")

            spawnVarlance()
        end
    end,
    repeating = true
}

end
    
--endregion

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    --Get a sector that's very close to the outer edge of the barrier.
    mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))

    mission.data.custom.firstLocation = getNextLocation(true)

    local _X = mission.data.custom.firstLocation.x
    local _Y = mission.data.custom.firstLocation.y

    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_X, _Y) --Set the pirate level based on the first location.

    mission.data.description[3].arguments = { _X = mission.data.custom.firstLocation.x, _Y = mission.data.custom.firstLocation.y }
    
    --Send mail to player.
    local _Player = Player()
    local _Mail = Mail()
	_Mail.text = Format("Hey, buddy.\n\nI don't think the captain of this ship was highly regarded by his corporate overlords. Figures, since the idiot got his ship trashed in a rift. Not a whole lot of breadcrumbs to follow, but we've got enough. I found the shipyard they were going to tow this thing to in order to repair it - it looks like it was one of their own. Makes sense, I wouldn't trust a pirate shipyard with this baby either. We also found more Xsotan parts, which is... concerning. I'd like to investigate this further.\n\nLooking at the shipment schedule, there's a window we might be able to take advantage of - we can put a squad in one of their freighters and steal the data from their network before they're aware of what's happening. There's only one problem. That shipyard is way too heavily defended to pull a trick like that off. We'll need to get them to overcommit so we can get our forces in, and I've got an idea.\n\nThis ship also has data on a research outpost that's fairly out of the way. It's lightly defended, but it will start screaming for help once we hit it. We can use that to draw their forces in and defeat them in detail. I'll get an AWACS ship ready - meet us at (%1%:%2%) and get ready for action.\n\nVarlance", _X, _Y)
	_Mail.header = "Next Steps"
	_Mail.sender = "Varlance @FrostbiteCompany"
	_Mail.id = "_horizon_story5_mail"
	_Player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = {
	{
		name = "onMailRead",
		func = function(_PlayerIndex, _MailIndex)
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
				if _Mail.id == "_horizon_story5_mail" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].onBegin = function()
    local _MethodName = "Phase 2 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.location = mission.data.custom.firstLocation

    mission.data.description[2].fulfilled = true
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_x, _y)
    if onServer() then
        buildObjectiveSector(_x, _y)
    end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(_x, _y)
    HorizonUtil.varlanceChatter("Defend the AWACS. We'll need it to know when the installation sends a distress signal. Clean up the defenders first, then we'll set our bait.")
    nextPhase()
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].onBegin = function()
    local _MethodName = "Phase 3 On Begin"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
    mission.data.description[5].visible = true
    mission.data.description[6].visible = true
end

mission.phases[3].onBeginServer = function()
    mission.data.custom.phase3DialogAllowed = true
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    local methodName = "Phase 3 Update Target Location Server"

    mission.data.custom.phase3Timer1 = mission.data.custom.phase3Timer1 + timeStep

    --We don't care if we're on location or not here - if the player jumps out of the sector at this point in the mission, fail it.
    local _sector = Sector()
    local awacsEntities = { _sector:getEntitiesByScriptValue("is_frostbite_awacs") }
    local station = Entity(mission.data.custom.horizonStationID)

    if #awacsEntities == 0 then
        fail()
    else
        local _awacs = awacsEntities[1]

        --The AWACS gives you some time before it starts flying in.
        if not mission.data.custom.phase3AWACSOrderSent then
            if mission.data.custom.phase3Timer1 >= 10 and #awacsEntities > 0 and station and valid(station) then
                mission.Log(methodName, "Sending AWACS move order.")
    
                local awacsAI = ShipAI(_awacs)
                awacsAI:setIdle()
                awacsAI:setPassiveShooting(true)
                awacsAI:setFlyLinear(station.translationf, 1000, false)

                mission.data.custom.phase3AWACSOrderSent = true
            end
        end

        --If the player can keep the AWACs above 50% HP, they get a bonus.
        local awacsHPThreshold = _awacs.durability / _awacs.maxDurability
        if awacsHPThreshold < 0.5 then
            mission.data.custom.awacsRewardBonus = false
        end
    end

    --phase 3 ends and we go into phase 4 after the installation sends the distress call.
    local defenderCt = ESCCUtil.countEntitiesByValue("is_horizon_defender")
    local defenderObjectiveDone = false
    local stationObjectiveDone = false

    if defenderCt == 0 then
        defenderObjectiveDone = true
        mission.data.description[5].fulfilled = true
        setVarlancePhase3Orders()
    end

    local stationHPThreshold = station.durability / station.maxDurability
    if stationHPThreshold < 0.96 then
        stationObjectiveDone = true
        mission.data.description[6].fulfilled = true
    end

    if defenderObjectiveDone and stationObjectiveDone and mission.data.custom.phase3DialogAllowed then
        mission.Log(methodName, "Defender and station objectives are both done - starting dialog and moving to next phase.")

        mission.data.custom.phase3DialogAllowed = false 
        invokeClientFunction(Player(), "onPhase3Dialog", mission.data.custom.horizonStationID)
    end

    sync()
end

local onPhase3DialogFireTorp = makeDialogServerCallback("onPhase3DialogFireTorp", 3, function()
    local _MethodName = "Oh Phase 3 Dialog Fire Torp"
    mission.Log(_MethodName, "Starting.")

    local _Varlance = Entity(mission.data.custom.varlanceID)
    _Varlance:invokeFunction("torpedoslammer.lua", "resetTimeToActive", 0)
end)

local onPhase3DialogEnd = makeDialogServerCallback("onPhase3DialogEnd", 3, function()
    awacsDeparts()
    nextPhase()
end)

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].onBegin = function()
    mission.data.description[7].visible = true
end

mission.phases[4].onBeginServer = function()
    HorizonUtil.varlanceChatter("And now we wait...")
    setVarlancePhase4Orders()
end

--region #PHASE 4 TIMERS

if onServer() then

mission.phases[4].timers[1] = {
    time = 60,
    callback = function()
        --Don't do anything if we're not in the sector in question.
        if atTargetLocation() then
            --Send chatter if needed.
            if not mission.data.custom.varlanceP4ChatterSent then
                HorizonUtil.varlanceChatter("There they are. Eliminate them as they jump in. Sweep the installation too if you get the chance - it already served its purpose.")
                
                mission.data.description[8].visible = true
    
                mission.data.custom.varlanceP4ChatterSent = true
                sync()
            end
    
            --Spawn the next wave if needed.
            local horizonCt = ESCCUtil.countEntitiesByValue("is_horizon_ship")
            if horizonCt == 0 and mission.data.custom.waveNumber <= 3 then
                spawnHorizonWave()
    
                mission.data.custom.waveNumber = mission.data.custom.waveNumber + 1
            end
        end
    end,
    repeating = true
}

mission.phases[4].timers[2] = {
    time = 5,
    callback = function()
        --Don't do anything if not on location.
        if atTargetLocation() then
            --Mark fleet destroyed if applicable.
            local horizonShipCt = ESCCUtil.countEntitiesByValue("is_horizon_ship")
            if horizonShipCt == 0 and mission.data.custom.waveNumber == 4 then
                mission.data.description[7].fulfilled = true
            end
    
            --Mark station destroyed if applicable.
            local horizonStationCt = ESCCUtil.countEntitiesByValue("is_horizon_station")
            if horizonStationCt == 0 then
                mission.data.description[8].fulfilled = true
            end
    
            --Advance to next phase if both of the above objectives are done.
            local horizonCt = ESCCUtil.countEntitiesByValue("is_horizon")
            if horizonCt == 0 and mission.data.custom.waveNumber == 4 then
                nextPhase()
            end

            --Need to sync for mission objectives.
            sync()
        end
    end,
    repeating = true
}

end

--endregion

mission.phases[5] = {}
mission.phases[5].onBeginServer = function()
    spawnVarlance()

    invokeClientFunction(Player(), "onPhase5Dialog", mission.data.custom.varlanceID)
end

local onPhase5DialogEnd = makeDialogServerCallback("onPhase5DialogEnd", 5, function()
    local _Varlance = Entity(mission.data.custom.varlanceID)
    _Varlance:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))

    finishAndReward()
end)

--endregion

--region #SERVER CALLS

function getNextLocation(_onBlockRing)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    if _onBlockRing then
        --Get a sector that's very close to the outer edge of the barrier.
        mission.Log(_MethodName, "BlockRingMax is " .. tostring(Balancing.BlockRingMax))
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, Balancing.BlockRingMax + 10)
        target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
        local _safetyBreakout = 0
        while target.x == x and target.y == y and _safetyBreakout <= 100 do
            target.x, target.y = MissionUT.getEmptySector(_Nx,_Ny, 6, 12, false)
            _safetyBreakout = _safetyBreakout + 1
        end
    else
        target.x, target.y = MissionUT.getEmptySector(x, y, 6, 16, false)
    end

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function buildObjectiveSector(x, y)
    local _MethodName = "Build Objective Sector"
    mission.Log(_MethodName, "Beginning.")

    local _random = random()

    local _Generator = SectorGenerator(x, y)

    _Generator:createAsteroidField()

    local _fields = _random:getInt(3, 5)
    --Add: 3-5 small asteroid fields.
    for _ = 1, _fields do
        _Generator:createSmallAsteroidField()
    end

    local look = _random:getVector(-100, 100)
    local up = _random:getVector(-100, 100)
    local pos = vec3(0, 0, 0)
    local _Player = Player()
    local _Ship = Entity(_Player.craftIndex)

    if _Ship then
        pos = _Ship.translationf
    end

    local _basepos = ESCCUtil.getVectorAtDistance(pos, 4500, true)
    local matrix = MatrixLookUpPosition(look, up, _basepos)
    
    --Spawn horizon station.
    local _Station = HorizonUtil.spawnHorizonResearchStation(false, matrix)
    mission.data.custom.horizonStationID = _Station.index

    --Spawn Ice Nova
    spawnVarlance()

    --Spawn AWACS
    HorizonUtil.spawnFrostbiteAWACS(false)

    --Spawn defenders
    local _HorizonFaction = HorizonUtil.getEnemyFaction()
    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, "Low")
    local _CreatedPirateTable = {}

    for _, _Pirate in pairs(_PirateTable) do
        local pLook = _random:getVector(-100, 100)
        local pUp = _random:getVector(-100, 100)
        local pPos = ESCCUtil.getVectorAtDistance(_Station.translationf, 1000, false)

        local _ship = PirateGenerator.createScaledPirateByName(_Pirate, MatrixLookUpPosition(pLook, pUp, pPos))
        _ship.factionIndex = _HorizonFaction.index
        _ship:setValue("is_horizon_defender", true)

        local _attackerData = {
            _TargetPriority = 1,
            _TargetTag = "is_frostbite_awacs"
        }

        _ship:addScriptOnce("ai/priorityattacker.lua", _attackerData)

        table.insert(_CreatedPirateTable, _ship)
    end

    SpawnUtility.addEnemyBuffs(_CreatedPirateTable)

    Placer.resolveIntersections()

    mission.data.custom.cleanUpSector = true
end

function spawnVarlance()
    local _MethodName = "Spawn Varlance"
    
    local _spawnVarlance = true
    if mission.data.custom.varlanceID then
        local _Varlance = Entity(mission.data.custom.varlanceID)
        if _Varlance and valid(_Varlance) and not _Varlance:getValue("varlance_withdrawing") then
            _spawnVarlance = false
        end
    end

    if _spawnVarlance then
        mission.Log(_MethodName, "No Varlance in sector - spawning him in.")

        local _Varlance = HorizonUtil.spawnVarlanceBattleship(false)
        local _VarlanceAI = ShipAI(_Varlance)

        --give him a very special torpslammer
        local _SlammerData = {
            _ROF = 2,
            _DurabilityFactor = 999,
            _TimeToActive = math.huge,
            _TargetPriority = 2,
            _TargetTag = "is_horizon_station",
            _ReachFactor = 999,
            _TurningSpeedFactor = 999,
            _ShockwaveFactor = 6,
            _AccelFactor = 4,
            _VelocityFactor = 4,
            _PreferBodyType = 9, --Hawk
            _PreferWarheadType = 9, --EMP
            _LimitAmmo = true,
            _Ammo = 1
        }

        _Varlance:addScript("torpedoslammer.lua", _SlammerData)
    
        _VarlanceAI:setAggressive()

        mission.data.custom.varlanceID = _Varlance.index
    end
end

function awacsDeparts()
    local _awacsPlural = { Sector():getEntitiesByScriptValue("is_frostbite_awacs") }
    if #_awacsPlural > 0 then
        local _awacs = _awacsPlural[1]
        _awacs:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
        mission.data.description[4].fulfilled = true
    end
end

function frostbiteDeparts()
    local _frostbiteShips = { Sector():getEntitiesByScriptValue("is_frostbite") }
    for _, _ship in pairs(_frostbiteShips) do
        _ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(3, 6))
    end
end

function setVarlancePhase3Orders()
    local _Varlance = Entity(mission.data.custom.varlanceID)
    local _VarlanceAI = ShipAI(_Varlance)

    local horizonStation = Entity(mission.data.custom.horizonStationID)

    _VarlanceAI:stop()
    _VarlanceAI:setIdle()
    _VarlanceAI:setPassiveShooting(true)
    _VarlanceAI:setFlyLinear(horizonStation.translationf, 800, false)
end

function setVarlancePhase4Orders()
    local _Varlance = Entity(mission.data.custom.varlanceID)
    local _VarlanceAI = ShipAI(_Varlance)

    _VarlanceAI:setPassiveShooting(false)
    _VarlanceAI:setAggressive()
end

function spawnHorizonWave()
    local shipsSpawned = {}

    local shipPositions = PirateGenerator.getStandardPositions(5, 500, nil)

    local attackScript = "ai/priorityattacker.lua"

    local priorityPlayerAttackerValues = {
        _TargetPriority = 2
    }

    local priorityVarlanceAttackerValues = {
        _TargetPriority = 1,
        _TargetTag = "is_varlance"
    }

    local torpSlammerValuesTargetPlayer = {
        _TimeToActive = 5,
        _ROF = 6,
        _PreferWarheadType = 3, --Fusion
        _PreferBodyType = 7, --Osprey
        _DurabilityFactor = 4,
        _TargetPriority = 5, --Player's current ship.
        _pindex = Player().index
    }

    local torpSlammerValuesTargetVarlance = {
        _TimeToActive = 5,
        _ROF = 6,
        _PreferWarheadType = 3, --Fusion
        _PreferBodyType = 7, --Osprey
        _DurabilityFactor = 4,
        _TargetPriority = 2, --Script value
        _TargetTag = "is_varlance"
    }

    local spawnFuncTable = {
        function() --w1 = 2 combat cruiser / 2 arty
            local _arty1 = HorizonUtil.spawnHorizonArtyCruiser(false, shipPositions[1], nil)

            local _combat1 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[2], nil)

            local _combat2 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[3], nil)

            local _arty2 = HorizonUtil.spawnHorizonArtyCruiser(false, shipPositions[4], nil)

            --Even split - arty1 / combat1 go after player, arty2 / combat2 go after Varlance
            _arty1:addScriptOnce(attackScript, priorityPlayerAttackerValues)
            _arty2:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _combat1:addScriptOnce(attackScript, priorityPlayerAttackerValues)
            _combat2:addScriptOnce(attackScript, priorityVarlanceAttackerValues)

            _arty1:addScriptOnce("torpedoslammer.lua", torpSlammerValuesTargetPlayer)
            _arty2:addScriptOnce("torpedoslammer.lua", torpSlammerValuesTargetVarlance)

            table.insert(shipsSpawned, _arty1)
            table.insert(shipsSpawned, _arty2)
            table.insert(shipsSpawned, _combat1)
            table.insert(shipsSpawned, _combat2)
        end,
        function() --w2 = 2 combat / 2 arty / 1 battleship
            local _combat1 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[1], nil)

            local _arty1 = HorizonUtil.spawnHorizonArtyCruiser(false, shipPositions[2], nil)

            local _bship1 = HorizonUtil.spawnHorizonBattleship(false, shipPositions[3], nil)

            local _arty2 = HorizonUtil.spawnHorizonArtyCruiser(false, shipPositions[4], nil)

            local _combat2 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[5], nil)

            --even split on combat / arty going after the player like w1 - battleship goes after the player.
            _arty1:addScriptOnce(attackScript, priorityPlayerAttackerValues)
            _arty2:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _combat1:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _combat2:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _bship1:addScriptOnce(attackScript, priorityPlayerAttackerValues)

            _arty1:addScriptOnce("torpedoslammer.lua", torpSlammerValuesTargetPlayer)
            _arty2:addScriptOnce("torpedoslammer.lua", torpSlammerValuesTargetVarlance)

            table.insert(shipsSpawned, _arty1)
            table.insert(shipsSpawned, _arty2)
            table.insert(shipsSpawned, _combat1)
            table.insert(shipsSpawned, _combat2)
            table.insert(shipsSpawned, _bship1)
        end,
        function() --w3 = 3 combat / 2 battleship
            local _combat1 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[1], nil)

            local _bship1 = HorizonUtil.spawnHorizonBattleship(false, shipPositions[2], nil)

            local _bship2 = HorizonUtil.spawnHorizonBattleship(false, shipPositions[3], nil)

            local _combat2 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[4], nil)

            local _combat3 = HorizonUtil.spawnHorizonCombatCruiser(false, shipPositions[5], nil)

            --combat1 / combat2 go after varlance, all remaining ships go after player.
            _combat1:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _combat2:addScriptOnce(attackScript, priorityVarlanceAttackerValues)
            _combat3:addScriptOnce(attackScript, priorityPlayerAttackerValues)
            _bship1:addScriptOnce(attackScript, priorityPlayerAttackerValues)
            _bship2:addScriptOnce(attackScript, priorityPlayerAttackerValues)

            local withdrawData = {
                _Threshold = 0.10,
                _Invincibility = 0.01
            }

            _bship1:addScriptOnce("ai/withdrawatlowhealth.lua", withdrawData)
            _bship2:addScriptOnce("ai/withdrawatlowhealth.lua", withdrawData)            

            table.insert(shipsSpawned, _combat1)
            table.insert(shipsSpawned, _combat2)
            table.insert(shipsSpawned, _combat3)
            table.insert(shipsSpawned, _bship1)
            table.insert(shipsSpawned, _bship2)
        end
    }

    local waveidx = mission.data.custom.waveNumber

    spawnFuncTable[waveidx]()

    for _, _ship in pairs(shipsSpawned) do
        --This will be overridden pretty quickly by the ai script but it is needed.
        local _shipAI = ShipAI(_ship)
        _shipAI:setAggressive()        
    end

    SpawnUtility.addEnemyBuffs(shipsSpawned)

    Placer.resolveIntersections()
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _player = Player()

    local _AccomplishMessage = "Frostbite Company thanks you. Here's your compensation."
    local _Reward = 27440000
    local _PaymentMessage = "Earned %1% credits for destroying the Horizon Keeper fleet."

    if mission.data.custom.awacsRewardBonus then
        _Reward = _Reward * 1.1
        _PaymentMessage = "Earned %1% credits for destroying the Horizon Keeper fleet. This includes a bonus for excellent work."
    end

    _player:setValue("_horizonkeepers_story_stage", 6)

    _player:sendChatMessage("Frostbite Company", 0, _AccomplishMessage)
    mission.data.reward = {credits = _Reward, paymentMessage = _PaymentMessage }

    HorizonUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onPhase3Dialog(_StationID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}

    d0.text = "<Intercepted> HQ, this is Research Installation HRI-7873-SRD6F6C. Our defenders have been terminated by a powerful independent strike force. Requesting immediate assistance. Send all response teams!"
    d0.followUp = d1

    d1.text = "There's the distress call. Let's turn that off. Gunnery, fire the modified EMP torpedo."
    d1.followUp = d2
    d1.onStart = onPhase3DialogFireTorp

    d2.text = "Excellent. That will silence our bait."
    d2.followUp = d3

    d3.text = "We'll edit that on retransmission and downplay our attack. With any luck, once the first wave realizes their mistake, it will be too late for them to reorganize their deployment."
    d3.followUp = d4

    d4.text= "AWACS, you're cleared to depart. We won't be able to defend you from whatever Horizon decides to bring in next."
    d4.followUp = d5

    d5.text = "Understood! Good luck, Captain Varlance! And to you as well, Captain. Activating hyperdrive now."
    d5.talker = "Frostbite AWACS"
    d5.onEnd = onPhase3DialogEnd

    ESCCUtil.setTalkerTextColors({d1, d2, d3, d4}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(_StationID):interactShowDialog(d0, false)
end

function onPhase5Dialog(varlanceID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    d0.text = "No more incoming subspace vectors detected."
    d0.followUp = d1

    d1.text = "That should be a significant portion of their local assets. I can't imagine they'll have much more to draw on - especially not with two of their battleships lost and another two critically damaged."
    d1.followUp = d2

    d2.text = "Speaking of - we'll need to hunt those down before we take any further offensive action against Horizon Keepers."
    d2.followUp = d3

    d3.text = "Good work today, buddy. I'll contact you once I've figured out where they're hiding. Won't take too long - it's likely they made a crash jump to escape."
    d3.onEnd = onPhase5DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(varlanceID):interactShowDialog(d0, false)
end

--endregion