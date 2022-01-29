-- Add torpedo auto-targeting support to every ship
-- (it'll only do something for player ships)
local entity = Entity()
if entity.isShip then
    entity:addScriptOnce("entity/utility/torpedoautotargeter.lua")
end