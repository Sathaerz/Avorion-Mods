local MassDriver_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/massdriver.png"] = WeaponType.MassDriver

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return MassDriver_legacyDetectWeaponType(item)
    end
end