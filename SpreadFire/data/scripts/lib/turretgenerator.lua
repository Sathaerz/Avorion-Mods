scales[WeaponType.SpreadFire] = {
    {from = 0, to = 30, size = 0.5, usedSlots = 1},
    {from = 31, to = 37, size = 1.0, usedSlots = 2},
    {from = 38, to = 44, size = 1.5, usedSlots = 3},
    {from = 45, to = 48, size = 2.0, usedSlots = 4},
    {from = 49, to = 52, size = 3.0, usedSlots = 5}
}

possibleSpecialties[WeaponType.SpreadFire] = {
    {specialty = Specialty.HighDamage, probability = 0.1},
    {specialty = Specialty.HighRange, probability = 0.1},
    {specialty = Specialty.LessEnergyConsumption, probability = 0.2},
    {specialty = Specialty.HighFireRate, probability = 0.1}
}

local _Version = GameVersion()
if _Version.major <= 1 then
    table.insert(possibleSpecialties[WeaponType.SpreadFire], {specialty = Specialty.AutomaticFire, probability = 0.05})
end

function TurretGenerator.generateSpreadFireTurret(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local result = TurretTemplate()

    -- generate turret
    local requiredCrew = TurretGenerator.dpsToRequiredCrew(dps)
    local crew = Crew()
    crew:add(requiredCrew, CrewMan(CrewProfessionType.Gunner))
    result.crew = crew

    -- generate weapons
    local numWeapons = 2

    local _WROF = rand:getFloat(0.28, 0.38)
    local _WACC1 = 0.99 - rand:getFloat(0, 0.01)
    local _WACC2 = 0.85 - rand:getFloat(0, 0.10)
    local _COLOR = ColorHSV(rand:getFloat(195, 240), 1, 1)
    local _WRANGE = rand:getFloat(580, 880) --Plasma gun is normaly 550 - 800
    local _WVEL = rand:getFloat(400, 600) --Plasma gun is normally 500 - 700
    local _WSIZE = rand:getFloat(0.4, 0.7) --Plasma gun is normally 0.4 to 0.8

    local weapon = WeaponGenerator.generateSpreadFire(rand, dps, tech, material, rarity, _WROF, _WACC1, _COLOR, _WRANGE, _WVEL, _WSIZE)
    weapon.fireDelay = weapon.fireDelay * numWeapons

    local weapon2 = WeaponGenerator.generateSpreadFire(rand, dps, tech, material, rarity, _WROF, _WACC2, _COLOR, _WRANGE, _WVEL, _WSIZE)
    weapon2.fireDelay = weapon2.fireDelay * numWeapons

    -- attach weapons to turret
    TurretGenerator.attachSpreadfireWeapons(rand, result, { weapon, weapon2 })

    local rechargeTime = 18 * rand:getFloat(0.8, 1.2)
    local shootingTime = 30 * rand:getFloat(0.8, 1.2)
    TurretGenerator.createBatteryChargeCooling(result, rechargeTime, shootingTime)

    -- add further descriptions
    TurretGenerator.scale(rand, result, WeaponType.SpreadFire, tech, 0.7)
    local specialties = TurretGenerator.addSpecialties(rand, result, WeaponType.SpreadFire)

    if _Version.major > 1 then
        result.slotType = TurretSlotType.Armed
    end

    result:updateStaticStats()

    if _Version.major > 1 then
        local name = "Spreadfire Cannon"

        local dmgAdjective, outerAdjective, barrel, multishot, coax, serial = makeTitleParts(rand, specialties, result, DamageType.Energy)
        --/* [outer-adjective][coax][dmg-adjective][name][serial], e.g. Enduring Dual Coaxial E-Tri-Plasma Cannon T-F */
        result.title = Format("%1%%2%%3%%4%%5%", outerAdjective, coax, dmgAdjective, name, serial)
    else
        if result.coaxial then
            result.title = "Coaxial Spreadfire Cannon Turret"
        else
            result.title = "Spreadfire Cannon Turret"
        end
    end

    return result
end

function TurretGenerator.attachSpreadfireWeapons(rand, turret, weapons)
    turret:clearWeapons()

    local places = {TurretGenerator.createWeaponPlaces(rand, #weapons)}

    local _widx = 1
    for _, position in pairs(places) do
        local _localWeapon = weapons[_widx]

        _localWeapon.localPosition = position * turret.size
        turret:addWeapon(_localWeapon)

        _widx = _widx+1
    end
end

generatorFunction[WeaponType.SpreadFire] = TurretGenerator.generateSpreadFireTurret