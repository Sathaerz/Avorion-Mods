package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

local ESCCUtil = include("esccutil")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local Placer = include("placer")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Vengeance9Xinull
Vengeance9Xinull = {}
local self = Vengeance9Xinull

self._Debug = 0

self.data = {}
self.damageTakenTable = {}

local laser = nil

self.laserData = {}
self.laserData.from = nil
self.laserData.to = nil

function Vengeance9Xinull.initialize(useEnhanced, personality)
    local methodName = "Initialize"
    self.Log(methodName, "Adding v6 of Vengeance 9 Xinull script to enemy.")

    if onServer() then
        local _entity = Entity()

        if not _restoring then
            self.Log(methodName, "Not restoring - running normal init.")

            self.data = {}

            self.data.enhancedMode = useEnhanced or false
            self.data.usePersonality = personality or 1

            local reinforcementCycle = 75
            local shieldThreshold = 0.5
            local meathookDamageFactor = 0.5
            local armorDamageFactor = 0.75
            local resistanceFactor = 0.33
            if self.data.enhancedMode then
                reinforcementCycle = 70
                shieldThreshold = 0.99
                meathookDamageFactor = 0.75
                armorDamageFactor = 0.6
                resistanceFactor = 0.4
            end

            --Weakness block
            self.data.initialDamageMultiplier = _entity.damageMultiplier
            self.data.weaknessBlockTimer = 30 --Start partway through the timer so the block is added more quickly.
            self.data.weaknessBlockAdded = false
            self.data.weaknessBlockIndex = -1 --Not necessary but it is easy to find from here.
            self.data.weaknessBlockAnimationTimer = 0
            --Weakness block shield recharge
            self.data.wBlockShieldTimer = 0
            self.data.shieldChargedAmount = 0
            self.data.wBlockShieldCharging = false
            self.data.wBlockShieldCanCharge = false
            self.data.wBlockShieldRechargeBroadcast = false
            self.data.wBlockFirstAdd = true
            self.data.wBlockMaxShieldChargeThreshold = shieldThreshold
            --Meathook
            self.data.meathookActive = false
            self.data.sentMeathookTaunt = false
            self.data.sentSecondMeathookTaunt = false
            self.data.meathookTimer = 0
            self.data.meathookPullTimer = 0
            self.data.meathookPower = 10
            self.data.meathookWaitCycle = 24
            self.data.meathookPullCycle = 12
            self.data.meathookDamageMultiplier = meathookDamageFactor
            --Reinforcements
            self.data.reinforcementTimer = 30 --Start partway through so that the first wave is summoned more quickly.
            self.data.reinforcementTimerMax = reinforcementCycle
            --Adaptive defender
            self.data.resistance = resistanceFactor
            self.data.physDamageTaken = 0
            self.data.antiDamageTaken = 0
            self.data.plasDamageTaken = 0
            self.data.elecDamageTaken = 0
            self.data.enrgDamageTaken = 0
            self.data.timeUntilActive = 25
            self.data.timeUntilUpdate = 5
            self.data.adaptiveActiveTimer = 0
            self.data.adaptiveUpdateTimer = 0
            --other
            self.data.useArmorDamageFactor = armorDamageFactor
        else
            self.Log(methodName, "Data will be restored.")
        end

        --These need to be done each time regardless.
        _entity:registerCallback("onBlockDestroyed", "onBlockDestroyed")
        _entity:registerCallback("onDestroyed", "onDestroyed")
        _entity:registerCallback("onShieldDamaged", "onShieldDamaged")
        _entity:registerCallback("onDamaged", "onDamaged")

        local _plan = Plan()
        local armorTypes = {
                BlockType.Armor,
                BlockType.EdgeArmor,
                BlockType.CornerArmor,
                BlockType.OuterCornerArmor,
                BlockType.InnerCornerArmor,
                BlockType.TwistedCorner1Armor,
                BlockType.TwistedCorner2Armor,
                BlockType.FlatCornerArmor
            }

        for _, armorType in pairs(armorTypes) do
            _plan:setBlockTypeDamageFactor(armorType, self.data.useArmorDamageFactor)
        end
    else --onClient()
        displayChatMessage(string.format("%s is attacking!"%_t, Entity().translatedTitle), "", 2)
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/vengeance/ac4fall.ogg")
    end
end

function Vengeance9Xinull.getUpdateInterval()
    return 0 --Update every frame.
end

function Vengeance9Xinull.update(timeStep)
    local methodName = "Update"
    self.updateMeathookLaser()

    if onServer() then
        --Manage reinforcement timer
        self.data.reinforcementTimer = self.data.reinforcementTimer + timeStep

        if self.data.reinforcementTimer >= self.data.reinforcementTimerMax then
            self.Log(methodName, "Spawning reinforcements if applicable.")
            self.spawnReinforcements()
            self.data.reinforcementTimer = 0
        end

        --Manage weakness block timer
        if not self.data.weaknessBlockAdded then
            self.data.weaknessBlockTimer = self.data.weaknessBlockTimer + timeStep
            self.data.wBlockShieldTimer = 0
        else
            self.data.weaknessBlockAnimationTimer = self.data.weaknessBlockAnimationTimer + timeStep
            self.data.wBlockShieldTimer = self.data.wBlockShieldTimer + timeStep
        end

        if self.data.weaknessBlockTimer >= 45 then
            self.Log(methodName, "Weakness block timer proc - add weakness block.")
            self.addWeaknessBlock()
            self.data.weaknessBlockTimer = 0
            self.data.weaknessBlockAdded = true
            if self.data.wBlockFirstAdd then
                self.Log(methodName, "First weakness block add - do not start shield timer.")
                self.data.wBlockFirstAdd = false
            else
                self.Log(methodName, "Subsequent weakness block add - start shield timer.")
                self.data.wBlockShieldCanCharge = true
            end
            self.data.shieldChargedAmount = 0
        end

        --Give the player 45 seconds to blow it up before his shields recharge.
        --Adjust as needed.
        if self.data.wBlockShieldCanCharge and self.data.wBlockShieldTimer > 45 then 
            self.data.wBlockShieldCharging = true
        end

        if self.data.wBlockShieldCharging then
            --Broadcast handholding message
            if not self.data.wBlockShieldRechargeBroadcast then
                Sector():sendCallback("vbmn_xinull_first_recharged_shields")
                self.data.wBlockShieldRechargeBroadcast = true
            end

            local _entity = Entity()
            local chargeAmount = _entity.shieldMaxDurability / 3 --Recharge in 3 seconds.

            --Add % hp to shield
            local healAmount = chargeAmount * timeStep
            _entity:healShield(healAmount)
            self.data.shieldChargedAmount = self.data.shieldChargedAmount + healAmount

            --If shield is 50%+, stop recharge and disable ability to recharge until weakness block is regenerated
            local shieldThreshold = _entity.shieldDurability / _entity.shieldMaxDurability
            if shieldThreshold >= self.data.wBlockMaxShieldChargeThreshold or self.data.shieldChargedAmount >= _entity.shieldMaxDurability then
                self.data.wBlockShieldCharging = false
                self.data.wBlockShieldCanCharge = false
            end
        end

        if self.data.weaknessBlockAnimationTimer >= 2 then
            broadcastInvokeClientFunction("showWeaknessBlockAnimation", self.data.weaknessBlockIndex)
        end

        --Manage meathook timer
        if not self.data.meathookTarget or not valid(self.data.meathookTarget) then
            --self.Log(methodName, "Meathook target no longer valid - resetting.") --Be careful about enabling this one - it is very spammy.
            self.data.meathookTarget = self.pickMeathookTarget()
            self.data.meathookActive = false
            self.data.meathookTimer = 0
            self.data.meathookPullTimer = 0
            self.deleteCurrentLasers()
        else
            self.data.meathookTimer = self.data.meathookTimer + timeStep

            if self.data.meathookTimer >= self.data.meathookWaitCycle then
                self.Log(methodName, "Meathook laser active - repositioning target.")
                broadcastInvokeClientFunction("createMeathookLaser", 15, Entity().translationf, self.data.meathookTarget.translationf)
                self.data.meathookActive = true
                self.data.meathookTimer = 0
                self.data.meathookPullTimer = 0

                if not self.data.sentMeathookTaunt then
                    local _sector = Sector()
                    _sector:broadcastChatMessage(Entity(), ChatMessageType.Chatter, self.getMeathookLines())
                    _sector:sendCallback("vbmn_xinull_first_used_meathook")
                    self.data.sentMeathookTaunt = true
                end
            end

            if self.data.meathookActive then
                self.data.meathookPullTimer = self.data.meathookPullTimer + timeStep
                self.repositionMeathookTarget()

                if self.data.meathookPullTimer >= self.data.meathookPullCycle then
                    self.data.meathookActive = false
                    self.deleteCurrentLasers()
                end

            end
        end

        --manage adaptive defender timer
        self.data.adaptiveActiveTimer = self.data.adaptiveActiveTimer + timeStep
        if self.data.adaptiveActiveTimer >= self.data.timeUntilActive then
            self.data.adaptiveUpdateTimer = self.data.adaptiveUpdateTimer + timeStep

            if self.data.adaptiveUpdateTimer > self.data.timeUntilUpdate then
                self.setResistances()
                self.data.adaptiveUpdateTimer = 0
            end
        end
    end --END ONSERVER BLOCK (this one is rather long)
end

--region #SERVER CALLS

function Vengeance9Xinull.getWeaknessBlockDestroyedLines()
    local funcTable = {
        function() --Normal
            return {
                "Aughh!",
                "No! Not there!",
                "You'll pay for that!",
                "Not that one!",
                "Ugh!",
                "Damn you!",
                "My one weakness...!"
            }
        end,
        function() --Cringe Pirate
            return {
                "Argh! Me exhaust port!",
                "They won't be makin' a peg for that one!",
                "Avast! Ye scoundrel!",
                "Ye scurvy dog!",
                "I'll keelhull you for that!",
                "Shiver me armor blocks!",
                "Yer dead for that one, matey!"
            }
        end,
        function() --Cynical
            return {
                "Sigh...",
                "Guess I'll have to win without that one.",
                "Not again...",
                "That's a real headache.",
                "How exhausting.",
                "Bah. That's annoying.",
                "What a stupid design flaw."
            }
        end,
        function() --Gamer
            return {
                "Mods?? Mods?!",
                "I've been nerfed!",
                "I'll IP ban you right off the server!",
                "No! My rig!",
                "You stupid hacker!",
                "W/e! You're still a noob!",
                "You filthy casual!"
            }
        end
    }

    return funcTable[self.data.usePersonality]()
end

function Vengeance9Xinull.getReinforcementLines()
    local funcTable = {
        function() --Normal
            local normalLines = {
                "To me! To me!",
                "Rally to me, boys!",
                "Over here!",
                "Hit those boosters and get into the fight!",
                "Kill these two rabid dogs!",
                "Form up on me!",
                "Attack!",
                "Go go go! Get moving!",
                "What are you waiting for?! Kill them!",
                "You gotta fight!"
            }

            if random():test(0.05) then
                table.insert(normalLines, "You know what you're doing! Launch every ship!") --An AYBABTU joke in 2025? We really went into the wine cellar for this one.
            end

            return normalLines
        end,
        function() --Cringe Pirate
            local normalLines = {
                "Keelhaul those landlubbers! Wait...",
                "I brought me mateys along!",
                "Come, ye scurvy dogs! Kill them!",
                "Raise the jolly roger!",
                "Full sail ahead, mateys!",
                "Get yer peg legs into the fight!",
                "Me crew will be the end of ye!",
                "Yarrr! Me mateys will finish ye off!",
                "We'll have yer guts for garters!"
            }

            if random():test(0.05) then
                table.insert(normalLines, "Ye know what yer doin'! Launch every ship!")
            end

            return normalLines
        end,
        function() --Cynic
            local normalLines = {
                "Let's give these a try, I guess.",
                "I'd rather not die, sooo... I called in some help.",
                "More ships? Why not.",
                "Eeeeehhhh... I guess I could use some help.",
                "You sure are annoying, but two can play at that.",
                "C'mon, c'mon...",
                "Could use some help, I suppose.",
                "More ships, more problems.",
                "You'd all better form up quickly."
            }

            if random():test(0.05) then
                table.insert(normalLines, "- What? No, I'm not making an AYBABTU joke.")
            end

            return normalLines
        end,
        function() --Gamer
            local normalLines = {
                "Ready for an epic raid, bros?!",
                "You're no match for my guild!",
                "We'll take you out for some killer loot!",
                "Just like a raid boss...",
                "Just like the simulations!",
                "Bronze league ass.",
                "Whoever kills that dipshit gets 50 DKP!",
                "You'll hit zero HP first!",
                "I brought some friends to this lobby!"
            }

            if random():test(0.05) then
                table.insert(normalLines, "AYBABTU! AYBABTU! AYBABTU!")
            end

            return normalLines
        end
    }

    return funcTable[self.data.usePersonality]()
end

function Vengeance9Xinull.getMeathookLines()
    local lineTable = {
        "Ship cannibalization beam active!", --Normal
        "GET IN ME BELLY!", --Cringe Pirate
        "Better you than me...", --Cynic
        "I'll use you for a buff!" --Gamer
    }

    return lineTable[self.data.usePersonality]
end

function Vengeance9Xinull.getMeathookShipEatenLines()
    local lineTable = {
        "Energy transfer complete!", --Normal
        "NOM NOM NOM!", --Cringe Pirate
        "Powering up weapons... will this be enough?", --Cynic
        "OH YEAH, BABY! I'VE GOT THAT GAMER FUEL!" --Gamer
    }

    return lineTable[self.data.usePersonality]
end

--region #WEAKNESS BLOCK

function Vengeance9Xinull.addWeaknessBlock()
    local methodName = "Add Weakness Block"

    local _plan = Plan()
    if not _plan then
        return
    end
    local armorEdges = _plan:getBlocksByType(BlockType.EdgeArmor)
    --Pick a random armor edge
    local armorEdgeIdx = randomEntry(armorEdges)
    local armorEdgeBlock = _plan:getBlock(armorEdgeIdx)
    local armorEdgePosition = armorEdgeBlock.box.center
    local blockMatl = Material(MaterialType.Trinium)
    local blockColor = ColorRGB(0, 0.1, 1.0) --Blue should be fairly noticeable.

    self.Log(methodName, "Found armor edge block, adding weakness block.")
    self.data.weaknessBlockIndex = _plan:addBlock(armorEdgePosition, vec3(4.0, 4.0, 4.0), armorEdgeIdx, -1, blockColor, blockMatl, armorEdgeBlock.orientation, BlockType.Glow, nil)
    self.Log(methodName, "Weakness block successfully added - idx is " .. tostring(self.data.weaknessBlockIndex))

    Sector():sendCallback("vbmn_xinull_added_weakness_block")
end

function Vengeance9Xinull.onBlockDestroyed(objectIndex, index, block, lastDamageInflictor, damageSource)
    local methodName = "On Block Destroyed"

    if index == self.data.weaknessBlockIndex then
        local _entity = Entity()

        --Reset damage multiplier
        self.Log(methodName, "Weakness block destroyed! Resetting values. Resetting damage multiplier from " .. tostring(_entity.damageMultiplier) .. " to " .. tostring(self.data.initialDamageMultiplier))
        _entity.damageMultiplier = self.data.initialDamageMultiplier
        self.data.weaknessBlockAdded = false
        self.data.weaknessBlockIndex = -1
        self.data.weaknessBlockAnimationTimer = 0

        --Reset meathook
        self.data.meathookActive = false
        self.data.meathookTimer = 0
        self.data.meathookPullTimer = 0

        --Reset shield / durability and timer.
        self.data.adaptiveActiveTimer = 0
        self.data.adaptiveUpdateTimer = 0
        self.Log(methodName, "Resetting shield / hull resistances...")
        local myShield = Shield()
        if myShield then
            self.Log(methodName,"Shield exists - resetting resistance amount.")
            myShield:resetResistance()
        end

        local myDurability = Durability()
        if myDurability then
            self.Log(methodName, "Durability exists - resetting resistance amount.")
            myDurability:resetWeakness()
        end

        local lines = self.getWeaknessBlockDestroyedLines()

        Sector():broadcastChatMessage(_entity, ChatMessageType.Chatter, randomEntry(lines))
    end
end

--endregion

--region #MEATHOOK

function Vengeance9Xinull.onDestroyed()
    self.deleteCurrentLasers()
end

function Vengeance9Xinull.pickMeathookTarget()
    local methodName = "Pick Meathook Target"

    --self.Log(methodName, "Picking target.") --Careful about enabling this - very spammy.

    local pirates = { Sector():getEntitiesByScriptValue("is_pirate") }
    local potentialTargets = {}

    for _, p in pairs(pirates) do
        if not p:getValue("is_xinull") then
            table.insert(potentialTargets, p)
        end
    end

    return randomEntry(potentialTargets)
end

function Vengeance9Xinull.repositionMeathookTarget()
    local methodName = "Reposition Target"
    
    local _entity = Entity()
    local myPosition = _entity.translationf
    local enemyPosition = self.data.meathookTarget.translationf

    local radius = _entity:getBoundingSphere().radius
    local distanceToTarget = distance(myPosition, enemyPosition)
    local minPullDistance = radius * 2
    local minConsumeDistance = radius * 3

    if distanceToTarget > minPullDistance then
        local diffPosition = enemyPosition - myPosition
        local normalizedDiff = normalize(diffPosition)
        local shift = normalizedDiff * self.data.meathookPower

        local targetPosition = self.data.meathookTarget.position
        targetPosition.translation = targetPosition.translation - shift
        self.data.meathookTarget.position = targetPosition

        local targetVelocity = Velocity(self.data.meathookTarget.index)
        local normalizedVelocity = normalize(targetVelocity.velocity)
        targetVelocity.velocity = (targetVelocity.velocity - normalizedVelocity * 2)
    end

    if distanceToTarget < minConsumeDistance then --Eat it :)
        self.Log(methodName, "Killing repositioning target. Turning off hook and eating.")

        local mhDamageMultiplier = 1 + ((self.data.meathookTarget.damageMultiplier or 1) * self.data.meathookDamageMultiplier)
        local mhMaxDurability = self.data.meathookTarget.maxDurability
        local healPct = (mhMaxDurability / 500) / 100

        _entity.damageMultiplier = (_entity.damageMultiplier or 1) * mhDamageMultiplier

        local healAmt = _entity.maxDurability * healPct
        _entity.durability = _entity.durability + healAmt

        self.Log(methodName, "Healed " .. tostring(healPct) .. "% hp and got x" .. tostring(mhDamageMultiplier) .. " damage mult" )

        self.data.meathookTarget:destroy(_entity.index, 1, DamageType.Energy)
        self.data.meathookActive = false
        self.deleteCurrentLasers()

        if not self.data.sentSecondMeathookTaunt then
            local _sector = Sector()
            _sector:broadcastChatMessage(_entity, ChatMessageType.Chatter, self.getMeathookShipEatenLines())
            _sector:sendCallback("vbmn_xinull_first_ate_ally")
            self.data.sentSecondMeathookTaunt = true
        end
    end
end

--endregion

--region #REINFORCEMENTS

function Vengeance9Xinull.spawnReinforcements()
    local pirateCt = ESCCUtil.countEntitiesByValue("is_pirate")

    local useDanger = 8
    local useTable = "Low"
    if self.data.enhancedMode then
        useDanger = 9
        if random():test(0.5) then
            useTable = "Standard"
        end
    end

    if pirateCt < 4 then
        local pirateGenerator = AsyncPirateGenerator(Vengeance9Xinull, onReinforcementsFinished)
        local pirateTable = ESCCUtil.getStandardWave(useDanger, 4, useTable, false)
        local piratePositions = pirateGenerator:getStandardPositions(4, 250) --_#DistAdj

        pirateGenerator:startBatch()

        for posIdx, p in pairs(pirateTable) do
            pirateGenerator:createScaledPirateByName(p, piratePositions[posIdx])
        end

        pirateGenerator:endBatch()

        local lines = self.getReinforcementLines()

        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, randomEntry(lines))
    end
end

function Vengeance9Xinull.onReinforcementsFinished(generated)
    for _, p in pairs(generated) do
        p.damageMultiplier = (p.damageMultiplier or 1) * 1.25 --Xinull goon boost
        p:addScriptOnce("player/missions/vengeance/story9/vengeance9rally.lua")
    end

    SpawnUtility.addEnemyBuffs(generated)
    Placer.resolveIntersections(generated)
end

--endregion

--region #ADAPTIVE DEFENDER

function Vengeance9Xinull.onShieldDamaged(objectIndex, amount, damageType, inflictorID)
    if not damageType or not amount then
        return
    else
        self.adaptDefense(damageType, amount)
    end
end

function Vengeance9Xinull.onDamaged(objectIndex, amount, inflictor, damageSource, damageType)
    if not damageType or not amount then
        return
    else
        self.adaptDefense(damageType, amount)
    end
end

function Vengeance9Xinull.adaptDefense(damageType, amount)
    self.damageTakenTable[damageType] = (self.damageTakenTable[damageType] or 0) + amount
end

function Vengeance9Xinull.setResistances()
    local methodName = "Set Resistances"

    local adaptToDamage = 0
    local adaptToType = DamageType.Physical
    for dmgType, dmgTaken in pairs(self.damageTakenTable) do
        if dmgTaken > adaptToDamage then
            adaptToDamage = dmgTaken
            adaptToType = dmgType
        end
    end

    self.Log(methodName, "Setting shield reisstance to " .. tostring(adaptToType))
    
    local myShield = Shield()
    if myShield then
        self.Log(methodName,"Shield exists - setting resistance amount.")
        myShield:setResistance(adaptToType, self.data.resistance)
    end

    self.Log(methodName, "Setting hull resistance to " .. tostring(adaptToType))
    
    local myDurability = Durability()
    if myDurability then
        self.Log(methodName, "Durability exists - setting resistance amount.")
        myDurability:setWeakness(adaptToType, self.data.resistance * -1)
    end
end

--endregion

--endregion

--region #CLIENT CALLS

function Vengeance9Xinull.showWeaknessBlockAnimation(blockIdx)
    local _sector = Sector()
    local _random = random()
    local _entity = Entity()
    local _plan = Plan(_entity)
    local block = _plan:getBlock(blockIdx)

    local sparks = 15

    local animColor = ColorRGB(0, 0.1, 1.0)

    if block then
        for i = 1, sparks do
            local center = block.box.center
            local dir = _random:getDirection()
            local factor = 1 + _random:getFloat(-3, 3)
            local size = _entity.radius * 0.125

            _sector:createSpark(center, dir * 4 * factor, size, 2.25, animColor, 0, _entity)

            local factor2 = 0.5
            _sector:createSpark(center, dir * 4 * factor2, size, 2.5, animColor, 0, _entity)
        end
    end
end

function Vengeance9Xinull.createMeathookLaser(width, from, to)
    local laserColor = ColorRGB(0.0, 0.6, 1.0)
    laser = Sector():createLaser(vec3(), vec3(), laserColor, width or 1)
    laser.from = from
    laser.to = to
    laser.collision = false

    self.Log(methodName, "Making laser from : " .. tostring(from) .. " to : " .. tostring(to))
    if not laser then
        self.Log("WARNING! Laser is nil")
    end

    laser.maxAliveTime = 1.5
end

function Vengeance9Xinull.updateMeathookLaser()
    local methodName = "Update Laser"

    if onServer() then
        --self.Log(methodName, "Called on server.") --CAREFUL WHEN ENABLING THIS - SPAM
        if not self.data.meathookTarget or self.data.meathookTimer >= self.data.meathookWaitCycle + self.data.meathookPullCycle then
            return
        end

        local _entity = Entity()
        local target = self.data.meathookTarget

        if target and valid(target) then
            local from = _entity.translationf
            local to = target.translationf

            self.laserData.from = from
            self.laserData.to = to

            --self.Log(methodName, "sending from = " .. tostring(self.laserData.from) .. " to " .. tostring(self.laserData.to)) --CAREFUL WHEN ENABLING THIS - SPAM
            self.syncLaserData()
        end
    else --onClient()
        --self.Log(methodName, "Called on client.") --CAREFUL WHEN ENABLING THIS - SPAM
        if not laser or not valid(laser) or not self.laserData.from or not self.laserData.to then
            return
        end

        --self.Log(methodName, "Setting laser from / to / aliveTime") --CAREFUL WHEN ENABLING THIS - SPAM
        laser.from = self.laserData.from
        laser.to = self.laserData.to
        laser.aliveTime = 0
    end
end

function Vengeance9Xinull.deleteCurrentLasers()
    local methodName = "Delete Current Lasers"
    if onServer() then
        self.Log(methodName, "Calling on Server => Invoking on Client")
        broadcastInvokeClientFunction("deleteCurrentLasers")
        return
    else
        self.Log(methodName, "Calling on Client")
    end

    if valid(laser) then 
        Sector():removeLaser(laser) 
    end
end

--endregion

--region #SYNC

function Vengeance9Xinull.syncLaserData(dataIn)
    if onServer() then
        broadcastInvokeClientFunction("syncLaserData", self.laserData)
    else
        if dataIn then
            self.laserData = dataIn
        else
            invokeServerFunction("syncLaserData")
        end
    end
end
callable(Vengeance9Xinull, "syncLaserData")

--endregion

--region #LOG / SECURE / RESTORE

function Vengeance9Xinull.Log(methodName, msg)
    if self._Debug == 1 then
        print("[Vengeance9Xinull] - [" .. tostring(methodName) .. "] - " .. tostring(msg))
    end
end

function Vengeance9Xinull.secure()
    local methodName = "Secure"
    self.Log(methodName, "Securing self.data")

    self.data.physDamageTaken = self.damageTakenTable[DamageType.Physical]
    self.data.antiDamageTaken = self.damageTakenTable[DamageType.AntiMatter]
    self.data.plasDamageTaken = self.damageTakenTable[DamageType.Plasma]
    self.data.elecDamageTaken = self.damageTakenTable[DamageType.Electric]
    self.data.enrgDamageTaken = self.damageTakenTable[DamageType.Energy]

    return self.data
end

function Vengeance9Xinull.restore(values)
    local methodName = "Restore"
    self.Log(methodName, "Resotring self.data")
    self.data = values

    self.damageTakenTable[DamageType.Physical] =    self.data.physDamageTaken
    self.damageTakenTable[DamageType.AntiMatter] =  self.data.antiDamageTaken
    self.damageTakenTable[DamageType.Plasma] =      self.data.plasDamageTaken
    self.damageTakenTable[DamageType.Electric] =    self.data.elecDamageTaken
    self.damageTakenTable[DamageType.Energy] =      self.data.enrgDamageTaken
end

--endregion