TurretIngredients[WeaponType.FusionCannon] =
{
    {name = "Fusion Generator",     amount = 8,    investable = 4,  minimum = 1,   weaponStat = "damage" },
    {name = "High Pressure Tube",   amount = 4,    investable = 4,  minimum = 1,   weaponStat = "damage" },
    {name = "Energy Tube",          amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach" },
    {name = "Conductor",            amount = 5,    investable = 6,  minimum = 1 },
    {name = "Energy Container",     amount = 5,    investable = 6,  minimum = 1 },
    {name = "Fusion Core",          amount = 5,    investable = 3,  minimum = 3,    turretStat = "maxHeat", investFactor = 0.75},
    {name = "Steel",                amount = 4,    investable = 10, minimum = 3 },
    {name = "Crystal",              amount = 2,    investable = 10, minimum = 1 },
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(TurretIngredients[WeaponType.FusionCannon], {name = "Targeting System",     amount = 0,    investable = 2,  minimum = 0, turretStat = "automatic", investFactor = 1, changeType = StatChanges.Flat})
end