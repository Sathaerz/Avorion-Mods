local SlugGun_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/slug-gun.png"] = WeaponType.SlugGun

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return SlugGun_legacyDetectWeaponType(item)
    end
end