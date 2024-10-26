package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

HorizonUtil = include("horizonutil")

--namespace HorizonStory2Dialog3
HorizonStory2Dialog3 = {}
local self = HorizonStory2Dialog3

self._Debug = 1

self._Data = {}

--region #INIT

function HorizonStory2Dialog3.initialize(_X, _Y)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")

    --This data is server side and NOT client side, so we need to send it to the client immedaitely.
    self._Data = {}
    self._Data._X = _X
    self._Data._Y = _Y

    HorizonStory2Dialog3.sync()
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HorizonStory2Dialog3.interactionPossible(playerIndex)
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

function HorizonStory2Dialog3.initUI()
    ScriptUI():registerInteraction("Contact the Hacker", "onContact", 99)
    ScriptUI():registerInteraction("Report Lost Satellite Package", "onLostSatellite", 98)
end

function HorizonStory2Dialog3.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function HorizonStory2Dialog3.onLostSatellite(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getSatelliteDialog())
end

function HorizonStory2Dialog3.getDialog()
    local _MethodName = "Get Dialogue"
    self.Log(_MethodName, "Beginning...")

    local _Talker = "Hacker"
    local _TalkerColor = HorizonUtil.getDialogMaceTalkerColor()
    local _TextColor = HorizonUtil.getDialogMaceTextColor()

    local d0 = {}

    d0.text = "... Yes?"
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor

    local _JobsDone = Entity():getValue("horizon2_job_done")

    if _JobsDone then
        local d1 = {}
        local d2 = {}
        local d3 = {}
        local w1_1 = {}
        local w1_2 = {}
        local w1_3 = {}
        local w1_4 = {}
        local d4 = {}
        local d5 = {}
        local w2_1 = {}
        local w2_2 = {}
        local w2_3 = {}
        local w2_4 = {}
        local d6 = {}
        local d7 = {}
        local w3_1 = {}
        local w3_2 = {}
        local w3_3 = {}
        local w3_4 = {}
        local d8 = {}
        local d9 = {}
        local d10 = {}
        local d11 = {}

        d0.answers = {
            { answer = "Can you decrypt the chip?", followUp = d1 }
        }

        d1.text = "I don't like messing with that stuff. It's dangerous. You never know who the data belongs to or what they're doing with it."
        d1.followUp = d3

        d2.text = "[The transmission abruptly ends.]"

        d3.text = "In the worst case, they know you've broken into their stuff and they'll come after you."
        d3.answers = {
            { answer = "I'll protect you.", followUp = w1_1 },
            { answer = "No they won't.", followUp = w1_2 },
            { answer = "You've survived this long.", followUp = w1_3 },
            { answer = "We misdirect them.", followUp = d4 },
            { answer = "Go to ground again.", followUp = w1_4 }
        }

        w1_1.text = "What, forever? There's no way you can keep your eyes on me all the time... and that's when they'll slip a knife into my back."
        w1_2.text = "You don't know that. How could you possibly know that? You don't even know what's on this chip."
        w1_3.text =  "Yeah, by not doing crazy stuff like this!"
        w1_4.text = "And let all my work and contacts dry up? Forget that - emergencies only. I'm still trying to recover from the last time I went to ground."
        w1_1.followUp = d2
        w1_2.followUp = d2
        w1_3.followUp = d2
        w1_4.followUp = d2

        d4.text = "Okay, that's not a bad idea. You and Varlance already hit one pirate group right? Maybe you could hit a second group and drop a copy of the chip in one of the wreckages..."
        d4.followUp = d5

        d5.text = "But here's the thing. We don't know what's on this chip. It could be something terrible. Something that we can't risk falling into the wrong hands."
        d5.answers = {
            { answer = "It won't be.", followUp = w2_1 },
            { answer = "It doesn't matter.", followUp = w2_2 },
            { answer = "I can take care of myself.", followUp = d6 },
            { answer = "We'll sabatoge the chip.", followUp = w2_3 },
            { answer = "I'll be careful.", followUp = w2_4 }
        }

        w2_1.text = "Oh yeah? Must be nice to be so certain. Well, I haven't lived this long by taking stupid risks... like this one."
        w2_2.text = "What are you talking about? Of course it matters. What if it's the genetic code for some sort of fucked up super virus? What if it's steps to build a WMD?"
        w2_3.text = "What are you saying? Have you been watching too many movies or something? Once you've gotten the information, destroying the chip doesn't matter. When it's out there, it's out there!"
        w2_4.text = "That's the most generic platitude you could possibly offer."
        w2_1.followUp = d2
        w2_2.followUp = d2
        w2_3.followUp = d2
        w2_4.followUp = d2

        d6.text = "Your ship does look quite impressive... if I delete the information off of my own computers... Hm. If you don't get captured, this means it won't come back to me."
        d6.followUp = d7

        d7.text = "I dunno, though. I still feel uneasy about this. Are you absolutely sure that this is a good idea?"
        d7.answers = {
            { answer = "It's a great idea.", followUp = w3_1 },
            { answer = "Yes, it's a good idea.", followUp = w3_2 },
            { answer = "No, I'm not.", followUp = w3_3 },
            { answer = "Yeah, it's fine.", followUp = w3_4 },
            { answer = "Heroes die once.", followUp = d8 }
        }

        w3_1.text = "Yeah? If you're so sure, why don't you get the tech to break this encryption yourself?"
        w3_2.text = "No. No no no. I still don't like this. If your instincts are wrong, I'm dead. I'm not willing to put that kind of trust in you - we've barely met."
        w3_3.text = "... Why are we even doing this, then?"
        w3_4.text = "Don't be so cavalier about this! You have no idea what's at stake!!"
        w3_1.followUp = d2
        w3_2.followUp = d2
        w3_3.followUp = d2
        w3_4.followUp = d2

        d8.text = "You! You're... you're right. I shouldn't let fear rule me. I... just... after the last group I dealt with... I don't want to..."
        d8.followUp = d9

        d9.text = "Maybe you can deal with them for me. There's a group that I agreed to hand over an artifact to, but they scared the hell out of me. They were all corporate suit looking people, but the scars on them... they way they carried themselves..."
        d9.followUp = d10

        d10.text = "Could you give them the artifact for me? Tell you what. If you do that, I won't even charge you for breaking into the chip."
        d10.answers = {
            { answer = "Sure.", followUp = d11 }
        }

        d11.text = "Thanks again. They're located in (${_X}:${_Y}). Come to the dock and grab the artifact. You can call me Mace, by the way." % self._Data
        d11.onEnd = "onEnd"

        for _, _d in pairs({ d1, d3, w1_1, w1_2, w1_3, w1_4, d4, d5, w2_1, w2_2, w2_3, w2_4, d6, d7, w3_1, w3_2, w3_3, w3_4, d8, d9, d10, d11 }) do
            _d.talker = _Talker
            _d.textColor = _TextColor
            _d.talkerColor = _TalkerColor
        end

        return d0
    else
        local d1 = {}
    
        d0.answers = {
            { answer = "Can you decrypt the chip?", followUp = d1 }
        }
    
        d1.text = "I still don't think I can trust you. Why should I help?"
        d1.talker = _Talker
        d1.textColor = _TextColor
        d1.talkerColor = _TalkerColor
    
        return d0
    end
end

function HorizonStory2Dialog3.getSatelliteDialog()
    local _MethodName = "Get Satellite Dialogue"
    self.Log(_MethodName, "Beginning...")

    local _PlayerHasSatellite = false
    local items = Player():getInventory():getItemsByType(InventoryItemType.UsableItem)
    for _, slot in pairs(items) do
        local item = slot.item

        -- we assume they're stackable, so we return here
        if item:getValue("subtype") == "HorizonStory2ResearchSatellite" then
            _PlayerHasSatellite = true
            break
        end
    end

    if Entity():getValue("horizon2_satellitejob_done") then
        _PlayerHasSatellite = true
    end

    local _Talker = "Hacker"
	local _TalkerColor = HorizonUtil.getDialogMaceTalkerColor()
	local _TextColor = HorizonUtil.getDialogMaceTextColor()

    local d0 = {}
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor

    if _PlayerHasSatellite then
        d0.text = "... That's not funny. Stop wasting my time."
    else
        d0.text = "Seriously? You lost it? Be a little more careful. Those are expensive!"
        d0.onEnd = "onEndGiveSat"
    end

    return d0
end

function HorizonStory2Dialog3.onEnd()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "contactedHacker3")
end

function HorizonStory2Dialog3.onEndGiveSat()
    local _MethodName = "On End Give Sat"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "contactedHackerGiveSat")
end

--endregion

--region #SECURE / RESTORE / LOG / SYNC

function HorizonStory2Dialog3.sync(_Data_In)
    if onServer() then
        broadcastInvokeClientFunction("sync", self._Data)
    else
        if _Data_In then
            self._Data = _Data_In
        else
            invokeServerFunction("sync")
        end
    end
end
callable(HorizonStory2Dialog3, "sync")

function HorizonStory2Dialog3.secure()
    return self._Data
end

function HorizonStory2Dialog3.restore(_Values)
    self._Data = _Values
end

function HorizonStory2Dialog3.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 2 Dialog 3] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion