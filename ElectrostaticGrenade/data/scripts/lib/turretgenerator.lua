scales[WeaponType.ElectroGrenade] = {
    {from = 0, to = 18, size = 0.5, usedSlots = 1},
    {from = 19, to = 33, size = 1.0, usedSlots = 2},
    {from = 34, to = 45, size = 1.5, usedSlots = 3},
    {from = 46, to = 52, size = 2.0, usedSlots = 4},
}

possibleSpecialties[WeaponType.ElectroGrenade] = {
    {specialty = Specialty.HighShootingTime, probability = 0.15},
    {specialty = Specialty.HighDamage, probability = 0.1},
    {specialty = Specialty.HighRange, probability = 0.2},
    {specialty = Specialty.HighAccuracy, probability = 0.05}
}

function TurretGenerator.generateElectrostaticGrenadeTurret(rand, dps, tech, material, rarity)
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = 1

    local weapon = WeaponGenerator.generateElectrostaticGrenade(rand, dps, tech, material, rarity)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    local positions = { vec3(0, 0.3, 0) }

    -- attach
    for _, position in pairs(positions) do
        weapon.localPosition = position * result.size
        result:addWeapon(weapon)
    end

    local shootingTime = 20 * rand:getFloat(0.8, 1.2)
    local coolingTime = 15 * rand:getFloat(0.8, 1.2)
    TurretGenerator.createStandardCooling(result, coolingTime, shootingTime)

    TurretGenerator.scale(rand, result, WeaponType.ElectroGrenade, tech, 0.6, coaxialAllowed)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.ElectroGrenade)

    result.slotType = TurretSlotType.Armed
    result:updateStaticStats()

    -- create a nice name for the turret
    local name = "Electrostatic Grenade Launcher"
    if result.slots == 3 then name = "Electroburst Grenade Launcher"
    elseif result.slots == 4 then name = "Hyperstatic Grenade Launcher" end

    local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Electric)
    result.title = Format("%1%%2%%3%%4%%5%%6% /* [outer-adjective][barrel][coax][dmg-adjective][name][serial], e.g. Enduring Dual Coaxial Anti-Tri-Missile Battery T-F */"%_T, outerAdjective, barrel, coax, dmgAdjective, name, serial)

    return result
end

generatorFunction[WeaponType.ElectroGrenade] = TurretGenerator.generateElectrostaticGrenadeTurret