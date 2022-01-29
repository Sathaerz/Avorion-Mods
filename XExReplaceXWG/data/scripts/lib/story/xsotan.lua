local XEX_ReplaceGuardian = Xsotan.createGuardian
function Xsotan.createGuardian(position, volumeFactor)
    position = position or Matrix()

    local x, y = Sector():getCoordinates()
    local probabilities = Balancing_GetTechnologyMaterialProbability(x, y)
    local faction = Xsotan.getFaction()

    local bossplan = Xsotan.getGuardianPlan(volumeFactor)

    local boss = Sector():createShip(faction, "", bossplan, position, EntityArrivalType.Jump)

    -- Xsotan have random turrets

    local numTurrets = math.max(1, Balancing_GetEnemySectorTurrets(x, y) / 2)

    ShipUtility.addTurretsToCraft(boss, Xsotan.createPlasmaTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createLaserTurret(), numTurrets, numTurrets)
    ShipUtility.addTurretsToCraft(boss, Xsotan.createRailgunTurret(), numTurrets, numTurrets)
    ShipUtility.addBossAntiTorpedoEquipment(boss)

    boss.title = "Xsotan Wormhole Guardian"%_T
    boss.crew = boss.idealCrew
    boss.shieldDurability = boss.shieldMaxDurability

    local upgrades =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local turrets =
    {
        {rarity = Rarity(RarityType.Legendary), amount = 2},
        {rarity = Rarity(RarityType.Exotic), amount = 3},
        {rarity = Rarity(RarityType.Exceptional), amount = 3},
        {rarity = Rarity(RarityType.Rare), amount = 5},
        {rarity = Rarity(RarityType.Uncommon), amount = 8},
        {rarity = Rarity(RarityType.Common), amount = 14},
    }

    local generator = UpgradeGenerator()
    for _, p in pairs(upgrades) do
        for i = 1, p.amount do
            Loot(boss.index):insert(generator:generateSectorSystem(x, y, p.rarity))
        end
    end

    for _, p in pairs(turrets) do
        for i = 1, p.amount do
            Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, p.rarity)))
        end
    end

    Xsotan.upScale(boss)

    AddDefaultShipScripts(boss)
    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    boss:addScriptOnce("story/wormholeguardian.lua")
    boss:addScriptOnce("story/xsotanbehaviour.lua")
    boss:setValue("is_xsotan", true)

    Boarding(boss).boardable = false
    boss.dockable = false

    return boss
end

function Xsotan.getGuardianPlan(volumeFactor)
    local _FilePlan = LoadPlanFromFile("data/plans/XWG.xml")

    if _FilePlan then
        return _FilePlan
    else
        local volume = Balancing_GetSectorShipVolume(Sector():getCoordinates())

        volume = volume * (volumeFactor or 10)
    
        local material = Material(MaterialType.Avorion)
    
        local plan = PlanGenerator.makeXsotanShipPlan(volume, material)
        local front = PlanGenerator.makeXsotanShipPlan(volume, material)
        local back = PlanGenerator.makeXsotanShipPlan(volume, material)
        local top = PlanGenerator.makeXsotanShipPlan(volume, material)
        local bottom = PlanGenerator.makeXsotanShipPlan(volume, material)
        local left = PlanGenerator.makeXsotanShipPlan(volume, material)
        local right = PlanGenerator.makeXsotanShipPlan(volume, material)
        local frontleft= PlanGenerator.makeXsotanShipPlan(volume, material)
        local frontright = PlanGenerator.makeXsotanShipPlan(volume, material)
    
        Xsotan.infectPlan(plan)
        Xsotan.infectPlan(front)
        Xsotan.infectPlan(back)
        Xsotan.infectPlan(top)
        Xsotan.infectPlan(bottom)
        Xsotan.infectPlan(left)
        Xsotan.infectPlan(right)
        Xsotan.infectPlan(frontleft)
        Xsotan.infectPlan(frontright)
    
        --
        attachMin(plan, back, "z")
        attachMax(plan, front, "z")
        attachMax(plan, front, "z")
    
        attachMin(plan, bottom, "y")
        attachMax(plan, top, "y")
    
        attachMin(plan, left, "x")
        attachMax(plan, right, "x")
    
        local self = findMaxBlock(plan, "z")
        local other = findMinBlock(frontleft, "x")
        plan:addPlanDisplaced(self.index, frontleft, other.index, self.box.center - other.box.center)
    
        local other = findMaxBlock(frontright, "x")
        plan:addPlanDisplaced(self.index, frontright, other.index, self.box.center - other.box.center)
    
        Xsotan.infectPlan(plan)

        return plan
    end
end