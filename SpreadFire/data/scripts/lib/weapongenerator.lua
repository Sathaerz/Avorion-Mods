function WeaponGenerator.generateSpreadFire(rand, dps, tech, material, rarity, _ROF, _ACC, _COLOR, _RANGE, _VELOCITY, _SIZE)
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = _ROF or rand:getFloat(0.28, 0.38) --In case it is nil
    local reach = _RANGE or rand:getFloat(580, 880)
    local damage = dps * fireDelay
    local speed = _VELOCITY or rand:getFloat(400, 600)
    local weaponcolor = _COLOR or ColorHSV(rand:getFloat(195, 240), 1, 1)
    local weaponaccuracy =  _ACC or 0.99 - rand:getFloat(0, 0.01) --Favor the more accurate variety for just the weapon generation.
    local projectilesize = _SIZE or rand:getFloat(0.4, 0.7)
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.PlasmaGun
    weapon.name = "Spreadfire Cannon /* Weapon Name*/"%_t
    weapon.prefix = "Spreadfire /* Weapon Prefix*/"%_t
    weapon.icon = "data/textures/icons/spreadfire.png" -- previously tesla-turret.png
    weapon.sound = "plasma"
    weapon.accuracy = weaponaccuracy

    weapon.damage = damage
    weapon.damageType = DamageType.Energy
    weapon.impactParticles = ImpactParticles.Energy
    weapon.impactSound = 1
    weapon.pshape = ProjectileShape.Plasma

    weapon.psize = projectilesize
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = weaponcolor
    
    weapon.shotsFired = 3
    weapon.damage = weapon.damage * 1.5 / weapon.shotsFired

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    weapon.recoil = weapon.damage * 4

    return weapon
end

generatorFunction[WeaponType.SpreadFire] = WeaponGenerator.generateSpreadFire