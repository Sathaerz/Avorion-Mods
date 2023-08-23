ShipUtility._Dangerous = false

local xmods = Mods()

local _Vauss = false
local _Spread = false
local _Helix = false
local _Fusion = false
local _Lancer = false
local _SRM = false
local _Slug = false
local _ESCC = false
local _Accel = false
local _PlasFlamer = false
local _MassDriver = false
local _ArsPulseLaser = false
local _Dangerous = false

for _, p in pairs(xmods) do
    if p.id == "2532733728" then
        _Vauss = true
    end
    if p.id == "2537658830" then
        _Spread = true
    end
    if p.id == "2537659039" then
        _Helix = true
    end
    if p.id == "2539125971" then
        _Fusion = true
    end
    if p.id == "2540473355" then
        _Lancer = true
    end
    if p.id == "2556651648" then
        _SRM = true
    end
    if p.id == "2556651689" then
        _Slug = true
    end
    if p.id == "2207469437" then
        _ESCC = true
    end
    if p.id == "2422999823" then
        _Dangerous = true
    end
    if p.id == "2745345613" then
        _Dangerous = true
    end
    if p.id == "3016092256" then
        _PlasFlamer = true
    end
    if p.id == "3024338660" then
        _MassDriver = true
    end
    if p.id == "3016092361" then
        _ArsPulseLaser = true
    end
end

if _Dangerous then
    ShipUtility._Dangerous = true
end

if _Spread then
    table.insert(AttackWeapons, WeaponType.SpreadFire)
    table.insert(AntiShieldWeapons, WeaponType.SpreadFire)
end

if _Helix then
    table.insert(AttackWeapons, WeaponType.HelixCannon)
    table.insert(AntiShieldWeapons, WeaponType.HelixCannon)
end

if _Fusion then
    table.insert(AttackWeapons, WeaponType.FusionCannon)
    table.insert(ArtilleryWeapons, WeaponType.FusionCannon)
    table.insert(LongRangeWeapons, WeaponType.FusionCannon)
end

if _SRM then
    table.insert(AttackWeapons, WeaponType.ShortRangeMissile)
    table.insert(AntiHullWeapons, WeaponType.ShortRangeMissile)
end

if _Slug then
    table.insert(AttackWeapons, WeaponType.SlugGun)
end

if _PlasFlamer then
    table.insert(AttackWeapons, WeaponType.PlasmaFlamer)
    table.insert(AntiShieldWeapons, WeaponType.PlasmaFlamer)
end

if _MassDriver then
    table.insert(AttackWeapons, WeaponType.MassDriver)
    table.insert(LongRangeWeapons, WeaponType.MassDriver)
end

if _ArsPulseLaser then
    table.insert(AttackWeapons, WeaponType.ArsPulseLaser)
end

if ShipUtility._Dangerous then
    if _Vauss then
        table.insert(AttackWeapons, WeaponType.VaussCannon)
        table.insert(LongRangeWeapons, WeaponType.VaussCannon)
    end

    if _Lancer then
        table.insert(AttackWeapons, WeaponType.LancerLaser)
    end

    if _Accel then
        table.insert(AttackWeapons, WeaponType.PulseAccelerator)
    end
end

if _ESCC then
    if _Spread then
        table.insert(ExecutionerWeapons, WeaponType.SpreadFire)
    end

    if _Helix then
        table.insert(ExecutionerWeapons, WeaponType.HelixCannon)
    end

    if _Slug then
        table.insert(ExecutionerWeapons, WeaponType.SlugGun)
    end

    if _ArsPulseLaser then
        table.insert(ExecutionerWeapons, WeaponType.ArsPulseLaser)
    end

    if _MassDriver then
        table.insert(ExecutionerWeapons, WeaponType.MassDriver)
    end

    if ShipUtility._Dangerous then
        if _Vauss then
            table.insert(ExecutionerWeapons, WeaponType.VaussCannon)
        end

        if _Accel then
            table.insert(ExecutionerWeapons, WeaponType.PulseAccelerator)
        end
    end
end

ShipUtility.AttackWeapons = AttackWeapons
ShipUtility.LongRangeWeapons = LongRangeWeapons
ShipUtility.AntiHullWeapons = AntiHullWeapons
ShipUtility.AntiShieldWeapons = AntiShieldWeapons
ShipUtility.ArtilleryWeapons = ArtilleryWeapons

if _ESCC then
    ShipUtility.ExecutionerWeapons = ExecutionerWeapons
end