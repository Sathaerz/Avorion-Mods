package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")
local SectorTurretGenerator = include ("sectorturretgenerator")

local DestroyProtoGenerator = {}

--Create the Prototype Battleship.
--We pass the faction to this in order to make sure that ships from two different pirate factions don't spawn.
function DestroyProtoGenerator.create(position, giverFaction, pirateFaction, dangerValue)
	--Base scale is 40. 6+ = 50, 8+ = 60, 10 = 70
	local bshipScale = 40
	if dangerValue > 5 then
		bshipScale = bshipScale + 10
	end
	if dangerValue >= 8 then
		bshipScale = bshipScale + 10
	end
	if dangerValue == 10 then
		bshipScale = bshipScale + 10
	end
	
	--I don't see this ever going above 1, but we'll see what happens.
	local playerScaleFactor = DestroyProtoGenerator.getPlayerScaleFactor()
	
	position = position or Matrix()
    local x, y = Sector():getCoordinates()

    local volume = Balancing_GetSectorShipVolume(x, y) * bshipScale * playerScaleFactor;

    local plan = PlanGenerator.makeShipPlan(giverFaction, volume)
    local ship = Sector():createShip(pirateFaction, "", plan, position)

    DestroyProtoGenerator.addBattleshipEquipment(ship, dangerValue)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    return ship
end

function DestroyProtoGenerator.addBattleshipEquipment(ship, dangerValue)
	local turretDrops = 0

    local x, y = Sector():getCoordinates()
    local turretGenerator = SectorTurretGenerator()
    local rarities = turretGenerator:getSectorRarityDistribution(x, y)
	
	local turretFactor = 3
	local damageFactor = 3
	if dangerValue > 5 then
		turretFactor = turretFactor + 1
	end
	if dangerValue >= 8 then
		turretFactor = turretFactor + 1
	end
	if dangerValue == 10 then
		turretFactor = turretFactor + 1
		damageFactor = damageFactor + 1
	end
	
	--Add two different types of military weapons + disruptor weapons -- also add artillery so the player can't just stand off and hammer it to death.
	--Well, they still _can_, but at least it's a little more difficult this way.
	ShipUtility.addMilitaryEquipment(ship, turretFactor, 0)
	ShipUtility.addMilitaryEquipment(ship, turretFactor, 0)
	ShipUtility.addDisruptorEquipment(ship)
	ShipUtility.addArtilleryEquipment(ship)
	
	--Finally, increase the ship's damage multiplier by a random amount depending on the danger level of the mission.
	local forceMultiplier = 1 + (random():getInt(0, dangerValue) / 50)
	print("forceMultiplier is " .. forceMultiplier)
	print("turretFactor is " .. turretFactor)
	ship.damageMultiplier = damageFactor * forceMultiplier
	--Make it unboardable because I don't want to account for what happens if the player boards it.
	Boarding(ship).boardable = false

	turretDrops = 3
	if dangerValue == 10 then
		turretDrops = 4
	end
    rarities[-1] = 0 -- no petty turrets
    rarities[0] = 0 -- no common turrets
    rarities[1] = 0 -- no uncommon turrets
    rarities[2] = rarities[2] * 0.5 -- reduce rates for rare turrets to have higher chance for the others

    turretGenerator.rarities = rarities
    for i = 1, turretDrops do
        Loot(ship):insert(InventoryTurret(turretGenerator:generate(x, y)))
    end

    ShipAI(ship.index):setAggressive()
    ship:setTitle("${toughness}Prototype Battleship"%_T, {toughness = ""})
	ship:addScript("icon.lua", "data/textures/icons/pixel/flagship.png")
    ship.shieldDurability = ship.shieldMaxDurability

    ship:setValue("is_pirate", true)
end

function DestroyProtoGenerator.getPlayerScaleFactor()
	local scaling = Sector().numPlayers

    if scaling == 0 then scaling = 1 end
    return scaling
end

return DestroyProtoGenerator