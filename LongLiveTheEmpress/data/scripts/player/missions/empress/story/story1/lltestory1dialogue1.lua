package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

--Let's try namespacing this. I want to see what happens.
--namespace LLTEStory1Dialogue1
LLTEStory1Dialogue1 = {}
local self = LLTEStory1Dialogue1

self._Data = {}

self._Debug = 0

--region #INIT

function LLTEStory1Dialogue1.initialize(_X, _Y)
    local _MethodName = "Initialize"
    if onServer() then
        _MethodName = _MethodName .. " SERVER"
        self.Log(_MethodName, "Calling on Server - setting self._Data")

        self._Data._X = _X
        self._Data._Y = _Y
    else
        _MethodName = _MethodName .. " CLIENT"
        self.Log(_MethodName, "Calling on Client - syncing")

        self.sync()
    end
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function LLTEStory1Dialogue1.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)

    self._PlayerIndex = playerIndex

    local craft = _Player.craft
    if craft == nil then return false end

    return true
end

function LLTEStory1Dialogue1.initUI()
    ScriptUI():registerInteraction("Contact the Cavaliers Informant"%_t, "onContact", 99)
end

function LLTEStory1Dialogue1.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function LLTEStory1Dialogue1.getDialog()
    local _MethodName = "Get Dialogue"
    self.Log(_MethodName, "Beginning...")

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}

    d0.text = "Hello? Hello? Who are you?"
    d0.answers = {
        {answer = "The Empress sent me. I'm here on behalf of The Cavaliers.", followUp = d1 }
    }

    d1.text = "The Empress? Huh? What do you want?"
    d1.answers = {
        {answer = "I'm looking for a powerful group of pirates.", followUp = d2 },
        {answer = "... Who are you?", followUp = d3 }
    }

    d2.text = "Those guys? They're a bunch of chumps, actually. You'll find them in sector (" .. self._Data._X .. ":" .. self._Data._Y .. ") They should be easy pickings."
    d2.answers = {
        { answer = "Acknowledged.", onSelect = "onEnd" }
    }

    d3.text = "That's none of your concern. Now, do you want your information or not?"
    d3.answers = {
        { answer = "Yes.", followUp = d5 },
        { answer = "... Tell me who you are first.", followUp = d4 }
    }

    d4.text = "Seriously, that's none of your concern. Don't you have anything better to do? Take your information and go."
    d4.answers = {
        { answer = "Okay, okay.", followUp = d5 },
        { answer = "Sure, whatever.", followUp = d5 },
    }

    d5.text = "Great. Now that you're done wasting my time... The guys you're after aren't as strong as you think. You can find them in sector (" .. self._Data._X .. ":" .. self._Data._Y .. "). I'll bet you can take them out without any problems."
    d5.onEnd = "onEnd"

    return d0
end

function LLTEStory1Dialogue1.onEnd()
    Player():invokeFunction("player/missions/empress/story/lltestorymission1.lua", "contactedInformant")
    terminate()
    return
end

--endregion

--region #CLIENT / SERVER CALLS

function LLTEStory1Dialogue1.sync(_X, _Y)
    local _MethodName = "Sync"

    if onClient() then
        _MethodName = _MethodName .. " CLIENT"
        self.Log(_MethodName, "Beginning...")
        if _X and _Y then
            self.Log(_MethodName, "Got coordinates. X is " .. tostring(_X) .. " and Y is " .. tostring(_Y))
            self._Data._X = _X
            self._Data._Y = _Y
        else
            invokeServerFunction("sync")
        end
    else
        _MethodName = _MethodName .. " SERVER"
        self.Log(_MethodName, "Beginning...")

        broadcastInvokeClientFunction("sync", self._Data._X, self._Data._Y)
    end
end
callable(LLTEStory1Dialogue1, "sync")

function LLTEStory1Dialogue1.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[LLTE Story 1 Dialog 1] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion

--region #SECURE / RESTORE

function LLTEStory1Dialogue1.secure()
    return self._Data
end

function LLTEStory1Dialogue1.restore(_Values)
    self._Data = _Values
end

--endregion