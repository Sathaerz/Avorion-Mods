local SpreadFire_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/spreadfire.png"] = WeaponType.SpreadFire

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return SpreadFire_legacyDetectWeaponType(item)
    end
end