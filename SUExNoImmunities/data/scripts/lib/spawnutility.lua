local SpawnUtilExtension_addEnemyBuffs = SpawnUtility.addEnemyBuffs
function SpawnUtility.addEnemyBuffs(ships)
    SpawnUtilExtension_addEnemyBuffs(ships)

    for _, _Ship in pairs(ships) do
        local _Shield = Shield(_Ship)
        local _ResType, _ResFactor = _Shield:getResistance()
        local _MaxRes = 0.7

        if _ResType and _ResFactor then
            if _ResFactor > _MaxRes then
                _Shield:setResistance(_ResType, _MaxRes)
            end
        end
    end
end