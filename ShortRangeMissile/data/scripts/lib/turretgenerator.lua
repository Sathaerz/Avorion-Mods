scales[WeaponType.ShortRangeMissile] = {
    {from = 0, to = 30, size = 0.5, usedSlots = 1},
    {from = 31, to = 39, size = 1.0, usedSlots = 2},
    {from = 40, to = 48, size = 1.5, usedSlots = 3},
    {from = 49, to = 52, size = 2.0, usedSlots = 4},
}

--This used to have HighShootingTime as a specialty, but those were ridiculously overpowered.
possibleSpecialties[WeaponType.ShortRangeMissile] = {
    {specialty = Specialty.HighDamage, probability = 0.25},
    {specialty = Specialty.HighRange, probability = 0.1},
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(possibleSpecialties[WeaponType.ShortRangeMissile], {specialty = Specialty.AutomaticFire, probability = 0.05})
end

function TurretGenerator.generateShortRangeMissileTurret(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = rand:getInt(1, 2)

    local weapon = WeaponGenerator.generateShortRangeMissile(rand, dps, tech, material, rarity)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    -- attach weapons to turret
    local positions = {}
    if rand:getBool() then
        table.insert(positions, vec3(0, 0.3, 0))
    else
        table.insert(positions, vec3(0.4, 0.3, 0))
        table.insert(positions, vec3(-0.4, 0.3, 0))
    end

    -- attach
    for _, position in pairs(positions) do
        weapon.localPosition = position * result.size
        result:addWeapon(weapon)
    end

    local shootingTime = 1.5 * rand:getFloat(0.8, 1.2) --Standard rocket launcher is 20
    local coolingTime = 9 * rand:getFloat(0.8, 1.2) --Standard rocket launcher is 15
    TurretGenerator.createStandardCooling(result, coolingTime, shootingTime)

    TurretGenerator.scale(rand, result, WeaponType.ShortRangeMissile, tech, 0.6)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.ShortRangeMissile)

    if _Version.major > 1 then
        result.slotType = TurretSlotType.Armed
    end

    result:updateStaticStats()

    if _Version.major > 1 then
        local name = "SRM Launcher"

        if result.slots == 3 then 
            name = "SRM Battery"
        elseif result.slots == 4 then
            name = "SRM Phalanx"
        end

        if specialties[Specialty.HighDamage] and specialties[Specialty.HighRange] then
            name = "Streak SRM Launcher"
            specialties[Specialty.HighDamage] = nil
            specialties[Specialty.HighRange] = nil
        end

        local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Physical)
        --/* [outer-adjective][barrel][coax][dmg-adjective][multishot][name][serial], e.g. Enduring Dual Coaxial Anti-Tri-Missile Battery T-F */
        result.title = Format("%1%%2%%3%%4%%5%%6%%7%", outerAdjective, barrel, coax, dmgAdjective, multishot, name, serial)
    end

    return result
end

generatorFunction[WeaponType.ShortRangeMissile] = TurretGenerator.generateShortRangeMissileTurret