package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

-- namespace Vengeance5CommRelayActivate
Vengeance5CommRelayActivate = {}
local self = Vengeance5CommRelayActivate

self._Debug = 0

self.data = {}

function Vengeance5CommRelayActivate.initialize(values)
    local methodName = "Initialize"

    self.data = values or {}

    if onServer() and not _restoring then
        self.data.timeToActivate = self.data.timeToActivate or 40

        self.data.activationTimer = 0
        self.data.animationTimer = 0
        self.data.firstMessageSent = false
        self.data.secondMessageSent = false
    end

    self.Log(methodName, "Activation timer is " .. tostring(self.data.activationTimer) .. " and animation timer is " .. tostring(self.data.animationTimer))
end

function Vengeance5CommRelayActivate.getUpdateInterval()
    return 0.25
end

function Vengeance5CommRelayActivate.updateServer(timeStep)
    self.data.activationTimer = self.data.activationTimer + timeStep
    self.data.animationTimer = self.data.animationTimer + timeStep

    local _entity = Entity()

    _entity:setValue("_vbmn5_time_until_relay_active", self.data.timeToActivate - self.data.activationTimer)

    if self.data.animationTimer >= 2 then
        self.data.animationTimer = 0
        broadcastInvokeClientFunction("animation")
    end

    if self.data.activationTimer >= 0 and not self.data.firstMessageSent then
        Sector():broadcastChatMessage(_entity, ChatMessageType.Chatter, "We're under attack! Activate the relay! If we boost the signal we can punch through the jamming!")
        self.data.firstMessageSent = true
    end

    if self.data.activationTimer >= (self.data.timeToActivate / 2) and not self.data.secondMessageSent then
        Sector():broadcastChatMessage(_entity, ChatMessageType.Chatter, "We've almost got it! Hold on for ${_SECONDS} more seconds!" % { _SECONDS = tostring(math.floor(self.data.timeToActivate / 2))})
        self.data.secondMessageSent = true
    end

    if self.data.activationTimer >= self.data.timeToActivate then
        Sector():sendCallback("vbmnStory5FailCommRelayActivation")
        terminate()
        return
    end
end

function Vengeance5CommRelayActivate.animation()
    local _sector = Sector()
    local _random = random()
    local _entity = Entity()
    local _plan = Plan(_entity)

    local blocks = _plan.numBlocks
    local sparks = math.min(200, blocks)

    local animColor = ColorRGB(0, 0.1, 1.0)

    for i = 1, sparks do
        local block = _plan:getNthBlock(_random:getInt(0, blocks - 1))

        local center = block.box.center
        local dir = _random:getDirection()
        local factor = 1 + _random:getFloat(-3, 3)
        local size = _entity.radius * 0.075

        _sector:createSpark(center, dir * 4 * factor, size, 2.25, animColor, 0, _entity)

        local factor2 = 0.5
        _sector:createSpark(center, dir * 4 * factor2, size, 2.5, animColor, 0, _entity)
    end

    local direction = _random:getDirection()

    _sector:createHyperspaceJumpAnimation(_entity, direction, animColor, 0.2)
end

--regin #LOG

function Vengeance5CommRelayActivate.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Vengeance 5 Comm Array Active] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion