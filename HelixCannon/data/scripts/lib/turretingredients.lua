TurretIngredients[WeaponType.HelixCannon] =
{
    {name = "Plasma Cell",          amount = 9,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 1.15 },
    {name = "High Capacity Lens",   amount = 5,    investable = 3,  minimum = 1,    weaponStat = "damage", investFactor = 0.45 },
    {name = "Energy Tube",          amount = 3,    investable = 9,  minimum = 1,    weaponStat = "reach", },
    {name = "Conductor",            amount = 6,    investable = 9,  minimum = 1,},
    {name = "Energy Container",     amount = 6,    investable = 9,  minimum = 1,},
    {name = "Power Unit",           amount = 6,    investable = 5,  minimum = 3,    turretStat = "maxHeat", investFactor = 0.75},
    {name = "Steel",                amount = 4,    investable = 15, minimum = 3,},
    {name = "Crystal",              amount = 3,    investable = 15, minimum = 1,},
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(TurretIngredients[WeaponType.HelixCannon], {name = "Targeting System",     amount = 0,    investable = 2,  minimum = 0, turretStat = "automatic", investFactor = 1, changeType = StatChanges.Flat})
end