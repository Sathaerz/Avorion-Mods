function WeaponGenerator.generatePlasmaFlamer(rand, dps, tech, material, rarity)
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = 0.005
    local reach = rand:getFloat(120, 150)
    local damage = dps * fireDelay * 0.5 --Low damage but terrifying shield stripping potential.
    local speed = rand:getFloat(500, 700)
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.PlasmaGun
    weapon.name = "Plasma Flamer"
    weapon.prefix = "Plasma Flamer"
    weapon.icon = "data/textures/icons/plasmaflamer.png" -- previously tesla-turret.png
    weapon.sound = "plasmaflamer"
    weapon.accuracy = 0.98 - rand:getFloat(0, 0.03)

    weapon.damage = damage
    weapon.damageType = DamageType.Plasma
    weapon.impactParticles = ImpactParticles.Energy
    weapon.impactSound = 1
    --weapon.pshape = ProjectileShape.Plasma

    -- 100 % chance for plasma damage
    -- Formula is shield damage multiplier = (flat factor) + (random 0 to random factor) + (rarity * factor)
    WeaponGenerator.addPlasmaDamage(rand, weapon, rarity, 8.3, 1.3, 0.3)

    weapon.psize = rand:getFloat(1.1, 1.5)
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(rand:getFloat(0, 360), 0.7, 1)

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    weapon.recoil = weapon.damage * 4

    return weapon
end

generatorFunction[WeaponType.PlasmaFlamer] = WeaponGenerator.generatePlasmaFlamer