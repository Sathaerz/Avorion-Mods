local PulseAccelerator_legacyDetectWeaponType = legacyDetectWeaponType
function legacyDetectWeaponType(item)
    local legacyTypeByIcon = {}
    legacyTypeByIcon["data/textures/icons/pulseaccel.png"] = WeaponType.PulseAccelerator

    local type = legacyTypeByIcon[item.weaponIcon]
    if type then
        return type
    else
        return PulseAccelerator_legacyDetectWeaponType(item)
    end
end