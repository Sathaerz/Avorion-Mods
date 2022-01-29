package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

ESCCUtil = include("esccutil")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Meathook2
Meathook2 = {}
local self = Meathook2

--If distance is greater than 9,500 from center of the sector, pull in.
self._Debug = 0

self._Data = {}

function Meathook2.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Adding v23 of meathook.lua to entity.")

    self._Data = _Values or {}

    --Values the player isn't meant to adjust
    

    --Values the player is meant to adjust.
    self._Data._MaxDistance = self._Data._MaxDistance or 9500

    Entity():registerCallback("onDestroyed", "onDestroyed")
end

--region #CLIENT / SERVER functions

function Meathook2.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Meathook2] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Meathook2.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Meathook2.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion