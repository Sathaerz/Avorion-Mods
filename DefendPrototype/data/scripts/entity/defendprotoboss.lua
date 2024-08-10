package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace DefendProtoBoss
DefendProtoBoss = {}
local self = DefendProtoBoss

function DefendProtoBoss.initialize()
    local _MethodName = "Initialize"

    if onClient() then
        local _ship = Entity()

        registerBoss(_ship.index)
        setBossHealthColor(_ship.index, ColorRGB(0.2, 0.7, 0.2))
    end

    if onServer() then
        ShipAI():setIdle()
        ShipAI():setPassiveShooting(true)
    end
end