package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LLTEStory1EmpressBlade
LLTEStory1EmpressBlade = {}

-- make the NPC talk to players
LLTEStory1EmpressBlade = include("npcapi/singleinteraction")
MissionUT = include("missionutility")

include("stringutility")

local data = LLTEStory1EmpressBlade.data
data.closeableDialog = false

function LLTEStory1EmpressBlade.getDialog()
    local d0 = {}
    local d1 = {}
    local d2 = {}

    local _PlayerRank = Player():getValue("_llte_cavaliers_rank")
    local _PlayerName = Player().name

    local _Talker = "Adriana Stahl"
    local _TalkerColor = MissionUT.getDialogTalkerColor1()
    local _TextColor = MissionUT.getDialogTextColor1()

    --d0
    d0.text = _PlayerRank .. " " .. _PlayerName .. "! Glad to see you could make it. As you can see, we've been busy as well."
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor
    d0.answers = {
        { answer = "I can see that.", followUp = d1 }
    }
    --d1
    d1.text = "Since you've intercepted their shipments and obtained the materiel we need, we're just about ready to attack the pirate stronghold. All that's left is sorting through the containers and organizing the remainder of the fleet."
    d1.talker = _Talker
    d1.textColor = _TextColor
    d1.talkerColor = _TalkerColor
    d1.followUp = d2
    --d2
    d2.text = "I'll contact you when we're ready to launch the assault. I hope we can count on your support!"
    d2.talker = _Talker
    d2.textColor = _TextColor
    d2.talkerColor = _TalkerColor
    d2.answers = {
        { answer = "I'll be there.", onSelect = "onEnd" }
    }

    return d0
end

function LLTEStory1EmpressBlade.onEnd()
    Player():invokeFunction("player/missions/empress/story/lltestorymission1.lua", "contactedAdriana")
end