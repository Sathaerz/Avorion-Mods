package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")

include ("galaxy")

local ESCCBossUtil = {}
local self = ESCCBossUtil

self._Debug = 0

function ESCCBossUtil.spawnESCCBoss(_Faction, _BossType) --Formerly spawnIncreasingThreatBoss
    local _MethodName = "Spawn Increasing Threat Boss"
    ESCCBossUtil.Log(_MethodName, "Beginning...")

    local _ActiveMods = Mods()
    local _HETActive = false
    local _HarderEnemysActive = false
    for _, _Xmod in pairs(_ActiveMods) do
        if _Xmod.id == "1821043731" then --HET
            ESCCBossUtil.Log(_MethodName, "HET is active - increasing _Amp / _HighAmp")
            _HETActive = true
        end
        if _Xmod.id == "2191291553" then --HarderEnemys
            ESCCBossUtil.Log(_MethodName, "HarderEnemys is active - increasing _Amp / _HighAmp")
            _HarderEnemysActive = true
        end
    end

    --INCREASING THREAT BOSS QUICKREF
    --1 = Katana
    --2 = Goliath
    --3 = Hellcat
    --4 = Hunter
    --5 = Shield
    --6 = Phoenix
    local _BossTypes = {
        { _PlanFile = "data/plans/Katana.xml", _Title = "Baleful Katana", _EngineFactor = 2, _ThrustFactor = 1, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")

            _Boss:addScriptOnce("adaptivedefense.lua")
            _Boss:addScriptOnce("overdrive.lua")
            _Boss:addScriptOnce("dialogs/encounters/balefulkatana.lua")
            ShipUtility.addKatanaRailguns(_Boss)
            ShipUtility.addKatanaMortars(_Boss)
            ShipUtility.addBossAntiTorpedoEquipment(_Boss, nil, nil, 1850)
            _Boss:setValue("_escc_is_baleful_katana", true)
        end },
        { _PlanFile = "data/plans/Goliath.xml", _Title = "Dervish Goliath", _EngineFactor = 2.5, _ThrustFactor = 1, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")

            local _TorpedoFactor = 2
            local _TorpDuraFactor = 2
            local _ActiveMods = Mods()

            for _, _Xmod in pairs(_ActiveMods) do
            	if _Xmod.id == "2422999823" then --Ferocity
            		_TorpedoFactor = _TorpedoFactor * 16
                    _TorpDuraFactor = _TorpDuraFactor * 2
            	end
            end

            local _TorpSlammerValues = {}
            _TorpSlammerValues._TimeToActive = 12
            _TorpSlammerValues._ROF = 1.75
            _TorpSlammerValues._UpAdjust = false
            _TorpSlammerValues._DamageFactor = _TorpedoFactor
            _TorpSlammerValues._DurabilityFactor = _TorpDuraFactor
            _TorpSlammerValues._ForwardAdjustFactor = 1

            _Boss:addScriptOnce("phasemode.lua")
            _Boss:addScriptOnce("torpedoslammer.lua", _TorpSlammerValues)
            _Boss:addScriptOnce("dialogs/encounters/dervishgoliath.lua")
            ShipUtility.addGoliathLaunchers(_Boss)
            ShipUtility.addBossAntiTorpedoEquipment(_Boss, nil, nil, 2000)
            _Boss:setValue("_escc_is_dervish_goliath", true)
        end },
        { _PlanFile = "data/plans/Hellcat.xml", _Title = "Relentless Hellcat", _EngineFactor = 6, _ThrustFactor = 2, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")

            _Boss:addScriptOnce("phasemode.lua")
            _Boss:addScriptOnce("eternal.lua", 0.005, 10)
            _Boss:addScriptOnce("dialogs/encounters/relentlesshellcat.lua")
            ShipUtility.addHellcatLasers(_Boss)
            ShipUtility.addBossAntiTorpedoEquipment(_Boss, nil, nil, 575)
            _Boss:setValue("_escc_is_relentless_hellcat", true)
        end },
        { _PlanFile = "data/plans/Hunter.xml", _Title = "Steadfast Hunter", _EngineFactor = 2, _ThrustFactor = 1, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")

            _Boss:addScriptOnce("dialogs/encounters/steadfasthunter.lua")
            _Boss:addScriptOnce("lasersniper.lua")
            _Boss:addScriptOnce("absolutepointdefense.lua", 0.45, true, true, 12, 12, 20, 4)
            ShipUtility.addHunterRailguns(_Boss)
            ShipUtility.addHunterLightningGuns(_Boss)
            _Boss:setValue("_escc_is_steadfast_hunter", true)
        end },
        { _PlanFile = "data/plans/Shield.xml", _Title = "Vigilant Shield", _EngineFactor = 0, _ThrustFactor = 1, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")

            _Boss:addScriptOnce("adaptivedefense.lua")
            _Boss:addScriptOnce("allybooster.lua")
            _Boss:addScriptOnce("absolutepointdefense.lua", 0.45, true, true, 12, 12, 20, 4)
            _Boss:addScriptOnce("dialogs/encounters/vigilantshield.lua")
            ShipUtility.addVigShieldCannons(_Boss)
            _Boss:setValue("_escc_is_vigilant_shield", true)
        end },
        { _PlanFile = "data/plans/Phoenix.xml", _Title = "Scouring Phoenix", _EngineFactor = 2, _ThrustFactor = 1, _CustomFunction = function(_Boss)
            local ShipUtility = include("shiputility")
            local TorpedoUtility = include ("torpedoutility")

            local _TorpedoFactor = 55
            local _TorpDuraFactor = 4
            local _ActiveMods = Mods()

            for _, _Xmod in pairs(_ActiveMods) do
            	if _Xmod.id == "2422999823" then --Ferocity
            		_TorpedoFactor = _TorpedoFactor * 16
                    _TorpDuraFactor = _TorpDuraFactor * 2
            	end
            end

            local _TorpSlammerValues = {}
            _TorpSlammerValues._TimeToActive = 12
            _TorpSlammerValues._ROF = 9
            _TorpSlammerValues._UpAdjust = false
            _TorpSlammerValues._DamageFactor = _TorpedoFactor
            _TorpSlammerValues._DurabilityFactor = _TorpDuraFactor
            _TorpSlammerValues._ForwardAdjustFactor = 1
            _TorpSlammerValues._PreferWarheadType = TorpedoUtility.WarheadType.Nuclear
            _TorpSlammerValues._PreferBodyType = TorpedoUtility.BodyType.Hawk

            _Boss:addScriptOnce("overdrive.lua", 3)
            _Boss:addScriptOnce("torpedoslammer.lua", _TorpSlammerValues)
            _Boss:addScriptOnce("dialogs/encounters/scouringphoenix.lua")
            ShipUtility.addPhoenixCannons(_Boss)
            ShipUtility.addBossAntiTorpedoEquipment(_Boss, nil, nil, 2000)
            _Boss:setValue("_escc_is_scouring_phoenix", true)
        end }
    }

    local _BossData = _BossTypes[_BossType]

    local _PlanFileName = _BossData._PlanFile
    ESCCBossUtil.Log(_MethodName, "Loading plan : " .. tostring(_PlanFileName))

    local _Plan = LoadPlanFromFile(_PlanFileName)

    local PirateGenerator = include("pirategenerator")

    local _IncreasingThreatBoss = Sector():createShip(_Faction, "", _Plan, PirateGenerator.getGenericPosition())

    _IncreasingThreatBoss:setTitle(_BossData._Title, {})

    ESCCBossUtil.Log(_MethodName, "Upgrading Thrusters and engine")
    local _Thrusters = Thrusters(_IncreasingThreatBoss)
    _Thrusters.baseYaw = _Thrusters.baseYaw * 2 * _BossData._ThrustFactor
    _Thrusters.basePitch = _Thrusters.basePitch * 2 * _BossData._ThrustFactor
    _Thrusters.baseRoll = _Thrusters.baseRoll * 2 * _BossData._ThrustFactor
    _Thrusters.fixedStats = true
    _IncreasingThreatBoss:addMultiplier(acceleration, _BossData._EngineFactor)
    _IncreasingThreatBoss:addMultiplier(velocity, _BossData._EngineFactor)

    ESCCBossUtil.Log(_MethodName, "Upgrading Boarding and Docking")
    Boarding(_IncreasingThreatBoss).boardable = false
    _IncreasingThreatBoss.dockable = false

    --Set _Amp according to active mods and buff accordingly.
    local _Amp = 0
    local _HighAmp = 1
    if _HETActive then
        _Amp = _Amp + 1
        _HighAmp = _HighAmp * 2
    end
    if _HarderEnemysActive then
        _Amp = _Amp + 2
        _HighAmp = _HighAmp * 2
    end

    ESCCBossUtil.Log(_MethodName, "_Amp is " .. tostring(_Amp) .. " and highAmp is " .. tostring(_HighAmp))

    _IncreasingThreatBoss.damageMultiplier = (_IncreasingThreatBoss.damageMultiplier or 1) * _HighAmp

    local _ITBossShields = Shield(_IncreasingThreatBoss)
    if _ITBossShields then
        _ITBossShields.maxDurabilityFactor = (_ITBossShields.maxDurabilityFactor or 0) + _Amp
    end

    local _ITBossDurability = Durability(_IncreasingThreatBoss)
    if _ITBossDurability then
        _ITBossDurability.maxDurabilityFactor = (_ITBossDurability.maxDurabilityFactor or 0) + _Amp
    end

    --Obviously this drops an incredible amount of loot.
    ESCCBossUtil.Log(_MethodName, "Adding loot.")
    local SectorTurretGenerator = include ("sectorturretgenerator")
    local SectorUpgradeGenerator = include ("upgradegenerator")
    local _X, _Y = Sector():getCoordinates()
    local _TurretGenerator = SectorTurretGenerator()
    local _UpgradeGenerator = SectorUpgradeGenerator()

    local _Loot = Loot(_IncreasingThreatBoss)

    local _Upgrades =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 5},
        {rarity = Rarity(RarityType.Exceptional), amount = 7},
        {rarity = Rarity(RarityType.Rare), amount = 7},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local _Turrets =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 5},
        {rarity = Rarity(RarityType.Exceptional), amount = 7},
        {rarity = Rarity(RarityType.Rare), amount = 7},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    for _, _Up in pairs(_Upgrades) do
        for _ = 1, _Up.amount do
            _Loot:insert(_UpgradeGenerator:generateSectorSystem(_X, _Y, _Up.rarity))
        end
    end

    for _, _Tt in pairs(_Turrets) do
        for _ = 1, _Tt.amount do
            _Loot:insert(InventoryTurret(_TurretGenerator:generate(_X, _Y, -156, _Tt.rarity)))
        end
    end

    ESCCBossUtil.Log(_MethodName, "Adding standard scripts.")
    _IncreasingThreatBoss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    _IncreasingThreatBoss:addScriptOnce("megablocker.lua", 1)
    _IncreasingThreatBoss:addScriptOnce("esccbossbehavior.lua", _BossType)
    _BossData._CustomFunction(_IncreasingThreatBoss)

    _IncreasingThreatBoss.crew = _IncreasingThreatBoss.idealCrew

    _IncreasingThreatBoss:removeScript("icon.lua")
    _IncreasingThreatBoss:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
    _IncreasingThreatBoss:setValue("_DefenseController_Manage_Own_Invincibility", true)
    _IncreasingThreatBoss:setValue("is_pirate", true) --These guys should always spawn for pirate factions.

    _IncreasingThreatBoss:setDropsAttachedTurrets(false)

    local Balancing = include("galaxy")
    --Finally, add a DCD.

    local _AllyFactor = 0
    if _BossType == 5 then --Vigilant Shield gets stronger allies to buff.
        _AllyFactor = 2
    end

    local _DCD = {}
    _DCD._DefenseLeader = _IncreasingThreatBoss.id
    _DCD._DefenderCycleTime = 60
    _DCD._DangerLevel = 5 + _AllyFactor
    _DCD._MaxDefenders = 4
    _DCD._DefenderHPThreshold = 0.2
    _DCD._DefenderOmicronThreshold = 0.2
    _DCD._IsPirate = true
    _DCD._Factionid = _Faction.index
    _DCD._PirateLevel = Balancing_GetPirateLevel(_X, _Y)
    _DCD._UseLeaderSupply = false
    _DCD._LowTable = "High"
    _DCD._AbsoluteFactionLimit = 5 --4 + boss.

    Sector():addScript("sector/background/defensecontroller.lua", _DCD)

    return _IncreasingThreatBoss
end

function ESCCBossUtil.Log(_MethodName, _Msg)
    if ESCCBossUtil._Debug == 1 then
        print("[ESCC Boss Utility] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

return ESCCBossUtil