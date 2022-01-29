package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"
include ("randomext")
include ("utility")
local SectorSpecifics = include ("sectorspecifics")
local PirateGenerator = include ("pirategenerator")
local SectorTurretGenerator = include ("sectorturretgenerator")

local Swenks = {}

function Swenks.spawn(player, x, y)
    local _MethodName = "Spawn Swenks"

    local function piratePosition()
        local pos = random():getVector(-1000, 1000)
        return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
    end

    -- spawn
    local boss = PirateGenerator.createBoss(piratePosition())
    boss:setTitle("Boss Swenks"%_T, {})
    boss.dockable = false

    local _pirates = {}
    table.insert(_pirates, boss)
    table.insert(_pirates, PirateGenerator.createRaider(piratePosition()))
    table.insert(_pirates, PirateGenerator.createRavager(piratePosition()))
    table.insert(_pirates, PirateGenerator.createMarauder(piratePosition()))
    table.insert(_pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(_pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(_pirates, PirateGenerator.createBandit(piratePosition()))
    table.insert(_pirates, PirateGenerator.createBandit(piratePosition()))

    boss:registerCallback("onDestroyed", "onSwenksDestroyed")

    -- adds legendary turret drop
    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), Seed(1)))

    for _, pirate in pairs(_pirates) do
        pirate:addScript("deleteonplayersleft.lua")

        local _Player = Player()
        if not _Player then break end
        local allianceIndex = _Player.allianceIndex
        local ai = ShipAI(pirate.index)
        ai:registerFriendFaction(_Player.index)
        if allianceIndex then
            ai:registerFriendFaction(allianceIndex)
        end
    end

    if Server():getValue("swoks_beaten") then
        boss:setValue("swoks_beaten", true)
    end
    
    boss:removeScript("icon.lua")
    boss:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
    boss:addScript("player/missions/lotw/mission5/swenks.lua")
    boss:addScript("player/missions/lotw/mission5/swenksspecial.lua", 30, 0.75, "Think you have me, do you?")
    boss:addScript("player/missions/lotw/mission5/swenksspecial.lua", 35, 0.50, "More! More!!")
    boss:addScript("player/missions/lotw/mission5/swenksspecial.lua", 40, 0.25, "I'll tear you to pieces, wretch!")
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("avenger.lua", {_Multiplier = 1.1})
    boss:setValue("is_pirate", true)
    boss:setValue("is_swenks", true)

    Boarding(boss).boardable = false
end

return Swenks