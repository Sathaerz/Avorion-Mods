package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

local ESCCUtil = include("esccutil")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Vengeance6Gruznier
Vengeance6Gruznier = {}
local self = Vengeance6Gruznier

self._Debug = 0

self.data = {}

function Vengeance6Gruznier.initialize(useEnhanced, personality)
    local methodName = "Initialize"
    self.Log(methodName, "Adding v30 of Vengeance 6 Gruznier script to enemy.")
    
    if onServer() then
        if not _restoring then
            self.Log(methodName, "Not restoring - running normal init.")

            self.data = {}

            self.data.enhancedMode = useEnhanced or false
            self.data.usePersonality = personality or 1

            local smallAccelFactor = 8
            local smallVelocityFactor = 8
            local bigAccelFactor = 32
            local bigVelocityFactor = 24
            local ramCounterMax = 10
            local ramCounterDamageFactor = 0.075
            local oneShotCap = 0.33
            local startPhaseTimerAt = 45
            if self.data.enhancedMode then
                smallAccelFactor = 10
                smallVelocityFactor = 10
                bigAccelFactor = 40
                bigVelocityFactor = 32
                ramCounterMax = 5
                ramCounterDamageFactor = 0.15
                oneShotCap = 0.66
                startPhaseTimerAt = 52 --Thought about doing 5 seconds or 10 seconds. Wasn't quite happy with either so we split the difference.
            end

            self.data.normalAccelFactor = smallAccelFactor
            self.data.normalVelocityFactor = smallVelocityFactor
            self.data.accelFactor = bigAccelFactor
            self.data.velocityFactor = bigVelocityFactor
            self.data.ramCounter = 0
            self.data.maxRamCounter = ramCounterMax
            self.data.ramCounterDamageIncrease = ramCounterDamageFactor
            self.data.ramOneShotDamageCap = oneShotCap
            self.data.canIncreaseRamDamage = true --Limit how often the ram counter damage increase can proc
        
            self.data.phaseTimer = startPhaseTimerAt --Start partially through the phase timer to make first ram phase happen faster.
            self.data.animTimer = 0
            self.data.collisionDamageTimer = 0
            self.data.boostMode = false
            self.data.saidWarCry = false

            self.data.activatedReinforcements75 = false
            self.data.activatedReinforcements50 = false
            self.data.activatedReinforcements25 = false

            self.data.currentTarget = nil
        else --onClient()
            self.Log(methodName, "Data will be restored.")
        end

        Entity():registerCallback("onCollision", "onCollision")
    else
        displayChatMessage(string.format("%s is attacking!"%_t, Entity().translatedTitle), "", 2)
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/special/bladesedge.ogg")
    end
end

function Vengeance6Gruznier.getUpdateInterval()
    return 1 --Update every second.
end

function Vengeance6Gruznier.updateServer(timeStep)
    local methodName = "Update Server"
    self.data.phaseTimer = self.data.phaseTimer + timeStep
    self.data.animTimer = self.data.animTimer + timeStep
    self.data.collisionDamageTimer = self.data.collisionDamageTimer + timeStep
    self.data.canIncreaseRamDamage = true
    local _entity = Entity()
    local _ShowAnimation = false

    local hp = _entity.durability
    local maxHp = _entity.maxDurability
    local ratio = hp / maxHp

    local phase2 = ratio <= 0.5
    local phase3 = ratio <= 0.25

    self.handleReinforcements(_entity)

    if not self.data.currentTarget or not valid(self.data.currentTarget) then
        self.data.currentTarget = self.pickNewTarget()
    end

    self.handleFlyPosition(_entity)

    --self.Log(methodName, "Desired velocity is " .. tostring(_entity.desiredVelocity)) --Be careful about enabling this due to spam.

    --flip to out / in - length of out depends on phase - 60/p1, 50/p2, 40/p3 - always in mode for 40 seconds.
    if self.data.boostMode then
        if self.data.phaseTimer >= 40 then
            --40 seconds have passed. Flip us to being OUT of the mode
            self.data.boostMode = false
            self.data.saidWarCry = false
            self.data.phaseTimer = 0

            _entity:addKeyedMultiplier(StatsBonuses.Acceleration, 2207469437, self.data.normalAccelFactor)
            _entity:addKeyedMultiplier(StatsBonuses.Velocity, 2207469437, self.data.normalVelocityFactor)

            if self._Debug == 1 then
                --Don't want to do all of this unless we're debugging.
                local _engine = Engine()
                self.Log(methodName, "Exiting boost mode. Velocity is " .. tostring(_engine.maxVelocity) .. " Acceleration is " .. tostring(_engine.acceleration))
            end
        else
            --blink to give a visual indication of the ship being in MAXIMUM BURN
            _ShowAnimation = true
        end
    else
        if self.data.phaseTimer >= 60 or (phase2 and self.data.phaseTimer >= 50) or (phase3 and self.data.phaseTimer >= 40) then
            --Flip us to being IN the mode.
            self.data.boostMode = true
            self.data.phaseTimer = 0

            if not self.data.saidWarCry then
                --pick a new target once per cycle. We can key this off of the war cry because it's easy and predone.
                self.data.currentTarget = self.pickNewTarget()

                local lines = self.getWarcryLines()

                local line = randomEntry(lines)

                Sector():broadcastChatMessage(_entity, ChatMessageType.Chatter, line)

                self.data.saidWarCry = true
            end

            if self.data.animTimer >= 2 then
                _ShowAnimation = true
                self.data.animTimer = 0
            end

            self.Log(methodName, "Setting bonus - final velocity is " .. tostring(self.data.velocityFactor) .. " Final accel is " .. tostring(self.data.accelFactor))

            _entity:addKeyedMultiplier(StatsBonuses.Acceleration, 2207469437, self.data.accelFactor)
            _entity:addKeyedMultiplier(StatsBonuses.Velocity, 2207469437, self.data.velocityFactor)

            if self._Debug == 1 then
                --Don't want to do all of this unless we're debugging.
                local _engine = Engine()
                self.Log(methodName, "Entering boost mode. Velocity is " .. tostring(_engine.maxVelocity) .. " Acceleration is " .. tostring(_engine.acceleration))
            end
        end
    end

    if _ShowAnimation then
        broadcastInvokeClientFunction("animation")
    end
end

--region #SERVER CALLS

function Vengeance6Gruznier.getWarcryLines()
    local funcTable = {
        function() --normal
            return {
                "You die now!",
                "WAAAAAARRRRRGGGHHHHH!",
                "KILL! KILL! KILL!",
                "YAAAAAAAAAAAAAAAAAHHHH!",
                "Ram you! Kill you!",
                "Gruznier impale you!",
                "Crush you! Destroy you!",
                "RAMMING SPEED!",
                "Set engines to KILL!"
            }
        end,
        function() --posh
            return {
                "Here is where you will meet your end!",
                "I'll tear your ship asunder!",
                "Now... now, you will die!",
                "YAH!",
                "Ramming speed!",
                "Prepare to be impaled!",
                "You'll be crushed and destroyed!",
                "Bring us to full ramming speed!",
                "Set engines to maximum thrust!"
            }
        end,
        function() --angry
            return {
                "RAAAAAAAAAAAAGGGHHHH!",
                "WAAAAAARRRRRGGGHHHHH!",
                "AAAAAAARRRRRRRRRRGHH!",
                "DIE! DIE!",
                "RRRRRRAAAAAHHHHHHHH!",
                "KILL YOU!",
                "GWOOOOOOOH!",
                "YOU! WILL! DIE!",
                "UOOORRRGHHH!"
            }
        end,
        function() --gamer
            return {
                "Speed hack on!",
                "Nerf this!",
                "I'll get your ass!",
                "WAAAAAOOOOOOOWWWW!",
                "Block this, noob!",
                "Eat my space dust, loser!",
                "Die! Die! DIE!",
                "Suck my panem, nerd!",
                "Time to die, dipshit!"
            }
        end
    }

    return funcTable[self.data.usePersonality]()
end

function Vengeance6Gruznier.getReinforcementLines(lineIndex)
    local funcTable = {
        function() --normal
            return {
                "Gruznier has friends, unlike you! Monster!",
                "More friends come! Friends kill!",
                "... MORE friends! Gruznier kill anything with friends!"
            }
        end,
        function() --posh
            return {
                "You do realize my friends here will kill you, yes?",
                "I've got plenty more where that came from, knave!",
                "One last cast of the die!"
            }
        end,
        function() --angry
            return {
                "MORE! MOOOOORE!",
                "REINFORCEMENTS! KILL! KILL KILL KILL!",
                "MORE SHIPS! MORE SHIPS KILL YOU!"
            }
        end,
        function() --gamer
            return {
                "My squad will get you!",
                "Time for a TPK, bitch!",
                "We're gonna drop the whole freaking battle bus on your head!"
            }
        end
    }
    
    local lineTable = funcTable[self.data.usePersonality]()

    return lineTable[lineIndex]
end

--region #HANDLE RAMMING

function Vengeance6Gruznier.pickNewTarget()
    local _sector = Sector()

    local sectorShips = { _sector:getEntitiesByType(EntityType.Ship) }
    local potentialTargets = {}

    --Any player ships / Allison are all valid targets
    for _, ship in pairs(sectorShips) do
        if ship.playerOrAllianceOwned or ship:getValue("is_allison") then
            table.insert(potentialTargets, ship)
        end
    end

    return randomEntry(potentialTargets)
end

function Vengeance6Gruznier.handleFlyPosition(_entity)
    local myAI = ShipAI(_entity)
    if self.data.currentTarget and valid(self.data.currentTarget) then
        --We need to make sure the current target is not null, otherwise it spams errors like crazy.
        local chosenTargetPosition = self.data.currentTarget.translationf
        local myPosition = _entity.translationf

        local dir = normalize(myPosition - chosenTargetPosition)

        local finalLoc = myPosition + (dir * -50000) --He will actively try to ram his current target, whether that is the player or Allison.

        myAI:setFlyLinear(finalLoc, 0, false)
    end
end

function Vengeance6Gruznier.onCollision(objIdxA, objIdxB, dmgA, dmgB, steererA, steererB)
    local methodName = "On Collision"

    local rammingEntity = Entity(objIdxA) --This will always be Gruznier.
    local rammedEntity = Entity(objIdxB)

    local lowCollideDamage = false
    if Server().collisionDamage <= 0.25 then
        lowCollideDamage = true
    end

    self.Log(methodName, "Entity " .. rammingEntity.name .. " rammed " .. rammedEntity.name .. ", dealing " .. tostring(dmgB) .. " damage!")

    if rammedEntity.type == EntityType.Ship then
        self.data.ramCounter = self.data.ramCounter + 1
    end

    local shouldInflictDamage = false
    if self.data.boostMode then
        if dmgB > 2500 or lowCollideDamage then
            shouldInflictDamage = true --Try not to waste the proc on bad rams while boosting.
        end
    else
        if dmgB > 500 or self.data.ramCounter >= 5 or lowCollideDamage then 
            shouldInflictDamage = true --Try not to waste the proc on bad rams, but not as severely as otherwise.
        end
    end

    if self.data.ramCounter > self.data.maxRamCounter and self.data.canIncreaseRamDamage then
        rammingEntity.damageMultiplier = rammingEntity.damageMultiplier + self.data.ramCounterDamageIncrease --If the player tries to stall out Gruznier by staying in melee, slowly make him more dangerous.
        self.data.ramCounter = 0
        self.data.canIncreaseRamDamage = false
    end

    if shouldInflictDamage and self.data.collisionDamageTimer >= 1 then --Only allow extra damage to proc once per second.
        local rammedEntityDurability = Durability(objIdxB)
        if rammedEntityDurability then
            local swdpsFactor = 4 --4x sector weapon dps normally (swpdpsFactor = sector weapon dps factor)
            local speedFactor = 10
            if lowCollideDamage and self.data.boostMode then
                swdpsFactor = swdpsFactor * 10
                speedFactor = speedFactor * 10
            end
            if self.data.enhancedMode then
                swdpsFactor = swdpsFactor * 2
                speedFactor = speedFactor * 2
            end

            local x, y = Sector():getCoordinates()
            local swdps = Balancing_GetSectorWeaponDPS(x, y) * swdpsFactor 

            local _velocity = Velocity(objIdxA)
            local linearVelocity = _velocity.linear * speedFactor

            self.Log(methodName, "linear velocity is " .. tostring(linearVelocity))

            --ramming has a minimum damage. Do minimum of: actual ram damage, sector weapon dps * factor, OR linear velocity * speed factor
            local ramdmg = math.max(dmgB, swdps, linearVelocity)

            local finalRamDmg = ramdmg * rammingEntity.damageMultiplier

            self.Log(methodName, "Dealing additional " .. tostring(ramdmg) .. " * " .. tostring(rammingEntity.damageMultiplier) .. " => (" .. tostring(finalRamDmg) .. ") damage base!")

            --Not sure what it is, but occasionally he gets off a JUICY ram that one shots you. This is, needless to say, very frustrating.
            --So we have an anti-one shot mechanic
            if finalRamDmg > rammedEntityDurability.maximum then
                local useRamDamageCap = self.data.ramOneShotDamageCap
                if not rammedEntity.playerOrAllianceOwned then
                    if rammingEntity.factionIndex ~= rammedEntity.factionIndex then --We're a bit nicer to the AI, who doesn't really know how to dodge Da Gruzier...
                        useRamDamageCap = 0.3 
                        if rammedEntity.durability / rammedEntity.maxDurability < 0.33 then
                            useRamDamageCap = 0.1
                            self.Log(methodName, "Ramming an AI ship from a different faction that's at low HP - be even nicer.")
                        else
                            self.Log(methodName, "Ramming an AI ship from a different faction - be nicer.")
                        end
                    else --... unless it's one of his own guys. If the player can somehow trick Grunizer into ramming his friends they get to watch him splatter them.
                        useRamDamageCap = math.huge
                    end
                end
                self.Log(methodName, "Rammed damage exceeds maximum durability. Using anti one-shot mechanic.")
                finalRamDmg = rammedEntityDurability.maximum * useRamDamageCap --This might still one shot the player, but they'd have to be damaged first.
                self.Log(methodName, "Final ram damage is " .. tostring(finalRamDmg))
            end

            --Why DamageSource.Weaponry? Because DamageSource.Collision is incredibly unreliable and doesn't always fire.
            rammedEntityDurability:inflictDamage(finalRamDmg, DamageSource.Weaponry, DamageType.Physical, objIdxA)
            self.data.collisionDamageTimer = 0
        end
    end
end

--endregion

--region #HANDLE REINFORCEMENTS

function Vengeance6Gruznier.handleReinforcements(_entity)
    local methodName = "Handle Reinforcements"

    local hp = _entity.durability
    local maxHp = _entity.maxDurability
    local ratio = hp / maxHp

    local useDanger = 8
    if self.data.enhancedMode then
        useDanger = 9
    end

    local spawnFriendWave = function(msg, useHigh)
        self.Log(methodName, "Running local function.")

        local useTable = "Standard"
        if useHigh then
            useTable = "High"
        end

        local pGenerator = AsyncPirateGenerator(Vengeance6Gruznier, onReinforcementsFinished)
        local pWave = ESCCUtil.getStandardWave(useDanger, 4, useTable, false) --8 or 9 danger / 4 ships / standard table / pirates
        local pPositions = pGenerator:getStandardPositions(4, 250) --#_DistAdj

        pGenerator:startBatch()

        for posIdx, friend in pairs(pWave) do
            self.Log(methodName, "Creating Scaled " .. friend)
            pGenerator:createScaledPirateByName(friend, pPositions[posIdx])
        end

        pGenerator:endBatch()

        Sector():broadcastChatMessage(_entity, ChatMessageType.Chatter, msg)
    end

    if ratio <= 0.75 and not self.data.activatedReinforcements75 then
        spawnFriendWave(self.getReinforcementLines(1), false)
        self.data.activatedReinforcements75 = true
    end

    if ratio <= 0.50 and not self.data.activatedReinforcements50 then
        spawnFriendWave(self.getReinforcementLines(2), false)
        self.data.activatedReinforcements50 = true
    end

    if ratio <= 0.25 and not self.data.activatedReinforcements25 then
        local uhmEnhanced = false
        if self.data.enhancedMode then
            uhmEnhanced = true
        end

        spawnFriendWave(self.getReinforcementLines(3), uhmEnhanced)
        self.data.activatedReinforcements25 = true
    end
end

function Vengeance6Gruznier.onReinforcementsFinished(generated)
    for _, friend in pairs(generated) do
        local mult = 1.25 --Xinull goon boost
        if self.data.activatedReinforcements75 and self.data.activatedReinforcements50 then
            mult = 1.375 --Make the last wave a bit stronger.
        end

        friend.damageMultiplier = (friend.damageMultiplier or 1) * mult
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

--endregion

--endregion

--region #CLIENT CALLS

function Vengeance6Gruznier.animation()
    local _sector = Sector()
    local _random = random()
    local _entity = Entity()
    local _plan = Plan(_entity)

    local blocks = _plan.numBlocks
    local sparks = math.min(200, blocks)

    local animColor = ColorRGB(1.0, 1.0, 0.0)

    for i = 1, sparks do
        local block = _plan:getNthBlock(_random:getInt(0, blocks - 1))

        local center = block.box.center
        local dir = _random:getDirection()
        local factor = 1 + _random:getFloat(-3, 3)
        local size = _entity.radius * 0.075

        _sector:createSpark(center, dir * 4 * factor, size, 2.25, animColor, 0, _entity)

        local factor2 = 0.5
        _sector:createSpark(center, dir * 4 * factor2, size, 2.5, animColor, 0, _entity)
    end

    local direction = _random:getDirection()

    _sector:createHyperspaceJumpAnimation(_entity, direction, animColor, 0.2)
end

--endregion

--region #LOG / SECURE / RESTORE

function Vengeance6Gruznier.Log(methodName, _Msg)
    if self._Debug == 1 then
        print("[Vengeance6Gruznier] - [" .. tostring(methodName) .. "] - " .. tostring(_Msg))
    end
end

function Vengeance6Gruznier.secure()
    local methodName = "Secure"
    self.Log(methodName, "Securing self.data")
    return self.data
end

function Vengeance6Gruznier.restore(_Values)
    local methodName = "Restore"
    self.Log(methodName, "Restoring self.data")
    self.data = _Values
end

--endregion