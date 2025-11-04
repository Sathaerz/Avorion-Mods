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

mission._Debug = 0
mission._Name = "Destroy Prototype Battleship"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
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
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(methodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

            local _X, _Y = _Data_in.location.x, _Data_in.location.y

            local _Sector = Sector()
            local _Giver = Entity(_Data_in.giver)
            --[[=====================================================
                CUSTOM MISSION DATA SETUP
            =========================================================]]
            mission.data.custom.dangerLevel = _Data_in.dangerLevel
            mission.data.custom.spawnedSecondWave = false
            mission.data.custom.friendlyFaction = _Giver.factionIndex
            mission.data.custom.battleshipName = ""

            --[[=====================================================
                MISSION DESCRIPTION SETUP:
            =========================================================]]
            mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
            mission.data.description[2].text = _Data_in.initialDesc
            mission.data.description[2].arguments = {x = _X, y = _Y }

            mission.data.icon = _Data_in.iconIn
            mission.data.accomplishMessage = _Data_in.winMsg
            mission.data.failMessage = _Data_in.loseMsg

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

mission.globalPhase.timers = {}

mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

--region #GLOBALPHASE TIMERS

if onServer() then

mission.globalPhase.timers[1] = {
    time = 10,
    callback = function()
        local methodName = "Global Phase Timer"
        mission.Log(methodName, "Beginning.")

        if atTargetLocation() and mission.data.custom.dangerLevel >= 8 and not mission.data.custom.spawnedSecondWave then
            local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}

            if #_Pirates == 1 then
                mission.data.custom.spawnedSecondWave = true
                destroyPrototype_spawnSecondWave()
            end
        end
    end,
    repeating = true
}
    
end

--endregion

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y)
    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    destroyPrototype_spawnPrototype()
    destroyPrototype_spawnInitialDefenders()

    mission.data.custom.cleanUpSector = true
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _Prototypes = {Sector():getEntitiesByScriptValue("is_prototype")}

    local entryTaunts = {
        "You'll never see this coming!",
        "It seems we've been found out! Take them down now!",
        "I guess this is it. At least we'll be taking you with us.",
        "Witness us!",
        "Never thought we'd die running from a do-gooder.",
        "To infinity! And beyond!",
        "One shall stand! One shall fall!",
        "Target verified, commencing hostilities.",
        "This will be our first and final battle!",
        "Let's see what this baby can do, hmm?",
        "A good prototype needs testing, I suppose...",
        "You should have backed off when you had the chance!",
        "Prepare yourself!",
        "Ready or not, here I come!"
    }

    Sector():broadcastChatMessage(_Prototypes[1], ChatMessageType.Chatter, getRandomEntry(entryTaunts))
    nextPhase()
end

mission.phases[2] = {}
mission.phases[2].sectorCallbacks = {}
mission.phases[2].onTargetLocationEntered = function(_X, _Y)
    local _func = "resetTimeToActive"
    local _time = 30 --Give the player a grace period before the battleship starts blasting again.
    local _BattleShips = {Sector():getEntitiesByScriptValue("is_prototype")}
    local _BattleShip = _BattleShips[1]

    if _BattleShip and valid(_BattleShip) and _BattleShip:getValue("_prototype_superweapon_script") then
        local _script = _BattleShip:getValue("_prototype_superweapon_script")
        _BattleShip:invokeFunction(_script, _func, _time)
    end
end

mission.phases[2].onFail = function()
    if atTargetLocation() then
        local _sector = Sector()
        local _Prototypes = {_sector:getEntitiesByScriptValue("is_prototype")}
        local _prototype = _Prototypes[1]

        local goodbyeTaunts = {
            "Ha! This thing is invincible!",
            "Finally! The hyperdrive is recharged! Get us out of here!",
            "Can't wait to paint the town red with this...",
            "See ya! Wouldn't want to be ya.",
            "Mediocre, Captain!",
            "All shall despair before our might!",
            "AhahahahahAHAHAHAAHAHAHAHAHA!!!",
            "The drive is charged, punch it!",
            "As much as I enjoyed our little dance, it's time to cut and run.",
            "I expected more from you, Captain. Maybe next time."
        }

        _sector:broadcastChatMessage(_prototype, ChatMessageType.Chatter, getRandomEntry(goodbyeTaunts))

        local _protoDurability = Durability(_prototype)
        _prototype:setValue("escc_active_ironcurtain", true) --fake an iron curtain being active so phasemode doesn't turn it off.
        if _protoDurability then
            _protoDurability.invincibility = 0.01
        end

        ESCCUtil.allPiratesDepart()
    end
end

--region #PHASE 2 SECTOR CALLBACKS

if onServer() then

mission.phases[2].sectorCallbacks[1] = {
    name = "onDamaged",
    func = function(_Entityidx, _Amount, _Inflictor, _DmgSrc, _DmgType)
        if mission.data.custom.dangerLevel >= 8 and not mission.data.custom.spawnedSecondWave then
            local _DamagedEntity = Entity(_Entityidx)

            if not _DamagedEntity or not valid(_DamagedEntity) then
                return
            end

            if _DamagedEntity:getValue("is_prototype") then
                local _Hull = _DamagedEntity.durability
                local _HullThreshold = _DamagedEntity.maxDurability / 2
                if _Hull < _HullThreshold then
                    mission.data.custom.spawnedSecondWave = true
                    destroyPrototype_spawnSecondWave()
                end
            end
        end
    end
}

end

--endregion

mission.phases[2].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _DestroyedEntity = Entity(_ID)

    local _Sector = Sector()

    if atTargetLocation() and _DestroyedEntity:getValue("is_prototype") then
        local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}

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
        
                    _Sector:broadcastChatMessage(_Pirate, ChatMessageType.Chatter, getRandomEntry(_Lines))
    
                    break
                end
            end

            for _, _Pirate in pairs(_Pirates) do
                if not _Pirate:getValue("is_prototype") then
                    _Pirate:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))
                end
            end
        end

        destroyPrototype_finishAndReward()
    end
end

mission.phases[2].onAbandon = function()
    destroyPrototype_failAndPunish()
end

--endregion

--region #SERVER CALLS

function destroyPrototype_spawnPrototype()
    local methodName = "Spawn Prototype"
    mission.Log(methodName, "Beginning.")

    local _Rgen = random()

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
    local _AddBlocker = false
    local _BlockerToAdd = ""

    if _Danger >= 5 then
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
        mission.Log(methodName, "Adding blocker script.")
        _BattleShip:addScriptOnce(_BlockerToAdd)
    end

    local _DefensiveScripts = {
        { scriptName = "adaptivedefense.lua" },
        { scriptName = "phasemode.lua", },
        { scriptName = "ironcurtain.lua" }
    }
    local _OffensiveScripts = {
        { scriptName = "overdrive.lua", scriptArgs = { incrementOnPhaseOut = true, incrementOnPhaseOutValue = 0.15 } },
        { scriptName = "avenger.lua" },
        { scriptName = "frenzy.lua", scriptArgs = { _UpdateCycle = 5, _IncreasePerUpdate = 0.3 } }
    }

    shuffle(random(), _DefensiveScripts)
    shuffle(random(), _OffensiveScripts)

    if _DefensiveScriptsct > 0 then
        for idx = 1, _DefensiveScriptsct do
            local _Script = _DefensiveScripts[idx]
            mission.Log(methodName, "Adding defensive script : " .. tostring(_Script.scriptName) .. " script args is : " .. tostring(_Script.scriptArgs))
            _BattleShip:addScriptOnce(_Script.scriptName, _Script.scriptArgs)
        end
    end

    if _OffensiveScriptsct > 0 then
        for idx = 1, _OffensiveScriptsct do
            local _Script = _OffensiveScripts[idx]
            mission.Log(methodName, "Adding offensive script : " .. tostring(_Script.scriptName) .. " script args is : " .. tostring(_Script.scriptArgs))
            _BattleShip:addScriptOnce(_Script.scriptName, _Script.scriptArgs)
        end
    end

    --Add durability.
    local durability = Durability(_BattleShip)
    if durability then 
        local _Factor = (durability.maxDurabilityFactor or 1) * _DuraFactor
        mission.Log(methodName, "Setting durability factor of the prototype to : " .. tostring(_Factor))
        durability.maxDurabilityFactor = _Factor
    end

    --Add damage.
    local _FinalDamageFactor = (_BattleShip.damageMultiplier or 1) * _DamageFactor
    mission.Log(methodName, "Setting final damage factor to : " .. tostring(_FinalDamageFactor))
    _BattleShip.damageMultiplier = _FinalDamageFactor

    --Add the superweapon script.
    if _Danger == 10 then
        local _X, _Y = Sector():getCoordinates()
        local insideBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)

        local _StaticMult = true
        if insideBarrier then
            _StaticMult = false
        end
        
        --local _Type = 3
        local _Type = _Rgen:getInt(1, 3)
        local sectorWeaponDPS = Balancing_GetSectorWeaponDPS(_X, _Y)
        
        if _Type == 1 then
            mission.Log(methodName, "Torpedo type chosen.")
            --Torpedo
            local _TorpValues = {
                _ROF = 6,
                _DurabilityFactor = 10,
                _TimeToActive = 30,
                _DamageFactor = 4,
                _UseEntityDamageMult = true,
                _UseStaticDamageMult = _StaticMult,
                _AccelFactor = 2,
                _VelocityFactor = 2,
                _TurningSpeedFactor = 2.5,
                _ShockwaveFactor = 2,
                _FireBarrage = true,
                _BarrageCount = 3,
                _BarrageDelay = 0.75
            }
            _BattleShip:addScriptOnce("torpedoslammer.lua", _TorpValues)
            _BattleShip:setValue("_prototype_superweapon_script", "torpedoslammer.lua")
        elseif _Type == 2 then
            mission.Log(methodName, "Siege Gun type chosen.")
            --Siege Gun
            local _SiegeGunValues = {
                _Velocity = 150,
                _ShotCycle = 30,
                _ShotCycleSupply = 0,
                _ShotCycleTimer = 0,
                _UseSupply = false,
                _FragileShots = false,
                _TargetPriority = 1,
                _BaseDamagePerShot = sectorWeaponDPS * 2500,
                _TimeToActive = 30,
                _UseEntityDamageMult = true,
                _UseStaticDamageMult = _StaticMult
            }
            _BattleShip:addScriptOnce("stationsiegegun.lua", _SiegeGunValues)
            _BattleShip:setValue("_prototype_superweapon_script", "stationsiegegun.lua")
        elseif _Type == 3 then
            mission.Log(methodName, "Laser Sniper type chosen.")
            --Laser sniper
            local distToCenter = length(vec2(_X, _Y))
            local laserSniperFactor = 125 --Same damage as a longinus
            if distToCenter > 360 then
                mission.Log(methodName, "No shields available - cut damage in half.")
                laserSniperFactor = 62 --Cut it in half to compensate for lack of shields.
            end

            local _LaserSniperValues = {
                _DamagePerFrame = sectorWeaponDPS * laserSniperFactor,
                _TimeToActive = 30,
                _UseEntityDamageMult = true,
                _UseStaticDamageMult = _StaticMult
            }
            _BattleShip:addScriptOnce("lasersniper.lua", _LaserSniperValues)
            _BattleShip:setValue("_prototype_superweapon_script", "lasersniper.lua")
        end
    end

    --Attach the boss script.
    if mission.data.custom.dangerLevel == 10 then
        _BattleShip:addScriptOnce("esccbossdespair.lua")
    else
        _BattleShip:addScriptOnce("esccbossblades.lua")
    end
end

function destroyPrototype_spawnInitialDefenders()
    local methodName = "Spawn Initial Defenders"
    mission.Log(methodName, "Beginning.")

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

    mission.Log(methodName, "Spawning table of " .. tostring(_Piratect) .. " " .. tostring(_Table) .. " pirates.")

    local _PirateTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, _Piratect, _Table, false)
    local _CreatedPirateTable = {}

    PirateGenerator.pirateLevel = Balancing_GetPirateLevel(mission.data.location.x, mission.data.location.y)
    for _, _Pirate in pairs(_PirateTable) do
        table.insert(_CreatedPirateTable, PirateGenerator.createPirateByName(_Pirate, PirateGenerator.getGenericPosition()))
    end

    SpawnUtility.addEnemyBuffs(_CreatedPirateTable)
end

function destroyPrototype_spawnSecondWave()
    local methodName = "Spawn Pirate Wave"
    mission.Log(methodName, "Beginning.")

    local _Table = "Standard"
    if mission.data.custom.dangerLevel == 10 then
        _Table = "High"
    end

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, 6, _Table, false)

    local generator = AsyncPirateGenerator(nil, destroyPrototype_onSecondWaveFinished)
    generator.pirateLevel = Balancing_GetPirateLevel(mission.data.location.x, mission.data.location.y)

    generator:startBatch()

    local distance = 250 --_#DistAdj
    if mission.data.custom.dangerLevel == 10 then
        distance = 350
    end
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for posCtr, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCtr])
    end

    generator:endBatch()
end

function destroyPrototype_onSecondWaveFinished(_Generated)
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

    Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, getRandomEntry(_Taunts))
end

function destroyPrototype_finishAndReward()
    local methodName = "Finish and Reward"
    mission.Log(methodName, "Running win condition.")

    reward()
    accomplish()
end

function destroyPrototype_failAndPunish()
    local methodName = "Fail and Punish"
    mission.Log(methodName, "Running lose condition.")

    punish()
    fail()
end

--endregion

--region #MAKEBULLETIN CALL

function destroyPrototype_formatWinMessage(_Station)
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

function destroyPrototype_formatLoseMessage(_Station)
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

function destroyPrototype_formatDescription(_Station)
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
    local methodName = "Make Bulletin"

    --We don't need a specific type of sector here. Just an empty one that's on the same side of the barrier as the questgiver.
    local _Rgen = ESCCUtil.getRand()
    local _sector = Sector()

    local target = {}
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
    target.x, target.y = MissionUT.getEmptySector(x, y, 7, 20, insideBarrier)

    if not target.x or not target.y then
        mission.Log(methodName, "Target.x or Target.y not set - returning nil.")
        return 
    end

    local _DangerLevel = _Rgen:getInt(1, 10)

    local _IconIn = nil
    local _Difficulty = "Difficult"
    if _DangerLevel > 5 then
        _Difficulty = "Extreme"
    end
    if _DangerLevel == 10 then
        _IconIn = "data/textures/icons/hazard-sign.png"
        _Difficulty = "Death Sentence"
    end
    
    local _Description = destroyPrototype_formatDescription(_Station)
    local _WinMsg = destroyPrototype_formatWinMessage(_Station)
    local _LoseMsg = destroyPrototype_formatLoseMessage(_Station)

    local _BaseReward = 500000
    if _DangerLevel > 5 then
        _BaseReward = _BaseReward + 200000
    end
    if _DangerLevel == 10 then
        _BaseReward = _BaseReward + 300000
    end
    if insideBarrier then
        _BaseReward = _BaseReward * 2
    end

    local rewardFactor = Balancing.GetSectorRewardFactor(_sector:getCoordinates())
    reward = _BaseReward * rewardFactor --SET REWARD HERE
    reputation = 8000 + (8000 * (0.0175 * _DangerLevel) * rewardFactor) --Anywhere from 8000 to 64500
    punishRep = reputation / 2
    if reputation > 20000 then
        punishRep = reputation / 2.5
    end
    if _DangerLevel == 10 then
        reputation = reputation * 1.5
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
            reward = { credits = reward, relations = reputation, paymentMessage = "Earned %1% for destroying the prototype." },
            punishment = { relations = punishRep },
            dangerLevel = _DangerLevel,
            initialDesc = _Description,
            winMsg = _WinMsg,
            loseMsg = _LoseMsg,
            iconIn = _IconIn
        }},
    }

    return bulletin
end

--endregion