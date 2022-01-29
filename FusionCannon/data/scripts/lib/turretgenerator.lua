scales[WeaponType.FusionCannon] = {
    {from = 0, to = 28, size = 1.5, usedSlots = 3},
    {from = 29, to = 38, size = 2.0, usedSlots = 4},
    {from = 39, to = 49, size = 3.0, usedSlots = 5},
    {from = 50, to = 52, size = 3.5, usedSlots = 6},
}

possibleSpecialties[WeaponType.FusionCannon] = {
    {specialty = Specialty.HighDamage, probability = 0.125},
    {specialty = Specialty.HighRange, probability = 0.125},
    {specialty = Specialty.LessEnergyConsumption, probability = 0.2}
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(possibleSpecialties[WeaponType.FusionCannon], {specialty = Specialty.AutomaticFire, probability = 0.05})
end

function TurretGenerator.generateFusionCannonTurret(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = 1    --Normal cannon is 1-4

    local weapon = WeaponGenerator.generateFusionCannon(rand, dps, tech, material, rarity)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    TurretGenerator.attachWeapons(rand, result, weapon, numWeapons)

    local rechargeTime = 30 * rand:getFloat(0.8, 1.2)
    local shootingTime = 20 * rand:getFloat(0.8, 1.2)

    TurretGenerator.createFusionCannonCooling(result, rechargeTime, shootingTime)

    TurretGenerator.scale(rand, result, WeaponType.FusionCannon, tech, 0.5)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.FusionCannon)

    if _Version.major > 1 then
        result.slotType = TurretSlotType.Armed
    end

    result:updateStaticStats()

    if _Version.major > 1 then
        local name = "Fusion Cannon"

        local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Energy)
        --/* [outer-adjective][coax][dmg-adjective][name][serial], e.g. Enduring Dual Coaxial E-Tri-Plasma Cannon T-F */
        result.title = Format("%1%%2%%3%%4%%5%", outerAdjective, coax, dmgAdjective, name, serial)
    end

    return result
end

function TurretGenerator.createFusionCannonCooling(turret, rechargeTime, shootingTime)
    turret:updateStaticStats()

    local maxCharge
    if turret.dps > 0 then
        maxCharge = turret.dps * 500
    else
        maxCharge = 250
    end

    local rechargeRate = maxCharge / rechargeTime -- must be smaller than consumption rate or the weapon will never run out of energy
    local consumptionDelta = maxCharge / shootingTime
    local consumptionRate = consumptionDelta + rechargeRate

    local consumptionPerShot = consumptionRate / turret.firingsPerSecond

    turret.coolingType = CoolingType.BatteryCharge
    turret.maxHeat = maxCharge
    turret.heatPerShot = consumptionPerShot or 0
    turret.coolingRate = rechargeRate or 0
end

generatorFunction[WeaponType.FusionCannon              ] = TurretGenerator.generateFusionCannonTurret