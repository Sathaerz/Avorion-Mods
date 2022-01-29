package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LLTEStory1AmbushLeader
LLTEStory1AmbushLeader = {}

-- make the NPC talk to players
LLTEStory1AmbushLeader = include("npcapi/singleinteraction")

include("stringutility")

function LLTEStory1AmbushLeader.getDialog()
    return { text = "Ha, looks like we found a stray one! I knew paying that smuggler off was a good idea. Get them!" }
end