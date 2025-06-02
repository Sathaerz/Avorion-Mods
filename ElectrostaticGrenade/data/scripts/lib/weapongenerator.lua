--0x7767656E657261746566756E637374617274
function WeaponGenerator.generateElectrostaticGrenade(rand, dps, tech, material, rarity)
    local weapon = Weapon()
    weapon:setProjectile()

    local fireDelay = rand:getFloat(2.5, 3.5)
    local reach = rand:getFloat(500, 550)
    local damage = dps * fireDelay
    local speed = rand:getFloat(500, 700)
    local existingTime = reach / speed

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.appearance = WeaponAppearance.RocketLauncher
    weapon.name = "Electrostatic Grenade Launcher"
    weapon.prefix = "Electrostatic Grenade"
    weapon.icon = "data/textures/icons/esgturret.png"
    weapon.sound = "esglauncher"
    weapon.accuracy = 0.85 - rand:getFloat(0, 0.08)

    weapon.damage = damage
    weapon.damageType = DamageType.Electric
    weapon.impactParticles = ImpactParticles.Energy
    weapon.impactSound = 1
    weapon.impactExplosion = true

    WeaponGenerator.addElectricDamage(weapon)

    -- 10 % chance for plasma
    if rand:test(0.1) then
        WeaponGenerator.addPlasmaDamage(rand, weapon, rarity, 2, 0.15, 0.2)
    end

    weapon.stoneDamageMultiplier = 0.125 --There's still a physical component to this, but most damage is from the dischage.

    weapon.psize = rand:getFloat(0.4, 0.6)
    weapon.pmaximumTime = existingTime
    weapon.pvelocity = speed
    weapon.pcolor = ColorHSV(rand:getFloat(10, 60), 0.7, 1)
    weapon.pshape = ProjectileShape.Rocket

    local shots = {5, 5, 5, 6, 7}
    weapon.shotsFired = shots[rand:getInt(1, #shots)]
    weapon.damage = (weapon.damage * 1.25) / weapon.shotsFired

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    -- these have to be assigned after the weapon was adjusted since the damage might be changed
    weapon.recoil = weapon.damage * 2
    weapon.explosionRadius = math.sqrt(weapon.damage * 5)

    return weapon
end
--0x7767656E657261746566756E63656E64

--0x776D6574617461626C6566756E636C696E65
generatorFunction[WeaponType.ElectroGrenade] = WeaponGenerator.generateElectrostaticGrenade