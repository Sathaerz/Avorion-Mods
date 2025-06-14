--0x7363616C657461626C657374617274
scales[WeaponType.ArsPulseLaser] = {
    {from = 0, to = 12, size = 0.5, usedSlots = 1},
    {from = 13, to = 21, size = 1.0, usedSlots = 2},
    {from = 22, to = 30, size = 1.5, usedSlots = 3},
    {from = 31, to = 39, size = 2.5, usedSlots = 4},
    {from = 40, to = 48, size = 3.0, usedSlots = 5},
    {from = 49, to = 52, size = 3.5, usedSlots = 6},
}
--0x7363616C657461626C65656E64

--0x7370656369616C74797461626C657374617274
possibleSpecialties[WeaponType.ArsPulseLaser] = {
    {specialty = Specialty.HighDamage, probability = 0.2},
    {specialty = Specialty.HighRange, probability = 0.2},
    {specialty = Specialty.LessEnergyConsumption, probability = 0.2},
    {specialty = Specialty.HighFireRate, probability = 0.1},
    {specialty = Specialty.IonizedProjectile, probability = 0.05},
    {specialty = Specialty.HighAccuracy, probability = 0.2},
}
--0x7370656369616C74797461626C65656E64

--0x67656E657261746566756E637374617274
function TurretGenerator.generateArsPulseLaserTurret(rand, dps, tech, material, rarity)
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = rand:getInt(1, 3)

    --get tech / slots - have to split the scale function due to part of the stats being determined by the scale.
    local scaleToSlots, scaleToLvl = TurretGenerator.preScaleArsPulseLaser(rand, WeaponType.ArsPulseLaser, tech)

    local weapon = WeaponGenerator.generateArsPulseLaser(rand, dps, tech, material, rarity, scaleToSlots.usedSlots)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    TurretGenerator.attachWeapons(rand, result, weapon, numWeapons)

    local rechargeTime = 7 * rand:getFloat(1, 1.5)
    local shootingTime = 22 * rand:getFloat(1, 1.5)
    TurretGenerator.createArsPulseLaserCooling(result, rechargeTime, shootingTime, scaleToSlots.usedSlots)

    local scaleLevel = TurretGenerator.postScaleArsPulseLaser(rand, result, WeaponType.ArsPulseLaser, tech, 1, coaxialAllowed, scaleToSlots, scaleToLvl)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.ArsPulseLaser)

    result.slotType = TurretSlotType.Armed
    result:updateStaticStats()

    -- create a nice name for the turret
    local name = "Small Pulse Laser"
    if result.slots == 3 or result.slots == 4 then
        name = "Medium Pulse Laser"
    elseif result.slots >= 5 then
        name = "Large Pulse Laser"
    end

    local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Energy)
    result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)

    return result
end
--0x67656E657261746566756E63656E64

--0x7363616C6566756E637374617274
function TurretGenerator.preScaleArsPulseLaser(rand, type, tech)
    local scaleTech = tech
    if rand:test(0.5) then
        scaleTech = math.floor(math.max(1, scaleTech * rand:getFloat(0, 1)))
    end

    local scale, lvl = TurretGenerator.getScale(type, scaleTech)

    return scale, lvl
end

function TurretGenerator.postScaleArsPulseLaser(rand, turret, type, tech, turnSpeedFactor, coaxialPossible, scaleToSlots, scaleToLvl)
    if coaxialPossible == nil then coaxialPossible = true end -- avoid coaxialPossible = coaxialPossible or true, as it will set it to true if "false" is passed

    local scale, lvl = scaleToSlots, scaleToLvl

    if coaxialPossible then
        turret.coaxial = (scale.usedSlots >= 3) and rand:test(0.25)
    else
        turret.coaxial = false
    end

    turret.size = scale.size
    turret.slots = scale.usedSlots
    turret.turningSpeed = lerp(turret.size, 0.5, 3, 1, 0.5) * rand:getFloat(0.8, 1.2) * turnSpeedFactor

    local coaxialDamageScale = turret.coaxial and 3 or 1

    local weapons = {turret:getWeapons()}
    for _, weapon in pairs(weapons) do
        weapon.localPosition = weapon.localPosition * scale.size

        if scale.usedSlots > 1 then
            -- scale damage, etc. linearly with amount of used slots
            if weapon.damage ~= 0 then
                weapon.damage = weapon.damage * scale.usedSlots * coaxialDamageScale
            end
            
            --None of the other stats are relevant so we don't need to care about those :3

            local shotSizeFactor = scale.size * 2
            if weapon.isProjectile then
                local velocityIncrease = (scale.usedSlots - 1) * 0.25

                weapon.psize = weapon.psize * shotSizeFactor
                weapon.pvelocity = weapon.pvelocity * (1 + velocityIncrease)
            end
        end
    end

    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        turret:addWeapon(weapon)
    end

    return lvl
end
--0x7363616C6566756E63656E64

--0x636F6F6C66756E637374617274
function TurretGenerator.createArsPulseLaserCooling(turret, rechargeTime, shootingTime, scaleToSlots)
    turret:updateStaticStats()

    local _factor = 10
    if scaleToSlots == 3 or scaleToSlots == 4 then
        _factor = 50
    elseif scaleToSlots >= 5 then
        _factor = 250
    end

    local maxCharge
    if turret.dps > 0 then
        maxCharge = turret.dps * _factor
    else
        maxCharge = (_factor / 2)
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
generatorFunction[WeaponType.ArsPulseLaser] = TurretGenerator.generateArsPulseLaserTurret