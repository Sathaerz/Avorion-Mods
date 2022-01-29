package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")
MissionUT = include("missionutility")

--namespace LLTESide6GetShipment
LLTESide6GetShipment = {}
local self = LLTESide6GetShipment

self._Data = {}

self._Debug = 0

--region #INIT

function LLTESide6GetShipment.initialize()
    local _MethodName = "Initialize"
    if onServer() then
        self.Log(_MethodName, "Calling on Server")
    else
        self.Log(_MethodName, "Calling on Client")
    end
end

--endregion

--region #SERVER CALLS

function LLTESide6GetShipment.retrieveShipmentServer()
    local _MethodName = "Retrieve Shipment Server"
    self.Log(_MethodName, "Calling on Server")

    local _Player = Player(callingPlayer)
    --Get the player's current ship.
    local _Ship = Entity(_Player.craftIndex)
    local _Cargo = CargoBay(_Ship)

    self.Log(_MethodName, "Checking free space.")
    if _Cargo then
        if _Cargo.freeSpace >= 75 then
            self.Log(_MethodName, "Enough space.")
            local _Good = TradingGood("Avorion Shipment", plural_t("Avorion Shipment", "Avorion Shipments", 1), "A crate full of Avorion", "data/textures/icons/lead.png", 358000, 75)
            _Cargo:addCargo(_Good, 1)
            terminate()
            return
        else
            self.Log(_MethodName, "Not enough space.")
            --Error: not enough space.
            _Player:sendChatMessage(Entity().title, ChatMessageType.Error,  "You need at least 75 cargo space to pick up the shipment.")
        end
    else
        --Error: no cargo.
        _Player:sendChatMessage(Entity().title, ChatMessageType.Error,  "You need a cargo hold with at least 75 cargo space to pick up the shipment.")
    end

end
callable(LLTESide6GetShipment, "retrieveShipmentServer")

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function LLTESide6GetShipment.interactionPossible(playerIndex)
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

function LLTESide6GetShipment.initUI()
    ScriptUI():registerInteraction("Retrieve Avorion Shipment", "onRetrieve", 99)
end

function LLTESide6GetShipment.onRetrieve(_EntityIndex)
    local _MethodName = "On Retrieve"
    self.Log(_MethodName, "Beginning...")
    --Use the mission UT for the two dialog thingies. One of them should invoke the server function to retrieve the goods.
    local _Condition = function() return true end --No conditions - once we get here this should always succeed.

    local _DockedMaker = function()
        local _Docked = {}
        _Docked.text = "Transferring the shipment now."
        _Docked.onEnd = "onDockedEnd"

        return _Docked
    end

    local _UndockedMaker = function()
        local _Undocked = {}
        _Undocked.text = "You'll need to dock for us to transfer the shipment. Come to the nearest dock and we'll have it over in no time."

        return _Undocked
    end

    local _FailedMaker = function()
        return {}
    end

    self.Log(_MethodName, "Getting docked dialog selector.")
    MissionUT.dockedDialogSelector(Entity().index, _Condition, _FailedMaker, _UndockedMaker, _DockedMaker)    
end

function LLTESide6GetShipment.onDockedEnd()
    invokeServerFunction("retrieveShipmentServer")
end

--endregion

--region #CLIENT / SERVER CALLS

function LLTESide6GetShipment.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[LLTE Side 6 Get Shipment] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion

--region #SECURE / RESTORE

function LLTESide6GetShipment.secure()
    return self._Data
end

function LLTESide6GetShipment.restore(_Values)
    self._Data = _Values
end

--endregion