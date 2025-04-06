function WeaponGenerator.generateArsPulseLaser(rand, dps, tech, material, rarity, _WSCALE)
    local weapon = Weapon()
    weapon:setProjectile()

    local weaponScale = _WSCALE or 1 --Relevant when a fighter weapon is generated.

    --Lots of these stats depend on slots. Large Pulse Lasers have better stats than the other two but consume more power.
    local fireDelay = rand:getFloat(0.15, 0.35)
    local reach = rand:getFloat(400, 450)
    local damage = dps * fireDelay
    local speed = rand:getFloat(575, 750)
    local _pSize = rand:getFloat(0.05, 0.2)
    local _pColorHVALUE = rand:getFloat(0, 360)
    local _idealHValue = 0

    if weaponScale == 3 or weaponScale == 4 then
        fireDelay = rand:getFloat(0.45, 0.6)
        reach = rand:getFloat(625, 675)
        damage = dps * fireDelay * 1.25
        _pSize = rand:getFloat(0.1, 0.25)
        _idealHValue = 120
    elseif weaponScale >= 5 then
        fireDelay = rand:getFloat(1.25, 1.4)
        reach = rand:getFloat(850, 900)
        damage = dps * fireDelay * 1.55
        _pSize = rand:getFloat(0.15, 0.3)
        _idealHValue = 240
    end

    --Small pulse lasers have a bias towards red (0), medium towards green (120), and large towards blue (240).
    --It's possible that the value will be adjustbed by 0, and that's fine.
    local _adjustHVALUE = 0
    if _pColorHVALUE > _idealHValue then
        _adjustHVALUE = rand:getFloat(0, 60) * -1
    elseif _pColorHVALUE < _idealHValue then
        _adjustHVALUE = rand:getFloat(0, 60)
    end

    _pColorHVALUE = _pColorHVALUE + _adjustHVALUE

    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.PulseCannon
    weapon.icon = "data/textures/icons/arspulselaser.png"
    weapon.name = "Pulse Laser"
    weapon.prefix = "Pulse Laser"
    weapon.sound = "splas"
    if weaponScale == 3 or weaponScale == 4 then
        weapon.sound = "mplas"
    elseif weaponScale >= 5 then
        weapon.sound = "lplas"
    end
    weapon.accuracy = 0.99 - rand:getFloat(0, 0.06)

    weapon.damage = damage
    weapon.damageType = DamageType.Energy
    weapon.impactParticles = ImpactParticles.Energy
    weapon.impactSound = 1

    weapon.psize = _pSize
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(_pColorHVALUE, 0.72, 1)

    -- 10 % chance for plasma
    if rand:test(0.1) then
        WeaponGenerator.addPlasmaDamage(rand, weapon, rarity, 1.75, 0.125, 0.175)
    end

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)
    weapon.recoil = weapon.damage * 20

    --Needed for debugging when the scale was janked.
    --print("final weapon scale is " .. tostring(weaponScale) .. " final fire delay is " .. tostring(fireDelay) .. " final sound is " .. tostring(weapon.sound))

    return weapon
end

generatorFunction[WeaponType.ArsPulseLaser] = WeaponGenerator.generateArsPulseLaser