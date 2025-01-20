package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

--namespace PriorityAttacker
PriorityAttacker = {}
local self = PriorityAttacker

self._Debug = 0
self._Target_Invincible_Debug = 0

self._Data = {}
--[[
    Here's a guide to how this thing works:
        _TargetPriority = Targets enemies according to specific priorities. Defaults to 1.
                            1 - target enemies with the _TargetTag script value.
                            2 - target player or alliance owned ships only.
        _TargetTag      = Targets entities with this script value.
        _CurrentTarget  = The current target of this entity.
]]

function PriorityAttacker.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Initializing AI Priority Attacker v6 script on entity.")

    self._Data = _Values or {}

    self._Data._TargetPriority = self._Data._TargetPriority or 1
end

function PriorityAttacker.getUpdateInterval()
    return 10
end

function PriorityAttacker.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self.Log(_MethodName, "Running. Looking for tag " .. tostring(self._Data._TargetTag))

    local _ShipAI = ShipAI()
    local aiState = _ShipAI.state

    --Pick a new target and attack that target.
    if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
        self._Data._CurrentTarget = self.pickNewTarget()
    end

    --If we couldn't find a new, valid target, just set the AI to aggressive.
    if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
        if aiState ~= AIState.Attack and aiState ~= AIState.Aggressive then
            self.Log(_MethodName, "Picked target is dead and ship AI is not aggressive state - setting to general attacking state.")
            _ShipAI:setAggressive()
        end
    else
        if _ShipAI.attackedEntity ~= self._Data._CurrentTarget.index then
            self.Log(_MethodName, "Ship not attacking picked target - attacking picked target.")
            _ShipAI:setAttack(self._Data._CurrentTarget)
        end
    end
end

function PriorityAttacker.pickNewTarget()
    local _MethodName = "Pick New Target"
    local _Factionidx = Entity().factionIndex
    local _Sector = Sector()
    local _TargetPriority = self._Data._TargetPriority

    --Get the list of enemies. This is a bit of work since it includes wacky crap like turrets.
    local _RawEnemies = {_Sector:getEnemies(_Factionidx)}
    local _Enemies = {}
    for _, _RawEnemy in pairs(_RawEnemies) do
        if _RawEnemy.type == EntityType.Ship or _RawEnemy.type == EntityType.Station then
           table.insert(_Enemies, _RawEnemy) 
        end
    end

    local _TargetCandidates = {}

    local _TargetPriorityFunctions = {
        function() --1 = Targets enemies with the target script value / tag as set by _TargetTag
            for _, _Candidate in pairs(_Enemies) do
                if _Candidate:getValue(self._Data._TargetTag) then
                    table.insert(_TargetCandidates, _Candidate)
                end
            end
        end,
        function() --2 = Targets player / alliance enemies only
            for _, _Candidate in pairs(_Enemies) do
                if _Candidate.playerOrAllianceOwned then
                    table.insert(_TargetCandidates, _Candidate)
                end
            end
        end
    }

    _TargetPriorityFunctions[_TargetPriority]()

    if #_TargetCandidates > 0 then
        local chosenCandidate = nil
        local attempts = 0

        self.Log(_MethodName, "Found at least one suitable target. Picking a random one.")

        while not chosenCandidate and attempts < 10 do
            local randomPick = getRandomEntry(_TargetCandidates)
            if self.invincibleTargetCheck(randomPick) then
                chosenCandidate = randomPick
            end
            attempts = attempts + 1
        end

        if not chosenCandidate then
            self.Log(_MethodName, "Could not find a non-invincible target in 10 tries - picking one at random")
            chosenCandidate = getRandomEntry(_TargetCandidates)
        end
        
        return chosenCandidate
    else
        self.Log(_MethodName, "WARNING - Could not find any target candidates.")
        return nil
    end
end

function PriorityAttacker.invincibleTargetCheck(entity)
    if not entity.invincible or self._Target_Invincible_Debug == 1 then
        return true
    else
        return false
    end
end

--region #CLIENT / SERVER CALLS

function PriorityAttacker.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[AI Escort Attacker] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function PriorityAttacker.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function PriorityAttacker.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion