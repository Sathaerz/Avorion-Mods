package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Avenger
Avenger = {}
local self = Avenger

self._Debug = 0

self._Data = {}

function Avenger.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Adding v7 of avenger.lua to entity.")

    self._Data = _Values or {}

    self._Data._Multiplier = self._Data._Multiplier or 1.2
    self._Data._AllowMultiProc = self._Data._AllowMultiProc or false
    --Cannot be set by the player.
    self._Data._Invoked = false

    if onServer() then
        if Sector():registerCallback("onDestroyed", "onDestroyed") == 1 then
            self.Log(_MethodName, "Could not register onEntityDestroyed callback.")
        end
    end
end

--region #SERVER functions

function Avenger.getUpdateInterval()
    return 1
end

function Avenger.updateServer(_TimeStamp)
    self._Data._Invoked = false
end

function Avenger.avengerBuff()
    local _MethodName = "AvengerBuff"
    if not self._Data._Invoked then
        --If multiple procs in a second are allowed, don't set this to true so it can keep going off.
        if not self._Data._AllowMultiProc then
            self._Data._Invoked = true
        end

        local _entity = Entity()

        self.Log(_MethodName, "Current damage multiplier is " .. tostring(_entity.damageMultiplier))
    
        local _DamageMultiplier = (_entity.damageMultiplier or 1) * self._Data._Multiplier
        _entity.damageMultiplier = _DamageMultiplier
    
        self.Log(_MethodName, "Damage multiplier is now " .. tostring(_DamageMultiplier))
    
        local _random = random()

        local direction1 = _random:getDirection()
        local direction2 = _random:getDirection()
        local direction3 = _random:getDirection()
        broadcastInvokeClientFunction("animation", direction1, direction2, direction3)
    else
        self.Log(_MethodName, "Avenger has been invoked recently - waiting 1 second to clear.")
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

--endregion

--region #CLIENT functions

function Avenger.animation(direction, direction2, direction3)
    local _Sector = Sector()
    _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(1.0, 0.4, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction2, ColorRGB(1.0, 0.6, 0.0), 0.3)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction3, ColorRGB(1.0, 0.6, 0.0), 0.3)
end

--endregion

--region #LOG / SECURE / RESTORE

function Avenger.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Avenger] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

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