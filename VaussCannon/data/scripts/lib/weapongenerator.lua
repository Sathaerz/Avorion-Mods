function WeaponGenerator.generateVaussCannon(rand, dps, tech, material, rarity)
    local _Version = GameVersion()
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = rand:getFloat(0.05, 0.21) --Chaingun is 0.04 - 0.2
    local reach = rand:getFloat(470, 620) --Chaingun is 300 - 450
    local damage = dps * fireDelay
    local speed = rand:getFloat(1000, 1100) --Chaingun is 300 - 400
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.ChainGun
    weapon.name = "Vauss Cannon"
    weapon.prefix = "Vauss Cannon"
    weapon.icon = "data/textures/icons/vausscannon.png" -- previously minigun.png
    weapon.sound = "chaingun"
    weapon.accuracy = 0.99 - rand:getFloat(0, 0.05) --Chaingun is 0 - 0.06

    weapon.damage = damage
    weapon.damageType = DamageType.Physical
    weapon.impactParticles = ImpactParticles.Physical
    weapon.impactSound = 1

    weapon.psize = rand:getFloat(0.1, 0.22) --Chaingun is 0.05 to 0.2
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(rand:getFloat(10, 60), 0.7, 1)

    if rand:test(0.05) then
        local shots = {2, 2, 2, 2, 2, 2, 3, 4}
        weapon.shotsFired = shots[rand:getInt(1, #shots)]

        weapon.damage = (weapon.damage * 1.5) / weapon.shotsFired
    end

    if _Version.major > 1 then
        -- 7.5 % chance for anti matter damage / plasma damage
        if rand:test(0.075) then
            WeaponGenerator.addAntiMatterDamage(rand, weapon, rarity, 1.5, 0.15, 0.2)
        elseif rand:test(0.075) then
            WeaponGenerator.addPlasmaDamage(rand, weapon, rarity, 1.5, 0.1, 0.15)
        elseif rand:test(0.05) then
            WeaponGenerator.addElectricDamage(weapon)
        end
    else
        if rand:test(0.05) then
            WeaponGenerator.addAntiMatterDamage(rand, weapon, rarity, 1.5, 0.15, 0.2)
        end
    end

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)
    weapon.recoil = weapon.damage * 20

    return weapon
end

generatorFunction[WeaponType.VaussCannon] = WeaponGenerator.generateVaussCannon