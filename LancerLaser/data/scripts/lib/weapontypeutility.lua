local LancerLaser_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/lancer.png"] = WeaponType.LancerLaser

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return LancerLaser_legacyDetectWeaponType(item)
    end
end