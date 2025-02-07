--[[
    MISSION 1: Hunt Pirate Fleet
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")
HorizonUtil = include("horizonutil")

local SectorGenerator = include ("SectorGenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Hunt Pirate Fleet"

--region #INIT / DATA

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.icon = "data/textures/icons/snowflake-2.png"
mission.data.priority = 9
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Head to sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy the remnants of the pirate fleet", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the first wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the second wave of pirates", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Destroy the third wave of pirates", bulletPoint = true, fulfilled = false, visible = false }
}

mission.data.accomplishMessage = "Good work, Captain - Frostbite Company thanks you. We transferred the reward to your account."

--Custom data that we'll want.
mission.data.custom.dangerLevel = 10 --Key everything off of danger 10.
mission.data.custom.advancePhase = false --Allows for the phase to advance.
mission.data.custom.givenChip = false
mission.data.custom.spawnedRemnants = false
mission.data.custom.spawnedAsteroids = false

--endregion

--region #PHASE CALLS

mission.globalPhase.timers = {}

mission.globalPhase.noBossEncountersTargetSector = true

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
    time = 10, 
    callback = function() 
        local _MethodName = "Global Phase Timer 1 Callback"

        if atTargetLocation() then
            --Don't do any of this unless we're on location
            local _pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

            mission.Log(_MethodName, "Number of pirates : " .. tostring(_pirateCt) .. " timer allowed to advance : " .. tostring(mission.data.custom.advancePhase))

            if mission.data.custom.advancePhase and _pirateCt == 0 then
                mission.data.custom.advancePhase = false
                nextPhase()
            end
        end
    end,
    repeating = true
}

mission.globalPhase.timers[2] = {
    time = 180, --He doesn't have the resources of Adriana, can't respawn as quickly.
    callback = function()
        local _MethodName = "Global Phase Timer 2 Callback"

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
mission.phases[1].onBegin = function()
    local _Giver = Entity(mission.data.giver.id)

    mission.data.description[1].arguments = { sectorName = Sector().name, giverTitle = _Giver.translatedTitle }
    mission.data.description[2].text = formatDescription()
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
end

mission.phases[1].updateServer = function(_timestep)
    if atTargetLocation() then
        local _pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

        if _pirateCt == 1 and not mission.data.custom.sentDistress then
            mission.data.custom.sentDistress = true
            sendDistressCall()
        end
    end
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    if onServer() then
        createAsteroidFields(x, y)
        spawnVarlance()
        spawnPirateRemnants()

        showMissionUpdated(mission._Name)
    end
end

mission.phases[2] = {}
mission.phases[2].showUpdateOnStart = true
mission.phases[2].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
end

mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    spawnPirateWave(1)
end

mission.phases[3] = {}
mission.phases[3].showUpdateOnStart = true
mission.phases[3].timers = {}
mission.phases[3].onBegin = function()
    mission.data.description[5].fulfilled = true
    mission.data.description[6].visible = true
end

mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    spawnPirateWave(2)
end

--region #PHASE 3 TIMERS

if onServer() then

mission.phases[3].timers[1] = {
    time = 15,
    callback = function()
        if atTargetLocation() then
            spawnTorpedoStrike()
        end
    end,
    repeating = false
}

end

--endregion

mission.phases[4] = {}
mission.phases[4].showUpdateOnStart = true
mission.phases[4].onBegin = function()
    mission.data.description[6].fulfilled = true
    mission.data.description[7].visible = true
end

mission.phases[4].onBeginServer = function()
    local _MethodName = "Phase 4 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    spawnPirateWave(3)
end

mission.phases[4].updateServer = function(_timeStep)
    --If the chip has not been given yet...
    if atTargetLocation() and mission.data.custom.advancePhase then
        givePlayerChip()
    end
end

mission.phases[5] = {}
mission.phases[5].onBegin = function()
    mission.data.description[7].fulfilled = true
end

mission.phases[5].onBeginServer = function()
    --Spawn Varlance if he doesn't already exist.
    spawnVarlance()

    --Give the player the chip if somehow phase 4 hasn't given them the chip yet.
    givePlayerChip()

    --Get varlance and his ID.
    local _Varlance = Entity(mission.data.custom.varlanceID)

    invokeClientFunction(Player(), "onPhase5Dialog", _Varlance.id)
end

local onPhase5DialogEnd = makeDialogServerCallback("onPhase5DialogEnd", 5, function()
    local _Varlance = Entity(mission.data.custom.varlanceID)
    _Varlance:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))

    finishAndReward()
end)

--endregion

--region #SERVER CALLS

function createAsteroidFields(x, y)
    if not mission.data.custom.spawnedAsteroids then
        local _Generator = SectorGenerator(x, y)

        _Generator:createAsteroidField()
    
        local _fields = random():getInt(3, 5)
        --Add: 3-5 small asteroid fields.
        for _ = 1, _fields do
            _Generator:createSmallAsteroidField()
        end

        Sector():addScriptOnce("sector/background/campaignsectormonitor.lua")

        mission.data.custom.spawnedAsteroids = true
    end
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

        local _Varlance = HorizonUtil.spawnVarlanceNormal(true)
        local _VarlanceAI = ShipAI(_Varlance)
    
        _VarlanceAI:setAggressive()

        mission.data.custom.varlanceID = _Varlance.index
    end
end

function spawnPirateRemnants()
    local _MethodName = "Create Pirate Remnants"
    mission.Log(_MethodName, "Running.")

    if not mission.data.custom.spawnedRemnants then
        local generator = AsyncPirateGenerator(nil, onPirateRemnantsFinished)

        generator:startBatch()
    
        generator:createScaledPirateByName("Outlaw", generator.getGenericPosition())
        generator:createScaledPirateByName("Outlaw", generator.getGenericPosition())
        generator:createScaledPirateByName("Outlaw", generator.getGenericPosition())
        generator:createScaledPirateByName("Bandit", generator.getGenericPosition())
        generator:createScaledPirateByName("Bandit", generator.getGenericPosition())
        generator:createScaledPirateByName("Pirate", generator.getGenericPosition())
        generator:createScaledPirateByName("Scorcher", generator.getGenericPosition())
        generator:createScaledPirateByName("Devastator", generator.getGenericPosition())
    
        generator:endBatch()

        mission.data.custom.spawnedRemnants = true
    end
end

function onPirateRemnantsFinished(_Generated)
    mission.data.custom.advancePhase = true

    local xrand = random()

    for _, _ship in pairs(_Generated) do
        local duraFactor = xrand:getFloat(.2, .5)
        _ship.durability = _ship.maxDurability * duraFactor
        _ship:removeScript("fleeondamaged.lua") --They already ran.
    end

    SpawnUtility.addEnemyBuffs(_Generated)
end

function sendDistressCall()
	--print("sending distress call")
    local _sector = Sector()
    local x, y = _sector:getCoordinates()
    local _pirates = {_sector:getEntitiesByScriptValue("is_pirate")}

	local lastShip = _pirates[1]

	local helpCalls = {
		"We're being slaughtered! Help us! HELP US!!!",
		"This is the " .. lastShip.name .. "! Everyone else is dead! Send help!",
		"This is a distress call! Our position is (" .. x .. ":" .. y .. ")! We're under attack!",
		"Mayday! All other ships are destroyed and we're critically damaged! Mayday!",
		"Save us! Save us! Hurt them! Hurt them!",
		"Get the fleet on red alert! They'll kill us all!",
		"No!!! NO!!! Not like this! Not like this!"
	}
    shuffle(random(), helpCalls)
    
	_sector:broadcastChatMessage(lastShip, ChatMessageType.Chatter, helpCalls[1])
	Player():sendChatMessage("", 3, "The pirate ship is broadcasting a distress signal!")
end

function spawnPirateWave(_waveNo)
    local _MethodName = "Spawn Pirate Wave"
    mission.Log(_MethodName, "Spawning wave " .. tostring(_waveNo))

    --Get a pirate table to spawn based on the wave #
    local _WaveData = {
        { ct = 4, tbl = "Standard", lvl = math.ceil(mission.data.custom.dangerLevel * 0.5), func = onPirateWaveFinished },
        { ct = 4, tbl = "Standard", lvl = math.ceil(mission.data.custom.dangerLevel * 0.75), func = onPirateWaveFinished },
        { ct = 5, tbl = "High", lvl = mission.data.custom.dangerLevel, func = onFinalPirateWaveGenerated }
    }

    local _WaveTable = ESCCUtil.getStandardWave(_WaveData[_waveNo].lvl, _WaveData[_waveNo].ct, _WaveData[_waveNo].tbl, false)

    local _WaveGenerator = AsyncPirateGenerator(nil, _WaveData[_waveNo].func)

    _WaveGenerator:startBatch()

    local posCounter = 1
    local _posDistance = 250 --#DistAdj

    local _piratePositions = _WaveGenerator:getStandardPositions(#_WaveTable, _posDistance)

    for _, p in pairs(_WaveTable) do
        _WaveGenerator:createScaledPirateByName(p, _piratePositions[posCounter])
        posCounter = posCounter + 1
    end

    _WaveGenerator:endBatch()
end

function onPirateWaveFinished(_Generated)
    mission.data.custom.advancePhase = true

    SpawnUtility.addEnemyBuffs(_Generated)
end

function onFinalPirateWaveGenerated(_Generated)
    mission.data.custom.advancePhase = true

    --Add a deadshot script to the first pirate. Make it as powerful as a stock longinus.
    local _Sector = Sector()
    local x, y = _Sector:getCoordinates()
    local _dpf = Balancing_GetSectorWeaponDPS(x, y) * 125

    local _MiniBoss = _Generated[1]
    
    local _LaserSniperValues = { --#LONGINUS_SNIPER
        _DamagePerFrame = _dpf,
        _TimeToActive = 10,
        _TargetCycle = 15,
        _TargetingTime = 2.25, --Take longer than normal to target.
        _TargetPriority = 4,
        _pindex = Player().index
    }

    ESCCUtil.setDeadshot(_MiniBoss)
    _MiniBoss:addScriptOnce("lasersniper.lua", _LaserSniperValues)

    SpawnUtility.addEnemyBuffs(_Generated)

    --Get Varlance and have him warn the player.
    local _Varlance = { _Sector:getEntitiesByScriptValue("is_varlance") }
    if #_Varlance > 0 then
        _Sector:broadcastChatMessage(_Varlance[1], ChatMessageType.Chatter, "That's a Deadshot, a heavy laser platform. It looks like it's after you - stay mobile and watch out for its targeting beam.")
    end
end

--Torp strike
function spawnTorpedoStrike()
    local _MethodName = "Spawning Torpedo Strike"

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 3, "High", false) --They're only in for 8-9 seconds. Make them the larger ships.

    local generator = AsyncPirateGenerator(nil, onTorpStrikePirateSpawned)

    generator:startBatch()

    for _, p in pairs(waveTable) do
        mission.Log(_MethodName, "Spawning torp strike pirate " .. tostring(_) .. " of 3")
        generator:createScaledPirateByName(p, generator.getGenericPosition())
    end

    generator:endBatch()
end

function givePlayerChip()
    if not mission.data.custom.givenChip then
        local _Player = Player()
        local items = _Player:getInventory():getItemsByType(InventoryItemType.VanillaItem)
        local _PlayerHasChip = false
        for _, slot in pairs(items) do
            local item = slot.item

            -- we assume they're stackable, so we return here
            if item:getValue("subtype") == "HorizonStoryDataChip" then
                _PlayerHasChip = true
                break
            end
        end

        if _PlayerHasChip then
            mission.data.custom.givenChip = true
        else
            if ESCCUtil.countEntitiesByValue("is_pirate") == 0 then
                _Player:getInventory():add(HorizonUtil.getEncryptedDataChip())
                mission.data.custom.givenChip = true
            end
        end
    end
end

function onTorpStrikePirateSpawned(_Generated)
    for _, _Ship in pairs(_Generated) do
        local _TorpSlamValues = {
            _ROF = 2,
            _DurabilityFactor = 2,
            _TimeToActive = 0,
            _DamageFactor = 3,
            _UseEntityDamageMult = true,
            _TargetPriority = 5,
            _pindex = Player().index
        }

        _Ship:addScriptOnce("torpedoslammer.lua", _TorpSlamValues)
        _Ship:addScriptOnce("utility/delayeddelete.lua", random():getFloat(8, 9)) --Should give it enough time to fire 3x and peace out.
        ESCCUtil.setBombardier(_Ship)
    end

    Placer.resolveIntersections(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _player = Player()
    _player:setValue("_horizonkeepers_story_stage", 2)
    _player:setValue("encyclopedia_koth_frostbite", true)
    _player:setValue("encyclopedia_koth_varlance", true)

    HorizonUtil.addFriendlyFactionRep(_player, 12500)

    reward()
    accomplish()
end

--endregion

--region #CLIENT DIALOG CALLS

function onPhase5Dialog(_VarlanceID)
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}

    d0.text = "So that's how an independent captain fights." 
    d0.followUp = d1

    d1.text = "They say war never changes. But lately... it feels like something's different. Heavy laser platforms. Shock-jumping torpedo strikes... It feels like the galaxy's on the edge of a knife. At any moment the factions could have the Sword of Damocles cleaving through their neck."
    d1.followUp = d2

    d2.text = "I suppose that's what people like us are for. People who aren't afraid to get some blood on our hands... no matter if it's ours or someone else's."
    d2.followUp = d3

    d3.text = "Well, we're war buddies now. So let me help you out - it looks like you picked up an encrypted data chip. I know someone who can break the encryption on that. Just need to figure out where they've gone to ground."
    d3.followUp = d4

    d4.text = "I'll be in touch. Try not to die out there."
    d4.answers = {
        { answer = "I'll do my best.", onSelect = onPhase5DialogEnd },
        { answer = "Thank you.", followUp = d5 }
    }

    d5.text = "Don't mention it. With luck, we'll meet again."
    d5.onEnd = onPhase5DialogEnd

    ESCCUtil.setTalkerTextColors({d0, d1, d2, d3, d4, d5}, "Varlance", HorizonUtil.getDialogVarlanceTalkerColor(), HorizonUtil.getDialogVarlanceTextColor())

    ScriptUI(_VarlanceID):interactShowDialog(d0, false)
end

--endregion

--region #MAKEBULLETIN CALL

function formatDescription()
    return "To any independent captains out there, this is captain Varlance with the mercenary group Frostbite Company. Our fleet repelled a fierce pirate attack on a local faction, but a number of their damaged ships managed to retreat before we could finish them off. I'm going after them, but I'd like some backup - the fact of the matter is that we don't know how well equipped they are and most of my group's ships are in need of repair. Help me hunt down the remnants of thie pirate fleet. I'll make sure you're compensated for your work."
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")

    local target = {}
    --GET TARGET HERE:
    local x, y = Sector():getCoordinates()
    target.x, target.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, false)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    reward = ESCCUtil.clampToNearest(600000 * Balancing.GetSectorRewardFactor(x, y), 5000, "Up") --SET REWARD HERE

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = mission.data.icon,
        description = formatDescription(),
        difficulty = "Medium",
        reward = "¢${reward}",
        script = "missions/horizon/horizonstory1.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "We've tracked the fleet to \\s(%1%:%2%). Meet up with me there and we'll destroy them.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/horizon/horizonstory1.lua") 
               or player:getValue("_horizonkeepers_story_stage") > 1 then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept this mission again.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = target,
            reward = {credits = reward, paymentMessage = "Earned %1% credits for destroying the pirate fleet."}
        }},
    }

    return bulletin
end

--endregion