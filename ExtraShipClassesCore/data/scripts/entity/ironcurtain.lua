package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--namespace IronCurtain
IronCurtain = {}
local self = IronCurtain

--Named after that old red alert unit that would give player units temporary invincibility
self._Data = {}

self._Debug = 0

function IronCurtain.initialize(_Values)
    local methodName = "Initialize"
    self.Log(methodName, "Initializing Iron Curtain v18")

    self._Data = _Values or {}

    self._Data._Duration = self._Data._Duration or 120
    self._Data._MinDura = self._Data._MinDura or 0.25

    --The player can't alter these.
    self._Data._TimeActive = 0
    self._Data._Active = false
    self._Data._SentMessage = false

    if onServer() then
        Entity():registerCallback("onDamaged", "onDamaged")
    end
end

function IronCurtain.getUpdateInterval()
    return 2
end

function IronCurtain.updateServer(_TimeStep)
    local methodName = "Update Server"

    local _entity = Entity()
    local _durability = Durability()

    if self._Data._Active then
        self._Data._TimeActive = self._Data._TimeActive + _TimeStep

        local _random = random()

        local direction = _random:getDirection()
        local direction2 = _random:getDirection()
        local direction3 = _random:getDirection()
        broadcastInvokeClientFunction("animation", direction, direction2, direction3)

        if self._Data._TimeActive > self._Data._Duration then
            self.Log(methodName, "Duration is up - resetting invincibility.")
            _entity.invincible = false
            _durability.invincibility = 0.0

            Sector():broadcastChatMessage("", 3, "The ${_SHIP}'s iron curtain expires!" % { _SHIP = Entity().translatedTitle })
            terminate()
            return
        end
    else
        _durability.invincibility = self._Data._MinDura --So we don't get blasted before invincibility can be set.
    end
end

function IronCurtain.onDamaged(_OwnID, _Amount, _InflictorID)
    local methodName = "On Damaged"

    local _Entity = Entity()
    local _Ratio = _Entity.durability / _Entity.maxDurability
    local _MinRatio = self._Data._MinDura + 0.01 --Fudge by 1%

    if _Ratio <= _MinRatio then
        --Super spammy
        --self.Log(methodName, "HP Ratio low enough - activating!")

        if not self._Data._SentMessage then
            Sector():broadcastChatMessage("", 3, "The ${_SHIP} activates its iron curtain!" % { _SHIP = Entity().translatedTitle })
            self._Data._SentMessage = true
        end
        
        _Entity.invincible = true
        self._Data._Active = true
    end
end

--region #CLIENT FUNCTIONS

function IronCurtain.animation(direction, direction2, direction3)
    local _Sector = Sector()
    _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(0.25, 0.25, 0.25), 0.4)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction2, ColorRGB(0.25, 0.25, 0.25), 0.4)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction3, ColorRGB(0.25, 0.25, 0.25), 0.4)
end

--endregion

--region #CLIENT / SERVER functions

function IronCurtain.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[IronCurtain] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function IronCurtain.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function IronCurtain.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion