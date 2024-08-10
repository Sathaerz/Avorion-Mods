package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
local PlanGenerator = include ("plangenerator")
local ShipUtility = include ("shiputility")

local DefendProtoGenerator = {}

--Create the Prototype Battleship.
function DefendProtoGenerator.create(position, giverFaction, dangerValue, scaleOverride)
	--Base scale is 70. Goes down to 60.
	local bshipScale = 70
	if dangerValue > 5 then
		bshipScale = bshipScale - 3
	end
	if dangerValue >= 8 then
		bshipScale = bshipScale - 3
	end
	if dangerValue == 10 then
		bshipScale = bshipScale - 4
	end

	if scaleOverride then
		bshipScale = scaleOverride
	end
	
	--I don't see this ever going above 1, but we'll see what happens.
	local playerScaleFactor = DefendProtoGenerator.getPlayerScaleFactor()
	
	position = position or Matrix()
    local x, y = Sector():getCoordinates()

    local volume = Balancing_GetSectorShipVolume(x, y) * bshipScale * playerScaleFactor;

	--Use highest available material level.
	local availableMaterials = Balancing_GetTechnologyMaterialProbability(x, y)
	local _m = 0
	for _k, _v in pairs(availableMaterials) do
		if _v > 0 and _k > _m then
			_m = _k
		end
	end

	--No Avorion outside of the core.
	local distFromCenter = length(vec2(x, y))
	if _m == 6 and distFromCenter > Balancing_GetBlockRingMin() then
		_m = 5
	end

    local plan = PlanGenerator.makeShipPlan(giverFaction, volume, nil, Material(_m))
    local ship = Sector():createShip(giverFaction, "", plan, position)

    DefendProtoGenerator.addBattleshipEquipment(ship, dangerValue)

    ship.crew = ship.idealCrew
    ship.shieldDurability = ship.shieldMaxDurability

    return ship
end

function DefendProtoGenerator.addBattleshipEquipment(ship, dangerValue)

	local turretFactor = 6
	local damageFactor = 4
	if dangerValue > 5 then
		turretFactor = turretFactor - 0.75
	end
	if dangerValue >= 8 then
		turretFactor = turretFactor - 0.75
	end
	if dangerValue == 10 then
		turretFactor = turretFactor - 0.75
		damageFactor = damageFactor - 1
	end

	turretFactor = math.floor(turretFactor)
	
	--Add two different types of military weapons + disruptor weapons -- also add artillery so the player can't just stand off and hammer it to death.
	--Well, they still _can_, but at least it's a little more difficult this way.
	ShipUtility.addMilitaryEquipment(ship, turretFactor, 0)
	ShipUtility.addMilitaryEquipment(ship, turretFactor, 0)
	ShipUtility.addDisruptorEquipment(ship)
	ShipUtility.addScalableArtilleryEquipment(ship, turretFactor)
	
	--Finally, increase the ship's damage multiplier by a random amount depending on the danger level of the mission.
	local forceMultiplier = 1 + (random():getInt(0, dangerValue) / 50)
	--print("forceMultiplier is " .. forceMultiplier)
	--print("turretFactor is " .. turretFactor)
	ship.damageMultiplier = damageFactor * forceMultiplier
	--Make it unboardable because I don't want to account for what happens if the player boards it.
	Boarding(ship).boardable = false

    ship:setTitle("${toughness}Prototype Battleship"%_T, {toughness = ""})
	ship:removeScript("icon.lua")
	ship:addScript("icon.lua", "data/textures/icons/pixel/flagship.png")
    ship.shieldDurability = ship.shieldMaxDurability

	ship:setValue("is_prototype", true)
end

function DefendProtoGenerator.getPlayerScaleFactor()
	local scaling = Sector().numPlayers

    if scaling == 0 then scaling = 1 end
    return scaling
end

return DefendProtoGenerator