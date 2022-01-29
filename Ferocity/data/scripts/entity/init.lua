if onServer() then

    local _Entity = Entity()
    if _Entity.type == EntityType.Ship or _Entity.type == EntityType.Station then
        if _Entity.playerOwned or _Entity.allianceOwned or _Entity:getValue("_ferocity_set") then 
            goto continue 
        end

        local _Dura = Durability(_Entity)
        if _Dura then
            _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 1) + 7
        end

        local _Shield = Shield(_Entity)
        if _Shield then
            _Shield.maxDurabilityFactor = (_Shield.maxDurabilityFactor or 1) + 7
        end

        _Entity.damageMultiplier = (_Entity.damageMultiplier or 1) * 8

        _Entity:setValue("_ferocity_set", true)

        ::continue::
    end

end