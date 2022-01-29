local FusionCannon_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/fusioncannon.png"] = WeaponType.FusionCannon

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return FusionCannon_legacyDetectWeaponType(item)
    end
end