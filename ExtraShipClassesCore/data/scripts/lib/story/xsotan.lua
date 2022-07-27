function Xsotan.createInfestor(_position, _volumeFactor, _extraLoot)
    local _MethodName = "Spawn Xsotan Infestor"
    mission.Log(_MethodName, "Beginning...")

    local _X, _Y = Sector():getCoordinates()
    --Initialize a bunch of turret generator stuff.
    local _TurretGenerator = SectorTurretGenerator()
    local _TurretRarities = _TurretGenerator:getSectorRarityDistribution(_X, _Y)
    local _UpgradeGenerator = UpgradeGenerator()
    local _UpgradeRarities = _UpgradeGenerator:getSectorRarityDistribution(_X, _Y)

    local _XsotanInfestor = Xsotan.createSummoner(_position, _volumeFactor)

    local name = "Infestor"
    _XsotanInfestor:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanInfestor:setValue("is_infestor", true)

    --Add extra loot. Guarantee rare+ with less likely rares.
    local _DropCount = 2
    _TurretRarities[-1] = 0 --No petty.
    _TurretRarities[0] = 0 --No common
    _TurretRarities[1] = 0 --No uncommon
    _TurretRarities[2] = _TurretRarities[2] * 0.5 --Cut rare chance in half

    _UpgradeRarities[-1] = 0
    _UpgradeRarities[0] = 0
    _UpgradeRarities[1] = 0
    _UpgradeRarities[2] = _UpgradeRarities[2] * 0.5 --See above.

    _TurretGenerator.rarities = _TurretRarities
    for _ = 1, _DropCount do
        Loot(_XsotanInfestor):insert(InventoryTurret(_TurretGenerator:generate(_X, _Y)))
    end
    for _ = 1, _DropCount do
        Loot(_XsotanInfestor):insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, getValueFromDistribution(_UpgradeRarities)))
    end

    if _extraLoot then 
        _TurretRarities[2] = 0
        _UpgradeRarities[2] = 0

        Loot(_XsotanInfestor):insert(InventoryTurret(_TurretGenerator:generate(_X, _Y)))
        Loot(_XsotanInfestor):insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, getValueFromDistribution(_UpgradeRarities)))
    end

    _XsotanInfestor.damageMultiplier = (_XsotanInfestor.damageMultiplier or 1 ) * 2

    return _XsotanInfestor
end

function Xsotan.createOppressor(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createShip(_position, _volumeFactor)

    local name = "Oppressor"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_oppressor", true)

    --Add Scripts
    _XsotanShip:addScriptOnce("oppressor.lua")

    return _XsotanShip
end

function Xsotan.createSunmaker(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createShip(_position, _volumeFactor)

    local name = "Sunmaker"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_sunmaker", true)

    --Add Scripts
    local _X, _Y = Sector():getCoordinates()

    local _SunGData = {} --Sunmaker Seige Gun
    _SunGData._TimeToActive = 12
    _SunGData._Velocity = 180
    _SunGData._ShotCycle = 30
    _SunGData._ShotCycleSupply = 0
    _SunGData._ShotCycleTimer = 0
    _SunGData._UseSupply = false
    _SunGData._FragileShots = false
    _SunGData._TargetPriority = 8 --Random non-xsotan.
    _SunGData._UseEntityDamageMult = true
    _SunGData._BaseDamagePerShot = Balancing_GetSectorWeaponDPS(_X, _Y) * 1500

    _XsotanShip:addScriptOnce("entity/stationsiegegun.lua", _SunGData)

    return _XsotanShip
end

function Xsotan.createBallistyx(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createShip(_position, _volumeFactor)

    local name = "Ballistyx"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_ballistyx", true)

    --Add Scripts
    local _TorpSlammerValues = {}
    _TorpSlammerValues._TimeToActive = 12
    _TorpSlammerValues._ROF = 4
    _TorpSlammerValues._UpAdjust = false
    _TorpSlammerValues._DurabilityFactor = 4
    _TorpSlammerValues._ForwardAdjustFactor = 1
    _TorpSlammerValues._UseEntityDamageMult = true
    _TorpSlammerValues._TargetPriority = 3 --Random non-xsotan.

    _XsotanShip:addScriptOnce("torpedoslammer.lua", _TorpSlammerValues)

    return _XsotanShip
end

function Xsotan.createLonginus(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createShip(_position, _volumeFactor)

    local name = "Longinus"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_longinus", true)

    --Add Scripts
    local _X, _Y = Sector():getCoordinates()

    local _LaserDamage = Balancing_GetSectorWeaponDPS(_X, _Y) * 250

    local _LaserSniperValues = {}
    _LaserSniperValues._DamagePerFrame = _LaserDamage
	_LaserSniperValues._UseEntityDamageMult = true
    _LaserSniperValues._TargetPriority = 2 --Random non-xsotan.
    _LaserSniperValues._TargetingTime = 2.25 --Take longer than normal to target.
    
    _XsotanShip:addScriptOnce("lasersniper.lua", _LaserSniperValues)

    return _XsotanShip
end

function Xsotan.createPulverizer(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createGenericShip(_position, _volumeFactor)

    local name, type = ShipUtility.getMilitaryNameByVolume(_XsotanShip.volume)
    _XsotanShip:setTitle("${toughness}Xsotan Pulverizer ${ship}"%_T, {toughness = "", ship = name})
    _XsotanShip:setValue("is_pulverizer", true)

    ShipUtility.addPulverizerCannons(_XsotanShip)

    return _XsotanShip
end

function Xsotan.createWarlock(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createShip(_position, _volumeFactor)

    local name = "Warlock"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_warlock", true)

    --Add Scripts
    _XsotanShip:addScriptOnce("reanimator.lua")

    return _XsotanShip
end

function Xsotan.createHierophant(_position, _volumeFactor)
    local _XsotanShip = Xsotan.createSummoner(_position, _volumeFactor)

    local name = "Hierophant"
    _XsotanShip:setTitle("${toughness}Xsotan ${ship}", {toughness = "", ship = name})
    _XsotanShip:setValue("is_hierophant", true)

    --Add Scripts
    _XsotanShip:addScriptOnce("reanimator.lua")

    return _XsotanShip
end

function Xsotan.createRevenant(_Wreckage)
    local _Sector = Sector()
    --Get plan from wreckage.
    local plan = _Wreckage:getMovePlan()
    local _position = _Wreckage.position
    local faction = Xsotan.getFaction()
    --Infect.
    Xsotan.infectPlan(plan)

    local ship = _Sector:createShip(faction, "", plan, _position, EntityArrivalType.Default)

    ShipUtility.addRevenantArtillery(ship)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    name = "Revenant"
    ship:setTitle("${toughness}Xsotan ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:setValue("is_revenant", true)

    Boarding(ship).boardable = false

    _Sector:deleteEntity(_Wreckage)

    return ship
end

function Xsotan.getSpecialXsotanFunctions()
    return {
        Xsotan.createOppressor,
        Xsotan.createSunmaker,
        Xsotan.createLonginus,
        Xsotan.createBallistyx,
        Xsotan.createWarlock
    }
end

function Xsotan.createGenericShip(position, volumeFactor)
    position = position or Matrix()
    local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())

    volume = volume * (volumeFactor or 1)
    volume = volume * 0.5 -- xsotan ships aren't supposed to be very big

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local material = Material(getValueFromDistribution(probabilities))
    local faction = Xsotan.getFaction()
    local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
    local ship = Sector():createShip(faction, "", plan, position, EntityArrivalType.Jump)

    local name, type = ShipUtility.getMilitaryNameByVolume(ship.volume)
    ship:setTitle("${toughness}Xsotan ${ship}"%_T, {toughness = "", ship = name})
    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    Xsotan.upScale(ship)

    AddDefaultShipScripts(ship)

    ship:addScriptOnce("ai/patrol.lua")
    ship:addScriptOnce("story/xsotanbehaviour.lua")
    ship:addScriptOnce("utility/aiundockable.lua")
    ship:setValue("is_xsotan", true)

    Boarding(ship).boardable = false

    return ship
end