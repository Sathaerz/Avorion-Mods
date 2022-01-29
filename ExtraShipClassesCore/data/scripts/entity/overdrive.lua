package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

ESCCUtil = include("esccutil")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Overdrive
Overdrive = {}
local self = Overdrive

self._Debug = 0

self._Data = {}
self._Data._TimeInPhase = 0
self._Data._AttackMode = false
self._Data._LowDamageMultiplier = nil
self._Data._HighDamageMultiplier = nil
self._Data._OverdriveMultiplier = nil

function Overdrive.initialize(_OverdriveMultiplier)
    _OverdriveMultiplier = _OverdriveMultiplier or 2

    self._Data._OverdriveMultiplier = _OverdriveMultiplier
end

function Overdrive.getUpdateInterval()
    return 2 --Update every 2 seconds.
end

function Overdrive.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self._Data._TimeInPhase = self._Data._TimeInPhase + _TimeStep
    local _Entity = Entity()
    local _ShowAnimation = false
    
    if not self._Data._LowDamageMultiplier then
        --Get the multiplier on the first update of the server.
        local _Multiplier = (_Entity.damageMultiplier or 1)
        self.Log(_MethodName, "Entity damage multplier is " .. tostring(_Entity.damageMultiplier))
        self._Data._LowDamageMultiplier = _Multiplier
        self._Data._HighDamageMultiplier = _Multiplier * self._Data._OverdriveMultiplier
    end

    --1 minute out, 30 seconds in.
    if self._Data._AttackMode then
        if self._Data._TimeInPhase >= 20 then
            --20 seconds have passed. Flip us to being OUT of the mode
            self._Data._AttackMode = false
            self._Data._TimeInPhase = 0
            _Entity.damageMultiplier = self._Data._LowDamageMultiplier
            self.Log(_MethodName, "Swapping modes. Entity damage multiplier is now " .. tostring(_Entity.damageMultiplier))
        else
            --blink to give a visual indication of the ship being in MAXIMUM OVERDRIVE
            _ShowAnimation = true
        end
    else
        if self._Data._TimeInPhase >= 30 then
            --30 seconds have passed. Flip us to being IN the mode.
            self._Data._AttackMode = true
            self._Data._TimeInPhase = 0
            _Entity.damageMultiplier = self._Data._HighDamageMultiplier
            _ShowAnimation = true
            self.Log(_MethodName, "Swapping modes. Entity damage multiplier is now " .. tostring(_Entity.damageMultiplier))
        end
    end

    if _ShowAnimation then
        local direction = random():getDirection()
        broadcastInvokeClientFunction("animation", direction)
    end
end

function Overdrive.avengerBuff(_Multiplier)
    self._Data._LowDamageMultiplier = self._Data._LowDamageMultiplier * _Multiplier
    self._Data._HighDamageMultiplier = self._Data._HighDamageMultiplier * _Multiplier
end

function Overdrive.animation(direction)
    ESCCUtil.compatibleJumpAnimation(Entity(), direction, ColorRGB(1.0, 0.0, 0.0), 0.2)
end

--region #CLIENT / SERVER functions

function Overdrive.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Overdrive] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Overdrive.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Overdrive.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion