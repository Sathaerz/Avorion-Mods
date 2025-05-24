--[[
	Story Mission 4
	March of the Cavaliers
	This is the longest and most complicated mission I've ever created, bar none. It makes the 1st story mission look very simple by comparison.
	ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
		- Story Mission 3 done.
		- Cavaliers Rank 4.
		- Cavaliers Strength 2. (Done Deliver Advance Materials at least 1)
	ROUGH OUTLINE:
		- Meet with other Cavaliers
		- Meet at the start location.
		- First Jump - minor pirate attack.
		- Second Jump - Animosity boss fight.
		- Third Jump - Crosses barrier + major xsotan attack.
		- Fourth Jump - Find artifact + minor xsotan attack.
	DANGER LEVEL:
		- 5+ The mission starts at Danger Level 5. It is a fixed value since this is a non-repeatable* story mission.
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
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local SpawnUtility = include ("spawnutility")
local Xsotan = include("story/xsotan")

mission._Debug = 0
mission._Name = "March of The Cavaliers"

local _TransferMinTime = 118 --118 / 12
local _TransferMaxTime = 124 --124 / 14
local _TransferTimerTime = 125 --125 / 15
local _TransferTimerHalfTime = 60 --60 / 6

--region #INIT

local llte_storymission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "March of the Cavaliers Begin...")

    if onServer()then
        if not _restoring then
            --Standard mission data.
            mission.data.brief = mission._Name
            mission.data.title = mission._Name
			mission.data.autoTrackMission = true
			mission.data.icon = "data/textures/icons/cavaliers.png"
			mission.data.priority = 9
            mission.data.description = { 
                "In order to defeat the threat of the Xsotan, the Cavaliers are pushing past the barrier.",
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false },
				--If any of these have an X / Y coordinate, they will be updated with the correct location when starting the appropriate phase.
				{ text = "Meet The Cavaliers in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Make the jump to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "At least two of the three capital ships '${_SHIP1}', '${_SHIP2}', and '${_SHIP3}' must survive", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Defeat the pirate attack", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Make the next jump to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Defeat the Animosity", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Make the next jump to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Defeat the Xsotan attack", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Make the next jump to (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Investigate the signals in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Protect the recovery ship while it recovers the Xsotan wreckage", bulletPoint = true, fulfilled = false, visible = false },
				{ text = "Return to The Cavaliers fleet in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }
            }

            --[[=====================================================
                CUSTOM MISSION DATA:
				.dangerLevel
				.pirateLevel
				.capitalsSpawned
				.sector1
				.sector2
				.sector3
				.sector4
				.sector5
				.beaconsector
				.phase2DialogAdded
				.phase3TimerStarted
				.phase4TimerStarted
				.phase5TimerStarted
				.phase6TimerStarted
				.phase7TimerStarted
				.initialPhase7Startup
				.secondScoutWaveSpawned
				.empressBladeid
				.animosityid
				.capitalsLost
				.transferring
				.miniswarm
				.xsotankilled
				.tugs
            =========================================================]]
			mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
			mission.data.custom.pirateLevel = Player():getValue("_llte_pirate_faction_vengeance")
			mission.data.custom.capitalsLost = 0
			mission.data.custom.xsotankilled = 0
			mission.data.custom.tugs = 0

            local missionReward = 1000000

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

mission.globalPhase.timers = {}
mission.globalPhase.triggers = {}

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.timers[1] = {
	time = 60,
	callback = function()
		if onServer() then
			local _MethodName = "Global Phase Timer 1 Callback"
			mission.Log(_MethodName, "Beginning...")
			--Don't do this until phase 2 at least, and don't do this if the blade of the empress is not in the sector.
			if mission.data.custom.phase2DialogAdded and ESCCUtil.countEntitiesByValue("_llte_empressblade") > 0 then
				local _Defenders = 0
				local _HeavyDefenders = 0
				local _CavShips = {Sector():getEntitiesByScriptValue("is_cavaliers")}
				for _, _Cav in pairs(_CavShips) do
					if _Cav:getValue("is_defender") then
						if _Cav:getValue("is_heavy_defender") then
							_HeavyDefenders = _HeavyDefenders + 1
						else
							_Defenders = _Defenders + 1
						end
					end
				end
				local _D2S = math.max(3 - _Defenders, 0)
				local _HD2S = math.max(3 - _HeavyDefenders, 0)
				mission.Log(_MethodName, "Spawning " .. tostring(_D2S) .. " defenders and " .. tostring(_HD2S) .. " heavy defenders.")
				spawnCavalierShips(_D2S, _HD2S)
			end
		end
	end,
	repeating = true
}

mission.globalPhase.onAbandon = function()
	Player():unregisterCallback("onPreRenderHud", "onMarkArtifact")
    runFullSectorCleanup_llte()
end

mission.globalPhase.onFail = function()
    --If there are any Cavaliers ships, they warp out.
    local _MethodName = "On Fail"
    mission.Log(_MethodName, "Beginning...")

	--Pirates, Xsotan, and Cavaliers withdraw.
	LLTEUtil.allCavaliersDepart()

	local _AnimosityTable = {Sector():getEntitiesByScriptValue("is_animosity")}
	if #_AnimosityTable >= 1 then
		local _Animosity = _AnimosityTable[1]
		Player():sendChatMessage(_Animosity, 0, "So much for the vaunted strength of The Cavaliers...")
	end
	
	ESCCUtil.allPiratesDepart()
	ESCCUtil.allXsotanDepart()

    --Add a script to the mission location to nuke it if we are there, nuke it remotely otherwise.
    runFullSectorCleanup_llte()
    --Send fail mail.
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")

    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nDespite our new equipment and our best efforts, we lost too many ships on our push to the center of the galaxy and will need to withdraw our forces for the time being. We'll try again!\nGet yourself some stronger weapons and shields, and I'll reorganize the fleet for another push towards the galactic core. We must unravel the mystery of the Xsotan to defeat them once and for all!\n\nEmpress Adriana Stahl", _Rank, _Player.name)
	_Mail.header = "Forced to Withdraw"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story4_mailfail"
	_Player:addMail(_Mail)
end

mission.globalPhase.onAccomplish = function()
	local _Player = Player()
	local _Rank = _Player:getValue("_llte_cavaliers_rank")

	local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nThank you once again for your help with reaching the center. Despite being newcomers, we've managed to establish ourselves as one of the strongest military powers in the region. Securing the remnants of the factions here is going smoothly, and we're holding off the Xsotan about as well as can be expected. They're much stronger here!\n\nRegarding the artifact, we've spent a considerable amount of time running deep scans on it. As far as we can tell, it seems to be some sort of beacon that's capable of entering a high-energy state and emitting incredibly strong signals over subspace. Judging from their behavior when we first breached the barrier, these signals will draw Xsotan like moths to a flame.\nWe think we can use this as bait to lure in Xsotan to destroy, but we haven't figured out a way to deliberately activate the artifact. I'll contact you again with an update.\n\nEmpress Adriana Stahl", _Rank, _Player.name)
	_Mail.header = "Our Analysis Continues"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story4_mailwin"
	_Player:addMail(_Mail)
end

mission.globalPhase.onEntityDestroyed = function(id, lastDamageInflictor)
    local _MethodName = "Global Phase On Entity Destroyed"

	local _Entity = Entity(id)
	if valid(_Entity) then
		if _Entity:getValue("_llte_cav_supercap") then
			mission.data.custom.capitalsLost = mission.data.custom.capitalsLost + 1
			mission.Log(_MethodName, "Lost a SuperCap - increasing count of capital ships lost. Currently " .. tostring(mission.data.custom.capitalsLost) .. " are lost.")
		end
		if _Entity:getValue("is_animosity") then
			Player():setValue("_llte_got_animosity_loot", true)
			Player():setValue("encyclopedia_llte_animosity_found", true)
			mission.data.description[8].fulfilled = true
			ESCCUtil.allPiratesDepart()
			sync()

			invokeClientFunction(Player(), "onPhase4Dialog2", mission.data.custom.empressBladeid)
		end
	end
	
	if mission.data.custom.capitalsLost > 1 then
		runFullSectorCleanup_llte()
		fail()
	end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.sector1 = getNextLocation(1)
    local _X, _Y = mission.data.custom.sector1.x, mission.data.custom.sector1.y
    
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nThe Avorion that you delivered to us offers an incredible opportunity - one to push into the center of the galaxy and deal with the Xsotan threat once and for all. I'm planning an operation to do exactly that!\nThe fleet is gathering in sector (%3%:%4%) - meet us there and I'll brief you on our plan.\n\nEmpress Adriana Stahl", _Rank, _Player.name, _X, _Y)
	_Mail.header = "Crossing the Barrier"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story4_mail1"
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
				if _Mail.id == "_llte_story4_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = false
mission.phases[2].onBeginServer = function()
	local _MethodName = "Phase 2 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.location = mission.data.custom.sector1
	mission.data.custom.sector2 = getNextLocation(2)
    mission.data.description[2].fulfilled = true
	mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
	mission.data.description[3].visible = true
	mission.data.description[4].arguments = { _X = mission.data.custom.sector2.x, _Y = mission.data.custom.sector2.y }
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
	local _MethodName = "Phase 2 on Target Location Entered"
	mission.Log(_MethodName, "Beginning...")

	if not mission.data.custom.capitalsSpawned then
		local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress(false)
		_EmpressBlade:removeScript("ai/withdrawatlowhealth.lua") --Need to make sure she doesn't jump out somehow. She'll remain @ 2% if she gets too badly damaged.
		local _SuperCap1 = LLTEUtil.spawnCavalierSupercap(false)
		local _SuperCap2 = LLTEUtil.spawnCavalierSupercap(false)
		local _SuperCap3 = LLTEUtil.spawnCavalierSupercap(false)
		spawnCavalierShips(3, 3)
		mission.data.custom.empressBladeid = _EmpressBlade.id

		mission.data.description[5].arguments = { _SHIP1 = _SuperCap1.name, _SHIP2 = _SuperCap2.name, _SHIP3 = _SuperCap3.name }
		mission.data.custom.capitalsSpawned = true
	end
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(_X, _Y)
	local _MethodName = "Phase 2 on Target Location Arrival Confirmed"
	mission.Log(_MethodName, "Beginning...")
	--Add dialog to Empress Blade. Once that is done, set transferring to true and have the ships make the jump in 2 minutes.
	if not mission.data.custom.phase2DialogAdded then
		invokeClientFunction(Player(), "onPhase2Dialog", mission.data.custom.empressBladeid)
		mission.data.custom.phase2DialogAdded = true
	end
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].triggers = {}
mission.phases[3].showUpdateOnEnd = false
mission.phases[3].onBeginServer = function()
	local _MethodName = "Phase 3 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.custom.sector3 = getNextLocation(3)
end

mission.phases[3].onEntityDestroyed = function(id, lastDamageInflictor)
    local _MethodName = "Phase 3 On Entity Destroyed"

	local _Entity = Entity(id)
	if valid(_Entity) and _Entity:getValue("is_pirate") and not mission.data.custom.secondScoutWaveSpawned then
		spawnPirateWave(1)
		--Set up a trigger to attach a script once the pirates are dead. For some reason a vanquish check doesn't work.
		mission.phases[3].triggers[1] = {
			condition = function()
				if onServer() then
					return ESCCUtil.countEntitiesByValue("is_pirate") == 0
				else
					--We don't do this on the client.
					return true
				end
			end,
			callback = function()
				if onServer() then
					local _MethodName = "Phase 3 Pirate Vanquish Trigger Callback"
					invokeClientFunction(Player(), "onPhase3Dialog", mission.data.custom.empressBladeid)
				end
			end,
			repeating = false
		}
		mission.data.custom.secondScoutWaveSpawned = true
	end
end

mission.phases[3].updateTargetLocationServer = function(_TimeStep)
	local _MethodName = "Phase 3 Update Target Location Server"
	--It's possible that the player jumped ahead of The Cavaliers, so we only start this timer once the player is on-site.
	if not mission.data.custom.phase3TimerStarted then
		mission.Log(_MethodName, "Starting first pirate attack timer.")
		mission.data.description[4].fulfilled = true --Since this effectively serves as our "on arrived" we can set the objective / sync here.
		showMissionUpdated(mission._Name)

		mission.phases[3].timers[1] = { time = 11, callback = function() 
			broadcastEmpressBladeMsg("Subspace signals detected! Get ready for a fight!")
		end, repeating = false}
		mission.phases[3].timers[2] = { time = 14, callback = function() 
			spawnPirateWave(1)
			mission.data.description[6].visible = true
			showMissionUpdated(mission._Name)
			sync()
		end, repeating = false}

		sync()
		mission.data.custom.phase3TimerStarted = true
	end
end

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = false
mission.phases[4].noBossEncountersTargetSector = true
mission.phases[4].noPlayerEventsTargetSector = true
mission.phases[4].onBeginServer = function()
	local _MethodName = "Phase 4 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.custom.sector4 = getNextLocation(4)
end

mission.phases[4].updateTargetLocationServer = function(_TimeStep)
	local _MethodName = "Phase 4 Update Target Location Server"
	--It's possible that the player jumped ahead of The Cavaliers, so we only start this timer once the player is on-site.
	if not mission.data.custom.phase4TimerStarted then
		mission.Log(_MethodName, "Starting Animosity attack timer.")
		mission.data.description[7].fulfilled = true --Since this effectively serves as our "on arrived" we can set the objective / sync here.
		showMissionUpdated(mission._Name)

		mission.phases[4].timers[1] = { time = 11, callback = function() 
			broadcastEmpressBladeMsg("More subspace signals detected...")
		end, repeating = false}
		mission.phases[4].timers[2] = { time = 14, callback = function() 
			--Spawn the Animosity
			local _GotLoot = Player():getValue("_llte_got_animosity_loot")
			local _AddLoot = true
			if _GotLoot then _AddLoot = false end
			local _Animosity = LLTEUtil.spawnAnimosity(mission.data.custom.pirateLevel, _AddLoot)
			mission.data.custom.animosityid = _Animosity.id
			--Make ALL CAVALIERS SHIPS passive.
			local _CavShips = {Sector():getEntitiesByScriptValue("is_cavaliers")}
			for _, _Cav in pairs(_CavShips) do
				local _AI = ShipAI(_Cav.index)
				_AI:setPassive()
				_AI:stop()
			end
			ShipAI(_Animosity.index):setPassive()
			--Attach dialog script to the Animosity.
			_Animosity:addScriptOnce("player/missions/empress/story/story4/lltestory4animosity.lua")
			Shield(_Animosity.id).invincible = true
			mission.data.description[8].visible = true
			showMissionUpdated(mission._Name)
			sync()
		end, repeating = false}

		sync()
		mission.data.custom.phase4TimerStarted = true
	end
end

mission.phases[5] = {}
mission.phases[5].timers = {}
mission.phases[5].triggers = {}
mission.phases[5].triggers[1] = {
	condition = function()
		if onServer() then
			return true
		else
			local _ScriptUI = ScriptUI(mission.data.custom.empressBladeid)
			return _ScriptUI ~= nil
		end
	end,
	callback = function()
		if onClient() then
			onPhase5Dialog1(mission.data.custom.empressBladeid)
		end
	end,
	repeating = false
}
mission.phases[5].showUpdateOnEnd = false
mission.phases[5].onBeginServer = function()
	local _MethodName = "Phase 5 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.custom.sector5 = getNextLocation(5) --This is the last jump location.
end

mission.phases[5].onEntityDestroyed = function(id, lastDamageInflictor)
    local _MethodName = "Phase 5 On Entity Destroyed"

	local _Entity = Entity(id)
	if valid(_Entity) and _Entity:getValue("_llte_miniswarm_xsotan") then
		if mission.data.custom.miniswarm then
			mission.data.custom.xsotankilled = mission.data.custom.xsotankilled + 1
		end
		if mission.data.custom.xsotankilled >= 40 then
			mission.data.custom.miniswarm = false
		end	
	end
end

mission.phases[5].updateTargetLocationServer = function(_TimeStep) 
	local _MethodName = "Phase 5 Update Target Location Server"
	--Remember, the player could have jumped ahead, so we need to activate this phase here and not in an "on sector entered"
	--^^^ Y'know, in case you don't see this comment in the previous 2 phase calls.
	local _EmpressBlade = Entity(mission.data.custom.empressBladeid)
	if valid(_EmpressBlade) then
		--I had to split this into this method / a client only trigger due to the dialog displaying immediately, but it is what it is.
		if not mission.data.custom.phase5TimerStarted then
			mission.Log(_MethodName, "Updating mission for phase 5")
			mission.data.description[9].fulfilled = true --Since this effectively serves as our "on arrived" we can set the objective / sync here.
			showMissionUpdated(mission._Name)
			sync()

			mission.data.custom.phase5TimerStarted = true
		end
	end
end

mission.phases[6] = {}
mission.phases[6].timers = {}
mission.phases[6].triggers = {}
mission.phases[6].triggers[1] = {
	condition = function()
		if onServer() then
			return true
		else
			local _ScriptUI = ScriptUI(mission.data.custom.empressBladeid)
			return _ScriptUI ~= nil
		end
	end,
	callback = function()
		if onClient() then
			onPhase6Dialog(mission.data.custom.empressBladeid, mission.data.custom.beaconsector.x, mission.data.custom.beaconsector.y)
		end
	end,
	repeating = false
}
mission.phases[6].showUpdateOnEnd = false
mission.phases[6].onBeginServer = function()
	local _MethodName = "Phase 6 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.custom.beaconsector = getBeaconLocation()
end

mission.phases[6].updateTargetLocationServer = function(_TimeStep)
	local _MethodName = "Phase 5 Update Target Location Server"
	--Blah blah jumped ahead. Blah blah. You know the drill by now.
	local _EmpressBlade = Entity(mission.data.custom.empressBladeid)
	local _Sector = Sector()
	local _X, _Y = _Sector:getCoordinates()

	if valid(_EmpressBlade) then
		if not mission.data.custom.phase6TimerStarted then --This is a bit of a misnomer, but I'm leaving the name the same for consistency reasons.
			mission.Log(_MethodName, "Updating mission for phase 6")
			mission.data.description[11].fulfilled = true --Since this effectively serves as our "on arrived" we can set the objective / sync here.
			showMissionUpdated(mission._Name)
			sync()

			mission.data.custom.phase6TimerStarted = true
		end
	end
end

mission.phases[7] = {}
mission.phases[7].timers = {}
mission.phases[7].triggers = {}
mission.phases[7].showUpdateOnStart = true
mission.phases[7].onBeginServer = function()
	local _MethodName = "Phase 7 On Begin Server"
	mission.Log(_MethodName, "Beginning...")
	mission.data.description[12].arguments = { _X = mission.data.custom.beaconsector.x, _Y = mission.data.custom.beaconsector.y }
	mission.data.description[12].visible = true
	mission.data.location = mission.data.custom.beaconsector
end

mission.phases[7].onTargetLocationEntered = function(_X, _Y)
	if not mission.data.custom.initialPhase7Startup then
		--Make a fairly large asteroid field.
		local _Generator = SectorGenerator(_X, _Y)
		local _Sector = Sector()
		for _ = 1, 5 do
			_Generator:createAsteroidField()
		end

		for _ = 1, 7 do
			_Generator:createSmallAsteroidField()
		end

		--Make a xsotan wreckage with a becaon somewhere.
		spawnXsotanWave(3)
		local _XsotanEntities = {_Sector:getEntitiesByScriptValue("is_xsotan")}
		for _, _X in pairs(_XsotanEntities) do
			_X:destroy(_X.id)
		end

		mission.data.custom.initialPhase7Startup = true
	end
end

mission.phases[7].onTargetLocationArrivalConfirmed = function(_X, _Y)
	if not mission.data.custom.phase7TimerStarted then	
		local _Sector = Sector()
		local _Rgen = ESCCUtil.getRand()	

		Player():sendChatMessage("Adriana Stahl", 0, "Whatever is causing the signals seems to be emanating from one of the wrecks in this sector. We've marked it on your HUD.")

		--Kill all loot.
		for _, entity in pairs({_Sector:getEntities()}) do
			if entity.type == EntityType.Loot then
				_Sector:deleteEntity(entity)
			end
		end
	
		local _WreckageEntities = {_Sector:getEntitiesByType(EntityType.Wreckage)}
		local _TargetWreck
		shuffle(random(), _WreckageEntities)

		for idx = 1, #_WreckageEntities do
			local _XWreck = _WreckageEntities[idx]
			local _XPlan = Plan(_XWreck.id)
			if _XPlan.numBlocks >= 200 then
				_TargetWreck = _XWreck
				break
			end
		end

		--Sort of the same thing as making a wreckage out of a ship, but we just make a wreckage out of a wreckage. According to SDK, this will not have a despawn timer.
		local _Plan = _TargetWreck:getMovePlan()
		_TargetWreck:setPlan(BlockPlan())
		local _ActualWreck = _Sector:createWreckage(_Plan, _TargetWreck.position)
		_ActualWreck:setValue("_llte_story4_xsotan_artifact", true)

		--Register prerender call.
		registerMarkArtifact()

		--Timers - 1 => tug + damage wreck to keep it active / 2 => actually spawn tug / 3 => xsotan swarm timer
		--Start the timer for the tug.
		mission.phases[7].timers[1] = {
			time = 60,
			callback = function()
				local _MethodName = "Phase 7 Timer 1"
				local _X, _Y = Sector():getCoordinates()
				if _X ~= mission.data.location.x or _Y ~= mission.data.location.y then
					mission.Log(_MethodName, "Not in mission location. Cancelling execution of this trigger.")
					return
				end
				
				local _TugCount = ESCCUtil.countEntitiesByValue("_llte_story4_artifactsalvager")
				if _TugCount == 0 then
					mission.data.custom.tugs = mission.data.custom.tugs + 1
					if mission.data.custom.tugs == 1 then
						Player():sendChatMessage("Adriana Stahl", 0, "We're sending in a recovery ship. Protect it while it recovers the whatever is causing those signals!")
					else
						Player():sendChatMessage("Adriana Stahl", 0, "We're sending in another recovery ship. Try not to lose this one too!")
					end

					--Start timer to spawn tug.
					mission.phases[7].timers[2] = {
						time = 8,
						callback = function()
							spawnWreckageSalvager()
						end,
						repeating = false
					}
				end
			end,
			repeating = true
		}

		--Start the timers for the 2nd mini-swarm.
		mission.phases[7].timers[3] = {
			time = 30,
			callback = function()
				spawnXsotanWave(1, 20)
			end,
			repeating = true
		}

		mission.data.custom.phase7TimerStarted = true
	end
end

mission.phases[8] = {}
mission.phases[8].timers = {}
mission.phases[8].triggers = {}
mission.phases[8].triggers[1] = {
	condition = function()
		if onServer() then
			return true
		else
			local _ScriptUI = ScriptUI(mission.data.custom.empressBladeid)
			return _ScriptUI ~= nil
		end
	end,
	callback = function()
		if onClient() then
			onPhase8Dialog(mission.data.custom.empressBladeid)
		end
	end,
	repeating = false
}
mission.phases[8].showUpdateOnEnd = false
mission.phases[8].onBeginServer = function()
	local _MissionName = "Phase 8 On Begin Server"
	mission.data.description[14].arguments = { _X = mission.data.custom.sector5.x, _Y = mission.data.custom.sector5.y }
	mission.data.description[14].visible = true
	mission.data.description[13].fulfilled = true
	mission.data.location = mission.data.custom.sector5
end

--endregion

--region #SERVER CALLS

--region #SPAWN OBJECTS

function spawnCavalierShips(_Defenders, _HeavyDefenders)
    local _Faction =  Galaxy():findFaction("The Cavaliers")
    local _Generator = AsyncShipGenerator(nil, onCavaliersFinished)
    _Generator:startBatch()

	if _Defenders > 0 then
		for _ = 1, _Defenders do
			_Generator:createDefender(_Faction, PirateGenerator.getGenericPosition())
		end
	end

	if _HeavyDefenders > 0 then
		for _ = 1, _HeavyDefenders do
			_Generator:createHeavyDefender(_Faction, PirateGenerator.getGenericPosition())
		end
	end

    _Generator:endBatch()
end

function spawnPirateWave(_Type)
	local _PirateGenerator = AsyncPirateGenerator(nil, onPirateWaveFinished)
	_PirateGenerator.pirateLevel = mission.data.custom.pirateLevel --I believe this has a built-in failsafe.
	local _WaveTable
	if _Type == 1 then
		_WaveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 5, "Low")
	elseif _Type == 2 then
		_WaveTable = ESCCUtil.getStandardWave(10, 5, "High")
	end

	local _PosCounter = 1
	local _PiratePositions = _PirateGenerator:getStandardPositions(#_WaveTable, 150)

	_PirateGenerator:startBatch()

	for _, _P in pairs(_WaveTable) do
		_PirateGenerator:createScaledPirateByName(_P, _PiratePositions[_PosCounter])
		_PosCounter = _PosCounter + 1
	end

	_PirateGenerator:endBatch()
end

function spawnXsotanWave(_Type, _XsotanMax)
	local _MethodName = "Spawn Xsotan Wave"
	_Type = _Type or 1
	_XsotanMax = _XsotanMax or 25

	local _Sector = Sector()
	local _Generator = SectorGenerator(_Sector:getCoordinates())
	local _Players = {_Sector:getPlayers()}
	local _XsotanCount = ESCCUtil.countEntitiesByValue("is_xsotan")
	local _Rgen = ESCCUtil.getRand()

	local _XsotanToSpawn = _XsotanMax - _XsotanCount
	--Don't spawn more than 5 at once for performance reasons.
	if _XsotanToSpawn > 5 then
		_XsotanToSpawn = 5
	end

	local _XsoMinSize = 1
	local _XsoMaxSize = 3
	local _BigXsoChance = 1
	local _BigXsoFactor = 2
	local _FirepowerFactor = 1
	if _Type == 2 then --Shows up for the 2nd half.
		_XsoMinSize = 4
		_XsoMaxSize = 7
		_BigXsoChance = 2
		_BigXsoFactor = 2.5
		_FirepowerFactor = 2
	elseif _Type == 3 then --These waves will only show up if the player / cavaliers are killing the Xsotan too quickly.
		_XsoMinSize = 6
		_XsoMaxSize = 10
		_BigXsoChance = 2
		_BigXsoFactor = 3
		_FirepowerFactor = 4
	end

	mission.Log(_MethodName, "Spawning final count of " .. tostring(_XsotanToSpawn) .. " Xsotan ships.")
	local _XsotanTable = {}
    --Spawn Xsotan based on what's in the nametable.
	for _ = 1, _XsotanToSpawn do
		local _Xsotan = nil
		local _Dist = 1500
		local _XsoSize = _Rgen:getInt(_XsoMinSize, _XsoMaxSize)
		if _Rgen:getInt(1, 4) <= _BigXsoChance then
			_XsoSize = _XsoSize * _BigXsoFactor --% chance to make a beefier Xsotan.
		end
        _Xsotan = Xsotan.createShip(_Generator:getPositionInSector(_Dist), _XsoSize)

        if _Xsotan then
            if valid(_Xsotan) then
                for _, p in pairs(_Players) do
                    ShipAI(_Xsotan.id):registerEnemyFaction(p.index)
                end
                ShipAI(_Xsotan.id):setAggressive()
            end
            _Xsotan:setValue("_llte_miniswarm_xsotan", true)
            table.insert(_XsotanTable, _Xsotan)
        else
            mission.Log(_MethodName, "ERROR - Xsotan was nil")
        end
    end

	SpawnUtility.addEnemyBuffs(_XsotanTable)
	for _, _X in pairs(_XsotanTable) do
		_X.damageMultiplier = (_X.damageMultiplier or 1) * _FirepowerFactor
	end
end

function spawnWreckageSalvager()
	local _Faction =  Galaxy():findFaction("The Cavaliers")
	local _Generator = AsyncShipGenerator(nil, onWreckageSalvagerFinished)
	local _Sector = Sector()
	local _X, _Y = _Sector:getCoordinates()
	local _SalvagerVolume = Balancing_GetSectorShipVolume(_X, _Y) * 8

	_Generator:startBatch()
	
	_Generator:createMiningShip(_Faction, _Generator:getGenericPosition(), _SalvagerVolume)

	_Generator:endBatch()
end

--endregion

--region #DESPAWN OBJECTS

function runFullSectorCleanup_llte()
	local _Sector = Sector()
	local _X, _Y = Sector():getCoordinates()
	local _EntityTypes = ESCCUtil.allEntityTypes()
	_Sector:addScriptOnce("sector/deleteentitiesonplayersleft.lua", _EntityTypes)

    if _X == mission.data.location.x and _Y == mission.data.location.y then
        _Sector:addScriptOnce("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
    end
end

--endregion

function broadcastEmpressBladeMsg(_Msg, ...)
	local _Sector = Sector()
	local _EmpressBlade = {_Sector:getEntitiesByScriptValue("_llte_empressblade")}
	_Sector:broadcastChatMessage(_EmpressBlade[1], ChatMessageType.Normal, _Msg, ...)
end

function onCavaliersFinished(_Generated)
    local _MethodName = "On Cavaliers Finished"
    for _, _S in pairs(_Generated) do
        _S.title = "Cavaliers " .. _S.title
        _S:setValue("npc_chatter", nil)
        _S:setValue("is_cavaliers", true)

		local _WithdrawData = {
        	_Threshold = 0.15
        }

        _S:addScript("ai/withdrawatlowhealth.lua", _WithdrawData)
		_S:removeScript("antismuggle.lua")
		LLTEUtil.rebuildShipWeapons(_S, Player():getValue("_llte_cavaliers_strength"))
    end
end

function onWreckageSalvagerFinished(_Generated)
	local _MethodName = "On Wreckage Salvager Finished"
	local _Miner = _Generated[1]

	_Miner.title = "Cavaliers Recovery Ship"

	_Miner:removeScript("civilship.lua")
    _Miner:removeScript("dialogs/storyhints.lua")
    _Miner:setValue("is_civil", nil)
    _Miner:setValue("is_miner", nil)
	_Miner:setValue("npc_chatter", nil)
	_Miner:setValue("is_cavaliers", true)
	_Miner:setValue("_llte_story4_artifactsalvager", true)

	local _StoryWrecks = {Sector():getEntitiesByScriptValue("_llte_story4_xsotan_artifact")}
	local _StoryWreck = _StoryWrecks[1]

	_Miner:addScript("player/missions/empress/story/story4/lltestory4artifactship.lua", _StoryWreck)

    mission.Log(_MethodName, "Updating mission objectives")
    mission.data.description[12].fulfilled = true
    mission.data.description[13].visible = true

    sync()
end

function onPirateWaveFinished(_Generated)
	SpawnUtility.addEnemyBuffs(_Generated)
end

function returnToLastStop()
	local _MethodName = "Return to Last Stop"
	mission.Log(_MethodName, "Beginning...")
	local _Sector = Sector()

	local _X, _Y = mission.data.custom.sector5.x, mission.data.custom.sector5.y

	--jump the artifact ship to the previous sector
	local _RecoveryShips = {_Sector:getEntitiesByScriptValue("_llte_story4_artifactsalvager")}
    Sector():transferEntity(_RecoveryShips[1], _X, _Y, SectorChangeType.Jump)

	--jump the wreck to the previous sector
	local _Wrecks = {_Sector:getEntitiesByScriptValue("_llte_story4_xsotan_artifact")}
	Sector():transferEntity(_Wrecks[1], _X, _Y, SectorChangeType.Jump)

	Player():sendChatMessage("Adriana Stahl", 0, "Artifact retrieved! Come back to \\s(%1%:%2%) for debriefing.", _X, _Y)
	Player():setValue("encyclopedia_llte_xsotan_artifact_found", true)

	--move to final stage of mission
	nextPhase()
end

function getNextLocation(_Location)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
	local target = {}
	
	local _NxTable = {
		{ _RingPos = 187, _InBarrier = false },
		{ _RingPos = 180, _InBarrier = false },
		{ _RingPos = 160, _InBarrier = false },
		{ _RingPos = 140, _InBarrier = true },
		{ _RingPos = 120, _InBarrier = true }
	}

	local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, _NxTable[_Location]._RingPos)
	target.x, target.y = MissionUT.getSector(_Nx, _Ny, 1, 4, false, false, false, false, _NxTable[_Location]._InBarrier)

	if target == nil or target.x == nil or target.y == nil then
		print("Could not get a location - enacting failsafe")
		target.x, target.y = MissionUT.getSector(x, y, 1, 20, false, false, false, false, _NxTable[_Location]._InBarrier)
	end	

    return target
end

function runTransfer(_FromLocation, _ToLocation)
	--If the player is in the mission sector, transfer the entities one by one. Otherwise, transfer them all at once - when the last one is transferred, advance the phase.
	local _Rgen = ESCCUtil.getRand()

	local _Cavaliers = {Sector():getEntitiesByScriptValue("is_cavaliers")}

	for _, _Cav in pairs(_Cavaliers) do
		_Cav:addScriptOnce("entity/utility/delayedjump.lua", _ToLocation.x, _ToLocation.y, _Rgen:getFloat(_TransferMinTime, _TransferMaxTime))
	end
end

function getBeaconLocation()
	local _MethodName = "Get Beacon Location"
	mission.Log(_MethodName, "Getting beacon location.")

	local x, y = Sector():getCoordinates()
	local _Target = {}

	_Target.x, _Target.y = MissionUT.getSector(x, y, 3, 6, false, false, false, false)
	return _Target
end

function llteStory4_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
	local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "Great job, " .. _Rank .. "!"
	}
	
	_Player:setValue("_llte_cavaliers_inbarrier", true)

	_Player:setValue("_llte_story_4_accomplished", true)

    --Increase reputation by 8
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + 8)
    _Player:sendChatMessage("Adriana Stahl", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " Here is your reward, as promised.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

--Oh look, another prerender UI call -_-
function onMarkArtifact()
    local _MethodName = "On Mark Artifact"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    local _Artifact = {Sector():getEntitiesByScriptValue("_llte_story4_xsotan_artifact")}
    for _, _A in pairs(_Artifact) do
        local _StandardOrange = ESCCUtil.getSaneColor(255, 173, 0)

        renderer:renderEntityTargeter(_A, _StandardOrange)
        renderer:renderEntityArrow(_A, 30, 10, 250, _StandardOrange)
    end

    renderer:display()
end

--Since we do multiple interactions we can't use singleinteraction-derived scripts.
function onPhase2Dialog(_ID)
	--At the start of the mission.
	local _MethodName = "On Phase 2 Dialog"
	mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

	local d0 = {}
	local d1 = {}
	local d2 = {}
	local d3 = {}
	local d4 = {}

	local _Player = Player()
	local _PlayerRank = _Player:getValue("_llte_cavaliers_rank")
    local _PlayerName = _Player.name

    --d0
    d0.text = _PlayerRank .. " " .. _PlayerName .. "! Glad to see you here!"
	d0.answers = {
		{ answer = "So, what's the plan?", followUp = d1 }
	}

	d1.text = "We've taken the Avorion that you delivered to us and fitted it to our hyperspace drives. We'll start here, then push all the way to the barrier. Lastly, enough of our ships have to make it through this, or it's all for nothing."
	d1.followUp = d4

	d4.text = "Once we reach the barrier we... just jump through it? That feels strange to say. 200 years of isolation and it's over just like that?"
	d4.answers = {
		{ answer = "It was a lot of work to make that happen, I'll have you know.", followUp = d2 }
	}

	d2.text = "You're right. Thank you for your efforts!"
	d2.answers = {
		{ answer = "You're welcome.", followUp = d3 }
	}

	d3.text = "We'll need a couple of minutes after each jump for our ships to recharge their hyperspace engines. We'll also transmit each jump location, so you should be able to keep up with us! Not that there was any doubt of that. Are you ready?"
	d3.answers = {
		{ answer = "I'm ready. Let's do this.", onSelect = "onPhase2DialogEnd" }
	}

	ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase3Dialog(_ID)
	--After the pirate attack.
	local _MethodName = "On Phase 3 Dialog"
	mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

	local d0 = {}
    local d1 = {}
    local d2 = {}

    --d0
    d0.text = "That was strange. It barely even counted as an attack. What is going on?"
    d0.answers = {
		{ answer = "Scouts, maybe?", followUp = d1 },
        { answer = "It's probably nothing to worry about.", followUp = d2 }
    }
    --d1
    d1.text = "Maybe. I don't like this. We'll be jumping to the next sector in two minutes. Stay alert."
    d1.onEnd = "onPhase3DialogEnd"
    --d2
    d2.text = "... Maybe. I don't like this. It doesn't make any sense - they must be up to something. We'll be jumping to the next sector in two minutes. Keep your eyes open."
    d2.onEnd = "onPhase3DialogEnd"

	ESCCUtil.setTalkerTextColors({d0, d1, d2}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

    ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase4Dialog2(_ID)
	--After animosity is destroyed.
	local _MethodName = "On Phase 4 Dialog 2"
	mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

	local d0 = {}
	local d1 = {}
	local d2 = {}
	local d3 = {}
	local d4 = {}

	local _Player = Player()
	local _PlayerRank = _Player:getValue("_llte_cavaliers_rank")

    --d0
    d0.text = "That ship was incredibly powerful. I've never seen its like before."
	d0.followUp = d1
	
	d1.text = "It's a shame. Just think of what they could have done with it. Instead, they threw their lives away to try and kill us."
	d1.followUp = d2

	d2.text = "I keep thinking about what they said about the galactic order. As long as people feel like they've been abandoned, there will always be pirates, won't there?"
	d2.followUp = d3

	d3.text = "Perhaps... destroying pirates isn't the only way to keep the peace. Maybe there's more that we could do."
	d3.followUp = d4

	d4.text = "I'll have to think about it. Regardless, the Xsotan are still a threat. Let's keep moving, ${_PLAYERRANK}." % { _PLAYERRANK = _PlayerRank }
    d4.onEnd = "onPhase4Dialog2End"

	ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase5Dialog1(_ID)
	--immediatley after getting into the core.
	local _MethodName = "On Phase 5 Dialog 1"
	mission.Log(_MethodName, "Beginning...")

	local d0 = {}
	local d1 = {}
	local d2 = {}
	local d3 = {}

    --d0
    d0.text = "So, this is the galactic core..."
    d0.answers = {
		{ answer = "You sound disappointed.", followUp = d1 }
	}

	--d1
	d1.text = "Oh, I was just... expecting it to be different, somehow?"
	d1.answers = {
		{ answer = "You haven't been here for long. Give it some time.", followUp = d2 },
		{ answer = "There are a lot more Xsotan here, and they are aggressive.", followUp = d3 }
	}

	--d2
	d2.text = "You're right, of course. Is there anything that we should be on the lookout for?"
	d2.answers = {
		{ answer = "There are a lot more Xsotan here, and they are aggressive.", followUp = d3 }
	}

	--d3
	d3.text = "That would worry anyone else, but that's what we're here for! We'll destroy them just like the pirates."
	d3.onEnd = "onPhase5Dialog1End"

	ESCCUtil.setTalkerTextColors({d0, d1, d2, d3}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	local _Entities = {Sector():getEntitiesByScriptValue("_llte_empressblade")}

	ScriptUI(_Entities[1].id):interactShowDialog(d0, false)
end

function onPhase5Dialog2(_ID)
	--after big xsotan attack.
	local _MethodName = "On Phase 5 Dialog 2"
	mission.Log(_MethodName, "Beginning...")

	local d0 = {}
	local d1 = {}
	local d2 = {}

    --d0
    d0.text = "That was intense! Do the Xsotan always do this inside the barrier?"
	d0.answers = {
		{ answer = "Not always. This is unusual.", followUp = d1 }
	}

	d1.text = "Interesting... I wonder if..."
	d1.answers = {
		{ answer = "Wonder if what?", followUp = d2 }
	}

	d2.text = "We'll get to that shortly! I'd like to move on from here just in case the Xsotan decide to attack again."
	d2.onEnd = "onPhase5Dialog2End"

	ESCCUtil.setTalkerTextColors({d0, d1, d2}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase6Dialog(_ID, _X, _Y)
	--after jump after big xsotan attack - before being sent to get artifact.
	local _MethodName = "On Phase 6 Dialog"
	mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

	local d0 = {}
	local d1 = {}
	local d2 = {}
	local d3 = {}

    --d0
    d0.text = "Before we jumped away from the sector where the Xsotan attacked us, we picked up some strange signals in a nearby sector. I wonder if it had to do with why we were attacked?"
	d0.answers = {
		{ answer = "Possibly. What of it?", followUp = d1 }
	}
	
	d1.text = "Whatever is causing those signals... I'd like to investgate it! If we could recover what's causing them, we might be able to figure out how to use it against the Xsotan."
	d1.answers = { 
		{ answer = "And you want me to recover it, don't you?", followUp = d2 }
	}
	
	d2.text = "It would be easier that way. We need to repair, rearm, and consolidate our base of operations here. We would also be able to provide a point for you to retreat to if you ran into trouble."
	d2.answers = {
		{ answer = "That makes sense. Where am I heading?", followUp = d3 }
	}
	
	d3.text = "Whatever is causing the signals should be in (" .. _X .. ":" .. _Y .. ")! Head there and investigate it. Make sure to send us the telemetry."
	d3.onEnd = "onPhase6DialogEnd"

	ESCCUtil.setTalkerTextColors({d0, d1, d2, d3}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase8Dialog(_ID)
	--after artifact recovery.
	local _MethodName = "On Phase 8 Dialog"
	mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

	local d0 = {}
	local d1 = {}
	local d2 = {}

	local _Player = Player()
	local _PlayerRank = _Player:getValue("_llte_cavaliers_rank")

    --d0
    d0.text = "Hello ${_PLAYERRANK}! We've had some time to figure out what is going on with those signals. They were coming from a strange artifact that we found embedded in the ship." % { _PLAYERRANK = _PlayerRank }
	d0.followUp = d1

	d1.text = "I ordered a salvage team to cut the artifact out of the hull of the ship, and we've moved it aboard the Blade of the Empress. I'll have our research teams start looking at it immediately."
	d1.followUp = d2

	d2.text = "Once we figure out some more about the artifact, I'll contact you with the details. Until then, take care!"
	d2.onEnd = "onPhase8DialogEnd"

	ESCCUtil.setTalkerTextColors({d0, d1, d2}, "Adriana Stahl", MissionUT.getDialogTalkerColor1(), MissionUT.getDialogTextColor1())

	ScriptUI(_ID):interactShowDialog(d0, false)
end	

--endregion

--region #CLIENT / SERVER CALLS

function registerMarkArtifact()
    local _MethodName = "Register Mark Artifact"
    if onClient() then
        _MethodName = _MethodName .. " [CLIENT]"
        mission.Log(_MethodName, "Reigstering onPreRenderHud callback.")

        local _Player = Player()
        if _Player:registerCallback("onPreRenderHud", "onMarkArtifact") == 1 then
            mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
        end
    else
        _MethodName = _MethodName .. " [SERVER]"
        mission.Log(_MethodName, "Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkArtifact")
    end
end

function onPhase2DialogEnd()
	local _MethodName = "On Phase 2 Dialog End"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase2DialogEnd")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

		mission.data.description[3].fulfilled = true
		mission.data.description[4].visible = true
		mission.data.description[5].visible = true
		mission.data.location = mission.data.custom.sector2
		--Start transfer timer.
		runTransfer(mission.data.custom.sector1, mission.data.custom.sector2)
		mission.phases[2].timers[1] = { time = _TransferTimerTime, callback = function() nextPhase() end, repeating = false}
		mission.phases[2].timers[2] = { time = _TransferTimerHalfTime, callback = function() 
			local _MethodName = "Phase 2 Timer 2 Callback"
			mission.Log(_MethodName, "Beginning...")
			local _X, _Y = mission.data.custom.sector2.x, mission.data.custom.sector2.y
			broadcastEmpressBladeMsg("Attention all ships! We're jumping to \\s(%1%:%2%) in 60 seconds!", _X, _Y)
		end, repeating = false}

		sync()
	end
end
callable(nil, "onPhase2DialogEnd")

function onPhase3DialogEnd()
	local _MethodName = "On Phase 3 Dialog End"
	
	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase3DialogEnd")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

		mission.data.description[6].fulfilled = true
		mission.data.description[7].arguments = { _X = mission.data.custom.sector3.x, _Y = mission.data.custom.sector3.y }
		mission.data.description[7].visible = true
		mission.data.location = mission.data.custom.sector3
		--Start transfer timer
		runTransfer(mission.data.custom.sector2, mission.data.custom.sector3)
		mission.phases[3].timers[3] = { time = _TransferTimerTime, callback = function() nextPhase() end, repeating = false }
		mission.phases[3].timers[4] = { time = _TransferTimerHalfTime, callback = function()
			local _X, _Y = mission.data.custom.sector3.x, mission.data.custom.sector3.y
			broadcastEmpressBladeMsg("Attention all ships! We're jumping to \\s(%1%:%2%) in 60 seconds!", _X, _Y)
		end, repeating = false}

		showMissionUpdated(mission._Name)
		sync()
	end
end
callable(nil, "onPhase3DialogEnd")

function onPhase4Dialog1End()
	local _MethodName = "On Phase 4 Dialog End"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase4Dialog1End")
		return
	else
		--Add siege gun to Animosity.
		local _Sector = Sector()
		local _AnimosityTable = {_Sector:getEntitiesByScriptValue("is_animosity")}
		local _Animosity = _AnimosityTable[1]
		local _SGD = {}
		_SGD._CodesCracked = false
		_SGD._Velocity = 220
		_SGD._ShotCycle = 30
		_SGD._ShotCycleSupply = 0
		_SGD._ShotCycleTimer = 30
		_SGD._UseSupply = false
		_SGD._FragileShots = false
		_SGD._BaseDamagePerShot = 825000
		_SGD._TargetPriority = 6
		_SGD._TargetTag = "_llte_cav_supercap"
	
		_Animosity:addScript("entity/stationsiegegun.lua", _SGD)
		_Animosity:addScript("player/missions/empress/story/story4/lltestory4animositybehavior.lua")
		--Spawn a pirate wave immediately and add a pirate DCD to the sector.
		spawnPirateWave(2)

		local _DCD = {}
		_DCD._DefenseLeader = _Animosity.id
		_DCD._CanTransfer = false
		_DCD._CodesCracked = false
		_DCD._DefenderCycleTime = 65
		_DCD._DangerLevel = 10
		_DCD._MaxDefenders = 7
		_DCD._MaxDefendersSpawn = 5
		_DCD._DefenderHPThreshold = 0.25
		_DCD._DefenderOmicronThreshold = 0.25
		_DCD._ForceWaveAtThreshold = 0.7
		_DCD._ForcedDefenderDamageScale = 1.5
		_DCD._IsPirate = true
		_DCD._Factionid = _Animosity.factionIndex
		_DCD._PirateLevel = mission.data.custom.pirateLevel
		_DCD._UseLeaderSupply = false
		_DCD._LowTable = "High"
		
		_Sector:addScript("sector/background/defensecontroller.lua", _DCD)

		--Set all cavaliers ships to aggressive.
		local _CavShips = {_Sector:getEntitiesByScriptValue("is_cavaliers")}
		for _, _Cav in pairs(_CavShips) do
			ShipAI(_Cav.index):setAggressive()
		end
		local _PirateShips = {_Sector:getEntitiesByScriptValue("is_pirate")}
		for _, _Pirate in pairs(_PirateShips) do
			ShipAI(_Pirate.index):setAggressive()
			if _Pirate:getValue("is_animosity") then --drop immune shield.
				Shield(_Pirate.id).invincible = false
			end
		end
		--Register Animosity as a boss [taken care of on client].
	end
end
callable(nil, "onPhase4Dialog1End")

function onPhase4Dialog2End()
	local _MethodName = "On Phase 4 Dialog End"
	
	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase4Dialog2End")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

		mission.data.description[9].arguments = { _X = mission.data.custom.sector4.x, _Y = mission.data.custom.sector4.y }
		mission.data.description[9].visible = true
		mission.data.location = mission.data.custom.sector4
		--Start transfer timer
		runTransfer(mission.data.custom.sector3, mission.data.custom.sector4)
		mission.phases[4].timers[3] = { time = _TransferTimerTime, callback = function() nextPhase() end, repeating = false }
		mission.phases[4].timers[4] = { time = _TransferTimerHalfTime, callback = function()
			local _X, _Y = mission.data.custom.sector4.x, mission.data.custom.sector4.y
			broadcastEmpressBladeMsg("Attention all ships! We're jumping to \\s(%1%:%2%) in 60 seconds! This is going to take us past the barrier!", _X, _Y)
		end, repeating = false}

		showMissionUpdated(mission._Name)
		sync()
	end
end
callable(nil, "onPhase4Dialog2End")

function onPhase5Dialog1End()
	local _MethodName = "On Phase 5 Dialog 1 End"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase5Dialog1End")
		return
	else
		--Set the first timer
		mission.Log(_MethodName, "Setting warning timer.")
		mission.phases[5].timers[1] = { time = 11, callback = function() 
			broadcastEmpressBladeMsg("These subspace signals are too strong for our scanners! What is this!?")
		end, repeating = false}
		--Set the 2nd timer.
		mission.Log(_MethodName, "Setting swarm timer.")
		mission.phases[5].timers[2] = { time = 14, callback = function() 
			mission.data.custom.miniswarm = true
			mission.data.description[10].visible = true
			spawnXsotanWave(1)
			mission.phases[5].timers[3] = { time = 20, callback = function() 
				local _MethodName = "Phase 5 Timer 3"
				if mission.data.custom.miniswarm and atTargetLocation() then
					mission.Log(_MethodName, "Spawning next Xsotan wave.")
					local _WaveType = 1
					if mission.data.custom.xsotankilled >= 20 then
						_WaveType = 2
					end
					spawnXsotanWave(_WaveType) 
				end
			end, repeating = true }
			showMissionUpdated(mission._Name)
			sync()
		end, repeating = false}
		--Set the first trigger.
		mission.Log(_MethodName, "Setting swarm vanquish trigger.")
		mission.phases[5].triggers[2] = {
			condition = function()
				if onServer() then
					return ESCCUtil.countEntitiesByValue("is_xsotan") == 0 and not mission.data.custom.miniswarm and mission.data.custom.xsotankilled >= 40 and atTargetLocation()
				else
					--We don't do this on the client.
					return true
				end
			end,
			callback = function()
				if onServer() then
					local _MethodName = "Phase 5 Xsotan Vanquish Trigger Callback"
					mission.data.description[10].fulfilled = true
					sync()

					invokeClientFunction(Player(), "onPhase5Dialog2", mission.data.custom.empressBladeid)
				end
			end,
			repeating = false
		}
		--Set the 2nd trigger.
		mission.Log(_MethodName, "Setting swarm continuation trigger.")
		mission.phases[5].triggers[3] = {
			condition = function()
				if onServer() then
					return ESCCUtil.countEntitiesByValue("is_xsotan") <= 1 and mission.data.custom.miniswarm
				else
					--Server-only trigger.
					return true
				end
			end,
			callback = function()
				if onServer() and atTargetLocation() then
					spawnXsotanWave(3)
				end
			end,
			repeating = true					
		}
	end
end
callable(nil, "onPhase5Dialog1End")

function onPhase5Dialog2End()
	local _MethodName = "On Phase 5 Dialog 2 End"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase5Dialog2End")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

		mission.data.description[11].arguments = { _X = mission.data.custom.sector5.x, _Y = mission.data.custom.sector5.y }
		mission.data.description[11].visible = true
		mission.data.location = mission.data.custom.sector5
		--Start transfer timer
		runTransfer(mission.data.custom.sector4, mission.data.custom.sector5)
		mission.phases[5].timers[4] = { time = _TransferTimerTime, callback = function() nextPhase() end, repeating = false }
		mission.phases[5].timers[5] = { time = _TransferTimerHalfTime, callback = function()
			local _X, _Y = mission.data.custom.sector5.x, mission.data.custom.sector5.y
			broadcastEmpressBladeMsg("Attention all ships! We're jumping to \\s(%1%:%2%) in 60 seconds!", _X, _Y)
		end, repeating = false}

		showMissionUpdated(mission._Name)
		sync()
	end
end
callable(nil, "onPhase5Dialog2End")

function onPhase6DialogEnd()
	local _MethodName = "On Phase 6 Dialog End"

	--This one is blessedly simple.
	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase6DialogEnd")
		return
	else
		mission.Log(_MethodName, "Calling on Server")
		nextPhase()
	end
end
callable(nil, "onPhase6DialogEnd")

function onPhase8DialogEnd()
	local _MethodName = "On Phase 8 Dialog End"
	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase8DialogEnd")
		return
	else
		mission.Log(_MethodName, "Calling on Server")
		--We are finally, FINALLY done with this mission. Holy shit.
		runFullSectorCleanup_llte()
		llteStory4_finishAndReward()
	end
end
callable(nil, "onPhase8DialogEnd")

--endregion