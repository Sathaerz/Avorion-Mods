local HelixCannon_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/helixcannon.png"] = WeaponType.HelixCannon

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return HelixCannon_legacyDetectWeaponType(item)
    end
end