package.path = package.path .. ";data/scripts/lib/?.lua"

ESCCUtil = include("esccutil")

--namespace AIEscortAttacker
AIEscortAttacker = {}
local self = AIEscortAttacker

self._Debug = 0

self._Data = {}
--[[
    Here's a guide to how this thing works:
        _TargetTag      = Targets entities with this script value.
        _CurrentTarget  = The current target of this entity.
]]
self._Data._TargetTag = nil
self._Data._CurrentTarget = nil

function AIEscortAttacker.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Initializing AI Escort Attacker v3 script on entity.")

    self._Data = _Values or {}
end

function AIEscortAttacker.getUpdateInterval()
    return 10
end

function AIEscortAttacker.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self.Log(_MethodName, "Running. Looking for tag " .. tostring(self._Data._TargetTag))

    local _ShipAI = ShipAI()

    --Pick a new target and attack that target.
    if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
        self._Data._CurrentTarget = self.pickNewTarget()
    end

    --If we couldn't find a new, valid target, just set the AI to aggressive.
    if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
        _ShipAI:setAggressive()
    else
        _ShipAI:setAttack(self._Data._CurrentTarget)
    end
end

function AIEscortAttacker.pickNewTarget()
    local _MethodName = "Pick New Target"
    local _Factionidx = Entity().factionIndex
    local _Rgen = ESCCUtil.getRand()

    local _Enemies = {Sector():getEnemies(_Factionidx)}
    local _TargetCandidates = {}

    for _, _Candidate in pairs(_Enemies) do
        if _Candidate:getValue(self._Data._TargetTag) then
            table.insert(_TargetCandidates, _Candidate)
        end
    end

    if #_TargetCandidates > 0 then
        self.Log(_MethodName, "Found " .. tostring(#_TargetCandidates) .. " suitable target. Picking a random one.")
        return _TargetCandidates[_Rgen:getInt(1, #_TargetCandidates)]
    else
        self.Log(_MethodName, "WARNING - Could not find any target candidates.")
        return nil
    end
end

--region #CLIENT / SERVER CALLS

function AIEscortAttacker.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[AI Escort Attacker] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function AIEscortAttacker.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function AIEscortAttacker.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion