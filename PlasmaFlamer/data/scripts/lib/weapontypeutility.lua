local PlasmaFlamer_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/plasmaflamer.png"] = WeaponType.PlasmaFlamer

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return PlasmaFlamer_legacyDetectWeaponType(item)
    end
end