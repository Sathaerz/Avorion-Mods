function WeaponGenerator.generatePulseAcceleratorLaserPart(rand, dps, tech, material, rarity, _WRANGE, _WCOLOR, _WCOLOROFF, _WOUTVAL, _WINVAL, _WROF)
    local weapon = Weapon()
    weapon:setBeam()

    local fireDelay = _WROF or rand:getFloat(0.3, 0.5)
    local reach = _WRANGE or rand:getFloat(850, 1200)
    local damage = 0 --dps * fireDelay * 3
    local weaponcolor = _WCOLOR or rand:getFloat(0, 360)
    local weaponcoloroffset = _WCOLOROFF or rand:getFloat(-120, 120)
    local outerval = _WOUTVAL or rand:getFloat(0.1, 0.3)
    local innerval = _WINVAL or rand:getFloat(0.7, 0.8)

    weapon.fireDelay = fireDelay
    weapon.reach = reach
    weapon.appearanceSeed = rand:getInt()
    weapon.continuousBeam = true
    weapon.appearance = WeaponAppearance.RailGun
    weapon.name = "Pulse Accelerator /* Weapon Name*/"%_t
    weapon.prefix = "Pulse Accelerator /* Weapon Prefix*/"%_t
    weapon.icon = "data/textures/icons/pulseaccel.png" -- previously laser-blast.png
    weapon.sound = "laser"

    weapon.damage = damage
    weapon.damageType = DamageType.Energy
    weapon.blength = weapon.reach

    weapon.bouterColor = ColorHSV(weaponcolor, 1, outerval)
    weapon.binnerColor = ColorHSV(weaponcolor + weaponcoloroffset, 0.3, innerval)
    weapon.bshape = BeamShape.Straight
    weapon.bwidth = 0.5
    weapon.bauraWidth = 1
    weapon.banimationSpeed = 4

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    return weapon
end

function WeaponGenerator.generatePulseAcceleratorPulsePart(rand, dps, tech, material, rarity, _WRANGE, _WCOLOR, _WCOLOROFF, _WOUTVAL, _WINVAL, _WROF)
    local weapon = Weapon()
    weapon:setBeam()

    local fireDelay = _WROF or rand:getFloat(0.3, 0.5)
    local reach = _WRANGE or rand:getFloat(850, 1200)
    local damage = dps * fireDelay * 3.5
    local weaponcolor = _WCOLOR or rand:getFloat(0, 360)
    local weaponcoloroffset = _WCOLOROFF or rand:getFloat(-120, 120)
    local outerval = _WOUTVAL or rand:getFloat(0.1, 0.3)
    local innerval = _WINVAL or rand:getFloat(0.7, 0.8)

    weapon.fireDelay = fireDelay
    weapon.appearanceSeed = rand:getInt()
    weapon.reach = reach
    weapon.continuousBeam = false
    weapon.appearance = WeaponAppearance.Invisible
    weapon.name = "Pulse Accelerator /* Weapon Name*/"%_t
    weapon.prefix = "Pulse Accelerator /* Weapon Prefix*/"%_t
    weapon.icon = "data/textures/icons/pulseaccel.png"
    weapon.sound = "railgun"

    weapon.damage = damage
    weapon.damageType = DamageType.Energy
    weapon.impactParticles = ImpactParticles.Energy
    weapon.impactSound = 1

    weapon.bouterColor = ColorHSV(weaponcolor, 1, outerval)
    weapon.binnerColor = ColorHSV(weaponcolor + weaponcoloroffset, 0.3, innerval)
    weapon.blength = weapon.reach
    weapon.bshape = BeamShape.Straight
    weapon.bwidth = 0.6
    weapon.bauraWidth = 5
    weapon.banimationSpeed = 10
    weapon.banimationAcceleration = -2

    WeaponGenerator.adaptWeapon(rand, weapon, tech, material, rarity)

    weapon.recoil = weapon.damage * 20

    return weapon
end

generatorFunction[WeaponType.PulseAccelerator] = WeaponGenerator.generatePulseAcceleratorPulsePart