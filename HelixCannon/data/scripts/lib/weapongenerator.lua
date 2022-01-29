function WeaponGenerator.generateHelixCannon(rand, dps, tech, material, rarity, _ROF, _ACC, _COLOR, _RANGE, _VELOCITY, _SIZE, _SEED)
    local _Version = GameVersion
    local weapon = Weapon()
    weapon:setProjectile()

    --NULL values come into play when generating a single weapon for fighters -- anything after "Rarity" will be null.
    local fireDelay = _ROF or rand:getFloat(0.15, 0.25)
    local reach = _RANGE or rand:getFloat(620, 920)
    local damage = dps * fireDelay
    local speed = _VELOCITY or rand:getFloat(410, 620)
    local weaponcolor = _COLOR or ColorHSV(rand:getFloat(135, 180), 1, 1)
    local weaponaccuracy =  _ACC or 0.99 - rand:getFloat(0, 0.01) --Favor the more accurate variety for just the weapon generation.
    local projectilesize = _SIZE or rand:getFloat(0.4, 0.8)
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = _SEED or rand:getInt()
    weapon.appearance = WeaponAppearance.PlasmaGun
    weapon.name = "Helix Cannon /* Weapon Name*/"%_t
    weapon.prefix = "Helix /* Weapon Prefix*/"%_t
    weapon.icon = "data/textures/icons/helixcannon.png" -- previously tesla-turret.png
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

    weapon.shotsFired = 5
    weapon.damage = weapon.damage * 2 / weapon.shotsFired --These scale better than normal to make up for the truly horrible accuracy.

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    weapon.recoil = weapon.damage * 5

    return weapon
end

generatorFunction[WeaponType.HelixCannon] = WeaponGenerator.generateHelixCannon