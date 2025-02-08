package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")
include ("stringutility")
local SectorTurretGenerator = include("sectorturretgenerator")
local UpgradeGenerator = include ("upgradegenerator")

--namespace LOTWFreighterMission3
LOTWFreighterMission3 = {}

local deleteTime = 30
local runningAway = false
local invokedEscape = false

function LOTWFreighterMission3.initialize(_AddLoot, _AddMoreLoot, _AddSideLoot, _DangerLevel)
    if onServer() then
        local ship = Entity()

        ship:addScriptOnce("data/scripts/entity/deleteonplayersleft.lua")
        local lines = LOTWFreighterMission3.getChatterLines()
        ship:addScriptOnce("data/scripts/entity/utility/radiochatter.lua", lines, 90, 120, random():getInt(30, 45))

        ship:registerCallback("onDamaged", "onDamaged")
        ship:registerCallback("onDestroyed", "onDestroyed")

        local goonLoot = Loot(ship.id)
        local x, y = Sector():getCoordinates()

        if _AddLoot then
            -- add turrets to loot
            local turrets = LOTWFreighterMission3.generateTurrets(x, y)
            for _, turret in pairs(turrets) do
                goonLoot:insert(turret)
            end

            -- add subsystems to loot
            local upgrades = LOTWFreighterMission3.generateUpgrades(x, y)
            for _, upgrade in pairs(upgrades) do
                goonLoot:insert(upgrade)
            end

            --Add commonly used upgrades to get the player started off.
            if _AddMoreLoot then
                local _SeedInt = random():getInt(1, 20000)
                goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Uncommon), Seed(_SeedInt)))
                goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/hyperspacebooster.lua", Rarity(RarityType.Uncommon), Seed(_SeedInt)))
                goonLoot:insert(SystemUpgradeTemplate("data/scripts/systems/energybooster.lua", Rarity(RarityType.Uncommon), Seed(_SeedInt)))
            end

            if _AddSideLoot then
                local sideLoot = LOTWFreighterMission3.generateSideLoot(x, y, _DangerLevel)
                for _, item in pairs(sideLoot) do
                    goonLoot:insert(item)
                end
            end
        end
    end
end

function LOTWFreighterMission3.getUpdateInterval()
    return 1
end

function LOTWFreighterMission3.onDamaged(entityId, damage, inflictor)
    -- start running away only once
    if not runningAway then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Our loot is in danger! We have to get out of here! We'll be safe in %1% seconds!"%_t, deleteTime)
        -- remove normal chatter to avoid casual lines while running away
        Entity():removeScript("radiochatter.lua")
        local position = Entity().position
        local shipAI = ShipAI()
        shipAI:setFlyLinear(position.look * 10000, 0)
        runningAway = true
    end
end

function LOTWFreighterMission3.onDestroyed()
    local _Entity = Entity()
    local _Sector = Sector()
    local x, y = _Sector:getCoordinates()
    if _Entity:getValue("_lotw_no_loot_drop") then
        --Do nothing.
    else
        local money = 10000 * Balancing_GetSectorRewardFactor(x, y)
        _Sector:dropBundle(_Entity.translationf, nil, nil, money)
    end
end

function LOTWFreighterMission3.updateServer(timeStep)
    local entity = Entity()
    -- delete one minute after getting damage
    if runningAway then
        deleteTime = deleteTime - timeStep
    end

    if deleteTime <= 10 and deleteTime + timeStep > 10 then
        Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, "Go, go, go! We're almost there! We're almost out of here!"%_t)
    elseif deleteTime <= 5 then
        Entity():addScriptOnce("deletejumped.lua")
    end
    if deleteTime <= 1 then
        local _Players = {Sector():getPlayers()}
        for _, _P in pairs(_Players) do
            if not invokedEscape then
                _P:invokeFunction("player/missions/lotw/lotwstory3.lua", "freighterEscaped")
            end
        end
    end
end

function LOTWFreighterMission3.generateTurrets(x, y)
    local turrets = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(5, 6)
    local lowRarityAmount = amount * 2

    -- add high value turrets to loot
    for i = 1, amount do
        local rarities = {}
        -- one turret has higher rarity
        if i == amount then
            rarities[RarityType.Exceptional] = 1.5
            rarities[RarityType.Exotic] = 0.5
            rarities[RarityType.Legendary] = 0.25
        else
            rarities[RarityType.Uncommon] = 2
            rarities[RarityType.Rare] = 2
            rarities[RarityType.Exceptional] = 1
        end

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

function LOTWFreighterMission3.generateUpgrades(x, y)
    local upgrades = {}
    -- amount is not the total amount but only for high rarities
    local amount = random():getInt(3, 4)
    local lowRarityAmount = amount * 2

    -- add high value subsytems to loot
    for i = 1, amount do
        local rarities = {}
        -- one subsystem has higher rarity
        if i == amount then
            rarities[RarityType.Exceptional] = 1.5
            rarities[RarityType.Exotic] = 0.5
            rarities[RarityType.Legendary] = 0.25
        else
            rarities[RarityType.Uncommon] = 2
            rarities[RarityType.Rare] = 1
            rarities[RarityType.Exceptional] = 0.5
        end

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

function LOTWFreighterMission3.generateSideLoot(x, y, dangerLevel)
    local items = {}

    local amount = math.max(1, math.floor(dangerLevel / 2))

    local upgradeGenerator = UpgradeGenerator()
    local turretGenerator = SectorTurretGenerator()
    local _random = random()

    local turretRarities = turretGenerator:getSectorRarityDistribution(x, y)
    local upgradeRarities = upgradeGenerator:getSectorRarityDistribution(x, y)

    turretRarities[-1] = 0 -- no petty turrets
    turretRarities[0] = 0 -- no common turrets
    turretRarities[1] = 0 -- no uncommon turrets

    upgradeRarities[-1] = 0 --no petty systems
    upgradeRarities[0] = 0 --no common systems
    upgradeRarities[1] = 0 --no uncommon systems

    for i = 1, amount do
        if _random:test(0.5) then
            --turret
            local rarity = selectByWeight(_random, turretRarities)
            local turret = InventoryTurret(turretGenerator:generate(x, y, 0, Rarity(rarity)))
            table.insert(items, turret)
        else
            --upgrade
            local rarity = selectByWeight(_random, upgradeRarities)
            local upgrade = upgradeGenerator:generateSectorSystem(x, y, rarity)
            table.insert(items, upgrade)
        end
    end

    return items
end

function LOTWFreighterMission3.getChatterLines()
    local chatterLines =
    {
        "Finally we got some real loot."%_t,
        "Once we get home, everyone will get their share."%_t,
        "I've got to hide my treasure."%_t,
        "Relax, everyone gets some of the spoils."%_t,
        "If anything happens, we can always run away."%_t,
        "Juicy spoils and a good fight every once in a while. A pirate's life for me!"%_t,
    }

    return chatterLines
end