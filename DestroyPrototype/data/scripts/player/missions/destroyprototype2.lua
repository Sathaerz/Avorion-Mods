--[[
    NAME HERE
    NOTES:
        - Man, it's been a long, long time since I made this mission. Feels like an eternity ago.
        - But now, I'm much better at this and I have much better tools at my disposal. Time to make this a fight for the ages. :3
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - None. Take it from a mission board.
    ROUGH OUTLINE
        - Go to location. Destroy Battleship. Ez.
    DANGER LEVEL
        1+  - [These conditions are present regardless of danger level]
            - A group of 4-6 ships will spawn with the prototype, chosen from the standard threat level.
            - Prototype Scale will be 40.
            - Prototype Turret / Damage factor will be 3.
            - Prototype Loot = 4 guaranteed turrets.
            - Prototype will get 1 randomly chosen defensive script (adaptive / iron curtain / phasemode)
        6-7 - [These conditions are present at danger level 6-7 and above]
            - Prototype Scale will be 50.
            - Prototype Turret Factor will be 4
            - The prototype will get 1 randomly chosen offensive script (overdrive / frenzy / avenger)
            - +1 initial defender
        8-9 - [These conditions are present at danger level 8-9 and above]
            - Prototype Durability will increase by 25%
            - Prototype Damage will increase by 20%
            - Prototype Turret Factor will be 5
            - Prototype has Blocker.
            - Whenever the prototype drops to 50% health, or the initial bandits are destroyed, a group of 6 reinforcement ships will spawn in from the chosen table.
            - The prototype will get a 2nd randomly chosen offensive and defensive script.
            - +1 initial defender
        9 - [These conditions are present at danger level 9 and above]
            - The prototype gets allybooster
        10 - [These conditions are present at danger level 10]
            - Prototype Durability will increase by 25% (50% total)
            - Prototype Damage will increase by 20% (40% total)
            - Prototype Turret Factor will be 6
            - Prototype Damage Factor will be 4
            - Prototype Loot = 6 guaranteed turrets + 3 guaranteed systems.
            - Prototype has Megablocker.
            - All pirate ships are chosen from the High threat table now, instead of the standard threat table.
            - The prototype will get either the torpedoslammer, lasersniper, or siege gun script, chosen at random.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")

ESCCUtil = include("esccutil")

local Balancing = include ("galaxy")
local PrototypeGenerator = include("destroyprotogenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local PirateGenerator = include("pirategenerator")
local SpawnUtility = include ("spawnutility")

mission._Debug = 1
mission._Name = "Destroy Prototype Battleship"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "..." }, --Placeholder
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy the Prototype", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.timeLimit = 60 * 60 --Player has 60 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.

mission.data.accomplishMessage = "..." --Placeholder, varies by faction.
mission.data.failMessage = "..." --Placeholder, varies by faction.

local DestroyPrototype_init = initialize
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
                .spawnedSecondWave
                .friendlyFaction
                .battleshipName
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.spawnedSecondWave = false
            mission.data.custom.friendlyFaction = _Giver.factionIndex
            mission.data.custom.battleshipName = ""

            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.description
            mission.data.description[2].arguments = {x = _X, y = _Y }

            mission.data.icon = _Data_in.iconIn
            mission.data.accomplishMessage = _Data_in.winMsg
            mission.data.failMessage = _Data_in.loseMsg

            _Data_in.reward.paymentMessage = "Earned %1% for destroying the prototype."

            --Run standard initialization
            DestroyPrototype_init(_Data_in)
        else
            --Restoring
            DestroyPrototype_init()
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
mission.globalPhase.timers = {}

--region #GLOBALPHASE TIMERS

if onServer() then

mission.globalPhase.timers[1] = {
    time = 10,
    callback = function()
        local _MethodName = "Global Phase Timer"
        mission.Log(_MethodName, "Beginning.")

        local _X, _Y = Sector():getCoordinates()
        local _onLocation = false
        if _X == mission.data.location.x and _Y == mission.data.location.y then
            _onLocation = true
        end

        if _onLocation and mission.data.custom.dangerLevel >= 8 and not mission.data.custom.spawnedSecondWave then
            local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}

            if #_Pirates == 1 then
                mission.data.custom.spawnedSecondWave = true
                spawnSecondWave()
            end
        end
    end,
    repeating = true
}
    
end

--endregion

mission.phases[1] = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].noPlayerEventsTargetSector = true
mission.phases[1].noLocalPlayerEventsTargetSector = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    spawnPrototype()
    spawnInitialDefenders()
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _Prototypes = {Sector():getEntitiesByScriptValue("is_prototype")}

    local _Taunts = {
        "You'll never see this coming!",
        "It seems we've been found out! Take them down now!",
        "I guess this is it. At least we'll be taking you with us.",
        "Witness us!",
        "Never thought we'd die running from a do-gooder.",
        "To infinity! And beyond!"
    }

    Sector():broadcastChatMessage(_Prototypes[1], ChatMessageType.Chatter, randomEntry(_Taunts))
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].noPlayerEventsTargetSector = true
mission.phases[2].noLocalPlayerEventsTargetSector = true
mission.phases[2].sectorCallbacks = {}

--region #PHASE 2 SECTOR CALLBACKS

if onServer() then

mission.phases[2].sectorCallbacks[1] = {
    name = "onDamaged",
    func = function(_Entityidx, _Amount, _Inflictor, _DmgSrc, _DmgType)
        if mission.data.custom.dangerLevel >= 8 and not mission.data.custom.spawnedSecondWave then
            local _DamagedEntity = Entity(_Entityidx)
            if _DamagedEntity:getValue("is_prototype") then
                local _Hull = _DamagedEntity.durability
                local _HullThreshold = _DamagedEntity.maxDurability / 2
                if _Hull < _HullThreshold then
                    mission.data.custom.spawnedSecondWave = true
                    spawnSecondWave()
                end
            end
        end
    end
}

end

--endregion

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _DestroyedEntity = Entity(_ID)
    if _DestroyedEntity:getValue("is_prototype") then
        local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}

        if #_Pirates > 0 then
            for _, _Pirate in pairs(_Pirates) do
                if not _Pirate:getValue("is_prototype") then
                    local _Lines = {
                        "No!!! NO!!!",
                        "Damn you! We'll remember this!",
                        "We'll get you next time!",
                        "We'll be watching, and we'll be waiting. When you least expect it... that's when we'll strike.",
                        "We'll see you sucking vacuum for this!",
                        "The day is yours, but revenge will be ours!"
                    }
        
                    Sector():broadcastChatMessage(_Pirate, ChatMessageType.Chatter, randomEntry(_Lines))
    
                    break
                end
            end

            for _, _Pirate in pairs(_Pirates) do
                if not _Pirate:getValue("is_prototype") then
                    _Pirate:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))
                end
            end
        end

        finishAndReward()
    end
end

mission.phases[2].onAbandon = function()
    failAndPunish()
end

--endregion

--region #SERVER CALLS

function spawnPrototype()
    local _MethodName = "Spawn Prototype"
    mission.Log(_MethodName, "Beginning.")

    local _Rgen = ESCCUtil:getRand()

    PirateGenerator.pirateLevel = Balancing_GetPirateLevel(mission.data.location.x, mission.data.location.y)
    local _Scale = 40
    local _DuraFactor = 1.5
    local _DamageFactor = 1.0
    if mission.data.custom.dangerLevel >= 6 then
        _Scale = 50
    end
    if mission.data.custom.dangerLevel >= 8 then
        _DuraFactor = 1.75
        _DamageFactor = 1.2
    end
    if mission.data.custom.dangerLevel == 10 then
        _DuraFactor = 2
        _DamageFactor = 1.4
    end

    local _Danger = mission.data.custom.dangerLevel
    local _Faction = Faction(mission.data.custom.friendlyFaction)
    local _PirateFaction = PirateGenerator:getPirateFaction()
    local _BattleShip =  PrototypeGenerator.create(PirateGenerator.getGenericPosition(), _Faction, _PirateFaction, _Danger, _Scale)

    mission.data.custom.battleshipName = _BattleShip.name
    
    --Add some scripts.
    local _DefensiveScriptsct = 1
    local _OffensiveScriptsct = 0
    local _SuperWeaponScriptsct = 0
    local _AddBlocker = false
    local _BlockerToAdd = ""

    if _Danger >= 6 then
        _OffensiveScriptsct = _OffensiveScriptsct + 1
    end
    if _Danger >= 8 then
        _DefensiveScriptsct = _DefensiveScriptsct + 1
        _OffensiveScriptsct = _OffensiveScriptsct + 1
        _AddBlocker = true
        _BlockerToAdd = "blocker.lua"
    end
    if _Danger >= 9 then
        _BattleShip:addScriptOnce("allybooster.lua")
    end
    if _Danger == 10 then
        _DefensiveScriptsct = _DefensiveScriptsct + 1 --Just add them all
        _OffensiveScriptsct = _OffensiveScriptsct + 1
        _BlockerToAdd = "megablocker.lua"
    end

    if _AddBlocker then
        mission.Log(_MethodName, "Adding blocker script.")
        _BattleShip:addScriptOnce(_BlockerToAdd)
    end

    local _DefensiveScripts = {
        "adaptivedefense.lua",
        "phasemode.lua",
        "ironcurtain.lua"
    }
    local _OffensiveScripts = {
        "overdrive.lua",
        "avenger.lua",
        "frenzy.lua"
    }

    shuffle(random(), _DefensiveScripts)
    shuffle(random(), _OffensiveScripts)

    if _DefensiveScriptsct > 0 then
        for idx = 1, _DefensiveScriptsct do
            local _Script = _DefensiveScripts[idx]
            mission.Log(_MethodName, "Adding defensive script : " .. tostring(_Script))
            _BattleShip:addScriptOnce(_Script)
        end
    end

    if _OffensiveScriptsct > 0 then
        for idx = 1, _OffensiveScriptsct do
            local _Script = _OffensiveScripts[idx]
            mission.Log(_MethodName, "Adding offensive script : " .. tostring(_Script))
            _BattleShip:addScriptOnce(_Script)
        end
    end

    if _Danger == 10 then
        local _X, _Y = Sector():getCoordinates()
        local _Type = _Rgen:getInt(1, 3)
        if _Type == 1 then
            mission.Log(_MethodName, "Torpedo type chosen.")
            --Torpedo
            local _TorpValues = {
                _ROF = 4,
                _DurabilityFactor = 2,
                _TimeToActive = 30,
                _UseEntityDamageMult = true
            }
            _BattleShip:addScriptOnce("torpedoslammer.lua", _TorpValues)
        elseif _Type == 2 then
            mission.Log(_MethodName, "Siege Gun type chosen.")
            --Siege Gun
            local _SiegeGunValues = {
                _Velocity = 150,
                _ShotCycle = 30,
                _ShotCycleSupply = 0,
                _ShotCycleTimer = 0,
                _UseSupply = false,
                _FragileShots = false,
                _TargetPriority = 1,
                _BaseDamagePerShot = Balancing_GetSectorWeaponDPS(_X, _Y) * 2000,
                _TimeUntilActive = 30,
                _UseEntityDamageMult = true
            }
            _BattleShip:addScriptOnce("stationsiegegun.lua", _SiegeGunValues)
        elseif _Type == 3 then
            mission.Log(_MethodName, "Laser Sniper type chosen.")
            --Laser sniper
            local _LaserSniperValues = {
                _DamagePerFrame = Balancing_GetSectorWeaponDPS(_X, _Y) * 1000,
                _TimeToActive = 30,
                _UseEntityDamageMult = true
            }
            _BattleShip:addScriptOnce("lasersniper.lua", _LaserSniperValues)
        end
    end

    --Add durability.
    local durability = Durability(_BattleShip)
    if durability then 
        local _Factor = (durability.maxDurabilityFactor or 1) * _DuraFactor
        mission.Log(_MethodName, "Setting durability factor of the prototype to : " .. tostring(_Factor))
        durability.maxDurabilityFactor = _Factor
    end

    --Add damage.
    local _FinalDamageFactor = (_BattleShip.damageMultiplier or 1) * _DamageFactor
    mission.Log(_MethodName, "Setting final damage factor to : " .. tostring(_FinalDamageFactor))
    _BattleShip.damageMultiplier = _FinalDamageFactor

    --Attach the boss script.
    if mission.data.custom.dangerLevel == 10 then
        _BattleShip:addScriptOnce("esccbossdespair.lua")
    else
        _BattleShip:addScriptOnce("esccbossblades.lua")
    end
end

function spawnInitialDefenders()
    local _MethodName = "Spawn Initial Defenders"
    mission.Log(_MethodName, "Beginning.")

    local _Table = "Standard"
    if mission.data.custom.dangerLevel == 10 then
        _Table = "High"
    end

    local _Rgen = ESCCUtil.getRand()

    local _LowBound = 4
    local _HighBound = 6
    local _Piratect = _Rgen:getInt(_LowBound, _HighBound)
    if mission.data.custom.dangerLevel >= 6 then
        _Piratect = _Piratect + 1
    end
    if mission.data.custom.dangerLevel >= 8 then
        _Piratect = _Piratect + 1
    end

    mission.Log(_MethodName, "Spawning table of " .. tostring(_Piratect) .. " " .. tostring(_Table) .. " pirates.")

    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _Piratect, _Table, false)
    local _CreatedPirateTable = {}

    PirateGenerator.pirateLevel = Balancing_GetPirateLevel(mission.data.location.x, mission.data.location.y)
    for _, _Pirate in pairs(_PirateTable) do
        table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
    end

    SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
end

function spawnSecondWave()
    local _MethodName = "Spawn Pirate Wave"
    mission.Log(_MethodName, "Beginning.")

    local _Table = "Standard"
    if mission.data.custom.dangerLevel == 10 then
        _Table = "High"
    end

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, _Table, false)

    local generator = AsyncPirateGenerator(nil, onSecondWaveFinished)
    generator.pirateLevel = Balancing_GetPirateLevel(mission.data.location.x, mission.data.location.y)

    generator:startBatch()

    local posCounter = 1
    local distance = 250 --_#DistAdj
    if mission.data.custom.dangerLevel == 10 then
        distance = 350
    end
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onSecondWaveFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)

    local _Name = mission.data.custom.battleshipName
    local _Taunts = {
        "Reinforcements on station! Stay strong, " .. _Name,
        "We'll tear you to pieces!",
        "If the " .. _Name .. " is destroyed, this is all for nothing! Protect it with your lives!",
        "All ships, weapons to full! Engage! Engage! Engage!",
        "Hang tight " .. _Name .. ", the cavalry is here!",
        "Mind if we cut in?"
    }

    Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(_Taunts))
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

--region #MAKEBULLETIN CALL

function formatWinMessage(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")
    local _MsgType = 1 --1 = Neutral / 2 = Aggressive / 3 = Peaceful

    if _Aggressive > 0.5 then
        _MsgType = 2
    elseif _Aggressive <= -0.5 then
        _MsgType = 3
    end

    local _Msgs = 
    { 
        "Thanks. Here's your reward, as promised.",
        "Thank you for taking care of that scum. We transferred the reward to your account.",
        "Thank you for your trouble. We transferred the reward to your account."
    }

    return _Msgs[_MsgType]
end

function formatLoseMessage(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")
    local _MsgType = 1 --1 = Neutral / 2 = Aggressive / 3 = Peaceful

    if _Aggressive > 0.5 then
        _MsgType = 2
    elseif _Aggressive <= -0.5 then
        _MsgType = 3
    end

    local _Msgs = {
        "You weren't able to destroy it? That's too bad. We'll find someone else to take care of it.",
        "We see that you weren't up for the task. Unfortunate, but unsurprising. We should have taken care of it ourselves.",
        "You weren't able to destroy it? This is bad... we were low on options to begin with..."
    }

    return _Msgs[_MsgType]
end

function formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local _DescriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        _DescriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        _DescriptionType = 3 --Peaceful.
    end

    local _Desc = {
        "We need your help. Our new battleship was hijacked by pirates and we can't afford to leave it in enemy hands, or else they'll be able to reverse-engineer it and use the experimental technology to enhance their own ships. We need you to destroy it. Don't worry - we'll reward you for doing so. We think the compensation is sufficient for the task.\n\nWe believe that is being escorted by additional pirate ships. Use caution on approach.\n\nIt seems that they didn't disable the ship's tracking beacon. It shows that the ship is currently in (${x}:${y}).",
        "Some scumbag pirates stole one of our new battleships! It was going to be the pride of our new fleet, but now it's as good as scrap metal! An example must be made. The loss of the materiel is regrettable, but those who would steal from us must be made to realize the consequences of their actions.\n\nIntel says that some of the bandits ran off with their prize. It doesn't matter. They'll pay with the rest of them.\n\nWe tracked it to (${x}:${y}). Destroy the ship, and kill all parties involved.",
        "We were developing a prototype self-defense system when it was captured by a gang of pirates! We regret that things have come to this, but the system must be destroyed before they have a chance to reverse-engineer the technology and enhance their ships. Or worse, sell it to our enemies. Unfortunately, our forces are insufficient for the task.\n\nSignals from the battleship's radar module show that it is being escorted. Use caution on approach.\n\nThe tracker on the stolen ship shows that it is located at (${x}:${y}). Please do what needs to be done."
    }

    return _Desc[_DescriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local target = {}
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getSector(x, y, 7, 20, false, false, false, false, insideBarrier)

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    --local _DangerLevel = 10
    local _DangerLevel = _Rgen:getInt(1, 10)

    local _IconIn = nil
    local _Difficulty = "Difficult"
    if _DangerLevel > 5 then
        _Difficulty = "Extreme"
    end
    if _DangerLevel == 10 then
        _IconIn = "data/textures/icons/hazard-sign.png"
        _Difficulty = "Anathema"
    end
    
    local _Description = formatDescription(_Station)
    local _WinMsg = formatWinMessage(_Station)
    local _LoseMsg = formatLoseMessage(_Station)

    local _BaseReward = 500000
    if _DangerLevel >= 5 then
        _BaseReward = _BaseReward + 200000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 300000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    reward = _BaseReward * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()) --SET REWARD HERE
    reputation = 8000
    if _DangerLevel == 10 then
        reputation = 12000
    end

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        icon = _IconIn,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/destroyprototype2.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you. We have tracked the battleship to \\s(%i:%i). Please destroy it.",
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
            reward = {credits = reward, relations = reputation},
            punishment = {relations = 8000 },
            dangerLevel = _DangerLevel,
            description = _Description,
            winMsg = _WinMsg,
            loseMsg = _LoseMsg,
            iconIn = _IconIn
        }},
    }

    return bulletin
end

--endregion