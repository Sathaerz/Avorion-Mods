package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LLTESide3Dialogue1
LLTESide3Dialogue1 = {}

-- make the NPC talk to players
LLTESide3Dialogue1 = include("npcapi/singleinteraction")
MissionUT = include("missionutility")
ESCCUtil = include("esccutil")

include("stringutility")

local data = LLTESide3Dialogue1.data
data.closeableDialog = false

function LLTESide3Dialogue1.getDialog()
    local d0 = {}
    local d1 = {}
    local d2 = {}

    local _Rgen = ESCCUtil.getRand()

    local _Possibled0Messages = {
        "Here on behalf of The Cavaliers, are you?",
        "I see the Emperor's lapdog has seen fit to show themselves.",
        "Don't you worry, we already know why we're here."
    }
    local _Possibled1Messages = {
        "You want the entire galaxy under your thumb.",
        "Don't you think you've already taken enough?",
        "We should have known you'd come for us next.",
        "Not satisfied with your blood wages?",
        "How long do you think you can go before you lose it all?"
    }
    local _Possibled2Messages = {
        "We'll never bend the knee to you, tyrant!",
        "We'd rather die than submit to your rule!",
        "We'll kill every last one of you, or die trying!",
        "You'll never take our freedom away!",
        "We're calling your bluff. It's time for you to fall!"
    }

    --d0
    d0.text = _Possibled0Messages[_Rgen:getInt(1, #_Possibled0Messages)]
    d0.followUp = d1
    --d1
    d1.text = _Possibled1Messages[_Rgen:getInt(1, #_Possibled1Messages)]
    d1.followUp = d2
    --d2
    d2.text = _Possibled2Messages[_Rgen:getInt(1, #_Possibled2Messages)]
    d2.onEnd = "onEnd"

    return d0
end

function LLTESide3Dialogue1.onEnd()
    Player():invokeFunction("player/missions/empress/side/lltesidemission3.lua", "factionDeclareWar")
end