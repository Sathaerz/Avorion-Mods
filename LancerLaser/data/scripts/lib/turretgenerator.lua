local _BaseScaleFactor = 3.0

scales[WeaponType.LancerLaser] = {
    {from = 0, to = 24, size = 0.5, usedSlots = 1},
    {from = 25, to = 35, size = 1.0, usedSlots = 2},
    {from = 36, to = 46, size = 1.5, usedSlots = 3},
    {from = 47, to = 49, size = 2.0, usedSlots = 4},
    {from = 50, to = 52, size = 3.5, usedSlots = 6},
}

possibleSpecialties[WeaponType.LancerLaser] = {
    {specialty = Specialty.LessEnergyConsumption, probability = 0.2},
    {specialty = Specialty.HighDamage, probability = 0.25},
    {specialty = Specialty.HighRange, probability = 0.2},
}

function TurretGenerator.generateLancerLaserTurret(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = rand:getInt(1, 2)

    local weapon = WeaponGenerator.generateLancerLaser(rand, dps, tech, material, rarity)
    weapon.damage = weapon.damage / numWeapons

    -- attach weapons to turret
    TurretGenerator.attachWeapons(rand, result, weapon, numWeapons)
    local scaleLevel = TurretGenerator.scaleLancer(rand, result, WeaponType.LancerLaser, tech, 0.75)

    local rechargeTime = 30 * rand:getFloat(0.8, 1.2)
    local shootingTime = 20 * rand:getFloat(0.8, 1.2)
    TurretGenerator.createBatteryChargeCooling(result, rechargeTime, shootingTime)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.LancerLaser)

    --Have to set it to an armed turret, otherwise it will default to unarmed.
    if _Version.major > 1 then
        result.slotType = TurretSlotType.Armed
    end

    result:updateStaticStats()

    if _Version.major > 1 then
        local name = "Lancer"

        if result.slots == 3 or result.slots == 4 then
            name = "Partisan"
        elseif result.slots >= 5 then
            name = "Halberdier"
        end
    
        local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Energy)
        result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)
    end

    --Final check.
    if not result.coaxial then
        result.coaxial = true
    end
    return result
end

function TurretGenerator.scaleLancer(rand, turret, type, tech, turnSpeedFactor, coaxialPossible)
    --Lancer Lasers are always coaxial.
    local scaleTech = tech
    if rand:test(0.5) then
        scaleTech = math.floor(math.max(1, scaleTech * rand:getFloat(0, 1)))
    end

    local scale, lvl = TurretGenerator.getScale(type, scaleTech)

    turret.size = scale.size
    turret.coaxial = true
    turret.slots = scale.usedSlots
    turret.turningSpeed = lerp(turret.size, 0.5, 3, 1, 0.3) * rand:getFloat(0.8, 1.2) * turnSpeedFactor

    local coaxialDamageScale = _BaseScaleFactor --No need for scaling better than teslas. These can do some vicious damage if given the right stats.

    local weapons = {turret:getWeapons()}
    for _, weapon in pairs(weapons) do
        weapon.localPosition = weapon.localPosition * scale.size

        -- scale damage, etc. linearly with amount of used slots. Doesn't matter how many slots it is since all of these are coaxial.
        if weapon.damage ~= 0 then
            weapon.damage = weapon.damage * scale.usedSlots * coaxialDamageScale
        end

        --These should never be greater than 0, but on the off chance they are...
        if weapon.hullRepair ~= 0 then
            weapon.hullRepair = weapon.hullRepair * scale.usedSlots * coaxialDamageScale
        end

        if weapon.shieldRepair ~= 0 then
            weapon.shieldRepair = weapon.shieldRepair * scale.usedSlots * coaxialDamageScale
        end

        if weapon.selfForce ~= 0 then
            weapon.selfForce = weapon.selfForce * scale.usedSlots * coaxialDamageScale
        end

        if weapon.otherForce ~= 0 then
            weapon.otherForce = weapon.otherForce * scale.usedSlots * coaxialDamageScale
        end

        --Scale range.
        local increase = (scale.usedSlots - 1) * 0.15
        weapon.reach = weapon.reach * (1 + increase)
        
        local shotSizeFactor = scale.size * 2
        weapon.bwidth = weapon.bwidth * shotSizeFactor
    end

    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        turret:addWeapon(weapon)
    end

    return lvl
end

generatorFunction[WeaponType.LancerLaser] = TurretGenerator.generateLancerLaserTurret