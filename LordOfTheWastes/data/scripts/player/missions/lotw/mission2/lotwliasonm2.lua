package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LOTWLiasonMission2Dialog1
LOTWLiasonMission2Dialog1 = {}

-- make the NPC talk to players
LOTWLiasonMission2Dialog1 = include("npcapi/singleinteraction")
MissionUT = include("missionutility")

include("stringutility")

local data = LOTWLiasonMission2Dialog1.data
data.closeableDialog = false

function LOTWLiasonMission2Dialog1.getDialog()
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}

    local _PlayerName = Player().name

    local _Talker = "Liason"

    --d0
    d0.text = "Well done, " .. _PlayerName .. ". With their supply lines crippled, the pirates will be forced to take action."
    d0.talker = _Talker
    d0.followUp = d1
    --d1
    d1.text = "We'll keep an eye out for any opportunities to further disrupt their little operation. With any luck, we can force the boss out into the open within the next few days. In the meantime, please look forward to more opportunities for work."
    d1.talker = _Talker
    d1.followUp = d2
    --d2
    d2.text = "As promised, full salvage rights are yours. We're transferring a license for any goods in your cargo bay right now."
    d2.talker = _Talker
    d2.followUp = d3

    d3.text = "I should warn you that is a one-time license and is not valid for future use. Please do not run an unlicensed smuggling operation in our territory."
    d3.talker = _Talker
    d3.onEnd = "onEnd"

    return d0
end

function LOTWLiasonMission2Dialog1.onEnd()
    Player():invokeFunction("player/missions/lotw/lotwstory2.lua", "lotwStory2_contactedLiason")
end