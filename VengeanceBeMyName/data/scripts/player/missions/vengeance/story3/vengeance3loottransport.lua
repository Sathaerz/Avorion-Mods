package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include ("stringutility")
local SectorTurretGenerator = include("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")

--namespace Vengeance3LootTransport
Vengeance3LootTransport = {}

function Vengeance3LootTransport.initialize()
    if onServer() then
        local ship = Entity()

        local goonLoot = Loot(ship.id)
        local x, y = Sector():getCoordinates()

        -- add turrets to loot
        local turrets = Vengeance3LootTransport.generateTurrets(x, y)
        for _, turret in pairs(turrets) do
            goonLoot:insert(turret)
        end

        -- add subsystems to loot
        local upgrades = Vengeance3LootTransport.generateUpgrades(x, y)
        for _, upgrade in pairs(upgrades) do
            goonLoot:insert(upgrade)
        end

        -- add guaranteed exceptional hyperspace upgrade, m-tcs, and generator upgrade
        local _SeedInt = random():getInt(1, 20000)
        goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exceptional), Seed(_SeedInt)))
        goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/hyperspacebooster.lua", Rarity(RarityType.Exceptional), Seed(_SeedInt)))
        goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/energybooster.lua", Rarity(RarityType.Exceptional), Seed(_SeedInt)))
    end
end

function Vengeance3LootTransport.generateTurrets(x, y)
    local turrets = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(2, 3)
    local lowRarityAmount = amount * 2

    -- add high value turrets to loot
    for i = 1, amount do
        local rarities = {}
        rarities[RarityType.Uncommon] = 2
        rarities[RarityType.Rare] = 2
        rarities[RarityType.Exceptional] = 1

        local rarity = selectByWeight(random(), rarities)
        local turret = InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(rarity)))
        table.insert(turrets, turret)
    end

    -- add low value turrets to loot
    for i = 1, lowRarityAmount do
        local rarities = {}
        rarities[RarityType.Petty] = 0.5
        rarities[RarityType.Common] = 1
        rarities[RarityType.Uncommon] = 2

        local rarity = selectByWeight(random(), rarities)
        local turret = InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(rarity)))
        table.insert(turrets, turret)
    end

    return turrets
end

function Vengeance3LootTransport.generateUpgrades(x, y)
    local upgrades = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(2, 3)
    local lowRarityAmount = amount * 2

    -- add high value subsytems to loot
    for i = 1, amount do
        local rarities = {}
        rarities[RarityType.Uncommon] = 2
        rarities[RarityType.Rare] = 1
        rarities[RarityType.Exceptional] = 0.5

        local rarity = selectByWeight(random(), rarities)
        local upgrade = UpgradeGenerator():generateSectorSystem(x, y, rarity)
        table.insert(upgrades, upgrade)
    end

    -- add low value subsytems to loot
    for i = 1, lowRarityAmount do
        local rarities = {}
        rarities[RarityType.Petty] = 0.5
        rarities[RarityType.Common] = 1
        rarities[RarityType.Uncommon] = 2

        local rarity = selectByWeight(random(), rarities)
        local upgrade = UpgradeGenerator():generateSectorSystem(x, y, rarity)
        table.insert(upgrades, upgrade)
    end

    return upgrades
end