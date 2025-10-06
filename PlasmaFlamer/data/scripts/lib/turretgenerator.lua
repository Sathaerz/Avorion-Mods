--0x7363616C657461626C657374617274
scales[WeaponType.PlasmaFlamer] = {
    {from = 0, to = 30, size = 0.5, usedSlots = 1},
    {from = 31, to = 39, size = 1.0, usedSlots = 2},
    {from = 40, to = 48, size = 1.5, usedSlots = 3},
    {from = 49, to = 52, size = 2.0, usedSlots = 4},
}
--0x7363616C657461626C65656E64

--0x7370656369616C74797461626C657374617274
possibleSpecialties[WeaponType.PlasmaFlamer] = {
    {specialty = Specialty.LessEnergyConsumption, probability = 0.2},
    {specialty = Specialty.HighDamage, probability = 0.1},
}
--0x7370656369616C74797461626C65656E64

--0x67656E657261746566756E637374617274
function TurretGenerator.generatePlasmaFlamerTurret(rand, dps, tech, material, rarity)
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = 1

    local weapon = WeaponGenerator.generatePlasmaFlamer(rand, dps, tech, material, rarity)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    TurretGenerator.attachWeapons(rand, result, weapon, numWeapons)

    local rechargeTime = 10 * rand:getFloat(0.8, 1.2)
    local shootingTime = 5 * rand:getFloat(0.8, 1.2)
    TurretGenerator.createPlasmaFlamerCooling(result, rechargeTime, shootingTime)

    -- add further descriptions
    TurretGenerator.scale(rand, result, WeaponType.PlasmaFlamer, tech, 1.75, coaxialAllowed)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.PlasmaFlamer)

    result.slotType = TurretSlotType.Armed
    result:updateStaticStats()

    -- create a nice name for the turret
    local name = "Plasma Flamer"
    if result.slots < 3 then
        if specialties[Specialty.HighDamage] and specialties[Specialty.LessEnergyConsumption] then
            name = "Plasma Burner"
            specialties[Specialty.HighDamage] = nil
            specialties[Specialty.LessEnergyConsumption] = nil
        end
    elseif result.slots == 3 then 
        name = "Sol Flamer"

        if specialties[Specialty.HighDamage] and specialties[Specialty.LessEnergyConsumption] then
            name = "Dragonsbreath Flamer"
            specialties[Specialty.HighDamage] = nil
            specialties[Specialty.LessEnergyConsumption] = nil
        end
    elseif result.slots >= 4 then 
        name = "Nova Flamer"

        if specialties[Specialty.HighDamage] and specialties[Specialty.LessEnergyConsumption] then
            name = "Protostar Flamer"
            specialties[Specialty.HighDamage] = nil
            specialties[Specialty.LessEnergyConsumption] = nil
        end
    end

    local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Plasma)
    result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)

    return result
end
--0x67656E657261746566756E63656E64

--0x636F6F6C66756E637374617274
function TurretGenerator.createPlasmaFlamerCooling(turret, rechargeTime, shootingTime)
    turret:updateStaticStats()

    local maxCharge
    if turret.dps > 0 then
        maxCharge = turret.dps * 25 --Uses a bit more energy than normal.
    else
        maxCharge = 5
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
--0x636F6F6C66756E63656E64

--0x6D6574617461626C6566756E636C696E65
generatorFunction[WeaponType.PlasmaFlamer] = TurretGenerator.generatePlasmaFlamerTurret