function WeaponGenerator.generateFusionCannon(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = rand:getFloat(3.75, 4.75)   --Normal cannon is 1.5 to 2.5
    local reach = rand:getFloat(750, 1050)      --Normal cannon is 1100 to 1500
    local damage = dps * fireDelay
    local speed = rand:getFloat(450, 550)       --Normal cannon is 300 - 400
    local existingTime = reach / speed

    if _Version.major > 1 then
        speed = rand:getFloat(650, 850) --2.0 cannon is 600 - 800
    end

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.Cannon
    weapon.name = "Fusion Cannon /* Weapon Name*/"%_t
    weapon.prefix = "Fusion Cannon /* Weapon Prefix*/"%_t
    weapon.icon = "data/textures/icons/fusioncannon.png" -- previously hypersonic-bolt.png
    weapon.sound = "fusion"
    weapon.accuracy = 0.99 - rand:getFloat(0, 0.01)

    weapon.damage = damage
    weapon.damageType = DamageType.Energy
    weapon.impactParticles = ImpactParticles.Explosion
    weapon.impactSound = 1
    weapon.impactExplosion = true

    -- 15 % chance for anti matter damage
    if rand:test(0.15) then
        WeaponGenerator.addAntiMatterDamage(rand, weapon, rarity, 2, 0.15, 0.2)
    end

    weapon.psize = rand:getFloat(0.75, 1.0)  --Normal cannon is 0.2 to 0.5
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(rand:getFloat(280, 325), 1, 1)

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    -- these have to be assigned after the weapon was adjusted since the damage might be changed
    weapon.recoil = weapon.damage * 30 --Normal cannon is * 20
    weapon.explosionRadius = math.sqrt(weapon.damage * 5) --Normal cannon is sqrt * 5

    return weapon
end

generatorFunction[WeaponType.FusionCannon              ] = WeaponGenerator.generateFusionCannon