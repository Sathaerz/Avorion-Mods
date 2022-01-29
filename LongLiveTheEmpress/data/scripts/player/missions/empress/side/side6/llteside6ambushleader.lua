package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace LLTESide6AmbushLeader
LLTESide6AmbushLeader = {}

-- make the NPC talk to players
LLTESide6AmbushLeader = include("npcapi/singleinteraction")

include("stringutility")

function LLTESide6AmbushLeader.getDialog()
    return { text = "So you're the ones who have been running errands for The Cavaliers? Kill them and take that shipment!" }
end