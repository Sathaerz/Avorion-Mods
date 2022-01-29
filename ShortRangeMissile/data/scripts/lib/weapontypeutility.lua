local ShortRangeMissile_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/shortrangemissile.png"] = WeaponType.ShortRangeMissile

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return ShortRangeMissile_legacyDetectWeaponType(item)
    end
end