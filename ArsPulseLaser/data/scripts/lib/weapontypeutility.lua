local ArsPulseLaser_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/arspulselaser.png"] = WeaponType.ArsPulseLaser

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return ArsPulseLaser_legacyDetectWeaponType(item)
    end
end