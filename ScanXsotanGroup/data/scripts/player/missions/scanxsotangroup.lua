package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Xsotan = include("story/xsotan")
local SpawnUtility = include ("spawnutility")
local SectorGenerator = include ("SectorGenerator")
local Balancing = include ("galaxy")

mission._Debug = 0
mission._Name = "Scan Xsotan Group"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." },
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Scan the Xsotan - ${_SCANNED}/${_SCANNEDMAX} Scanned", bulletPoint = true, fulfilled = false, visible = false }
}

mission.data.accomplishMessage = "We've gotten some good data off of your scans! Thank you for helping us with our research!"
mission.data.failMessage = "You won't be able to get all of the scans now. We could have used that data..."

local ScanXsotanGroup_init = initialize
function initialize(_Data_in, bulletin)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel) .. " threattype: " .. tostring(_Data_in.threatType))

        local _X, _Y = _Data_in.location.x, _Data_in.location.y

        local _Sector = Sector()
        local _Giver = Entity(_Data_in.giver)
        
        --[[=====================================================
            CUSTOM MISSION DATA SETUP:
        =========================================================]]
        mission.data.custom.dangerLevel = _Data_in.dangerLevel
        mission.data.custom.inBarrier = _Data_in.inBarrier
        mission.data.custom.spawnXsotanQty = 5
        local _random = random()
        for _ = 1, mission.data.custom.dangerLevel do
            if _random:test(0.5) then
                mission.data.custom.spawnXsotanQty = mission.data.custom.spawnXsotanQty + 1
            end
        end
        mission.data.custom.scannedXsotan = 0
        local scanPct = 0.5 + (mission.data.custom.dangerLevel * 0.05)
        mission.data.custom.scannedXsotanTgt = math.max(4, math.ceil(mission.data.custom.spawnXsotanQty * scanPct))
        mission.data.custom.scannableXsotanShips = {}

        if mission.data.custom.inBarrier then
            local _KilledGuardian = Player():getValue("wormhole_guardian_destroyed")
            if _KilledGuardian then
                mission.Log(_MethodName, "Player killed guardian. Setting joker mode.")
                mission.data.custom.killedGuardian = true
                _Data_in.reward.credits = _Data_in.reward.credits * 3
                _Data_in.reward.relations = _Data_in.reward.relations + 1000
            end
        end

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { x = _X, y = _Y }
        mission.data.description[3].arguments = { _X = _X, _Y = _Y }
        mission.data.description[4].arguments = { _SCANNED = mission.data.custom.scannedXsotan , _SCANNEDMAX = mission.data.custom.scannedXsotanTgt }
    end

    --Run vanilla init. Managers _restoring on its own.
    ScanXsotanGroup_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS

mission.globalPhase.noBossEncountersTargetSector = true

mission.globalPhase.getRewardedItems = function()
    --25% of getting a random rarity radar upgrade.
    if random():test(0.25) then
        local _SeedInt = random():getInt(1, 20000)
        local _Rarities = {RarityType.Common, RarityType.Common, RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare}

        if mission.data.custom.inBarrier then
            _Rarities = {RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare, RarityType.Rare, RarityType.Exceptional, RarityType.Exotic}
        end

        shuffle(random(), _Rarities)

        return SystemUpgradeTemplate("data/scripts/systems/scannerbooster.lua", Rarity(_Rarities[1]), Seed(_SeedInt))
    end
end

mission.globalPhase.onAbandon = function()
    unregisterMarkScannableXsotan()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onFail = function()
    unregisterMarkScannableXsotan()
    if mission.data.location then
        runFullSectorCleanup(true)
    end
end

mission.globalPhase.onAccomplish = function()
    unregisterMarkScannableXsotan()
    if mission.data.location then
        runFullSectorCleanup(false)
    end
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y) 
    local _MethodName = "Phase 1 on Target Location Entered"
    
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if onServer() then
        spawnMissionSector()
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 1 on Target Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")

    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].onBegin = function()
    if onClient() then
        registerMarkScannableXsotan()
    end
end

mission.phases[2].onRestore = function()
    registerMarkScannableXsotan()
end

--region #PHASE 2 PLAYER CALLBACKS

if onServer() then

mission.phases[2].playerCallbacks = {
    {
		name = "onMissionXsotanScanned",
		func = function(_xid)
            local methodName = "On Mission Xsotan Scanned"

            mission.Log(methodName, "Starting...")

            local xsotanScanned = false
			for _, _XsotanID in pairs(mission.data.custom.scannableXsotanShips) do
                if _XsotanID == _xid then
                    xsotanScanned = true
                    break
                end
            end

            if not xsotanScanned then return end

            mission.data.custom.scannedXsotan = mission.data.custom.scannedXsotan + 1

            --If we're inside the barrier and have killed the guardian, the Xsotan aggro after a certain # of them have been scanned.
            if mission.data.custom.inBarrier and mission.data.custom.killedGuardian then
                mission.Log(methodName, "Determining aggro point.")
                local xsotanAggroAfter = math.floor(mission.data.custom.scannedXsotanTgt / 2)
                if mission.data.custom.scannedXsotan >= xsotanAggroAfter then
                    mission.Log(methodName, "Scanned " .. tostring(mission.data.custom.scannedXsotan) .. " this is greater or equal to " .. tostring(xsotanAggroAfter) .. " - aggroing.")
                    aggroXsotan()
                end
            end

            mission.data.description[4].arguments = { _SCANNED = mission.data.custom.scannedXsotan , _SCANNEDMAX = mission.data.custom.scannedXsotanTgt }
            
            sync()
		end
	}
}

end

--endregion

--region #PHASE 2 TIMERS

--We have to check fail via timers b/c it's possible for the Xsotan to warp out if the player does not aggro them.
--Technically don't need to check win condition via timers but eh. Why not.
if onServer() then

mission.phases[2].timers[1] = {
    time = 5, 
    callback = function() 
        local methodName = "Phase 2 Timer 1 Callback"
        mission.Log(methodName, "Running win condition")

        if mission.data.custom.scannedXsotan >= mission.data.custom.scannedXsotanTgt then
            finishAndReward()
        end
    end,
    repeating = true
}

mission.phases[2].timers[2] = {
    time = 5, 
    callback = function() 
        local methodName = "Phase 2 Timer 2 Callback"
        mission.Log(methodName, "Running fail condition")

        if atTargetLocation() then --No need to do any of this if we're not at the target location.
            local remainingXsotanToScan = 0

            local xsotanShips = {Sector():getEntitiesByScriptValue("is_xsotan")}

            for _, xsotanShip in pairs(xsotanShips) do
                if xsotanShip:hasScript("player/missions/scanxsotan/scannablexsotan.lua") then
                    remainingXsotanToScan = remainingXsotanToScan + 1
                end
            end

            if mission.data.custom.scannedXsotan + remainingXsotanToScan < mission.data.custom.scannedXsotanTgt then
                mission.Log(methodName, "Not enough Xsotan left to scan - failing mission.")
                failAndPunish()
            end
        end
    end,
    repeating = true
}

end

--endregion

--endregion

--region #SERVER CALLS

function spawnMissionSector()
    local methodName = "Spawn Mission Sector"
    mission.Log(methodName, "Beginning...")

    --init
    mission.Log(methodName, "Initailizing values")

    local _SpawnCount = mission.data.custom.spawnXsotanQty
    local rgen = ESCCUtil.getRand()
    local _Generator = SectorGenerator(Sector():getCoordinates())
    local _XsotanByNameTable = {}
    local _XsotanTable = {}

    --make some asteroid fields (maybe)
    mission.Log(methodName, "Creating asteroid fields")

    for _ = 1, 3 do
        if rgen:test(0.5) then
            _Generator:createSmallAsteroidField()
        end
    end

    --create xsotan spawn table
    mission.Log(methodName, "Building Spawn Table")

    local _QuantumChance = 0.1 * mission.data.custom.dangerLevel --Caps @ 100% @ DL 10
    local _SummonerChance = 0.025 * mission.data.custom.dangerLevel --Caps @ 25% @ DL 10
    local _SpecialXsotanChance = 0.01 * mission.data.custom.dangerLevel --Caps @ 10% @ DL 10
    local _WildcardXsotanChance = 0.015 * mission.data.custom.dangerLevel --Caps @ 15% @ DL 10

    if mission.data.custom.inBarrier then
        _QuantumChance = math.min(1.0, _QuantumChance * 2) --Caps @ 100% @ DL 5
        _SummonerChance = _SummonerChance * 2 --Caps @ 50% @ DL 10
        _SpecialXsotanChance = _SpecialXsotanChance * 2 --Caps @ 20% @ DL 10
        _WildcardXsotanChance = _WildcardXsotanChance * 2 --Caps @ 30% @ DL 10

        if mission.data.custom.killedGuardian then
            _QuantumChance = math.min(1.0, _QuantumChance * 2) --Caps @ 100% @ DL 3
            _SummonerChance = math.min(1.0, _SummonerChance * 2) --Caps @ 100% @ DL 10
            _SpecialXsotanChance = math.min(1.0, _SpecialXsotanChance * 2) --Caps @ 40% @ DL 10
            _WildcardXsotanChance = math.min(1.0, _WildcardXsotanChance * 2) --Caps @ 60% @ DL 10
        end
    end

    local _AddQuantum = rgen:test(_QuantumChance)
    local _AddSmn = rgen:test(_SummonerChance)
    local _AddSpecial = rgen:test(_SpecialXsotanChance)
    local _AddWildcard = rgen:test(_WildcardXsotanChance)

    if _AddQuantum then
        mission.Log(methodName, "Adding Quantum Xsotan")
        table.insert(_XsotanByNameTable, "Quantum")
    end

    if _AddSmn then
        mission.Log(methodName, "Adding Summoner")
        table.insert(_XsotanByNameTable, "Summoner")
    end

    if _AddSpecial then
        mission.Log(methodName, "Adding Special Xsotan")
        table.insert(_XsotanByNameTable, "Special")
    end

    if _AddWildcard then
        mission.Log(methodName, "Adding Wildcard Xsotan")
        table.insert(_XsotanByNameTable, getRandomEntry({ "Quantum", "Summoner", "Special" }))
    end

    for _ = 1, _SpawnCount - #_XsotanByNameTable do
        table.insert(_XsotanByNameTable, "Ship")
    end

    --spawn xsotan
    mission.Log(methodName, "Spawning Table")

    for _ = 1, #_XsotanByNameTable do
        local _Xsotan = nil
        local _Dist = 1500
        if _XsotanByNameTable[_] == "Summoner" then
            _Xsotan = Xsotan.createSummoner(_Generator:getPositionInSector(_Dist), nil)
        elseif _XsotanByNameTable[_] == "Quantum" then
            _Xsotan = Xsotan.createQuantum(_Generator:getPositionInSector(_Dist), nil)
        elseif _XsotanByNameTable[_] == "Special" then
            local _XsotanFunction = getRandomEntry(Xsotan.getSpecialXsotanFunctions())

            _Xsotan = _XsotanFunction(_Generator:getPositionInSector(_Dist), nil)
        else
            _Xsotan = Xsotan.createShip(_Generator:getPositionInSector(_Dist), nil)
        end

        if _Xsotan then
            table.insert(_XsotanTable, _Xsotan)
        else
            mission.Log(_MethodName, "ERROR - Xsotan was nil")
        end
    end

    SpawnUtility.addEnemyBuffs(_XsotanTable)

    --add scripts to appropirate xsotan and build data table
    mission.Log(methodName, "Adding Xsotan to scannable Xsotan table")

    shuffle(_XsotanTable)

    for idx = 1, mission.data.custom.scannedXsotanTgt do
        --mission.Log(methodName, "Marking idx " .. tostring(idx))
        local _Xsotan = _XsotanTable[idx]

        _Xsotan:addScriptOnce("player/missions/scanxsotan/scannablexsotan.lua")
        mission.data.custom.scannableXsotanShips[idx] = _Xsotan.id.string
    end

    --add cleanup script
    mission.Log(methodName, "Adding sector monitor")
    Sector():addScriptOnce("sector/background/campaignsectormonitor.lua")

    --sync
    mission.Log(methodName, "Sync")

    sync()
end

function aggroXsotan()
    local _sector = Sector()
    local xsotan = {_sector:getEntitiesByScriptValue("is_xsotan")}
    local players = {_sector:getPlayers()}

    if not mission.data.custom.sentAggroWarning then
        _sector:broadcastChatMessage("", 3, "Your scanners have alerted the Xsotan to your presence!")
        mission.data.custom.sentAggroWarning = true
    end

    for _, xso in pairs(xsotan) do
        if valid(xso) then
            local xsoAI = ShipAI(xso.id)
            for _, p in pairs(players) do
                xsoAI:registerEnemyFaction(p.index)
            end
            xsoAI:setAggressive()
        end
    end
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

function failAndPunish()
    local _MethodName = "Fail and Punish"
    mission.Log(_MethodName, "Running lose condition.")

    punish()
    fail()
end

--endregion

--region #CLIENT CALLS

function onMarkScannableXsotan()
    local _MethodName = "On Mark Scannable Xsotan"

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret or player.state == PlayerStateType.PhotoMode then return end

    local renderer = UIRenderer()

    local _sector = Sector()
    for idx = 1, #mission.data.custom.scannableXsotanShips do
        local color = ColorRGB(0.2, 0.5, 0.2)
        local entity = _sector:getEntity(Uuid(mission.data.custom.scannableXsotanShips[idx]))
        if entity and entity:hasScript("player/missions/scanxsotan/scannablexsotan.lua") then

            local _, size = renderer:calculateEntityTargeter(entity)

            renderer:renderEntityTargeter(entity, color, size * 1.25)
            renderer:renderEntityArrow(entity, 30, 10, 250, color)
        end
    end

    renderer:display()
end

--endregion

--region #CLIENT / SERVER UTILITY CALLS

function registerMarkScannableXsotan()
    local _MethodName = "Register Mark Scannable Xsotan"

    if onClient() then
        mission.Log(_MethodName, "Invoked on Client - Reigstering onPreRenderHud callback.")

        if Player():registerCallback("onPreRenderHud", "onMarkScannableXsotan") == 1 then
            mission.Log(_MethodName, "WARNING - Could not attach prerender callback to script.")
        end
    else
        mission.Log(_MethodName, "Calling on Server => Invoking on Client")
        
        invokeClientFunction(Player(), "registerMarkScannableXsotan")
    end
end

function unregisterMarkScannableXsotan()
    local _MethodName = "Unregister Mark Scannable Xsotan"
    
    if onClient() then
        mission.Log(_MethodName, "Invoking on Client - Unregistering callback.")

        if Player():unregisterCallback("onPreRenderHud", "onMarkScannableXsotan") == 1 then
            mission.Log(_MethodName, "WARNING - Could not detach prerender callback to script.")
        end
    else
        mission.Log(_MethodName, "Calling on Server => Invoking on Client")
        
        invokeClientFunction(Player(), "unregisterMarkScannableXsotan")
    end
end

--endregion

--region #MAKEBULLETIN CALLS

function formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    if _Station.title == "Research Station" then
        descriptionType = descriptionType + 3
    end

    if _Station.title == "Resistance Outpost" then
        if random():test(0.5) then
            descriptionType = descriptionType + 3
        end
    end

    local descriptionTable = {
        "There are a group of Xsotan gathering in (${x}:${y}). We're looking for an independent captain to scan a few of them and learn more about their ships. We'll compenstate you for your work. You can destroy them if you need to - just be sure to get the data first.", --Military Outpost Neutral
        "An ancient warrior once said that if you know yourself and know and know yourself, you need not fear the result of a hundred battles. We need more information about the Xsotan. A group of them are gathering in (${x}:${y}). Scan their ships. Learn their weakness. We care not what you do with them afterwards.", --Military Outpost Aggressive
        "Peace be with you, Captain. We need your help. The Xsotan have taken much from us, but we know barely anything about them in turn. Our scouts found a group of the strange ships gathering in (${x}:${y}). Please travel there and scan their vessels. A peaceful solution is ideal, but your safety is foremost.", --Military Outpost Peaceful
        "Its been hundreds of years since the United Alliances fell, but it feels like we barely know anything about the strange aliens that toppled the pinnacle of the galaxy's might. Today, we'd like to change that. There are some Xsotan gathering in (${x}:${y}). We'll pay you for any data you can collect from them.", --Research Lab Neutral
        "We've long been curious about Xsotan combat efficacy. Their ships are often smaller than standard ships of this region, yet they frequently have outsize firepower compared to their weight class. We'd like to find out why. There are some Xsotan in (${x}:${y}). Scan their ships, and we'll figure out the rest.", --Research Lab Aggressive
        "Every time the Xsotan have attacked us, there has been a great loss of life. Perhaps we can find a way to prevent this, but we will need more information on what they're like. How they work. How they think and feel. Some Xsotan are gathering in (${x}:${y}). Please scan their ships and transmit the data to us." --Research Lab Peaceful
    }

    return descriptionTable[descriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Starting...")

    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local _sector = Sector()
    local target = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 2, 15, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)
    
    local _Description = formatDescription(_Station)

    local _Difficulty = "Medium"
    if _DangerLevel > 5 then
        _Difficulty = "Difficult"
    end

    local _BaseReward = 60000
    if _DangerLevel > 5 then
        _BaseReward = _BaseReward + 5000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates()) --SET REWARD HERE

    missionReward = { credits = reward, relations = 4000, paymentMessage = "Earned %1% credits for scanning Xsotan." }

    local distToCenter = math.sqrt(x * x + y * y)
    local _MatlMin = 0 --7000
    local _MatlMax = 0 --8000
    if distToCenter > 400 then
        _MatlMin = 5000
        _MatlMax = 6000
    elseif distToCenter < 400 and distToCenter > 300 then
        _MatlMin = 10000
        _MatlMax = 12000
    else
        _MatlMin = 20000
        _MatlMax = 24000
    end
    
    mission.Log(_MethodName, "matlmin is ${MIN} and matlmax is ${MAX}" % { MIN = _MatlMin, MAX = _MatlMax }) 

    local materialAmount = round(random():getInt(_MatlMin, _MatlMax) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, missionReward, materialAmount)

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission._Name,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/scanxsotangroup.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The Xsotan are located in sector \\s(%1%:%2%). Please scan their ships.",
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
            reward = missionReward,
            punishment = { relations = 4000 },
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            inBarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion