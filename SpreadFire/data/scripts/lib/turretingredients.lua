TurretIngredients[WeaponType.SpreadFire] =
{
    {name = "Plasma Cell",          amount = 8,    investable = 4,  minimum = 1,    weaponStat = "damage" },
    {name = "High Capacity Lens",   amount = 4,    investable = 2,  minimum = 1,    weaponStat = "damage", investFactor = 0.3 },
    {name = "Energy Tube",          amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach", },
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 1,},
    {name = "Energy Container",     amount = 5,    investable = 6,  minimum = 1,},
    {name = "Power Unit",           amount = 5,    investable = 3,  minimum = 3,    turretStat = "maxHeat", investFactor = 0.75},
    {name = "Steel",                amount = 4,    investable = 10, minimum = 3,},
    {name = "Crystal",              amount = 2,    investable = 10, minimum = 1,},
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(TurretIngredients[WeaponType.SpreadFire], {name = "Targeting System",     amount = 0,    investable = 2,  minimum = 0, turretStat = "automatic", investFactor = 1, changeType = StatChanges.Flat})
end