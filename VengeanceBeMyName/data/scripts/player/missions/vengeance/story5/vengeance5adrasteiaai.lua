package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

--namespace Vengeance5AdrasteiaAI
Vengeance5AdrasteiaAI = {}
local self = Vengeance5AdrasteiaAI

self._Debug = 0
self._Target_Invincible_Debug = 0

self.data = {}
--[[
    Here's a guide to how this thing works:
        _CurrentTarget  = The current target of this entity.
]]

function Vengeance5AdrasteiaAI.initialize(_Values)
    local methodName = "Initialize"
    self.Log(methodName, "Initializing Vengeance 5 Adrasteia AI v3 script on entity.")

    self.data = _Values or {}

    self.data.armsFortMinDistance = 2800
end

function Vengeance5AdrasteiaAI.getUpdateInterval()
    return 2
end

function Vengeance5AdrasteiaAI.updateServer(_TimeStep)
    local methodName = "Update Server"

    local _sector = Sector()
    local _entity = Entity()
    local myAI = ShipAI()
    
    self.Log(methodName, "Current AI state is " .. tostring(myAI.state))

    local distToArmsFort = 0
    local cruiserToRunTo = nil
    local nearestCruiserDistance = math.huge

    local scriptTbl = { _sector:getEntitiesByScriptValue("_vbmn5_arms_fortress") }
    local armsFort = scriptTbl[1]
    if armsFort and valid(armsFort) then
        distToArmsFort = _entity:getNearestDistance(armsFort)
    else
        distToArmsFort = math.huge
    end

    local cruiserTbl = { _sector:getEntitiesByScriptValue("is_adrasteia_missile_ship") }
    for _, cruiser in pairs(cruiserTbl) do
        local distToCruiser = _entity:getNearestDistance(cruiser)
        if distToCruiser < nearestCruiserDistance then
            nearestCruiserDistance = distToCruiser
            cruiserToRunTo = cruiser
        end
    end

    --First, check to see whether or not we are too close to the arms fortress. If we are, stop and start heading for the nearest missile cruiser.
    if distToArmsFort < self.data.armsFortMinDistance then
        self.Log(methodName, "Too closer to arms fort. Moving away.")
        self.data.currentTarget = nil --Dump current target.
        if myAI.state ~= AIState.LinearFly then
            myAI:stop()
        end
        if cruiserToRunTo then
            myAI:setFlyLinear(cruiserToRunTo.translationf, 0, false)
        else
            local dir = normalize(armsFort.translationf - _entity.translationf)
            local goToPos = dir * 20000
            myAI:setFlyLinear(goToPos, 0, false)
        end
    else
        if self.data.currentTarget == nil or not valid(self.data.currentTarget) then
            self.Log(methodName, "Target is nil or not valid. Picking a new target.")
            self.data.currentTarget = self.pickNewTarget(armsFort)
        end
        if self.data.currentTarget and valid(self.data.currentTarget) then
            if myAI.attackedEntity ~= self.data.currentTarget.index then
                self.Log(methodName, "Ship not attacking picked target - attacking picked target.")
                myAI:setAttack(self.data.currentTarget)
            end
        else
            if not self.data.currentTarget then
                self.Log(methodName, "Current Target is null.")
            end
            if not valid(self.data.currentTarget) then
                self.Log(methodName, "Current Target is not valid.")
            end
            --Find cruiser to run to, or just idle
            if cruiserToRunTo then
                myAI:setFlyLinear(cruiserToRunTo.translationf, 500, false)
            else
                myAI:setIdle()
            end
        end
    end
end

function Vengeance5AdrasteiaAI.pickNewTarget(armsFortress)
    local methodName = "Pick New Target"
    local _sector = Sector()

    local enemies = { _sector:getEntitiesByScriptValue("is_pirate") }

    local targetCandidates = {}
    for _, nme in pairs(enemies) do
        if nme.type == EntityType.Ship then
            if armsFortress and valid(armsFortress) then
                if nme:getNearestDistance(armsFortress) > self.data.armsFortMinDistance then
                    table.insert(targetCandidates, nme)
                end
            else
                table.insert(targetCandidates, nme) --No arms fortress left so we don't care about safe distance.
            end
        end
    end

    --Log # of enemies, etc.
    self.Log(methodName, "Raw number of target candidates found : " .. tostring(#targetCandidates) .. " out of " .. tostring(#enemies) .. " enemies")

    if #targetCandidates > 0 then
        local chosenCandidate = nil
        local attempts = 0

        self.Log(methodName, "Found at least one suitable target. Picking a random one.")

        while not chosenCandidate and attempts < 10 do
            local randomPick = randomEntry(targetCandidates)
            if self.invincibleTargetCheck(randomPick) then
                chosenCandidate = randomPick
            end
            attempts = attempts + 1
        end

        if not chosenCandidate then
            self.Log(methodName, "Could not find a non-invincible target in 10 tries - picking one at random")
            chosenCandidate = randomEntry(targetCandidates)
        end

        self.Log(methodName, "Chosen candidate is entity " .. tostring(chosenCandidate.name))
        
        return chosenCandidate
    else
        self.Log(methodName, "WARNING - Could not find any target candidates.")
        return nil
    end
end

function Vengeance5AdrasteiaAI.invincibleTargetCheck(entity)
    if not entity.invincible or self._Target_Invincible_Debug == 1 then
        return true
    else
        return false
    end
end

--region #CLIENT / SERVER CALLS

function Vengeance5AdrasteiaAI.Log(methodName, _Msg)
    if self._Debug == 1 then
        print("[VBMN5 Adrasteia AI] - [" .. tostring(methodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Vengeance5AdrasteiaAI.secure()
    local methodName = "Secure"
    self.Log(methodName, "Securing self.data")
    return self.data
end

function Vengeance5AdrasteiaAI.restore(_Values)
    local methodName = "Restore"
    self.Log(methodName, "Restoring self.data")
    self.data = _Values
end

--endregion