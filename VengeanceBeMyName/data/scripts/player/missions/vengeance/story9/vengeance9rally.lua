package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Vengeance9Rally
Vengeance9Rally = {}

function Vengeance9Rally.getUpdateInterval()
    return 5
end

function Vengeance9Rally.updateServer(timeStep)
    local xinulls = { Sector():getEntitiesByScriptValue("is_xinull") }
    local xinull = xinulls[1]

    if xinull and valid(xinull) then
        local _entity = Entity()
        local distToXinull = _entity:getNearestDistance(xinull)
        local speedBonus = 8 --Adjust as needed

        if distToXinull > 2000 then
            _entity:addKeyedMultiplier(StatsBonuses.Acceleration, 2207469437, speedBonus)
            _entity:addKeyedMultiplier(StatsBonuses.Velocity, 2207469437, speedBonus)
        else
            _entity:addKeyedMultiplier(StatsBonuses.Acceleration, 2207469437, 1)
            _entity:addKeyedMultiplier(StatsBonuses.Velocity, 2207469437, 1)
        end
    end
end