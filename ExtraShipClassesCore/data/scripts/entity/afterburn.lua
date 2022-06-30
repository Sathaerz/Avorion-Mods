package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Afterburn
Afterburn = {}
local self = Afterburn

self._Debug = 0

self._Data = {}
self._Data._TimeInPhase = 0
self._Data._BoostMode = false

function Afterburn.getUpdateInterval()
    return 2 --Update every 2 seconds.
end

function Afterburn.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self._Data._TimeInPhase = self._Data._TimeInPhase + _TimeStep
    local _Entity = Entity()
    local _ShowAnimation = false

    --1 minute out, 30 seconds in.
    if self._Data._BoostMode then
        if self._Data._TimeInPhase >= 20 then
            --20 seconds have passed. Flip us to being OUT of the mode
            self._Data._BoostMode = false
            self._Data._TimeInPhase = 0

            Afterburn.Log(_MethodName, "Exiting boost mode.")
            _Entity:addMultiplier(acceleration, 0.125)
            _Entity:addMultiplier(velocity, 0.125)
        else
            --blink to give a visual indication of the ship being in MAXIMUM Afterburn
            _ShowAnimation = true
        end
    else
        if self._Data._TimeInPhase >= 30 then
            --30 seconds have passed. Flip us to being IN the mode.
            self._Data._BoostMode = true
            self._Data._TimeInPhase = 0

            Afterburn.Log(_MethodName, "Entering boost mode.")
            _Entity:addMultiplier(acceleration, 8)
            _Entity:addMultiplier(velocity, 8)

            _ShowAnimation = true
        end
    end

    if _ShowAnimation then
        local direction = random():getDirection()
        broadcastInvokeClientFunction("animation", direction)
    end
end

function Afterburn.animation(direction)
    Sector():createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(1.0, 1.0, 0.0), 0.2)
end

--region #CLIENT / SERVER functions

function Afterburn.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Afterburn] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion