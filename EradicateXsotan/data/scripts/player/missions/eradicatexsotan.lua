--[[
    Rank 2 side mission.
    Eradicate Xsotan Infestation
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Rank 2
    ROUGH OUTLINE
        - Jump to the target sector.
        - Start killing Xsotan.
        - An infestor will show up after you've killed 25 of them.
        - Kill that and you're done. That's literally it.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - Maximum # of Xsotan in the sector is 10.
            - Xsotan will be size 1 to 3
            - Infestor size is 3 + max size + min size and has a +60% damage buff. In addition, it is always a summoner.
        6 - [These conditions are present at danger level 6 and above]
            - The first Xsotan in each wave has a 50% chance to be quantum.
        8 - [These conditions are present at danger level 8 and above]
            - Increases the maximum # of Xsotan by 1 (to 11)
            - Increases the maximum size of Xsotan by 1 (size 1 to 4)
        10 - [These conditions are present at danger level 10]
            - You have to kill 30 Xsotan instead of 25.
            - The first Xsotan in each wave is guaranteed to be quantum.
            - The second Xsotan in each wave has a 50% chance to be a summoner. This obviously has no effect if there is only 1 xsotan in a wave.
            - Increases the maximum # of Xsotan by 1 (to 12)
            - Increases the minimum and maximum size of Xsotan by 1 (size 2 to 5)
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Xsotan = include("story/xsotan")
local SpawnUtility = include ("spawnutility")
local SectorGenerator = include ("SectorGenerator")
local Balancing = include ("galaxy")

mission._Debug = 0
mission._TestSpecials = 0
mission._Name = "Eradicate Xsotan Infestation"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Head to sector (${x}:${y}) and destroy all present Xsotan", bulletPoint = true, fulfilled = false },
    { text = "Destroy the Xsotan Infestor", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Thank you for clearing out the Xsotan! We've transferred a reward to your account."

local EradicateXsotan_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .maximumXsotan
                .xsotanSizeBonus
                .xsotanKilled
                .xsotanKillreq
                .infestorSpawned
                .inBarrier
                .killedGuardian
                .xsoDamageMultiplier
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.maximumXsotan = 10
            mission.data.custom.maximumQuantum = 2
            mission.data.custom.xsotanSizeBonus = { min = 0, max = 2 }
            mission.data.custom.xsotanKilled = 0
            mission.data.custom.xsotanKillreq = 25
            mission.data.custom.infestorSpawned = false
            mission.data.custom.inBarrier = _Data_in.inbarrier
            mission.data.custom.xsoDamageMultiplier = 1

            if mission.data.custom.inBarrier then
                local _KilledGuardian = Player():getValue("wormhole_guardian_destroyed")
                if _KilledGuardian then
                    mission.Log(_MethodName, "Player killed guardian. Setting joker mode.")
                    mission.data.custom.killedGuardian = true
                end
            end

            if mission.data.custom.dangerLevel >= 8 then
                mission.data.custom.maximumXsotan = mission.data.custom.maximumXsotan + 1
                mission.data.custom.xsotanSizeBonus.max = mission.data.custom.xsotanSizeBonus.max + 1
            end
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.maximumXsotan = mission.data.custom.maximumXsotan + 1
                mission.data.custom.xsotanSizeBonus.min = mission.data.custom.xsotanSizeBonus.min + 1
                mission.data.custom.xsotanSizeBonus.max = mission.data.custom.xsotanSizeBonus.max + 1
                mission.data.custom.xsotanKillreq = mission.data.custom.xsotanKillreq + 2
            end

            if mission.data.custom.inBarrier then
                mission.data.custom.xsotanSizeBonus.min = mission.data.custom.xsotanSizeBonus.min + 2
                mission.data.custom.xsotanSizeBonus.max = mission.data.custom.xsotanSizeBonus.max + 2

                if mission.data.custom.killedGuardian then
                    mission.Log(_MethodName, "In barrier and killed guardian - increasing difficulty & rewards.")
                    mission.data.custom.xsoDamageMultiplier = mission.data.custom.xsoDamageMultiplier + 1
                    _Data_in.reward.credits = _Data_in.reward.credits * 3
                    _Data_in.reward.relations = _Data_in.reward.relations + 2000
                    
                    if mission.data.custom.dangerLevel == 10 then
                        mission.data.custom.maximumXsotan = mission.data.custom.maximumXsotan + 1
                        mission.data.custom.xsoDamageMultiplier = mission.data.custom.xsoDamageMultiplier + 1.5
                        mission.data.custom.xsotanKillreq = mission.data.custom.xsotanKillreq + 2
                        mission.data.custom.maximumQuantum = mission.data.custom.maximumQuantum + 1
                    end
                end
            end

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = {x = _X, y = _Y }
            mission.data.description[3].arguments = {x = _X, y = _Y }

            --Run standard initialization
            EradicateXsotan_init(_Data_in)
        else
            --Restoring
            EradicateXsotan_init()
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
--Try to keep the timer calls outside of onBeginServer / onSectorEntered / onSectorArrivalConfirmed unless they are non-repeating and 30 seconds or less.

mission.globalPhase = {}
mission.globalPhase.onAbandon = function()
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

mission.phases[1] = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    spawnObjectiveSector(x, y)
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onTargetLocationEntered = function(x, y)
    --Give the player a 30 second window before any sunmakers, longinus(es?), or ballistyx start shooting again.
    local _Sector = Sector()

    local _func = "resetTimeToActive"
    local _time = 30

    local _Sunmakers = {_Sector:getEntitiesByScriptValue("is_sunmaker")}
    for _, _sunmaker in pairs(_Sunmakers) do
        _sunmaker:invokeFunction("stationsiegegun.lua", _func, _time)
    end

    local _Longinus_plural = {_Sector:getEntitiesByScriptValue("is_longinus")}
    for _, _longinus in pairs(_Longinus_plural) do
        _longinus:invokeFunction("lasersniper.lua", _func, _time)
    end
    
    local _Ballistyx_plural = {_Sector:getEntitiesByScriptValue("is_ballistyx")}
    for _, _ballistyx in pairs(_Ballistyx_plural) do
        _ballistyx:invokeFunction("torpedoslammer.lua", _func, _time)
    end
end

mission.phases[2].onTargetLocationLeft = function(x, y)
    local _MethodName = "Phase 2 On Target Location Left"
    mission.Log(_MethodName, "Beginning...")
    --Reset.
    mission.data.custom.xsotanKilled = 0
    mission.data.custom.infestorSpawned = false
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 2 Update Target Location"

    local _XKR = mission.data.custom.xsotanKillreq
    if mission.data.custom.xsotanKilled >= _XKR and not mission.data.custom.infestorSpawned then
        mission.Log(_MethodName, tostring(_XKR) .. "+ Xsotan killed. Spawning Infestor.")
        spawnXsotanInfestor()   

        mission.data.description[4].visible = true
        showMissionUpdated("Eradicate Xsotan Infestation")

        mission.data.custom.infestorSpawned = true
        sync()
    end
end

mission.phases[2].onEntityDestroyed = function(id, lastDamageInflictor)
    local _MethodName = "Phase 2 On Entity Destroyed"
    
    local _OnLocation = getOnLocation(nil)

    if _OnLocation then
        local entity = Entity(id)
        if valid(entity) and entity:getValue("_infestation_xsotan") then
            mission.data.custom.xsotanKilled = mission.data.custom.xsotanKilled + 1
        end
    
        if entity:getValue("is_infestor") then
            local rgen = ESCCUtil.getRand()
            local _Xsos = {Sector():getEntitiesByScriptValue("is_xsotan")}
            if _Xsos then
                for _, _Xso in pairs(_Xsos) do
                    _Xso:addScriptOnce("utility/delayeddelete.lua", rgen:getFloat(5, 9))
                end
            end
    
            finishAndReward()
        end
        
        mission.Log(_MethodName, tostring(mission.data.custom.xsotanKilled) .. " Xsotan killed so far.")
    end
end

--region #PHASE 2 timers

if onServer() then

mission.phases[2].timers[1] = {
    time = 60,
    callback = function()
        local _OnLocation = getOnLocation(nil)
        if _OnLocation then
            spawnXsotanWave()
        end
    end,
    repeating = true
}
    
 end

--endregion

--endregion

--region #SERVER CALLS

function spawnObjectiveSector(x, y)
    local _MethodName = "Spawning Sector"

    local rgen = ESCCUtil.getRand()
    mission.Log(_MethodName, "Generating asteroid fields.")
    local generator = SectorGenerator(x, y)
    for _ = 1, rgen:getInt(2,6) do
        generator:createSmallAsteroidField()
    end

    mission.Log(_MethodName, "Generating Xsotan.")
    --Spawn the maximum number of Xsotan.
    spawnXsotanWave()

    mission.Log(_MethodName, "Adding sector monitor")
    Sector():addScriptOnce("sector/background/campaignsectormonitor.lua")
end

function spawnXsotanWave()
    local _MethodName = "Spawn Xsotan"
    
    local _SpawnCount = mission.data.custom.maximumXsotan - ESCCUtil.countEntitiesByValue("_infestation_xsotan")
    if mission.data.custom.xsotanKilled >= 200 then
        _SpawnCount = 0 --if you're silly enough to kill two hundred of these without killing the infestor, we'll throw you a bone.
    end
    local rgen = ESCCUtil.getRand()
    local _Generator = SectorGenerator(Sector():getCoordinates())
    local _Players = {Sector():getPlayers()}
    local _XsotanByNameTable = {}
    local _XsotanTable = {}

    mission.Log(_MethodName, "Spawning " .. tostring(_SpawnCount) .. " Xsotan ships.")
    --Use the same method for spawning a background Xsotan in the swarm event.
    --If danger level is 6+, 50% chance to add a quantum to each wave.
    local _AddSmn = false
    local _AddQuantum = false
    local _AddSpecial = false
    if mission.data.custom.dangerLevel >= 6 and rgen:getInt(1, 2) - 1 == 1 then
        mission.Log(_MethodName, "Adding danger 6 quantum to spawn table")
        _AddQuantum = true
    end
    --If danger level is 10, 100% chance to add a quantum and a 25% chance to add a summoner to each wave.
    if mission.data.custom.dangerLevel == 10 then
        mission.Log(_MethodName, "Adding danger 10 quantum to spawn table")
        _AddQuantum = true
        if rgen:getInt(1, 4) - 1 == 1 then 
            mission.Log(_MethodName, "Adding summoner to spawn table")
            _AddSmn = true 
        end
    end
    --If there's already a summoner here, don't spawn another one.
    local _Sector = Sector()
    local _Summoners = {_Sector:getEntitiesByScript("enemies/summoner.lua")}
    if #_Summoners > 0 then
        _AddSmn = false
    end

    local _Quantums = {_Sector:getEntitiesByScript("enemies/blinker.lua")}
    if #_Quantums >= mission.data.custom.maximumQuantum then
        _AddQuantum = false
    end

    if mission.data.custom.inBarrier and mission.data.custom.killedGuardian then
        local _ChanceToAdd = mission.data.custom.dangerLevel * 2
        local _Chance = rgen:getInt(1, 100)
        if _Chance < _ChanceToAdd then
            mission.Log(_MethodName, "Chance " .. tostring(_Chance) .. " was less than Chance to add " .. tostring(_ChanceToAdd) .. " adding special")
            _AddSpecial = true
        else
            mission.Log(_MethodName, "Chance " .. tostring(_Chance) .. " was more than Chance to add " .. tostring(_ChanceToAdd) .. " not adding special")
        end
    end

    if mission._TestSpecials == 1 then
        _AddSpecial = true
    end

    --Build our Xsotan name table.
    if _SpawnCount >= 1 and _AddQuantum then table.insert(_XsotanByNameTable, "Quantum") end
    if _SpawnCount >= 1 and _AddSmn then table.insert(_XsotanByNameTable, "Summoner") end
    if _SpawnCount >= 1 and _AddSpecial then table.insert(_XsotanByNameTable, "Special") end
    if _SpawnCount - #_XsotanByNameTable > 0 then
        for _ = 1, _SpawnCount - #_XsotanByNameTable do
            table.insert(_XsotanByNameTable, "Ship")
        end
    end
    
    mission.Log(_MethodName, "Spawning final count of " .. tostring(#_XsotanByNameTable) .. " Xsotan ships.")
    --Spawn Xsotan based on what's in the nametable.
    for _ = 1, #_XsotanByNameTable do
        local xsoSize = 1.0 + rgen:getInt(mission.data.custom.xsotanSizeBonus.min, mission.data.custom.xsotanSizeBonus.max)
        local _Xsotan = nil
        local _Dist = 1500
        if _XsotanByNameTable[_] == "Summoner" then
            _Xsotan = Xsotan.createSummoner(_Generator:getPositionInSector(_Dist), xsoSize)
        elseif _XsotanByNameTable[_] == "Quantum" then
            _Xsotan = Xsotan.createQuantum(_Generator:getPositionInSector(_Dist), xsoSize)
        elseif _XsotanByNameTable[_] == "Special" then
            local _SpecialSize = mission.data.custom.xsotanSizeBonus.max * 2
            local _XsotanFunction = getRandomEntry(Xsotan.getSpecialXsotanFunctions())

            _Xsotan = _XsotanFunction(_Generator:getPositionInSector(_Dist), _SpecialSize)
        else
            _Xsotan = Xsotan.createShip(_Generator:getPositionInSector(_Dist), xsoSize)
        end

        if _Xsotan then
            if valid(_Xsotan) then
                for _, p in pairs(_Players) do
                    ShipAI(_Xsotan.id):registerEnemyFaction(p.index)
                end
                ShipAI(_Xsotan.id):setAggressive()
            end
            _Xsotan:setValue("_infestation_xsotan", true)
            _Xsotan.damageMultiplier = (_Xsotan.damageMultiplier or 1 ) * mission.data.custom.xsoDamageMultiplier
            table.insert(_XsotanTable, _Xsotan)
        else
            Lmission.Log(_MethodName, "ERROR - Xsotan was nil")
        end
    end

    SpawnUtility.addEnemyBuffs(_XsotanTable)
end

function spawnXsotanInfestor()
    local _MethodName = "Spawn Xsotan Infestor"
    mission.Log(_MethodName, "Beginning...")

    local _InfestorSize = mission.data.custom.xsotanSizeBonus.min + mission.data.custom.xsotanSizeBonus.max + 3

    local _ExtraTurret = mission.data.custom.dangerLevel == 10

    local _X, _Y = Sector():getCoordinates()
    local _Generator = SectorGenerator(_X, _Y)
    local _XsotanInfestor = Xsotan.createInfestor(_Generator:getPositionInSector(2500), _InfestorSize, _ExtraTurret)

    local _Players = {Sector():getPlayers()}
    if valid(_XsotanInfestor) then
        for _, p in pairs(_Players) do
            ShipAI(_XsotanInfestor.id):registerEnemyFaction(p.index)
        end
        ShipAI(_XsotanInfestor.id):setAggressive()
    end
    
    local _XsotanInfestorTable = {}
    table.insert(_XsotanInfestorTable, _XsotanInfestor)
    SpawnUtility.addEnemyBuffs(_XsotanInfestorTable)
    invokeClientFunction(Player(), "startBossCameraAnimation", _XsotanInfestor.id)
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #MAKEBULLETIN CALL

function formatDescription(_Station, _insideBarrier)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _FinalDescription = ""
    if _insideBarrier then
        _FinalDescription = "The tide of Xsotan is endless! So is our will to defeat them - but occasionally we need some help. There's an especially bad cluster of Xsotan signatures in Sector (${x}:${y}). We need some asssistance cleaning them up - our own forces are depleted and we'll need some time to rebuild."
    else
        if _DescriptionType == 1 then --Neutral.
            _FinalDescription = "Our scouts have picked up Xsotan activity in Sector (${x}:${y}). This is a serious threat to our operations, and needs to be dealt with. We're offering a bounty for any captain brave enough to head into the sector and eradicate them. We'll await your return."
        elseif _DescriptionType == 2 then --Aggressive.
            _FinalDescription = "The Xsotan are a stain on the galaxy and must be eradicated. However, our forces are exhausted from several recent conflicts and aren't able to respond to them appropriately. We've picked up some Xsotan activity in Sector (${x}:${y}). Go there and destroy every one of their wretched ships you encounter."
        elseif _DescriptionType == 3 then --Peaceful.
            _FinalDescription = "We've recently detected a Xsotan incursion in Sector (${x}:${y}). Our forces are unprepared to respond, and if we leave the Xsotan to their own devices they could kill millions of people. We need your help. Please head there and wipe out any Xsotan ships you encounter. We will pay you for your efforts."
        end
    end

    return _FinalDescription
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Sector = Sector()
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = _Sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 2, 15, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)

    local _Difficulty = "Medium"
    if insideBarrier then
        _Difficulty = "Difficult"
        if _DangerLevel == 10 then
            _Difficulty = "Extreme"
        end
    else
        if _DangerLevel == 10 then
            _Difficulty = "Difficult"
        end
    end

    local _Description = formatDescription(_Station, insideBarrier)

    local _BaseReward = 73000
    local _BaseRelReward = 6000
    if _DangerLevel >= 5 then
        _BaseReward = _BaseReward + 5000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 12000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 3
        _BaseRelReward = _BaseRelReward + 4000
    end

    reward = _BaseReward * Balancing.GetSectorRichnessFactor(_Sector:getCoordinates()) --SET REWARD HERE
    relreward = _BaseRelReward

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/eradicatexsotan.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "The Xsotan are in \\s(%1%:%2%). Please destroy them.",
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
            reward = {credits = reward, relations = relreward, paymentMessage = "Earned %1% credits for destroying Xsotan." },
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            inbarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion