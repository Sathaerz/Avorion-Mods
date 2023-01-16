local spreadfireCannon_addWeapons = FighterGenerator.addWeapons
function FighterGenerator.addWeapons(...)
    _args = {...}

    if _args[2] == WeaponType.SpreadFire then
        --print("spreadfire cannon fighter found - replacing w/ plasma cannon fighter")
        _args[2] = WeaponType.PlasmaGun
    end

    spreadfireCannon_addWeapons(unpack(_args,1,select("#", ...)))
end