if onServer() then

    local _Entity = Entity()
    if  _Entity.type == EntityType.Ship and (_Entity.playerOwned or _Entity.allianceOwned) then
        _Entity:addScriptOnce("hydracontroller.lua")
    end

end