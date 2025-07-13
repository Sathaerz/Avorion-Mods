package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

HorizonUtil = include("horizonutil")

--namespace HorizonStory2Dialog1
HorizonStory2Dialog1 = {}
local self = HorizonStory2Dialog1

self._Debug = 0

--region #INIT

function HorizonStory2Dialog1.initialize()
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HorizonStory2Dialog1.interactionPossible(playerIndex)
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

function HorizonStory2Dialog1.initUI()
    ScriptUI():registerInteraction("Contact the Hacker", "onContact", 99)
end

function HorizonStory2Dialog1.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function HorizonStory2Dialog1.getDialog()
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

    d0.text = "Wh-who are you? Why are you contacting me!?"
    d0.answers = { 
        { answer = "I'm working with Varlance.", followUp = d1},
        { answer = "I've got a job for you.", followUp = d2 }
    }

    d1.text = "Varlance? We haven't talked for years. Told him we were done after that last op. W-why would he want something now?"
    d1.answers = {
        { answer = "We found a data chip.", followUp = d3 }
    }

    d2.text = "I don't know you! I can't trust you! Why should I do anything for you?"
    d2.answers = {
        { answer = "You can trust me.", followup = d4 },
        { answer = "I'll pay you.", followUp = d8 }
    }

    d3.text = "A data chip? Why do you need my help to deal with that?"
    d3.answers = {
        { answer = "It's encrypted.", followUp = d6 }
    }

    d4.text = "No I can't!! I don't know anything about you! Your reassurances could be as hollow as theirs!"
    d4.answers = {
        { answer = "Who's?", followUp = d7 }
    }

    d5.text = "There's not enough money in the galaxy for me to mess with that!"
    d5.onEnd = "onEnd"

    d6.text = "Encrypted? Oh no. Oh no no no. Ohhhh nononononono. I don't deal with that. That's way too dangerous."
    d6.answers = {
        { answer = "You can trust me.", followUp = d4 },
        { answer = "I'll pay you.", followUp = d5 }
    }

    d7.text = "[The transmission abruptly ends.]"
    d7.onEnd = "onEnd"

    d8.text = "I don't know what sort of work you're offering, but there's not enough money in the galaxy for me to mess with that! Not after... Oh no. I shouldn't have said that-"
    d8.followUp = d7

    for _, _d in pairs({ d0, d1, d2, d3, d4, d5, d6, d8 }) do
        _d.talker = "Hacker"
        _d.textColor = HorizonUtil.getDialogMaceTextColor()
        _d.talkerColor = HorizonUtil.getDialogMaceTalkerColor()
    end

    return d0
end

function HorizonStory2Dialog1.onEnd()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "kothStory2_contactedHacker")
end

--endregion

--region #CLIENT / SERVER CALLS

function HorizonStory2Dialog1.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 2 Dialog 1] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion