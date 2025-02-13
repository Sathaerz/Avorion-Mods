function WeaponGenerator.generateMassDriver(rand, dps, tech, material, rarity)
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = rand:getFloat(4.15, 5.15)
    local reach = rand:getFloat(3000, 3400)
    local damage = dps * fireDelay * 0.5 --These things are way too good if they're not weakened a bit. Insane burst damage, range, and accuracy. Something has to go.
    local speed = rand:getFloat(2600, 2800)
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    if tech <= 32 then
        weapon.appearance = WeaponAppearance.Bolter
    else
        weapon.appearance = WeaponAppearance.Cannon
    end
    weapon.name = "Mass Driver"
    weapon.prefix = "Mass Driver"
    weapon.icon = "data/textures/icons/massdriver.png" -- previously minigun.png
    weapon.sound = "massdriver"
    weapon.accuracy = 0.99

    weapon.damage = damage
    weapon.damageType = DamageType.Physical
    weapon.impactParticles = ImpactParticles.Physical
    weapon.impactSound = 1

    weapon.psize = rand:getFloat(0.04, 0.16)
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(rand:getFloat(10, 60), 0.7, 1)

    -- 7.5 % chance for anti matter damage
    if rand:test(0.075) then
        WeaponGenerator.addAntiMatterDamage(rand, weapon, rarity, 1.5, 0.15, 0.2)
    end

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)
    weapon.recoil = weapon.damage * 40

    return weapon
end

generatorFunction[WeaponType.MassDriver] = WeaponGenerator.generateMassDriver