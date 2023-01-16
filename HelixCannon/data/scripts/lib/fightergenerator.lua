local helixCannon_addWeapons = FighterGenerator.addWeapons
function FighterGenerator.addWeapons(...)
    _args = {...}

    if _args[2] == WeaponType.HelixCannon then
        --print("helix cannon fighter found - replacing w/ plasma cannon fighter")
        _args[2] = WeaponType.PlasmaGun
    end

    helixCannon_addWeapons(unpack(_args,1,select("#", ...)))
end