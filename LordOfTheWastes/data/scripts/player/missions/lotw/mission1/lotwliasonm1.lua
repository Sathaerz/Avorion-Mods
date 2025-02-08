package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LOTWLiasonMission1Dialog1
LOTWLiasonMission1Dialog1 = {}

-- make the NPC talk to players
LOTWLiasonMission1Dialog1 = include("npcapi/singleinteraction")
MissionUT = include("missionutility")

include("stringutility")

local data = LOTWLiasonMission1Dialog1.data
data.closeableDialog = false

function LOTWLiasonMission1Dialog1.getDialog()
    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}

    local _PlayerName = Player().name

    local _Talker = "Liason"

    --d0
    d0.text = "Good job, " .. _PlayerName .. ". Those pirates would have been a major threat if allowed to rampage uncontrolled."
    d0.talker = _Talker
    d0.followUp = d1
    --d1
    d1.text = "There's a particularly troubling pirate boss who seems to think that they've got free reign of this area. Just because we're in the outer reaches of the galaxy doesn't mean that we're uncivilized. We have an obligation to keep these sectors safe."
    d1.talker = _Talker
    d1.followUp = d2
    --d2
    d2.text = "We'd like to keep you on retainer for future work. We need to flush this scum out and eradicate them once and for all. What do you say?"
    d2.talker = _Talker
    d2.answers = {
        { answer = "Sure, I'll help you out.", followUp = d4 },
        { answer = "That sounds like a hassle. I'll pass.", followUp = d3 }
    }

    d3.text = "But why? We'll pay you much more than you'd get for any comparable jobs in the region, and you'll have full salvage rights to anything you find. If you're that determined to avoid an easy job, just don't follow up on the contract I guess."
    d3.talker = _Talker
    d3.onEnd = "onEnd"

    d4.text = "Great! We'll be in touch."
    d4.talker = _Talker
    d4.onEnd = "onEnd"

    return d0
end

function LOTWLiasonMission1Dialog1.onEnd()
    Player():invokeFunction("player/missions/lotw/lotwstory1.lua", "contactedLiason")
end