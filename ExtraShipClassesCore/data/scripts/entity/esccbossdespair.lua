package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ESCCBossDespair
ESCCBossDespair = {}
local self = ESCCBossDespair

function ESCCBossDespair.initialize()
    local _MethodName = "Initialize"

    if onClient() then
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/special/despair.ogg")
    end

    if onServer() then
        ShipAI():setAggressive()
    end
end