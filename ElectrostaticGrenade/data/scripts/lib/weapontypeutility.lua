local ElectrostaticGreande_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/esgturret.png"] = WeaponType.ElectroGrenade

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return ElectrostaticGreande_legacyDetectWeaponType(item)
    end
end