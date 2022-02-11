package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--namespace IronCurtain
IronCurtain = {}
local self = IronCurtain

--Named after that old red alert unit that would give player units temporary invincibility
self._Data = {}
self._Data._Duration = nil
self._Data._TimeActive = nil
self._Data._MinDura = nil
self._Data._Active = nil
self._Data._SentMessage = false

self._Debug = 0

function IronCurtain.initialize(_MaxDuration, _MinDurability)
    _MaxDuration = _MaxDuration or 120
    _MinDurability = _MinDurability or 0.25

    self._Data._Duration = _MaxDuration
    self._Data._MinDura = _MinDurability
    self._Data._TimeActive = 0
    self._Data._Active = false

    if onServer() then
        Entity():registerCallback("onDamaged", "onDamaged")
    end
end

function IronCurtain.getUpdateInterval()
    return 5
end

function IronCurtain.updateServer(_TimeStep)
    if self._Data._Active then
        self._Data._TimeActive = self._Data._TimeActive + _TimeStep
        if self._Data._TimeActive > self._Data._Duration then
            Entity().invincible = false
            terminate()
            return
        end
    end
end

function IronCurtain.onDamaged(_OwnID, _Amount, _InflictorID)
    local _Sector = Sector()
    
    local _Entity = Entity()
    local _Ratio = _Entity.durability / _Entity.maxDurability
    local _MinRatio = self._Data._MinDura

    if _Ratio < _MinRatio then
        if not self._Data._SentMessage then
            self.sendMessage()
            self._Data._SentMessage = true
        end
        _Entity.invincible = true
        self._Data._Active = true
    end
end

function IronCurtain.sendMessage()
    Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Iron curtain activated!")
end

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