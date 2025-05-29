--0x7767656E657261746566756E637374617274
function WeaponGenerator.generateMassDriver(rand, dps, tech, material, rarity)
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = rand:getFloat(4.5, 5.5)
    local reach = rand:getFloat(3000, 3400)
    local damage = dps * fireDelay * 0.6 --These things are way too good if they're not weakened a bit. Insane burst damage, range, and accuracy. Something has to go.
    local speed = rand:getFloat(1800, 2000)
    if rarity.value >= 3 then --exceptional (3)
        speed = speed + rand:getFloat(0, 100)
    end
    if rarity.value >= 4 then --exotic (4)
        speed = speed + rand:getFloat(0, 100)
    end
    if rarity.value >= 5 then --legendary (5)
        speed = speed + rand:getFloat(100, 300)
    end
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    if tech <= 32 then
        weapon.appearance = WeaponAppearance.Bolter
    else
        --tech 33+
        damage = dps * fireDelay * 0.7 --These need to scale a bit better towards mid-game, otherwise they're just not worth using over cannons / seekers.
        weapon.appearance = WeaponAppearance.Cannon
    end
    weapon.name = "Mass Driver"
    weapon.prefix = "Mass Driver"
    weapon.icon = "data/textures/icons/massdriver.png"
    weapon.sound = "massdriver"
    local rarityAccuracyReduction = 0.01 --Petty (-1) / common (0) / uncommon (1)
    if rarity.value == 2 then --rare (2)
        rarityAccuracyReduction = 0.005
    end
    if rarity.value == 3 then --exceptional (3)
        rarityAccuracyReduction = 0.0025
    end
    if rarity.value > 3 then --exotic (4) / legendary (5)
        rarityAccuracyReduction = 0
    end
    weapon.accuracy = 0.99 - rand:getFloat(0, rarityAccuracyReduction)

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
--0x7767656E657261746566756E63656E64

--0x776D6574617461626C6566756E636C696E65
generatorFunction[WeaponType.MassDriver] = WeaponGenerator.generateMassDriver