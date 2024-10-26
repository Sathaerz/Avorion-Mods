package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")
MissionUT = include("missionutility")
HorizonUtil = include("horizonutil")

--namespace HorizonStory2Dialog4
HorizonStory2Dialog4 = {}
local self = HorizonStory2Dialog4

self._Debug = 0

--region #INIT

function HorizonStory2Dialog4.initialize()
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HorizonStory2Dialog4.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)
    local _Entity = Entity()

    local craft = _Player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(_Entity)

    local targetplayerid = _Entity:getValue("horizon_story_player")

    if dist < 1000 and playerIndex == targetplayerid then
        return true
    end

    return false
end

function HorizonStory2Dialog4.initUI()
    ScriptUI():registerInteraction("Pick up the Artifact", "onPickup", 99)
end

function HorizonStory2Dialog4.onPickup(_EntityIndex)
    local _MethodName = "On Pickup"
    self.Log(_MethodName, "Beginning...")
    --Use the mission UT for the two dialog thingies. One of them should invoke the server function to retrieve the goods.
    local _Condition = function() return true end --No conditions - once we get here this should always succeed.

    local _Talker = "Mace"
    local _TalkerColor = HorizonUtil.getDialogMaceTalkerColor()
    local _TextColor = HorizonUtil.getDialogMaceTextColor()

    local _DockedMaker = function()
        local _Docked = {}
        _Docked.text = "Here's the artifact. Thanks again for taking care of this."
        _Docked.talker = _Talker
        _Docked.textColor = _TextColor
        _Docked.talkerColor = _TalkerColor
        _Docked.onEnd = "onDockedEnd"

        return _Docked
    end

    local _UndockedMaker = function()
        local _Undocked = {}
        _Undocked.text = "You need to dock before I can transfer the artifact!!"
        _Undocked.talker = _Talker
        _Undocked.textColor = _TextColor
        _Undocked.talkerColor = _TalkerColor

        return _Undocked
    end

    local _FailedMaker = function()
        return {}
    end

    self.Log(_MethodName, "Getting docked dialog selector.")
    MissionUT.dockedDialogSelector(Entity().index, _Condition, _FailedMaker, _UndockedMaker, _DockedMaker)    
end

function HorizonStory2Dialog4.onDockedEnd()
    invokeServerFunction("retrieveArtifactServer")
end

--endregion

--region #SERVER CALLS

function HorizonStory2Dialog4.retrieveArtifactServer()
    local _MethodName = "Retrieve Artifact Server"
    self.Log(_MethodName, "Calling on Server")

    local _Player = Player(callingPlayer)
    --Get the player's current ship.
    local _Ship = Entity(_Player.craftIndex)
    local _Cargo = CargoBay(_Ship)

    self.Log(_MethodName, "Checking free space.")
    if _Cargo then
        if _Cargo.freeSpace >= 1 then
            self.Log(_MethodName, "Enough space.")
            local _Good = TradingGood("Ancient Artifact", plural_t("Ancient Artifact", "Ancient Artifacts", 1), "A mysterious artifact. It looks quite old.", "data/textures/icons/metal-scale.png", 0, 1)
            _Good.tags = {mission_relevant = true}
            _Cargo:addCargo(_Good, 1)
            terminate()
            return
        else
            self.Log(_MethodName, "Not enough space.")
            --Error: not enough space.
            _Player:sendChatMessage(Entity().title, ChatMessageType.Error,  "You need at least 1 cargo space to pick up the artifact.")
        end
    else
        --Error: no cargo.
        _Player:sendChatMessage(Entity().title, ChatMessageType.Error,  "You need a cargo hold with at least 1 cargo space to pick up the artifact.")
    end

end
callable(HorizonStory2Dialog4, "retrieveArtifactServer")

--endregion

--region #SECURE / RESTORE / LOG

function HorizonStory2Dialog4.secure()
    return self._Data
end

function HorizonStory2Dialog4.restore(_Values)
    self._Data = _Values
end

function HorizonStory2Dialog4.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 2 Dialog 4] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion