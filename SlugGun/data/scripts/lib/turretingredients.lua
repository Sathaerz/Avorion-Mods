TurretIngredients[WeaponType.SlugGun] =
{
    {name = "Servo",                amount = 15,   investable = 10, minimum = 6,   weaponStat = "fireRate", investFactor = 1.0, changeType = StatChanges.Percentage},
    {name = "Electromagnetic Charge",amount = 5,   investable = 6,  minimum = 1,   weaponStat = "damage", investFactor = 0.75,},
    {name = "Electro Magnet",       amount = 8,    investable = 10, minimum = 3,    weaponStat = "reach", investFactor = 0.75,},
    {name = "Gauss Rail",           amount = 5,    investable = 6,  minimum = 1,    weaponStat = "damage", investFactor = 0.75,},
    {name = "High Pressure Tube",   amount = 2,    investable = 6,  minimum = 1,    weaponStat = "reach",  investFactor = 0.75,},
    {name = "Steel",                amount = 5,    investable = 10, minimum = 3,},
    {name = "Copper",               amount = 2,    investable = 10, minimum = 1,},
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(TurretIngredients[WeaponType.SlugGun], {name = "Targeting System",     amount = 0,    investable = 2,  minimum = 0, turretStat = "automatic", investFactor = 1, changeType = StatChanges.Flat})
end