local WGE_GenerateRocketLauncher = WeaponGenerator.generateRocketLauncher
function WeaponGenerator.generateRocketLauncher(rand, dps, tech, material, rarity)
    local _LauncherWeapon = WGE_GenerateRocketLauncher(rand, dps, tech, material, rarity)

    _LauncherWeapon.seeker = true

    return _LauncherWeapon
end