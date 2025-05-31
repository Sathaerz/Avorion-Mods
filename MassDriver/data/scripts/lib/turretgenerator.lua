--0x7363616C657461626C657374617274
scales[WeaponType.MassDriver] = {
    {from = 0, to = 18, size = 0.5, usedSlots = 1},
    {from = 19, to = 33, size = 1.0, usedSlots = 2},
    {from = 34, to = 45, size = 1.5, usedSlots = 3},
    {from = 46, to = 52, size = 2.0, usedSlots = 4},
}
--0x7363616C657461626C65656E64

--0x7370656369616C74797461626C657374617274
possibleSpecialties[WeaponType.MassDriver] = {
    {specialty = Specialty.HighShootingTime, probability = 0.1},
    {specialty = Specialty.HighFireRate, probability = 0.15},
    {specialty = Specialty.HighDamage, probability = 0.1},
    {specialty = Specialty.HighAccuracy, probability = 0.025 } --Relevant now with the accuracy reduction.
}
--0x7370656369616C74797461626C65656E64

--0x67656E657261746566756E637374617274
function TurretGenerator.generateMassDriverTurret(rand, dps, tech, material, rarity)
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    local numWeapons = 1

    local weapon = WeaponGenerator.generateMassDriver(rand, dps, tech, material, rarity)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    TurretGenerator.attachWeapons(rand, result, weapon, numWeapons)

    local shootingTime = 24 * rand:getFloat(0.8, 1.2)
    local coolingTime = 14 * rand:getFloat(0.8, 1.2)

    TurretGenerator.createStandardCooling(result, coolingTime, shootingTime)

    --I guess we don't really need this but there's no real reason to get rid of it either. Laziness wins.
    local weapons = {result:getWeapons()}
    result:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.damage = weapon.damage * ((coolingTime + shootingTime) / shootingTime)
        result:addWeapon(weapon)
    end

    local scaleLevel = TurretGenerator.scale(rand, result, WeaponType.MassDriver, tech, 0.7, coaxialAllowed)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.MassDriver)

    result.slotType = TurretSlotType.Armed
    result:updateStaticStats()

    -- create a nice name for the turret
    local name = "Mass Driver"
    if specialties[Specialty.HighDamage] and specialties[Specialty.HighFireRate] and specialties[Specialty.HighShootingTime] then
        name = "Mass OverDriver"
        specialties[Specialty.HighDamage] = nil
        specialties[Specialty.HighFireRate] = nil
        specialties[Specialty.HighShootingTime] = nil
    end

    local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Physical)
    result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)

    return result
end
--0x67656E657261746566756E63656E64

--0x6D6574617461626C6566756E636C696E65
generatorFunction[WeaponType.MassDriver] = TurretGenerator.generateMassDriverTurret