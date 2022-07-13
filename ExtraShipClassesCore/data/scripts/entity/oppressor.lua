package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Oppressor
Oppressor = {}
local self = Oppressor

self._Debug = 1

self._Data = {}
self._Data._Multiplier = nil
self._Data._Ticks = nil
self._Data._MaxTicks = nil

function Oppressor.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Adding v1 of Oppressor.lua to entity.")

    self._Data = _Values or {}

    self._Data._Multiplier = self._Data._Multiplier or 1.25
    self._Data._MaxTicks = self._Data._MaxTicks or 30
    self._Data._Ticks = 0
end

function Oppressor.getUpdateInterval()
    return 60
end

function Oppressor.updateServer(_TimeStep)
    self.OppressorBuff()
end

--Called in the Sector context.
function Oppressor.OppressorBuff()
    local _MethodName = "OppressorBuff"

    local _DamageMultiplier = (Entity().damageMultiplier or 1)

    if self._Data._Ticks <= self._Data._MaxTicks then
        _DamageMultiplier = _DamageMultiplier * self._Data._Multiplier
    else
        --Go additive after a while.
        _DamageMultiplier = _DamageMultiplier + self._Data._Multiplier
    end
    self._Data._Ticks = self._Data._Ticks + 1

    Entity().damageMultiplier = _DamageMultiplier

    self.Log(_MethodName, "Damage multiplier is now " .. tostring(_DamageMultiplier))

    local direction = random():getDirection()
    local direction2 = random():getDirection()
    local direction3 = random():getDirection()
    broadcastInvokeClientFunction("animation", direction, direction2, direction3)
end

--region #CLIENT functions

function Oppressor.animation(direction, direction2, direction3)
    local _Sector = Sector()
    _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(1.0, 0.0, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction2, ColorRGB(1.0, 0.0, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction3, ColorRGB(1.0, 0.0, 0.0), 0.3)
end

--endregion

--region #CLIENT / SERVER functions

function Oppressor.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Oppressor] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Oppressor.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Oppressor.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion