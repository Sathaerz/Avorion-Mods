--[[
    Destroy Pirate Stronghold
    NOTES:
        - Generic version of Side Mission 5 from LLTE
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("randomext")
include ("goods")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")

local SectorSpecifics = include ("sectorspecifics")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncFactionShipGenerator = include("asyncshipgenerator")
local Placer = include ("placer")
local ShipUtility = include("shiputility")
local SpawnUtility = include ("spawnutility")
local EventUT = include("eventutility")

mission._Debug = 0
mission._Name = "Rescue Slaves"

--region #INIT

--Standard mission data.
mission.data.autoTrackMission = true

mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Go to sector (${x}:${y})", bulletPoint = true, fulfilled = false },
    { text = "Find the slaves in local cargo ships. Be careful about which ships you actively scan!", bulletPoint = true, fulfilled = false, visible = false },
    { text = "Bring the slaves back to the ${giverTitle} ${name} in (${x}:${y})", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 60 * 60 --Player has 60 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "Thank you so much for bringing back our families. We are very, very thankful for your help."
mission.data.failMessage = "We lost track of our families and friends. Who knows where they are now..."

--Constants. No need to have it in init
mission.data.custom.amountSlaves = 10
mission.data.custom.spawnedDangerTenThreat = false

local RescueSlaves_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)

            local _X, _Y = _Data_in.location.x, _Data_in.location.y --get slaves from here.
            local _rX, _rY = _Sector:getCoordinates() --return here w/ slaves.

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .transportNumber
                .firstTransport
                .secondTransport
                .thirdTransport
                .fourthTransport
                .fifthTransport
                .sixthTransport
                .seventhTransport
                .eightTransport
                .ninthTransport
                .returnToSector
                .spawnedDangerTenThreat
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.transportNumber = 1
            mission.data.custom.firstTransport = random():getInt(2, 3)
            mission.data.custom.secondTransport = random():getInt(4, 5)
            mission.data.custom.thirdTransport = random():getInt(6, 8)
            mission.data.custom.fourthTransport = random():getInt(9, 11)
            mission.data.custom.fifthTransport = random():getInt(12, 14)
            mission.data.custom.sixthTransport = random():getInt(15, 18)
            mission.data.custom.seventhTransport = random():getInt(19, 22)
            mission.data.custom.eigthTransport = random():getInt(23, 26)
            mission.data.custom.ninthTransport = random():getInt(27, 30)
            
            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = { x = _X, y = _Y }
            mission.data.description[3].arguments = { x = _X, y = _Y }
            mission.data.description[5].arguments = { giverTitle = _Giver.translatedTitle, name = _Giver.name, x = _rX, y = _rY }

            --Run standard initialization
            RescueSlaves_init(_Data_in)
        else
            --Restoring
            RescueSlaves_init()
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
mission.globalPhase.onAbandon = function()
    failAndPunish() --We don't want to clean up the sector since it's a regular on-grid generated sector, but the player doesn't get to abandon this mission for free.
end

mission.globalPhase.updateServer = function(_TimeStep)
    --Get the player's current ship and unsteal all freed slaves in it.
    local _Player = Player()

    if _Player.craft then
        local _PlayerShip = Entity(_Player.craft.id)
        for _Good, _Amount in pairs(_PlayerShip:getCargos()) do
            if (string.find(_Good.name, "Rescued") or string.find(_Good.name, "Rescued")) and _Good.stolen then
                local _Unstolen = copy(_Good)
                _Unstolen.stolen = false
                _PlayerShip:removeCargo(_Good, _Amount)
                _PlayerShip:addCargo(_Unstolen, _Amount)
            end
        end
    end
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true
end

mission.phases[1].updateTargetLocationServer = function(_TimeStep)
    local _MethodName = "Phase 1 Update Target Location Server"

    local _Player = Player()
    local _Sector = Sector()

    if _Player.craft then
        local _PlayerShip = Entity(_Player.craft.id)
        local _MoveToNextPhase = false
    
        --Check to see if we can go to the next phase.
        local _RescuedSlaveAmount = _PlayerShip:getCargoAmount(RescuedSlavesGood())
        --mission.Log(_MethodName, "Player has " .. tostring(_RescuedSlaveAmount) .. " freed slaves.")
        if _RescuedSlaveAmount >= mission.data.custom.amountSlaves then
            _MoveToNextPhase = true
        end
    
        if _MoveToNextPhase then
            nextPhase()
        end
    end

    --Get all ship type entities in the sector. If "is_civil" is true, add the control script.
    local _CivilShips = { _Sector:getEntitiesByScriptValue("is_civil")}
    for _, _Ship in pairs(_CivilShips) do
        if _Ship.type == EntityType.Ship and not _Ship.playerOrAllianceOwned then
            _Ship:setValue("rescueslaves_mission_player", Player().index)
            _Ship:addScriptOnce("entity/rescueslavescontrol.lua")
        end
    end

    --Check to see if we need to highlight any slaves.
    invokeClientFunction(Player(), "highlightRescuedSlaves")
end

--region #PHASE 1 TIMERS

if onServer() then

--Every 5 minutes, spawn a threat. Threats are randomly chosen between a subspace torpedo strike, bounty hunter wave, and hijacked faction ships.
mission.phases[1].timers[1] = {
    time = 300, 
    callback = function() 
        local _MethodName = "Phase 1 Timer 1 Callback"
        mission.Log(_MethodName, "Running threat timer.")
        if getOnLocation(nil) then
            spawnThreat()
        end
    end,
    repeating = true
}

--Spawns a one-time threat in at 4 minutes. Does not repeat the spawn - done to prevent the sector from getting clogged w/ debris.
mission.phases[1].timers[2] = {
    time = 240,
    callback = function()
        local _MethodName = "Phase 1 Timer 2 Callback"
        mission.Log(_MethodName, "Running danger 10 threat timer.")
        if mission.data.custom.dangerLevel == 10 and not mission.data.custom.spawnedDangerTenThreat and getOnLocation(nil) then
            mission.Log(_MethodName, "Danger 10 - spawning threat.")
            spawnThreat()
            mission.data.custom.spawnedDangerTenThreat = true
        end
    end,
    repeating = true
}

mission.phases[1].timers[3] = {
    time = 360,
    callback = function()
        if getOnLocation(nil) then
            spawnLocalTransport()
        end
    end,
    repeating = true
}

mission.phases[1].timers[4] = {
    time = 540,
    callback = function()
        --Spawn extra transports @ danger level 10 - player needs to be more speedy about checking for slaves.
        if mission.data.custom.dangerLevel == 10 and getOnLocation(nil) then
            spawnLocalTransport()
        end
    end,
    repeating = true
}

end

--Whoa. An onClient timer. Need to highlight the first civil ship that jumps in and show a hint.
mission.phases[1].timers[5] = {
    time = 10,
    callback = function()
        if onClient() and getOnLocation(nil) then
            if not Player():getValue("_rescueslaves_tutorial_shown") then
                local _CivilShips = { Sector():getEntitiesByScriptValue("is_civil") }

                if #_CivilShips > 0 then
                    Hud():displayHint("You can fly close to a ship to determine what cargo it is carrying before actively scanning it.\nThis passive scan range can be increased by using a Scanner Booster upgrade.", _CivilShips[1])
                    invokeServerFunction("playerDoneTutorial")
                end
            end
        end
    end,
    repeating = true
}

--endregion

--In phase 2, we bring them back to the original station.
mission.phases[2] = {}
mission.phases[2].onBegin = function()
    mission.data.description[4].fulfilled = true
    mission.data.description[5].visible = true
    
    --slaves are free - no need for a timer.
    mission.data.timeLimitInDescription = false
    mission.data.timeLimit = nil

    --giver is initialized by this point so we can use it here. Can't use it in the init func b/c ours runs before boxel's
    mission.data.location = mission.data.giver.coordinates
end

mission.phases[2].onBeginServer = function()
    --Get rid of the control script from all present ships - we don't need it anymore.
    local _Ships = {Sector():getEntitiesByScriptValue("rescueslaves_mission_player")}
    for _, _Ship in pairs(_Ships) do
        _Ship:removeScript("entity/rescueslavescontrol.lua")
    end
end

local onBroughtHomeEnd = makeDialogServerCallback("onBroughtHomeEn", 2, function()
    -- we're happy and take them
    local ship = Player().craft
    -- if player doesn't bring back at least 10 slaves (somehow), the reward needs to be adjusted to the actual amount of freed slaves
    -- regardless, we remove all freed slaves from the cargo hold, even if the player gets more than 10.
    local slaveAmount = ship:getCargoAmount(RescuedSlavesGood())
    local repNumerator = slaveAmount
    if repNumerator > mission.data.custom.amountSlaves then
        repNumerator = mission.data.custom.amountSlaves
    end

    mission.data.reward.relations = mission.data.reward.relations * (repNumerator / mission.data.custom.amountSlaves)
    ship:removeCargo(RescuedSlavesGood(), slaveAmount)
    finishAndReward()
end)

mission.phases[2].onTargetLocationArrivalConfirmed = function()
    -- first check if player actually has the slaves
    if onServer() then
        local player = Player()
        local ship = player.craft
        if not ship then return end

        local playerHas = ship:getCargoAmount(RescuedSlavesGood())
        local station = Entity(mission.data.giver.id)
        if station and playerHas > 0 then
            invokeClientFunction(Player(), "showBroughtHomeDialog", station.id, playerHas, false)
        end
    end
end

mission.phases[2].onRestore = function()
    mission.phases[2].onTargetLocationArrivalConfirmed()
end

--endregion

--region #SERVER CALLS

function RescuedSlavesGood()
    local good = TradingGood("Rescued Slave"%_T, plural_t("Rescued Slave", "Rescued Slaves", 1), "A now freed life form that was forced to work for almost no food."%_T, "data/textures/icons/slave.png", 0, 1)
    good.tags = {mission_relevant = true}
    return good
end

--Spawn threat
function spawnThreat()
    local _xFuncs = {
        { _func = function() spawnTorpedoStrike() end },
        { _func = function() spawnBountyHunterAttack() end },
        { _func = function() spawnHijackedFactionShip() end }
    }
    shuffle(random(), _xFuncs)
    _xFuncs[1]._func()
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

function onTorpStrikePirateSpawned(_Generated)
    local _dmgFactor = 2
    local _duraFactor = 2
    if mission.data.custom.dangerLevel >= 6 then
        _dmgFactor = 4
    end
    if mission.data.custom.dangerLevel == 10 then
        _dmgFactor = 8
        _duraFactor = 4
    end

    for _, _Ship in pairs(_Generated) do
        local _Dura = Durability(_Ship)
        if _Dura then
            _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 1) * 2
        end

        local _TorpSlamValues = {
            _ROF = 2,
            _DurabilityFactor = _duraFactor,
            _TimeToActive = 0,
            _DamageFactor = _dmgFactor,
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

--Bounty hunters
function spawnBountyHunterAttack()
    local _MethodName = "Spawn Bounty Hunter Attack"

    mission.Log(_MethodName, "Spawning bounty hunters")

    local _Rgen = ESCCUtil.getRand()
    --Headhunters.
    local _HeadHunterFaction = getHeadHunterFaction()

    local _HunterGenerator = AsyncFactionShipGenerator(nil, onHuntersFinished)
    _HunterGenerator:startBatch()
    
    local x, y = Sector():getCoordinates()
    local _Volume = Balancing_GetSectorShipVolume(x, y)
    local _HunterPositions = _HunterGenerator:getStandardPositions(250, 4)
    local _RandomExtraVolume = _Rgen:getInt(1, 3) - 1

    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[1], _Volume * 4)
    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[2], _Volume * 4)
    _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[3], _Volume * (4 + _RandomExtraVolume))
    if mission.data.custom.dangerLevel == 10 then
        _HunterGenerator:createPersecutorShip(_HeadHunterFaction, _HunterPositions[4], _Volume * (4 + _RandomExtraVolume))
    end

    _HunterGenerator:endBatch()
end

function getHeadHunterFaction()
    local _X, _Y = Sector():getCoordinates()

    return EventUT.getHeadhunterFaction(_X, _Y)
end

function onHuntersFinished(_Generated)
    local _MethodName = "On Hunters Finished"
    mission.Log(_MethodName, "Running.")
    local _Player = Player()

    for _, _Ship in pairs(_Generated) do
        local _AI = ShipAI(_Ship)
        _AI:setAggressive()
        _AI:registerEnemyFaction(_Player.index)
        _AI:registerFriendFaction(mission.data.giver.factionIndex)
        if _Player.allianceIndex then
            _AI:registerEnemyFaction(_Player.allianceIndex)
        end

        local x, y = Sector():getCoordinates()
        local _pLevel = Balancing_GetPirateLevel(x, y)
        local _pFaction = Galaxy():getPirateFaction(_pLevel)

        _Ship:setValue("secret_contractor", _pFaction.index)
        MissionUT.deleteOnPlayersLeft(_Ship)
        _Ship:setValue("is_persecutor", true)

        mission.Log(_MethodName, "Ship title is " .. _Ship.title)

        if string.match(_Ship.title, "Persecutor") then
            _Ship.title = "Bounty Hunter"%_T
        end
    end

    Placer.resolveIntersections(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)

    local headhunterMessages =
    {
        "This is ${player}! That's the one our client wants!"%_T,
        "Found you, ${player}. Let's shoot them down and get our money. Make it quick."%_T,
        "There they are. Alright, ${player} it's nothing personal, it's just a job."%_T,
        "Did you think they'd make this easy for you?",
        "Time to die, ${player}."
    }

    _Player:sendChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(headhunterMessages) % {player = _Player.name})
end

--Hijacked ships
function spawnHijackedFactionShip()
    local _MethodName = "Spawn Hijacked Faction Ship"

    mission.Log(_MethodName, "Spawning hijacked ships")

    local _Faction = Faction(mission.data.giver.factionIndex)

    local _FactionWave = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 2, "High", true)
    local _FactionGenerator = AsyncShipGenerator(nil, onHijackedShipsFinished)

    _FactionGenerator:startBatch()

    for _, _Ship in pairs(_FactionWave) do
        _FactionGenerator:createDefenderByName(_Faction, _FactionGenerator:getGenericPosition(), _Ship)
    end

    _FactionGenerator:endBatch()
end

function onHijackedShipsFinished(_Generated)
    for _, _Ship in pairs(_Generated) do
        _Ship:addScriptOnce("entity/ai/hijackedfactionship.lua")
        --Do 25% more damage on danger 10.
        if mission.data.custom.dangerLevel == 10 then
            _Ship.damageMultiplier = (_Ship.damageMultiplier or 1) * 1.25
        end
    end

    Placer.resolveIntersections(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)
end

--Transports
function spawnLocalTransport()
    local _MethodName = "Spawn Local Transport"

    mission.Log(_MethodName, "Running.")

    -- this is the position where the trader spawns
    local dir = random():getDirection()
    local pos = dir * 1500

    -- this is the position where the trader will jump into hyperspace
    local destination = -pos + vec3(math.random(), math.random(), math.random()) * 1000
    destination = normalize(destination) * 1500

    --use this for onfinished.
    local onTransportFinished = function(ships)
        local _MethodName = "On Transport Finished"
        local _Transport = ships[1]
        local _AddSlaves = false
        local _tportNo = mission.data.custom.transportNumber

        mission.Log(_MethodName, "Transport " .. tostring(_tportNo) .. " spawned. Adding cargo and setting destination.")
        if _tportNo == mission.data.custom.firstTransport then
            mission.Log(_MethodName, "First slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.secondTransport then
            mission.Log(_MethodName, "Second slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.thirdTransport then
            mission.Log(_MethodName, "Third slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.fourthTransport then
            mission.Log(_MethodName, "Fourth slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.fifthTransport then
            mission.Log(_MethodName, "Fifth slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.sixthTransport then
            mission.Log(_MethodName, "Sixth slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.seventhTransport then
            mission.Log(_MethodName, "Seventh slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.eigthTransport then
            mission.Log(_MethodName, "Eigth slave transport spawned")
            _AddSlaves = true
        end
        if _tportNo == mission.data.custom.ninthTransport then
            mission.Log(_MethodName, "Ninth (and final) slave transport spawned")
            _AddSlaves = true
        end

        local _SlavesInHold = 12 --Almost always 1 ship.
        if mission.data.custom.dangerLevel >= 6 then
            _SlavesInHold = 10 --At least 1 ship - possibly 2.
        end
        if mission.data.custom.dangerLevel == 10 then
            _SlavesInHold = 5 --At least 2 ships - possibly 3.
        end

        if _AddSlaves then
            _Transport:addCargo(goods["Slave"]:good(), _SlavesInHold)
            _Transport:setValue("rescueslaves_has_slaves", true)
            _Transport:setValue("rescueslaves_slave_qty", _SlavesInHold)
            _Transport:setValue("rescueslaves_mission_player", Player().index)
        else
            ShipUtility.addCargoToCraft(_Transport)
        end
        
        _Transport:addScriptOnce("ai/passsector.lua", destination)
        _Transport:setValue("passing_ship", true)

        Placer.resolveIntersections(ships)

        mission.data.custom.transportNumber = _tportNo + 1
    end

    local _Faction = Faction(mission.data.giver.factionIndex)

    local generator = AsyncFactionShipGenerator(nil, onTransportFinished)
    generator:startBatch()

    pos = pos + dir * 200
    local matrix = MatrixLookUpPosition(-dir, vec3(0, 1, 0), pos)

    generator:createFreighterShip(_Faction, matrix)

    generator:endBatch()
end

--other
function playerDoneTutorial()
    Player():setValue("_rescueslaves_tutorial_shown", true)
end
callable(nil, "playerDoneTutorial")

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

function showBroughtHomeDialog(stationId, amount, closeable)
    local ui = ScriptUI(stationId)
    ui:interactShowDialog(broughtHomeDialog(amount), closeable)
end

function broughtHomeDialog(amount)
    amount = amount or 0

    local xrandom = random() --small optimization to avoid having to init this like 5 times.
    local dialog = {}
    local d1_End = {}
    local d2_Reimburse = {}

    if amount < mission.data.custom.amountSlaves then
        --In theory shouldn't be possible. In practice, someone will figure out a way to do this.
        dialog.text = "Ah. That's not... everyone. Thank you for those you brought back... we'll have to prepare mourning ceremonies."
        dialog.onEnd = onBroughtHomeEnd
    else
        local _initialGreetingLines = {
            "Thank you so much for getting our people home! Everything went smoothly, I hope?",
            "Oh thank god. You maanged to bring them home safe. Thank you- thank you so much!"
        }
        shuffle(xrandom, _initialGreetingLines)
    
        dialog.text = _initialGreetingLines[1]
        dialog.answers = {
            {answer = "Don't mention it. Seriously don't.", followUp = d1_End},
            {answer = "It was my pleasure.", followUp = d1_End},
            {answer = "Sure, sure. I did have to pay quite a few credits to bring them back, though...", followUp = d2_Reimburse}
        }
        
        local _thankYouLines = {
            "We'll never forget this - and please be safe, yourself. Goodness knows we could use more folks like you out here.",
            "Thank you so much, Captain. The galaxy could use more people like you."
        }
        shuffle(xrandom, _thankYouLines)
    
        d1_End.text = _thankYouLines[1]
        d1_End.onEnd = onBroughtHomeEnd
    
        local _noMoneyLines = {
            "You had to pay for them? I'm so sorry to hear that, but we can't pay you back. If we had that kind of money lying around, we would've bought them immediately.",
            "...ah. We don't... We don't have any money- if we did we would have just bought them back ourselves wouldn't we? I'm, sorry..."
        }
        shuffle(xrandom, _noMoneyLines)
        
        d2_Reimburse.text = _noMoneyLines[1]
        d2_Reimburse.onEnd = onBroughtHomeEnd
    end

    return dialog
end

function highlightRescuedSlaves()
    local _MethodName = "Highlight Rescued Slaves"

    for _, entity in pairs({Sector():getEntitiesByComponent(ComponentType.CargoLoot)}) do
        local loot = CargoLoot(entity)
        local _highlightsent = entity:getValue("rescueslaves_highlightsent")

        if loot:matches("Rescued Slave") and not _highlightsent then
            entity:setValue("rescueslaves_highlightsent", true) --see if this even works.
            Hud():displayHint("Pick up these Rescued Slaves! Make sure to turn on 'Pick up stolen goods'!", entity)
        end
    end
end

--endregion

--region #MAKEBULLETIN CALL

function formatDescription(_Station)
    local _Descriptions = {
        "Traffickers kidnapped some of our people. They were just normal males, females and children. We know what sector they're going to get shipped through, but the traffickers are deeply embedded in the local faction. There's no way that we'll be able to find them. If you help, you'll have our endless gratitude.",
        "Some of our people have been kidnapped! We know what sector they're going to be trafficked through, but we don't have the resources to investigate it ourselves. Please help us! If we're not able to find them before they're transferred, they'll vanish and we won't be able to find them again!",
        "Our families have been kidnapped! We don't have any particular sets of skills... or long careers... but perhaps you do. Perhaps you can be a nightmare to people like them. Please, captain. Help us - rescue our families and bring them back. We know where they've been taken, but we lack the means to find them ourselves.",
        "If you're seeing this then please - we need your help. Last night our station was attacked and many of our people - women and children among them - were kidnapped and taken to be sold. We know where they are, but the attack has left us too weak to chase after them. We'll make it worth your while, just please help us!!!"
    }
    shuffle(random(), _Descriptions)

    return _Descriptions[1]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Running.")
    --We need:
    --1 - a regular or offgrid content sector
    --2 - a sector that is owned by the current faction.
    --3 - a sector with at least 4-5 stations.
    --This is a bit spicy - we need to initialize a lot of stuff in order to do this. Really wish there was an easier way to do this. Any takers, Boxelware?
    local _Sector = Sector()
    local seed = Server().seed
    local specs = SectorSpecifics()

    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = _Sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    --Then we try to find a sector matching points 1, 2, and 3 above.
    local _ExcludedSectors = {}
    for _ = 1, 15 do
        --Don't try too many times for this.
        target.x, target.y = MissionUT.getSectorWithStations(x, y, 3, 22, true, nil, nil, nil, insideBarrier, _ExcludedSectors)
        --Careful about turning on too many of these logs. They're somewhat obnoxious.
        --mission.Log(_MethodName, "Checking " .. tostring(target.x) .. " : " .. tostring(target.y))

        local _, _, _, _, _, specsFactionIndex = specs:determineContent(target.x, target.y, seed)

        if specsFactionIndex and specsFactionIndex == _Station.factionIndex then
            --mission.Log(_MethodName, "specs faction index " .. tostring(specsFactionIndex) .. " matches station faction index " .. tostring(_Station.factionIndex))
            
            specs:initialize(target.x, target.y, seed)
            if specs.generationTemplate then
                --mission.Log(_MethodName, "Checking generation template")
                local contents = specs.generationTemplate.contents(target.x, target.y)
                if contents and contents["stations"] and contents["stations"] > 3 then
                    --mission.Log(_MethodName, "Found target w/ at least 3 stations. Breaking and continuing.")
                    break
                end
            end
        end

        --We should break out of the loop if a target is found, so that means if we're still here we haven't found a suitable target.
        --Add it to the blacklist so we don't keep trying the same sector over and over again and keep going.
        table.insert(_ExcludedSectors, { x = target.x, y = target.y })
        target = {}
    end

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)

    local _Difficulty = "Difficult"
    if _DangerLevel == 10 then
        _Difficulty = "Extreme"
    end

    local _Description = formatDescription(_Station)

    reward = 0 --SET REWARD HERE
    baseRep = 16000 --We actually get more than this due to potentially killing some pirates and stuff.
    reputation = baseRep
    if _DangerLevel == 10 then
       reputation = reputation + 2000 --Add 2k more at danger 10.
    end

    _MissionReward = { credits = reward, relations = reputation }

    local distToCenter = math.sqrt(x * x + y * y)
    local _MatlMin = 7000
    local _MatlMax = 8000
    if distToCenter > 400 then
        --Always give about 50% more than free slaves.
        _MatlMin = 10000
        _MatlMax = 12000
    elseif distToCenter < 400 and distToCenter > 300 then
        _MatlMin = 20000
        _MatlMax = 24000
    else
        _MatlMin = 40000
        _MatlMax = 48000
    end
    
    mission.Log(_MethodName, "matlmin is ${MIN} and matlmax is ${MAX}" % { MIN = _MatlMin, MAX = _MatlMax }) 

    local materialAmount = round(random():getInt(_MatlMin, _MatlMax) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, _MissionReward, materialAmount)

    _MissionPunishment = { relations = baseRep }

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}"%_T,
        script = "missions/rescueslaves.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Please go to sector \\s(%1%:%2%) and rescue our family members."%_T,
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
            reward = _MissionReward,
            punishment = _MissionPunishment,
            dangerLevel = _DangerLevel,
            initialDesc = _Description
        }},
    }

    return bulletin
end

--endregion