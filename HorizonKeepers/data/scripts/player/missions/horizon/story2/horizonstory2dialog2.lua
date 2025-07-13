package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

HorizonUtil = include("horizonutil")

--namespace HoirzonStory2Dialog2
HoirzonStory2Dialog2 = {}
local self = HoirzonStory2Dialog2

self._Debug = 0

--region #INIT

function HoirzonStory2Dialog2.initialize()
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HoirzonStory2Dialog2.interactionPossible(playerIndex)
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

function HoirzonStory2Dialog2.initUI()
    ScriptUI():registerInteraction("Contact the Hacker", "onContact", 99)
end

function HoirzonStory2Dialog2.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function HoirzonStory2Dialog2.getDialog()
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
    local d9 = {}
    local d10 = {}
    local d11 = {}
    local d12 = {}
    local d13 = {}

    d0.text = "Ugh! It's you again? I thought I told you I wanted nothing to do with you!"
    d0.answers = {
        { answer = "Relax.", followUp = d1 },
        { answer = "Wait! Don't end transmission!", followUp = d2 }
    }

    d1.text = "No! I don't want to talk to you! Go to hell!"
    d1.onEnd = "onEndBad"

    d2.text = "Fine, but you'd better have a damn good reason for contacting me again!"
    d2.answers = {
        { answer = "Is there anything you need done?", followUp = d3 }
    }

    d3.text = "... What? Is this a joke? Are you trying to get one over on me?"
    d3.answers = {
        { answer = "No. What do you need?", followUp = d4 }, 
        { answer = "Yeah. see you.", followUp = d6 }        
    }

    d4.text = "... You're sure you're not joking."
    d4.answers = {
        { answer = "Yes. This isn't a joke.", followUp = d5 },
        { answer = "I'm not so sure now.", followUp = d6 }
    }

    d5.text = "Mmm. Fine. There are three things that need to be done around the sector."
    d5.followUp = d7

    d6.text = "Idiot! I don't want to talk to you! Go to hell!"
    d6.onEnd = "onEndBad"

    d7.text = "First, I need one of the crates moved from the container field to this station. I'll use the station's transporter software to grab the contents - I don't want to be seen accessing it."
    d7.followUp = d8

    d8.text = "Next, I need a satellite deployed to monitor some subspace disturbances I picked up yesterday. It needs to be at least 50 km away from this station."
    d8.followUp = d9
    
    d9.text = "Finally, I need you to destroy some of the asteroids around here. Get rid of a few dozen for me."
    d9.followUp = d10

    d10.text = "Can you handle all that?"
    d10.answers = {
        { answer = "Yes.", onSelect = "onEndGood" },
        { answer = "Why do you need asteroids destroyed?", followUp = d11 }
    }

    d11.text = "The stupid merchant captains keep getting stuck on them. I've begged sector control to do something about it but they're dragging their feet like usual. Its been years and they still haven't fixed it. Can you believe that?"
    d11.answers = {
        { answer = "... Yeah, yeah I can.", followUp = d12 },
        { answer = "Why is it a problem?", followUp = d13 }
    }

    d12.text = "... I can't believe I'm saying this, but thanks. Let me know when you're finished."
    d12.onEnd = "onEndGood"

    d13.text = "Because if a captain is stuck, more captains won't jump into the system. It shuts down the entire station economy. I don't know about you, but I'd like to be able to eat and drink."
    d13.answers = {
        { answer = "Okay, okay. Got it.", onSelect = "onEndGood" }
    }

    for _, _d in pairs({ d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13 }) do
        _d.talker = "Hacker"
        _d.textColor = HorizonUtil.getDialogMaceTextColor()
        _d.talkerColor = HorizonUtil.getDialogMaceTalkerColor()
    end

    return d0
end

function HoirzonStory2Dialog2.onEndBad()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "kothStory2_contactedHacker2", false)
end

function HoirzonStory2Dialog2.onEndGood()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "kothStory2_contactedHacker2", true)
end

--endregion

--region #CLIENT / SERVER CALLS

function HoirzonStory2Dialog2.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 2 Dialog 2] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion