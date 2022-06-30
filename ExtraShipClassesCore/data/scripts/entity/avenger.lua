package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Avenger
Avenger = {}
local self = Avenger

self._Debug = 0

self._Data = {}
self._Data._Multiplier = nil

function Avenger.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Adding v3 of avenger.lua to entity.")

    self._Data = _Values or {}

    self._Data._Multiplier = self._Data._Multiplier or 1.2

    if onServer() then
        if Sector():registerCallback("onDestroyed", "onDestroyed") == 1 then
            self.Log(_MethodName, "Could not register onEntityDestroyed callback.")
        end
    end
end

--Called in the Sector context.
function Avenger.onDestroyed(_Entityidx, _LastDamageInflictor)
    local _MethodName = "OnDestroyed"
    self.Log(_MethodName, "Calling...")

    local _DestroyedEntity = Entity(_Entityidx)
    if _DestroyedEntity.type ~= EntityType.Ship and _DestroyedEntity.type ~= EntityType.Station then
        self.Log(_MethodName, "Destroyed entity type was not a ship or station - returning.")
        return
    end
    local _TargetFaction = _DestroyedEntity.factionIndex

    local _Ships = {Sector():getEntitiesByFaction(_TargetFaction)}
    for _, _Ship in pairs(_Ships) do
        if _Ship:hasScript("avenger.lua") then
            _Ship:invokeFunction("data/scripts/entity/avenger.lua", "avengerBuff")
            if _Ship:hasScript("overdrive.lua") then
                --buff the overdrive script as well.
                _Ship:invokeFunction("data/scripts/entity/overdrive.lua", "avengerBuff", self._Data._Multiplier)
            end
        end
    end
end

function Avenger.avengerBuff()
    local _MethodName = "AvengerBuff"
    local _DamageMultiplier = (Entity().damageMultiplier or 1) * self._Data._Multiplier
    Entity().damageMultiplier = _DamageMultiplier

    self.Log(_MethodName, "Damage multiplier is now " .. tostring(_DamageMultiplier))

    local direction = random():getDirection()
    local direction2 = random():getDirection()
    local direction3 = random():getDirection()
    broadcastInvokeClientFunction("animation", direction, direction2, direction3)
end

--region #CLIENT functions

function Avenger.animation(direction, direction2, direction3)
    local _Sector = Sector()
    _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(1.0, 0.4, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction2, ColorRGB(1.0, 0.6, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction3, ColorRGB(1.0, 0.6, 0.0), 0.3)
end

--endregion

--region #CLIENT / SERVER functions

function Avenger.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Avenger] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Avenger.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Avenger.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion