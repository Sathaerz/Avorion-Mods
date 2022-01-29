--[[
    Story Mission 2.
    The Unforgiving Blade
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Story Mission 1 Done
    ROUGH OUTLINE
        - Player reads mail from Adriana.
        - Player goes to Cavaliers sector. Brief dialog, and then all of the cav ships warp out.
        - Player goes to the pirate sector.
        - Pirate Sector has a Military Outpost, Shipyard, Repair Dock and Research Station.
            - Remove the cargo from all of the stations.
        - Player destroys all of the stations. The Blade of the Empress is there to help them out along with constantly respawning waves of Cavalier ships.
        - Keep Cavaliers ships from getting destroyed. If 10 Cav ships are destroyed, fail the mission.
            - This isn't as hard as it seems - the Cav ships will withdraw 4-8 seconds after hitting 15% health. 
            - You just need to keep them from getting into a slugging match with a devastator, scorcher, or executioner.
            - The Cavaliers ships shouldn't be a liability - they should be a necessary form of support that you have to occasionally watch out for.
            - Mark the ones that hit 50% HP.
        - The player's role is mostly to clean up ships and support the cavaliers while they wipe out the stations.
    DANGER LEVEL
        5+ - The mission starts at Danger Level 5. It is a fixed value since this is a non-repeatable* story mission.
            - Start with 6 standard-threat and 4 high-threat defenders in the sector.
            - 3 defenders and 2 heavy defenders spawn in to start.
            - Pirates spawn in groups of 4 every 80 seconds.
            - Cavaliers spawn in groups of 6 every 2:30.
            - Danger level increases once per 3:30, to a maximum of 10.
            - If the blade of the empress withdraws, it will respawn in 2 minutes.

        * - Technically. The player can always abandon and restart.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes.
include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local SectorGenerator = include ("sectorgenerator")
local PirateGenerator = include("pirategenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "The Unforgiving Blade"

--region #INIT

local llte_storymission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "The Unforgiving Blade Begin...")

    if onServer()then
        if not _restoring then
            --Standard mission data.
            mission.data.brief = "The Unforgiving Blade"
            mission.data.title = "The Unforgiving Blade"
			mission.data.icon = "data/textures/icons/cavaliers.png"
			mission.data.priority = 9
            mission.data.description = { 
                "The planned attack on the pirate stronghold is at hand. The Cavaliers have contacted you and asked you to participate in the assault.",
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false },
                --If any of these have an X / Y coordinate, they will be updated with the correct location when starting the appropriate phase.
				{ text = "Meet The Cavaliers scouts in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Destroy the pirate base in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false }, 
                { text = "Prevent Cavalier Ships from being destroyed - ${_LOST}/${_MAXLOST} Lost", bulletPoint = true, fulfilled = false, visible = false }
            }

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .destroyedCavaliers
                .maxDestroyedCavaliers
                .sendExtraCavaliers
                .pirateLevel
                .scoutSector
                .pirateSector
                .militaryStationid
                .builtMainSector
                .militaryStationid
                .firstStationDestroyed
                .empressBladeRespawning
                .missionStarted
                .firstEmpressSpawnDone
                ._HETActive
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
            mission.data.custom.destroyedCavaliers = 0
            mission.data.custom.maxDestroyedCavaliers = 8
            mission.data.custom.sendExtraCavaliers = false
            mission.data.custom._HETActive = false

            local _ActiveMods = Mods()
            for _, _Xmod in pairs(_ActiveMods) do
                if _Xmod.id == "1821043731" then --HET
                    mission.data.custom._HETActive = true
                    mission.data.custom.maxDestroyedCavaliers = mission.data.custom.maxDestroyedCavaliers + 6
                    break
                end
            end

            mission.Log(_MethodName, "Max destroyed cavaliers is " .. tostring(mission.data.custom.maxDestroyedCavaliers))

            local missionReward = 600000

            missionData_in = {location = nil, reward = {credits = missionReward}}
    
            llte_storymission_init(missionData_in)
        else
            --Restoring
            llte_storymission_init()
            if mission.currentPhase == mission.phases[3] then
                registermarkShips() --Reregister client callback.
            end
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
    Player():unregisterCallback("onPreRenderHud", "onMarkShips")
    if mission.data.location then
        runFullSectorCleanup()
    end
end

mission.globalPhase.updateServer = function(_TimeStep)
    if mission.data.custom.destroyedCavaliers >= mission.data.custom.maxDestroyedCavaliers then
        Player():setValue("_llte_failedstory2", true)
        fail()
    end
end

mission.globalPhase.onFail = function()
    --If there are any Cavaliers ships, they warp out.
    local _MethodName = "On Fail"
    mission.Log(_MethodName, "Beginning...")
    
    local _Rgen = ESCCUtil.getRand()
    LLTEUtil.allCavaliersDepart()
    --Add a script to the mission location to nuke it if we are there, nuke it remotely otherwise.
    runFullSectorCleanup()
    --Send fail mail.
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    _Player:unregisterCallback("onPreRenderHud", "onMarkShips")
    local _Mail = Mail()
    local _PirateFaction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)
	_Mail.text = Format("%1% %2%,\n\n%3% were too strong, and we need to break off our attack due to the amount of losses we suffered. Get yourself some stronger weapons and shields, and I'll get to work on reorganizing the fleet for another assault.\nWe will show the factions that it is possible to bring peace to the galaxy without throwing away thousands of lives to do it!\n\nEmpress Adriana Stahl", _Rank, _Player.name, _PirateFaction.name)
	_Mail.header = "Forced to Withdraw"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story2_mailfail"
	_Player:addMail(_Mail)
end

mission.globalPhase.onAccomplish = function()
    --Send success mail telling the player to watch out for the scouts and future opportunities to help.
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    _Player:setValue("_llte_pirate_faction_vengeance", mission.data.custom.pirateLevel)
    _Player:unregisterCallback("onPreRenderHud", "onMarkShips")
    local _Mail = Mail()
    local _PirateFaction = Galaxy():getPirateFaction(mission.data.custom.pirateLevel)
	_Mail.text = Format("%1% %2%,\n\nWe have accomplished something great today. %3% - an incredibly powerful group - have been broken before our might. With this, we've managed to send a message to the other pirates out there: it doesn't matter how powerful you are, we WILL destroy you to bring peace to the galaxy.\nThank you! This wouldn't have been possible without your help. We are, once again, in your debt.\n\nIn the coming days, we'll be working to consolidate our base of operations and destroy other pirate and xsotan infestations. Look for our scouts - they will occasionally approach you and offer jobs.\nThere will, of course, be something in it for you. We look forward to fighting alongside you again, %1%!\n\nEmpress Adriana Stahl", _Rank, _Player.name, _PirateFaction.name)
	_Mail.header = "Pirates Destroyed!"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story2_mailwin"
    _Player:addMail(_Mail)
    
    local _Mail2 = Mail()
    _Mail2.text = "We will remember this."
    _Mail2.header = "Notice"
    _Mail2.sender = _PirateFaction.name
    _Mail2.id = "_llte_story2_threat"
    _Player:addMail(_Mail2)
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.scoutSector =  getNextLocation(true)
    local _X, _Y = mission.data.custom.scoutSector.x, mission.data.custom.scoutSector.y
    mission.data.custom.pirateLevel = Balancing_GetPirateLevel(_X, _Y)
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nI told you that I'd contact you when we were ready to launch the attack on the pirates. This is it. It's time.\nOur scouts are waiting in (%3%:%4%) - we'll meet you there and brief you on our plan of attack.\n\nEmpress Adriana Stahl", _Rank, _Player.name, _X, _Y)
	_Mail.header = "Plan of Attack"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story2_mail1"
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
				if _Mail.id == "_llte_story2_mail1" then
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.data.location = mission.data.custom.scoutSector
    mission.data.description[2].fulfilled = true
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[3].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Entered"
    --get the next location
    mission.data.custom.pirateSector = getNextLocation(false)
    --spawn 3 scouts
    spawnCavalierScouts(3)
end

mission.phases[2].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 2 on Target Location Arrival Confirmed"
    --Start a 5 second timer to jump in The Cavaliers Fleet.
    mission.Log(_MethodName, "Beginning...")
    mission.phases[2].timers[1] = { time = 5, callback = function()
        spawnEmpressBlade(true)
        spawnCavalierShips(2, 2, false)
    end, repeating = false}
    mission.phases[2].timers[2] = { time = 7, callback = function()
        spawnCavalierShips(2, 1, false)
    end, repeating = false}
    mission.phases[2].timers[3] = { time = 9, callback = function()
        spawnCavalierShips(2, 1, false)
    end, repeating = false}
    mission.phases[2].timers[4] = { time = 11, callback = function()
        spawnCavalierShips(2, 0, false)
    end, repeating = false}
    mission.phases[2].timers[5] = { time = 13, callback = function()
        spawnCavalierShips(1, 1, false)
    end, repeating = false}
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.data.location = mission.data.custom.pirateSector
    mission.data.description[3].fulfilled = true
    mission.data.description[4].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[4].visible = true
    mission.data.description[5].arguments = { _LOST = 0, _MAXLOST = mission.data.custom.maxDestroyedCavaliers }
    mission.data.description[5].visible = true
end

mission.phases[3].onTargetLocationEntered = function(_X, _Y)
    local _MethodName = "Phase 3 on Enter Target Location"
    --Build main sector
    buildPirateSector(_X, _Y)
    registerMarkShips()
    mission.phases[3].timers[5] = nil
end

mission.phases[3].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 3 on Target Location Arrival Confirmed"
    --Spawn Cavaliers - they will always despawn on exit so we need to respawn them each time.
    --Add DCD for Cavaliers.
    mission.Log(_MethodName, "Beginning...")
    if not mission.data.custom.missionStarted then
        mission.phases[3].timers[1] = { time = 2, callback = function()
            local _MethodName = "Phase 3 Timer 1 Callback"
            mission.Log(_MethodName, "Beginning...")
            spawnEmpressBlade(false)
            spawnCavalierShips(3, 1, true)
            Entity(mission.data.custom.militaryStationid):addScript("player/missions/empress/story/story2/lltestory2piratesector.lua")

            local _Faction = Galaxy():findFaction("The Cavaliers")
            local _EmpressBlade = {Sector():getEntitiesByScriptValue("_llte_empressblade")}

            addCavaliersDefenseController(_Faction, _EmpressBlade[1])
            mission.data.custom.firstEmpressSpawnDone = true
        end, repeating = false}
        mission.data.custom.missionStarted = true
    end
end

mission.phases[3].updateTargetLocationServer = function(_TimeStep)
    local _MethodName = "Phase 3 Update Server"
    --Need this to check if all 4 stations are dead.
    if mission.data.custom.builtMainSector then
        local _EmpressBladeCt = ESCCUtil.countEntitiesByValue("_llte_empressblade")
        --If The Blade of The Empress was forced to withdraw due to low health (it is VERY unlikely that it was destroyed)
        --It comes back within 2 minutes.
        if _EmpressBladeCt == 0 and mission.data.custom.firstEmpressSpawnDone and not mission.data.custom.empressBladeRespawning then
            mission.Log("Empress blade count : " .. tostring(_EmpressBladeCt) .. " - Empress blade respawn value : " .. tostring(mission.data.custom.empressBladeRespawning))
            mission.phases[3].timers[2] = {
                time = 120, 
                callback = function()
                    local _MethodName = "Phase 3 Timer 2 Callback"
                    mission.Log(_MethodName, "Beginning...")
                    --It comes back in 2 minutes.
                    spawnEmpressBlade(false)
                    local _Faction = Galaxy():findFaction("The Cavaliers")
                    local _EmpressBlade = {Sector():getEntitiesByScriptValue("_llte_empressblade")}

                    addCavaliersDefenseController(_Faction, _EmpressBlade[1])
                    mission.data.custom.empressBladeRespawning = false
                end, 
                repeating = false}
            mission.data.custom.empressBladeRespawning = true
        end

        local _Stations = ESCCUtil.countEntitiesByValue("_llte_story2_mainobjective")
        if _Stations == 0 then
            ESCCUtil.allPiratesDepart()
            LLTEUtil.allCavaliersDepart()
            finishAndReward()
        end
    end
end

mission.phases[3].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 3 On Entity Destroyed"
    if Entity(_ID):getValue("is_cavaliers") then
        mission.data.custom.destroyedCavaliers = mission.data.custom.destroyedCavaliers + 1
        mission.data.description[5].arguments = { _LOST = mission.data.custom.destroyedCavaliers, _MAXLOST = mission.data.custom.maxDestroyedCavaliers }
        sync()
    end
    if Entity(_ID):getValue("_llte_story2_mainobjective") then
        local _ExtraReinforcements = 1
        mission.Log(_MethodName, "Adding extra casualty allowance.")

        if mission.data.custom.sendExtraCavaliers then
            local _ExtraReinforcements = 3
            if mission.data.custom._HETActive then
                local _ExtraReinforcements = 4
            end
        end

        mission.data.custom.maxDestroyedCavaliers = mission.data.custom.maxDestroyedCavaliers + _ExtraReinforcements
        mission.data.description[5].arguments = { _LOST = mission.data.custom.destroyedCavaliers, _MAXLOST = mission.data.custom.maxDestroyedCavaliers }
        sync()

        --Spawn a group of ships - no need to buff these guys.
        local _MiniWaveGenerator = AsyncPirateGenerator(nil, nil)
        _MiniWaveGenerator.pirateLevel = mission.data.custom.pirateLevel

        _MiniWaveGenerator:startBatch()

        local _MiniWaveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 3, "Standard")
        local _MiniWavePositions = _MiniWaveGenerator:getStandardPositions(#_MiniWaveTable, 200)

        local _PosCounter = 1
        for _, _P in pairs(_MiniWaveTable) do
            _MiniWaveGenerator:createScaledPirateByName(_P, _MiniWavePositions[_PosCounter])            
            _PosCounter = _PosCounter + 1
        end

        _MiniWaveGenerator:endBatch()

        if not mission.data.custom.firstStationDestroyed then
            --broadcast, then set timer, then set "firstStationDestroyed = true"
            local _Stations = {Sector():getEntitiesByType(EntityType.Station)}
            local _Rgen = ESCCUtil.getRand()
            local _BroadcastStation = _Stations[_Rgen:getInt(1, #_Stations)]
            Sector():broadcastChatMessage(_BroadcastStation, ChatMessageType.Chatter, "Did you think we would just lay down and die for you? This place will be your grave!")
            
            mission.phases[3].timers[2] = {time = 10, callback = function()
                local _Generator = AsyncPirateGenerator(nil, onExecutionersFinished)
                _Generator.pirateLevel = mission.data.custom.pirateLevel

                _Generator:startBatch()

                --Yeah, if you thought I was just using these guys for decaps, you were wrong.
                _Generator:createScaledExecutioner(_Generator:getGenericPosition(), 1000)

                _Generator:createScaledExecutioner(_Generator:getGenericPosition(), 1000)

                _Generator:endBatch()

            end, repeating = false}
            
            mission.data.custom.firstStationDestroyed = true
        end
    end
end

mission.phases[3].onTargetLocationLeft = function(_X, _Y)
    local _MethodName = "Phase 3 on Leave Target Location"
    --Start a soft failure timer.
    --Timer 1 is for when the Cavaliers first jump in.
    --Timer 2 happens after the 1st station gets destroyed.
    --Timer 3 is the Empress Blade respawn timer
    --Timer 4 is an increase in danger level every 3 minutes.
    --Timer 5 is the soft fail timer.
    mission.phases[3].timers[5] = {time = 60, callback = function() 
        mission.data.custom.destroyedCavaliers = mission.data.custom.destroyedCavaliers + 1
        mission.data.description[5].arguments = { _LOST = mission.data.custom.destroyedCavaliers, _MAXLOST = mission.data.custom.maxDestroyedCavaliers }
        sync()
    end, repeating = true}
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
        mission.Log(_MethodName, "Building sector for pirate level faction: " .. tostring(_Faction.name) .. " level " .. tostring(mission.data.custom.pirateLevel) .. " pirates")
        local _MilitaryOutpost = _Generator:createMilitaryBase(_Faction)
        mission.data.custom.militaryStationid = _MilitaryOutpost.index
        local _Shipyard = _Generator:createShipyard(_Faction)
        local _RepairDock = _Generator:createRepairDock(_Faction)
        local _ResearchOutpost = _Generator:createResearchStation(_Faction)
        local _Stations = { _MilitaryOutpost, _Shipyard, _RepairDock, _ResearchOutpost }
        for _, _Station in pairs(_Stations) do
            _Station:removeScript("consumer.lua")
            _Station:removeScript("backup.lua") --The delayed callback on this is dumb. I do like the idea of ships responding when an object is destroyed though.
            _Station:setValue("is_pirate", true)
            _Station:setValue("_llte_story2_mainobjective", true)
            local _StationBay = CargoBay(_Station)
            _StationBay:clear()
            Boarding(_Station).boardable = false
        end
        Sector():removeScript("traders.lua")
        --Add: 1 large asteroid and 3 small asteroid fields.
        for _ = 1, 3 do
            _Generator:createSmallAsteroidField()
        end
        _Generator:createAsteroidField()
        --Add: 6 medium-threat and 4 high-threat pirate defenders
        local _LowPirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, "Standard")
        local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 4, "High")
        local _CreatedPirateTable = {}

        PirateGenerator.pirateLevel = mission.data.custom.pirateLevel
        for _, _Pirate in pairs(_LowPirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end
        for _, _Pirate in pairs(_PirateTable) do
            table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
        end
        --Set aggressive after dialog between Adriana and the Military Outpost.
        for _, _Pirate in pairs(_CreatedPirateTable) do
            ShipAI(_Pirate.index):setPassive()
        end

        SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
        --Add: Defense Controller Script.
        local _DCD = {}
        _DCD._DefenseLeader = mission.data.custom.militaryStationid
        _DCD._DefenderCycleTime = 80
        _DCD._DangerLevel = mission.data.custom.dangerLevel
        _DCD._MaxDefenders = 8
        _DCD._MaxDefendersSpawn = 4
        _DCD._DefenderDistance = 5000 --Scatter these guys a bit more than usual.
        _DCD._DefenderHPThreshold = 0.5
        _DCD._DefenderOmicronThreshold = 0.5
        _DCD._ForceWaveAtThreshold = 0.8
        _DCD._ForcedDefenderDamageScale = 5
        _DCD._IsPirate = true
        _DCD._Factionid = _MilitaryOutpost.factionIndex
        _DCD._PirateLevel = mission.data.custom.pirateLevel
        _DCD._UseLeaderSupply = false
        _DCD._LowTable = "High"
        _DCD._ForceDebug = false

        Sector():addScript("sector/background/defensecontroller.lua", _DCD)

        mission.data.custom.builtMainSector = true
    end
end

function spawnEmpressBlade(_AddScript)
    local _MethodName = "Spawn Blade of the Empress"
    mission.Log(_MethodName, "Beginning...")
    local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress()

    if _AddScript then
        invokeClientFunction(Player(), "onPhase2SectorEnteredDialog", _EmpressBlade.id, mission.data.custom.pirateSector.x, mission.data.custom.pirateSector.y)
    end
end

function spawnCavalierScouts(_Scouts)
    local _Faction =  Galaxy():findFaction("The Cavaliers")
    local _Generator = AsyncShipGenerator(nil, onCavalierScoutsFinished)
    _Generator:startBatch()

    for _ = 1, _Scouts do
        _Generator:createScout(_Faction, PirateGenerator.getGenericPosition())
    end

    _Generator:endBatch()
end

function spawnCavalierShips(_Defenders, _HeavyDefenders, _StartPassive)
    _StartPassive = _StartPassive or false
    local _Faction =  Galaxy():findFaction("The Cavaliers")
    local _Generator = AsyncShipGenerator(nil, onCavaliersFinished, _StartPassive)
    _Generator:startBatch()

    for _ = 1, _Defenders do
        _Generator:createDefender(_Faction, PirateGenerator.getGenericPosition())
    end
    for _ = 1, _HeavyDefenders do
        _Generator:createHeavyDefender(_Faction, PirateGenerator.getGenericPosition())
    end

    _Generator:endBatch()
end

--endregion

--region #DESPAWN OBJECTS

function runFullSectorCleanup()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        local _EntityTypes = { EntityType.Ship, EntityType.Station, EntityType.Torpedo, EntityType.Fighter, EntityType.Asteroid, EntityType.Wreckage, EntityType.Unknown, EntityType.Other, EntityType.Loot }
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
    end
end

--endregion

function addCavaliersDefenseController(_CavFaction, _EmpressBlade)
    local _MethodName = "Add Cavaliers Defense Controller"
    local _CavFactor = 0
    local _CavTimeFactor = 0
    local _CavEvacFactor = 0
    local _CavExtraWaveShips = 0

    if mission.data.custom._HETActive then
        _CavFactor = _CavFactor + 3
        _CavExtraWaveShips = _CavExtraWaveShips + 1
        _CavEvacFactor = _CavEvacFactor + 0.1
        _CavTimeFactor = _CavTimeFactor + 20
    end
    
    mission.Log(_MethodName, "Send extra cavaliers value is " .. tostring(mission.data.custom.sendExtraCavaliers))
    if mission.data.custom.sendExtraCavaliers then
        _CavFactor = _CavFactor + 3
        _CavTimeFactor = _CavTimeFactor + 20
        _CavEvacFactor = _CavEvacFactor + 0.15
        _CavExtraWaveShips = _CavExtraWaveShips + 2
        if mission.data.custom._HETActive then
            _CavEvacFactor = _CavEvacFactor + 0.1
            _CavTimeFactor = _CavTimeFactor + 20
            _CavExtraWaveShips = _CavExtraWaveShips + 2
        end
    end

    local _CavDangerLevel = math.min(10, mission.data.custom.dangerLevel + _CavFactor) --Caps at 10
    local _CavCycleTime = 120 - _CavTimeFactor
    local _CavWithdrawHealth = 0.30 + _CavEvacFactor
    local _CavMaxDefenders = 6 + _CavExtraWaveShips
    local _CavMaxSpawn = 5 + _CavExtraWaveShips

    mission.Log(_MethodName, "Cavalier DCD sending " .. tostring(_CavMaxSpawn) .. " defenders at " .. tostring(_CavDangerLevel) .. " danger level every " .. tostring(_CavCycleTime) .. " seconds to a maximum of " .. tostring(_CavMaxDefenders) .. " - withdrawing at " .. tostring(_CavWithdrawHealth))

    local _CavDCD = {}
    _CavDCD._DefenseLeader = _EmpressBlade.index
    _CavDCD._CanTransfer = false
    _CavDCD._DefenderCycleTime = _CavCycleTime
    _CavDCD._DangerLevel = _CavDangerLevel
    _CavDCD._UseFixedDanger = true
    _CavDCD._MaxDefenders = _CavMaxDefenders
    _CavDCD._MaxDefendersSpawn = _CavMaxSpawn
    _CavDCD._AutoWithdrawDefenders = true
    _CavDCD._DefenderHPThreshold = _CavWithdrawHealth
    _CavDCD._DefenderOmicronThreshold = 0.5
    _CavDCD._PrependToDefenderTitle = "Cavaliers"
    _CavDCD._ForceWaveAtThreshold = -1
    _CavDCD._IsPirate = false
    _CavDCD._Factionid = _CavFaction.index
    _CavDCD._PirateLevel = -1
    _CavDCD._SupplyFactor = 0
    _CavDCD._UseLeaderSupply = false
    _CavDCD._ForceDebug = false

    _CavDCD._LowTable = "High"
    _CavDCD._KillWhenNoPlayers = true

    Sector():addScript("sector/background/defensecontroller.lua", _CavDCD)
end

function onCavalierScoutsFinished(_Generated)
    local _MethodName = "On Cavaliers Scouts Finished"
    for _, _S in pairs(_Generated) do
        _S.title = "Cavaliers " .. _S.title
        _S:setValue("is_cavaliers", true)
        _S:addScript("ai/patrolpeacefully.lua")
        MissionUT.deleteOnPlayersLeft(_S)
    end
end

function onCavaliersFinished(_Generated, _StartPassive)
    local _MethodName = "On Cavaliers Finished"
    for _, _S in pairs(_Generated) do
        _S.title = "Cavaliers " .. _S.title
        _S:setValue("npc_chatter", nil)
        _S:setValue("is_cavaliers", true)
        _S:addScript("ai/withdrawatlowhealth.lua", 0.30)
        _S:removeScript("antismuggle.lua")
        LLTEUtil.rebuildShipWeapons(_S, Player():getValue("_llte_cavaliers_strength"))
        --Sometimes you get a bad seed and get really frail cavaliers. This should help counteract that.
        local _HPFactor = 2.5
        local _DamageFactor = 2
        if mission.data.custom.sendExtraCavaliers then
            _HPFactor = 4
            _DamageFactor = 4
        end
        local _Dura = Durability(_S)
        if _Dura then
            _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 1) * _HPFactor
        end
        _S.damageMultiplier = (_S.damageMultiplier or 1) * _DamageFactor
        
        MissionUT.deleteOnPlayersLeft(_S)
        if _StartPassive then
            _S:removeScript("patrol.lua")
            local _AI = ShipAI(_S.index)
            _AI:stop()
            _AI:setIdle()
        end
    end
end

function onExecutionersFinished(_Generated)
    for _, _S in pairs(_Generated) do
        _S:removeScript("blocker.lua")
        _S:removeScript("megablocker.lua")
    end

    local _Rgen = ESCCUtil.getRand()

    --A little variety in case of abandon / recomplete.
    local _ExecutionerLines = {
        "Targets verified. Commencing hostilities.",
        "Cavaliers sighted. Excising.",
        "This is the end of the road for you.",
        "Time to cut the head from the beast."
    }

    Sector():broadcastChatMessage(_Generated[_Rgen:getInt(1, #_Generated)], ChatMessageType.Chatter, randomEntry(_ExecutionerLines))
end

function getNextLocation(_FirstLocation)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    if _FirstLocation then
        --Get a sector that's very close to the outer edge of the barrier.
        local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, Balancing.BlockRingMax + 2)
        target.x, target.y = MissionUT.getSector(math.floor(_Nx), math.floor(_Ny), 3, 6, false, false, false, false, false)
    else
        target.x, target.y = MissionUT.getSector(x, y, 5, 10, false, false, false, false, false)
    end

    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()
    _Player:setValue("_llte_story_2_accomplished", true)

    local _WinMsgTable = {
        "Great job, " .. _Rank .. "!"
    }

    --Increase reputation by 3
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + 3)
    _Player:sendChatMessage("Adriana Stahl", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " Here is your reward, as promised.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onMarkShips()
    local _MethodName = "On Mark Ships"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local renderer = UIRenderer()

    local _Ships = {Sector():getEntitiesByScriptValue("is_cavaliers")}
    for _, _S in pairs(_Ships) do
        local _HPRatio = _S.durability / _S.maxDurability
        --Yellow marks at 80%
        local _MarkColor = ESCCUtil.getSaneColor(255, 255, 0)

        if _HPRatio <= 0.8 then
            if _HPRatio <= 0.6 then
                --Orange at 60%
                _MarkColor = ESCCUtil.getSaneColor(255, 127, 0)
            end
            if _HPRatio <= 0.4 then
                --Red at 40%
                _MarkColor = ESCCUtil.getSaneColor(255, 0, 0)
            end
            renderer:renderEntityTargeter(_S, _MarkColor, 1.0)
            renderer:renderEntityArrow(_S, 30, 10, 100, _MarkColor)
            renderer:renderEntityArrow(_S, 30, 10, 100, _MarkColor, 0.13)
            renderer:renderEntityArrow(_S, 30, 30, 100, _MarkColor, 0.13)
        end
    end

    renderer:display()
end

function onPhase2SectorEnteredDialog(_ID, _X, _Y)
    --Can't do this with Boxel's Single NPC interaction script because that script doesn't sync values correctly, so we just do it here.
    local _MethodName = "On Phase 2 Sector Entered Dialog"
    mission.Log(_MethodName, "Beginning...")

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}

    local _Player = Player()
    local _PlayerRank = _Player:getValue("_llte_cavaliers_rank")
    local _PlayerName = _Player.name
    local _PlayerFailedStory2 = _Player:getValue("_llte_failedstory2")
    mission.Log(_MethodName, "Player failed story 2 value is " .. tostring(_PlayerFailedStory2))

    local _Talker = "Adriana Stahl"
    local _TalkerColor = MissionUT.getDialogTalkerColor1()
    local _TextColor = MissionUT.getDialogTextColor1()

    --d0
    d0.text = "Hello " .. _PlayerRank .. "! I'm so glad you decided to join us."
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor
    d0.followUp = d4
    --d4
    d4.text = "Our plan is very straightforward. We'll wait for you to jump into the sector and then we will follow you in to join the attack. I've ordered our captains to try and withdraw if their ships are damaged."
    d4.talker = _Talker
    d4.textColor = _TextColor
    d4.talkerColor = _TalkerColor
    d4.followUp = d5
    --d5
    d5.text = "We'll continue to cycle in waves of attackers until the pirates are scrap! I want everyone to come home from this alive."
    d5.talker = _Talker
    d5.textColor = _TextColor
    d5.talkerColor = _TalkerColor
    d5.followUp = d1
    --d1
    d1.text = "We can move out at moment's notice. Are you ready?"
    d1.talker = _Talker
    d1.textColor = _TextColor
    d1.talkerColor = _TalkerColor
    d1.answers = {}
    table.insert(d1.answers, { answer = "I'm ready.", followUp = d2 })
    if _PlayerFailedStory2 then
        mission.Log(_MethodName, "Adding extra dialog option.")
        table.insert(d1.answers, { answer = "I'm ready... but can you send additional reinforcements this time?", followUp = d6 })
    end
    table.insert(d1.answers, { answer = "I need more time.", followUp = d3 })
    --d2
    d2.text = string.format("Excellent! We'll meet in (%s:%s). It's time to put an end to this.", _X, _Y)
    d2.talker = _Talker
    d2.textColor = _TextColor
    d2.talkerColor = _TalkerColor
    d2.onEnd = "saidReady"
    --d3
    d3.text = "No problem - go make sure you're prepared. We don't know what they've got in store for us."
    d3.talker = _Talker
    d3.textColor = _TextColor
    d3.talkerColor = _TalkerColor
    d3.onEnd = "saidNotReady"
    --d6
    d6.text = string.format("I'm sure that I can arrange something! We'll meet in (%s:%s). It's time to put an end to this.", _X, _Y)
    d6.talker = _Talker
    d6.textColor = _TextColor
    d6.talkerColor = _TalkerColor
    d6.onEnd = "saidReadyHelp"
    
    ScriptUI(_ID):interactShowDialog(d0, false)
end

--endregion

--region #CLIENT / SERVER CALLS

function registerMarkShips()
    local _MethodName = "Register Mark Ships"
    if onClient() then
        _MethodName = _MethodName .. " [CLIENT]"
        mission.Log(_MethodName, "Reigstering onPreRenderHud callback.")

        local _Player = Player()
        if _Player:registerCallback("onPreRenderHud", "onMarkShips") == 1 then
            mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
        end
    else
        _MethodName = _MethodName .. " [SERVER]"
        mission.Log(_MethodName, "Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkShips")
    end
end

function saidReady()
    local _MethodName = "Said Ready"
    
    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("saidReady")
    else
        mission.Log(_MethodName, "Calling on Server")

        LLTEUtil.allCavaliersDepart()

        nextPhase()
    end
end
callable(nil, "saidReady")

function saidReadyHelp()
    local _MethodName = "Said Ready (Help)"
    
    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("saidReadyHelp")
    else
        mission.Log(_MethodName, "Calling on Server")

        LLTEUtil.allCavaliersDepart()
        mission.data.custom.sendExtraCavaliers = true

        nextPhase()
    end
end
callable(nil, "saidReadyHelp")

function saidNotReady()
    local _MethodName = "Said Not Ready"

    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("saidNotReady")
    else
        mission.Log(_MethodName, "Calling on Server")

        local _Blade = {Sector():getEntitiesByScriptValue("_llte_empressblade")}
        _Blade[1]:addScript("player/missions/empress/story/story2/lltestory2dialogue1.lua", mission.data.custom.pirateSector.x, mission.data.custom.pirateSector.y)
    end
end
callable(nil, "saidNotReady")

function startTheBattle()
    local _MethodName = "Start The Battle"

    if onClient() then
        mission.Log(_MethodName, "Calling on Client")
        mission.Log(_MethodName, "Invoking on server.")

        invokeServerFunction("startTheBattle")
    else
        mission.Log(_MethodName, "Calling on Server")

        local _Cavaliers = {Sector():getEntitiesByScriptValue("is_cavaliers")}
        for _, _Cav in pairs(_Cavaliers) do
            ShipAI(_Cav.index):setAggressive()
        end
    
        local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
        for _, _Pirate in pairs(_Pirates) do
            ShipAI(_Pirate.index):setAggressive()
        end

        --Timer to increase danger level over time. +1 every 3.5 minutes.
        mission.phases[3].timers[4] = {time = 210, callback = function() 
            if mission.data.custom.dangerLevel < 10 then
                local _MethodName = "Phase 3 Timer 4 Tick"
                mission.Log(_MethodName, "3 minutes have passed. Increasing the danger level.")
                mission.data.custom.dangerLevel = mission.data.custom.dangerLevel + 1
                Sector():invokeFunction("sector/background/defensecontroller.lua", "setDangerLevel", mission.data.custom.dangerLevel)
            end
        end, repeating = true}
    end
end
callable(nil, "startTheBattle")

--endregion