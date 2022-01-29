local VaussCannon_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/vausscannon.png"] = WeaponType.VaussCannon

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return VaussCannon_legacyDetectWeaponType(item)
    end
end