package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LOTWLiasonMission6Dialog1
LOTWLiasonMission6Dialog1 = {}

-- make the NPC talk to players
LOTWLiasonMission6Dialog1 = include("npcapi/singleinteraction")
MissionUT = include("missionutility")

include("stringutility")

local data = LOTWLiasonMission6Dialog1.data
data.closeableDialog = false

function LOTWLiasonMission6Dialog1.getDialog()
    local d0 = {}
    local d1 = {}

    local _PlayerName = Player().name

    local _Talker = "Liason"

    --d0
    d0.text = "Well done, " .. _PlayerName .. ". As promised, full salvage rights are yours. We're transferring a license for any goods in your cargo bay right now."
    d0.talker = _Talker
    d0.followUp = d1

    d1.text = "Remember that this is a one-time license and will not be valid for future ops."
    d1.talker = _Talker
    d1.onEnd = "onEnd"

    return d0
end

function LOTWLiasonMission6Dialog1.onEnd()
    Player():invokeFunction("player/missions/lotw/lotwmission6.lua", "contactedLiason")
end