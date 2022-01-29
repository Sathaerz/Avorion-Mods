scales[WeaponType.PulseAccelerator] = {
    {from = 0, to = 37, size = 1.0, usedSlots = 2},
    {from = 38, to = 40, size = 1.5, usedSlots = 3},
    {from = 41, to = 43, size = 2.0, usedSlots = 4},
    {from = 44, to = 46, size = 3.0, usedSlots = 5},
    {from = 47, to = 49, size = 3.5, usedSlots = 6},
    {from = 50, to = 52, size = 4.0, usedSlots = 7}
}

possibleSpecialties[WeaponType.PulseAccelerator] = {
    {specialty = Specialty.HighDamage, probability = 0.1},
    {specialty = Specialty.HighRange, probability = 0.25}
}

function TurretGenerator.generatePulseAcceleratorTurret(rand, dps, tech, material, rarity)
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local _WRANGE = rand:getFloat(850, 1200)
    local _WCOLOR = rand:getFloat(0, 360)
    local _WCOLOROFF = rand:getFloat(-120, 120)
    local _WCOLOROUTVAL = rand:getFloat(0.1, 0.3)
    local _WCOLORINVAL = rand:getFloat(0.7, 0.8)
    local _WROF = rand:getFloat(0.3, 0.5)

    local weapon =
        WeaponGenerator.generatePulseAcceleratorPulsePart(
        rand,
        dps,
        tech,
        material,
        rarity,
        _WRANGE,
        _WCOLOR,
        _WCOLOROFF,
        _WCOLORINVAL,
        _WCOLOROUTVAL,
        _WROF
    )

    local weapon2 =
        WeaponGenerator.generatePulseAcceleratorLaserPart(
        rand,
        dps,
        tech,
        material,
        rarity,
        _WRANGE,
        _WCOLOR,
        _WCOLOROFF,
        _WCOLORINVAL,
        _WCOLOROUTVAL,
        _WROF
    )

    -- attach weapons to turret
    TurretGenerator.attachPulseAccelWeapons(rand, result, {weapon, weapon2})

    local rechargeTime = 30 * rand:getFloat(0.8, 1.2)
    local shootingTime = 28 * rand:getFloat(0.8, 1.2)
    TurretGenerator.createPulseAcceleratorCooling(result, rechargeTime, shootingTime)

    -- add further descriptions
    TurretGenerator.scale(rand, result, WeaponType.PulseAccelerator, tech, 0.7)

    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.PulseAccelerator)

    result.simultaneousShooting = true

    result.slotType = TurretSlotType.Armed
    result:updateStaticStats()

    local name = "Pulse "

    if result.slots >= 4 and result.slots <= 5 then
        name = "Redlight "
    elseif result.slots >= 6 then
        name = "Blacklight "
    end

    if specialties[Specialty.HighDamage] and specialties[Specialty.HighRange] then
        name = name .. "Obliterator"
        specialties[Specialty.HighDamage] = nil
        specialties[Specialty.HighRange] = nil
    else
        name = name .. "Accelerator"
    end

    --/* [outer-adjective][barrel][coax][dmg-adjective][multishot][name][serial], e.g. Enduring Dual Coaxial Plasmatic Tri-Railgun T-F */
    local dmgAdjective, outerAdjective, barrel, multishot, coax, serial =
        makeTitleParts(rand, specialties, result, DamageType.Energy)
    result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)

    return result
end

function TurretGenerator.attachPulseAccelWeapons(rand, turret, weapons)
    turret:clearWeapons()

    local places = {vec3(0, 0, 0), vec3(0, 0, 0)}

    local _widx = 1
    for _, position in pairs(places) do
        local _localWeapon = weapons[_widx]

        _localWeapon.localPosition = position * turret.size
        turret:addWeapon(_localWeapon)

        _widx = _widx + 1
    end
end

function TurretGenerator.createPulseAcceleratorCooling(turret, rechargeTime, shootingTime)
    turret:updateStaticStats()

    local maxCharge
    if turret.dps > 0 then
        maxCharge = turret.dps * 1250
    else
        maxCharge = 625
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

generatorFunction[WeaponType.PulseAccelerator] = TurretGenerator.generatePulseAcceleratorTurret
