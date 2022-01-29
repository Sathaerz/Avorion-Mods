package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

--namespace LLTESide6BuildShipment
LLTESide6BuildShipment = {}
local self = LLTESide6BuildShipment

self._Data = {}

self._Debug = 0

--region #INIT

function LLTESide6BuildShipment.initialize()
    local _MethodName = "Initialize"
    if onServer() then
        self.Log(_MethodName, "Calling on Server")
    else
        self.Log(_MethodName, "Calling on Client")
    end
end

--endregion

--region #SERVER CALLS

function LLTESide6BuildShipment.startServerJob()
    local _MethodName = "Start Server Job"
    self.Log(_MethodName, "Calling on Server")

    local _Player = Player(callingPlayer)

    if not self._Data._RunningJob then
        self.Log(_MethodName, "Player " .. _Player.name .. " paying 5000 Avo - starting server / client job to build shipment.")

        if _Player:canPayResource(Material(MaterialType.Avorion), 5000) then
            _Player:payResource("Paid 5000 Avorion to build the shipment.", Material(MaterialType.Avorion), 5000)
            self._Data._RunningJob = { _Executed = 0, _Duration = 10, _PlayerFor = _Player.index }
            broadcastInvokeClientFunction("startClientJob")
        else
            _Player:sendChatMessage(Entity(), ChatMessageType.Normal,  "We don't have enough Avorion to build the shipment!")
        end
    else
        _Player:sendChatMessage(Entity(), ChatMessageType.Normal,  "Your Avorion shipment is being built!")
    end
end
callable(LLTESide6BuildShipment, "startServerJob")

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function LLTESide6BuildShipment.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)

    self._PlayerIndex = playerIndex

    --if the player does not have the side mission 6 script, just kill it.
    if not _Player:hasScript("lltesidemission6.lua") then
        terminate()
        return
    end

    local craft = _Player.craft
    if craft == nil then return false end

    return true
end

function LLTESide6BuildShipment.initUI()
    ScriptUI():registerInteraction("Build Avorion Shipment", "startJob", 99)
end

function LLTESide6BuildShipment.startJob(_EntityIndex)
    local _MethodName = "Start Job"

    if onClient() then
        self.Log(_MethodName, "Invoking Server Function")
        invokeServerFunction("startServerJob")
    end
end

function LLTESide6BuildShipment.startClientJob()
    self._Data._RunningJob = { _Executed = 0, _Duration = 10 }
end

function LLTESide6BuildShipment.renderUIIndicator(px, py, size)
    local x = px - size / 2;
    local y = py + size / 2;

    if self._Data._RunningJob then
        local _Executed =  self._Data._RunningJob._Executed
        local _Duration =  self._Data._RunningJob._Duration

        if _Executed < _Duration then 
            -- outer rect
            local dx = x
            local dy = y

            local sx = size + 2
            local sy = 4

            drawRect(Rect(dx, dy, sx + dx, sy + dy), ColorRGB(0, 0, 0));

            -- inner rect
            sx = sx - 2
            sy = sy - 2

            sx = sx * _Executed / _Duration

            drawRect(Rect(dx + 1, dy + 1, sx + dx + 1, sy + dy + 1), ColorRGB(0.66, 0.66, 1.0));
        end
    end
end

--endregion

--region #CLIENT / SERVER CALLS

function LLTESide6BuildShipment.getUpdateInterval()
    return 1.0
end

function LLTESide6BuildShipment.update(_TimeStep)
    local _MethodName = "Build Shipment Update"
    if self._Data._RunningJob then
        self.Log(_MethodName, "Updating running job.")
        self._Data._RunningJob._Executed = self._Data._RunningJob._Executed + _TimeStep

        local _Executed = self._Data._RunningJob._Executed
        local _Duration = self._Data._RunningJob._Duration
        
        if _Executed >= _Duration then 
            --Add the retrive script to the entity, then terminate this script.
            --Obviously this is only done on the server.
            if onServer() then
                self.Log(_MethodName, "Executed " .. tostring(_Executed) .. " equals or exceeds Duration " .. tostring(_Duration) .. " - terminating and adding getShipment")
                local _Entity = Entity()
                local f = Faction(self._Data._RunningJob._PlayerFor)
                if f then
                    f:sendChatMessage(Entity(), ChatMessageType.Normal, "We finished building the Avorion Shipment. You can pick it up in \\s(%1%:%2%)."%_t, Sector():getCoordinates())
                end
                _Entity:addScriptOnce("player/missions/empress/side/side6/llteside6getshipment.lua")
                terminate()
                return
            end
        end
    end
end

function LLTESide6BuildShipment.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[LLTE Side 6 Build Shipment] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion

--region #SECURE / RESTORE

function LLTESide6BuildShipment.secure()
    return self._Data
end

function LLTESide6BuildShipment.restore(_Values)
    self._Data = _Values
end

--endregion