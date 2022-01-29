include("galaxy")

ESCCUtil = include("esccutil")

local PariahUtil = {}
local self = PariahUtil

self._Debug = 0

function PariahUtil.getFaction()
    local _Galaxy = Galaxy()
    local name = "The Pariah"%_T
    local faction = _Galaxy:findFaction(name)
    if faction == nil then
        faction = _Galaxy:createFaction(name, 0, 0)
        faction.initialRelations = 0
        faction.initialRelationsToPlayer = 0
        faction.staticRelationsToPlayers = true
    end

    faction.initialRelationsToPlayer = 0
    faction.staticRelationsToPlayers = true
    faction.homeSectorUnknown = true

    return faction
end

function PariahUtil.spawnSuperWeapon(_MainWeapon, _AuxWeapon)
    local _MethodName = "Spawn Superweapon"
    self.Log(_MethodName, "Beginning...")

    local _Faction = self.getFaction()
    if not _Faction then
        self.Log(_MethodName, "ERROR - Could not get faction.")
        return
    end

    local _Rgen = ESCCUtil.getRand()
    _MainWeapon = _MainWeapon or _Rgen:getInt(1, 2)
    _AuxWeapon = _AuxWeapon or _Rgen:getInt(1, 2)

    local _Type = tostring(_Rgen:getInt(1, 6))
    if _MainWeapon == 2 then
        _Type = tostring(_Rgen:getInt(1, 6))
        _Type = "X" .. _Type
    end

    local _PlanFileName = "data/plans/Type" .. tostring(_Type) .. ".xml"
    self.Log(_MethodName, "Loading plan : " .. tostring(_PlanFileName))

    local _Plan = LoadPlanFromFile(_PlanFileName)
    local _Scale = 3

    local PirateGenerator = include("pirategenerator")
    local ShipUtility = include("shiputility")

    local _Factor = 70
    local _DamageFactor = 85
    local _Amp = 1

    --Calculate amp here.
    local _ActiveMods = Mods()
    local _ic1 = false
    local _ic2 = false

    self.Log(_MethodName, "Checking Amp")

    local _AmpTable = {
        ["2017677089"] = 0,     --Weapon Engineering is _Amp + 3 - Just want to note that it is on the list here. We have a special set of detection triggers for this later in the file.
        ["2191291553"] = 3,     --HarderEnemys - Your wish has been granted.
        ["2442089978"] = 3,     --Amped UP DPS - Sure, it makes the Gordian Knot hit harder, but we need to compensate with HP.
        ["1991691736"] = 2,     --Turret Replicator for turret factories
        ["1789307930"] = 2,     --PowerTurrets (WIP)
        ["2014035735"] = 2,     --Scaling Turret System
        ["2052687922"] = 0.5,   --Pirate Drop Extra Turrets
        ["1905374778"] = 1.5,   --Nanobot System Upgrade
        ["2021277562"] = 1.5,   --Nanobot updated and reworked
        ["2286575730"] = 1,     --Ancient Weapons
        ["2289497873"] = 1,     --Just Sell Me Guns Already
        ["1821043731"] = 2,     --High Efficiency Turrets (HET)
        ["1990599419"] = 3,     --v31-DmgFix
        ["2188351263"] = 1,     --Customize Turret Factory
        ["2043905084"] = 1,     
        ["2033776157"] = 1,
        ["2201230263"] = 1,     --Turret X4 - 28 RNG Edition!
        ["2187486306"] = 1,     --Turret Rebalance
        ["2091059429"] = 1,
        ["2002338565"] = 1,     --Custom Turret Builder II
        ["2039371866"] = 1,     --Custom Turret Builder III
        ["2130593404"] = 1,     --Custom Turret Designer
        ["2202592882"] = 1,     --Custom Turret Builder IV - SR
        ["2180668115"] = 1,     --Custom Turret Builder IV
        ["2084524044"] = 1,     --Specialized Military Shield Enhancer (SDK)
        ["2083280364"] = 1,     --Specialized Military Shield Booster (SDK)
        ["2087270794"] = 1,     --Specialized Military Hull Reinforcement (SDK)
        ["2093389493"] = 1,     --Specialized Military Turret Control System (SDK)
        ["2224360054"] = 1,     --Box Corp. !A Box Full Of Weapons!
        ["1912649093"] = 1,     --8x Turrets with reduced energy drain
        ["2287007906"] = 1,     --Custom Armed Turret Slots
        ["1847988904"] = 1,     --Weapon Pack Extended
        ["2021071111"] = 0.5,   --Plasma blaster turret
        ["2021183079"] = 0.5,   --Autocannon turret
        ["2033631749"] = 0.5,   --Armour Hardener
        ["1987912889"] = 0.5,   --Custom Fighter Builder II
        ["2287007906"] = 0.5,   --Custom Armed Turret Slots
        ["2021850808"] = 0.5,
        ["2127387501"] = 0.5,
        ["2201245637"] = 0.5,
        ["1817506461"] = 0.5,   --Turrets_x4
        ["2070272331"] = 0.5    --Capital Class Weapons
    }

    for _, _Xmod in pairs(_ActiveMods) do
        if _Xmod.id == "2017677089" or _Xmod.name == "DccWeaponEngineering" or _Xmod.title == "Weapon Engineering" then
            _Amp = _Amp + 3
            _ic2 = true
        end
        if _Xmod.id == "2052687922" or _Xmod.id == "1991691736" or _Xmod.id == "2289497873" then
            _ic1 = true
        end
        local _xAmp = _AmpTable[_Xmod.id]
        if _xAmp then
            _Amp = _Amp + _xAmp
        end
    end

    if not _ic2 then
        --Extra check to see if people are being sneaky.
        local _Players = {Sector():getPlayers()}
        for _, _P in pairs(_Players) do
            if _P:hasScript("TurretModding") or _P:hasScript("mods/DccTurretEditor/Commands/TurretModding") then
                _Amp = _Amp + 6
                _ic2 = true
                break
            end
        end
    end

    if _ic1 and _ic2 then
        _Amp = _Amp * 2
    end

    local _FinalFactor = _Factor * _Amp
    local _FinalDamageFactor = _DamageFactor * _Amp

    _Plan:scale(vec3(_Scale, _Scale, _Scale))

    local _Superweapon = Sector():createShip(_Faction, "", _Plan, PirateGenerator.getGenericPosition())
    local _AdjustSlammer = false
    local _TurnFactor = 1.0

    local _ShipNameTitle = "SW-T" .. tostring(_Type) .. "-MW"
    if _MainWeapon == 1 then
        _ShipNameTitle = _ShipNameTitle .. "SG-AW"
        --Siege Gun
        --Siege Gun Data
        local _SGD = {}
		_SGD._CodesCracked = false
		_SGD._Velocity = 400
		_SGD._ShotCycle = 30
		_SGD._ShotCycleSupply = 0
		_SGD._ShotCycleTimer = 30
		_SGD._UseSupply = false
		_SGD._FragileShots = false
		_SGD._TargetPriority = 3 --Target the most dangerous enemies first.

        local _Damage = 500000000 --500 million base damage, since this can't go through shields.
        _Damage = _Damage * math.max(1, _Amp / 2)
        _SGD._BaseDamagePerShot = _Damage

        _Superweapon:addScript("entity/stationsiegegun.lua", _SGD)
        ShipAI(_Superweapon.id):setAggressive()
        self.Log(_MethodName, "Attached siege gun script to SuperWeapon.")
    else
        _ShipNameTitle = _ShipNameTitle .. "LB-AW"
        --Laser Boss
        _AdjustSlammer = true
        _Superweapon:addScript("entity/gordianlaserboss.lua", _Amp)
        _TurnFactor = 2
        self.Log(_MethodName, "Attached laser boss script to SuperWeapon.")
    end

    local _TurretFactor = 18
    if _AuxWeapon == 1 then
        _ShipNameTitle = _ShipNameTitle .. "ML"
        ShipUtility.addMegaLasers(_Superweapon, _TurretFactor)
    else
        if _MainWeapon == 1 then
            _ShipNameTitle = _ShipNameTitle .. "HS"
            ShipUtility.addMegaSeekers(_Superweapon, _TurretFactor)
            _FinalDamageFactor = _FinalDamageFactor * 1.25
        else
            --Passive shooting doesn't trigger the seeking property, so we add a different type of artillery.
            _ShipNameTitle = _ShipNameTitle .. "VC"
            ShipUtility.addVelocityCannons(_Superweapon, _TurretFactor)
        end
    end

    _Superweapon.name = _ShipNameTitle
    _Superweapon.title = "The Gordian Knot"

    _Superweapon.crew = _Superweapon.idealCrew
    _Superweapon:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
    _Superweapon:setValue("is_attackresearchbase_superweapon", true)
    
    --Just remember. If you alter the code to make this easier, you cheated :P
    self.Log(_MethodName, "Upgrading Thrusters and engine to x2")
    local _Thrusters = Thrusters(_Superweapon)
    _Thrusters.baseYaw = _Thrusters.baseYaw * 2 * _TurnFactor
    _Thrusters.basePitch = _Thrusters.basePitch * 2 * _TurnFactor
    _Thrusters.baseRoll = _Thrusters.baseRoll * 2 * _TurnFactor
    _Thrusters.fixedStats = true
    _Superweapon:addMultiplier(acceleration, 2)
    _Superweapon:addMultiplier(velocity, 2)

    self.Log(_MethodName, "Upgrading Weapons")
    _Superweapon.damageMultiplier = (_Superweapon.damageMultiplier or 1) * _FinalDamageFactor

    self.Log(_MethodName, "Upgrading Hull")
    local _Dura = Durability(_Superweapon)
    if _Dura then 
        _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 0) + _FinalFactor
        _Dura:setWeakness(DamageType.AntiMatter, -0.6)
    end

    self.Log(_MethodName, "Upgrading Shields")
    local _Shield = Shield(_Superweapon)
    if _Shield then 
        _Shield.maxDurabilityFactor = (_Shield.maxDurabilityFactor or 0) + _FinalFactor
        _Shield:setResistance(DamageType.Plasma, 0.6)
    end

    self.Log(_MethodName, "Upgrading Boarding and Docking")
    Boarding(_Superweapon).boardable = false
    _Superweapon.dockable = false

    --Obviously this drops an incredible amount of loot.
    self.Log(_MethodName, "Adding loot.")
    local SectorTurretGenerator = include ("sectorturretgenerator")
    local SectorUpgradeGenerator = include ("upgradegenerator")
    local _X, _Y = Sector():getCoordinates()
    local _TurretGenerator = SectorTurretGenerator()
    local _UpgradeGenerator = SectorUpgradeGenerator()

    local _Loot = Loot(_Superweapon)
    local _TurretCount = _Rgen:getInt(14, 18)
    local _SystemCount = _Rgen:getInt(12, 16)
    for _ = 1, _TurretCount do
        _Loot:insert(InventoryTurret(_TurretGenerator:generate(_X, _Y, -156, Rarity(self.getRandomRarity()))))
    end
    for _ = 1, _SystemCount do
        _Loot:insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, Rarity(self.getRandomRarity())))
    end

    local _TorpDamageFactor = 1
    local _TechLevel = Balancing_GetTechLevel(_X, _Y)
    if _TechLevel <= 45 then
        _TorpDamageFactor = 2
    end
    if _TechLevel <= 40 then
        _TorpDamageFactor = 3
    end

    _Superweapon:addAbsoluteBias(StatsBonuses.ShieldImpenetrable, true)
    _Superweapon:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    _Superweapon:addScriptOnce("terminalblocker.lua", 1)
    _Superweapon:addScriptOnce("hyperaggro.lua")
    _Superweapon:addScriptOnce("torpedoslammer.lua", 10, 1, nil, nil, _AdjustSlammer, _TorpDamageFactor, true)
    _Superweapon:addScriptOnce("absolutepointdefense.lua")
    _Superweapon:addScriptOnce("gordianknotbehavior.lua")
    if _ic2 then
        _Superweapon:addScriptOnce("ironcurtain.lua")
    end
    if _Amp > 4 or _ic2 then
        _Superweapon:addScriptOnce("eternal.lua")
    end

    return _Superweapon
end

function PariahUtil.getRandomRarity()
    local _MethodName = "Random Rarity"

    local _Raregen = ESCCUtil.getRand()
    if _Raregen:getInt(1, 4) == 1 then
        return RarityType.Legendary
    else
        return RarityType.Exotic
    end
end

function PariahUtil.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[PariahUtility] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

return PariahUtil