local Balancing_GetWeaponProbability_LessPointDefenses = Balancing_GetWeaponProbability
function Balancing_GetWeaponProbability(x, y)
    local LessPointDefenses_Probabilities = Balancing_GetWeaponProbability_LessPointDefenses(x, y)

    for t, specs in pairs(LessPointDefenses_Probabilities) do
        if t == WeaponType.PointDefenseChainGun or t == WeaponType.PointDefenseLaser or t == WeaponType.AntiFighter then
            LessPointDefenses_Probabilities[t] = 0.25
        end
    end

    return LessPointDefenses_Probabilities
end