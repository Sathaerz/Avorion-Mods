package.path = package.path .. ";data/scripts/lib/?.lua"

LLTEUtil = include("llteutil")

include("stringutility")
include("callable")

--Let's try namespacing this. I want to see what happens.
--namespace LLTEStory1Dialogue2
LLTEStory1Dialogue2 = {}
local self = LLTEStory1Dialogue2

self._Data = {}

self._Debug = 0

function LLTEStory1Dialogue2.initialize()
    self._Data._Traitor = LLTEUtil.getRandomName(true, true)
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function LLTEStory1Dialogue2.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)

    self._PlayerIndex = playerIndex

    local craft = _Player.craft
    if craft == nil then return false end

    return true
end

function LLTEStory1Dialogue2.initUI()
    ScriptUI():registerInteraction("Contact the Traitor"%_t, "onContact", 99)
end

function LLTEStory1Dialogue2.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function LLTEStory1Dialogue2.getDialog()
    local _MethodName = "Get Dialogue"
    self.Log(_MethodName, "Beginning...")

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}

    d0.text = "Hello? Who is it this time? What do you want?"
    d0.answers = {
        { answer = "I'm back.", followUp = d1 },
        { answer = "Surprise.", followUp = d1 }
    }

    d1.text = "Uh... I... I... uh... h-hello."
    d1.answers = {
        {answer = "You tried to have me killed.", followUp = d2 }
    }

    d2.text = "W-well, look. When y-you're- HEY! WAIT! NO! [BLAMBLAMBLAMBLAMBLAM] AHHHHHHHHHHH-"
    d2.answers = {
        { answer = "... Hello?", followUp = d3 }
    }

    local _Name = self._Data._Traitor.name
    local _Pn1 = self._Data._Traitor.pn1
    local _Pn2 = self._Data._Traitor.pn2
    local _Tense = self._Data._Traitor.ptense

    d3.text = "Hello! Please accept our apologies for " .. _Name .. ". If we had realized " .. _Pn1 .. " " .. _Tense .. " a mole, we would have dealt with " .. _Pn2 .. " earlier. What do you need?"
    d3.answers = {
        { answer = "Do you know anything about a powerful group of pirates?", followUp = d8 }
    }

    d8.text = "... Perhaps. Who's asking?"
    d8.answers = {
        { answer = "The Cavaliers.", followUp = d4 }
    }

    d4.text = "The Cavaliers, huh? How is Adriana doing?"
    d4.answers = {
        { answer = "She is the Empress now.", followUp = d5 }
    }

    d5.text = "She actually did it? Amazing. We go way back. If she needs a favor, I'll oblige. I know the group you're talking about. They're nasty and powerful. I can point you to them, but you might be better softening them up first."
    d5.answers = {
        { answer = "I'm listening.", followUp = d6 }
    }

    d6.text = "I've got intel on a couple of shipments they're organizing. If you can take those out, you'll kneecap them. I'm uploading the data to your computer now. When you find them, the freighters will undoubtedly try to escape. Don't let them jump too many times, or you may lose track of them."
    d6.answers = {
        { answer = "Got it. Thanks.", onSelect = "onEnd" },
        { answer = "How do I know I can trust you?", followUp = d7 }
    }

    d7.text = "You don't. Sorry. Not much I can do about that. But let me put it this way, even if I'm leading you into another ambush, you'll get to kill more pirates. That's a reward unto itself, is it not?"
    d7.answers = {
        { answer = "Heh. That's a good point.", onSelect = "onEnd" },
        { answer = "Fair enough. Thank you.", onSelect = "onEnd" }
    }

    return d0
end

function LLTEStory1Dialogue2.onEnd()
    Player():invokeFunction("player/missions/empress/story/lltestorymission1.lua", "contactedTraitor")
    terminate()
    return
end

--region #CLIENT / SERVER CALLS

function LLTEStory1Dialogue2.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[LLTE Story 1 Dialog 2] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion