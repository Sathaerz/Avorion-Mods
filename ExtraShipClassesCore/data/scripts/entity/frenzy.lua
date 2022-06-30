package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

--namespace Frenzy
Frenzy = {}
local self = Frenzy

self._Data = {}
self._Data._Active = nil
self._Data._DamageThreshold = nil
self._Data._IncreasePerUpdate = nil
self._Data._UpdateCycle = nil

self._Debug = 1

function Frenzy.initialize(_Values)
    self._Data = _Values or {}

    self._Data._Active = false
    self._Data._Timer = 0

    self._Data._DamageThreshold = self._Data._DamageThreshold or 0.33
    self._Data._IncreasePerUpdate = self._Data._IncreasePerUpdate or 0.01
    self._Data._UpdateCycle = self._Data._UpdateCycle or 10

    if onServer() then
        Entity():registerCallback("onDamaged", "onDamaged")
    end
end

function Frenzy.getUpdateInterval()
    return 5
end

function Frenzy.updateServer(_TimeStep)
    local _MethodName = "On Update Server"
    if self._Data._Active then
        self._Data._Timer = self._Data._Timer + _TimeStep
        if self._Data._Timer >= self._Data._UpdateCycle then
            local _Entity = Entity()
            local _DmgFactor = (_Entity.damageMultiplier or 1) + self._Data._IncreasePerUpdate
            _Entity.damageMultiplier = _DmgFactor
            self._Data._Timer = 0

            self.Log(_MethodName, "Running update cycle - new damage multiplier is : " .. tostring(_DmgFactor))

            local direction = random():getDirection()
            broadcastInvokeClientFunction("animation", direction)

            if _Entity:hasScript("frenzy.lua") then
                --buff the overdrive script as well.
                _Entity:invokeFunction("data/scripts/entity/frenzy.lua", "frenzyBuff", self._Data._IncreasePerUpdate)
            end
        end
    end
end

function Frenzy.onDamaged(_OwnID, _Amount, _InflictorID)
    local _MethodName = "On Damaged"
    if not self._Data._Active then
        local _Entity = Entity()
        local _Ratio = _Entity.durability / _Entity.maxDurability
    
        if _Ratio < self._Data._DamageThreshold then
            self.Log(_MethodName, "Activating frenzy script.")
            self._Data._Active = true
        end
    end
end

--region #CLIENT functions

function Frenzy.animation(direction)
    Sector():createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(1.0, 0.0, 0.0), 0.2)
end

--endregion

--region #CLIENT / SERVER functions

function Frenzy.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Frenzy] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Frenzy.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Frenzy.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion