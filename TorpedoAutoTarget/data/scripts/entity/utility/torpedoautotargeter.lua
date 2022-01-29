package.path = package.path .. ";data/scripts/lib/?.lua"
include ("stringutility")
include ("randomext")

-- namespace TorpedoAutoTargeter
TorpedoAutoTargeter = {}

local sectorEnemies = {}
local retargetedThisCycle = {}
local lastEligibleTargetUpdateTime = appTime()

if onServer() then

function TorpedoAutoTargeter.initialize()
    Sector():registerCallback("onTorpedoLaunched", "reassignTorpedoTargetIfNeeded")
    Entity():registerCallback("onSectorChanged", "onSectorChanged")
end

function TorpedoAutoTargeter.onSectorChanged()
    Sector():registerCallback("onTorpedoLaunched", "reassignTorpedoTargetIfNeeded")
end

function TorpedoAutoTargeter.reassignTorpedoTargetIfNeeded(firingEntityId, firedTorpedoId)
    --print("Running auto-target callback.")
    -- Only evaluate torpedoes fired by the player-controlled ship
    local player = Player()
    if not player then return end
    local playerShip = Sector():getEntity(player.craftIndex)
    local firingEntity = Entity(firingEntityId)
    if not valid(playerShip) or not playerShip == firingEntity then return end

    -- Only consider reassignment if there's no current target for the torpedo or if the player
    -- is self-targeting the current ship
    local torpedoAI = TorpedoAI(firedTorpedoId)
    if not playerShip.id == torpedoAI.target and not torpedoAI.target.isNil then return end

    -- Update what targets exist in the sector
    TorpedoAutoTargeter.updateSectorEnemies(firingEntity)

    -- Get the next target
    local torpedo = Torpedo(firedTorpedoId)
    local nextTargetId = TorpedoAutoTargeter.getNextTargetId(torpedo)

    if nextTargetId and not nextTargetId.isNil then
        -- At last, reassign the target!
        torpedo.intendedTargetFaction = Entity(nextTargetId).factionIndex
        torpedoAI.target = nextTargetId
    end
end

function TorpedoAutoTargeter.updateSectorEnemies(firingEntity)
    -- Only do this update once per torpedo firing, which we're approximating here by
    -- only allowing update once per second
    local nowTime = appTime()
    if (lastEligibleTargetUpdateTime + 1 > nowTime) then
        return
    end

    -- Reset state for the firing cycle
    sectorEnemies = {}
    retargetedThisCycle = {}
    lastEligibleTargetUpdateTime = nowTime

    -- Now just cache the list of in-sector enemies to share across torpedos for this next period
    local shipsInSector = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(shipsInSector) do
        local shipAI = ShipAI(ship)
        local shipDistance = ship:getNearestDistance(firingEntity)
        local isEnemy = shipAI:isEnemy(firingEntity)
        if isEnemy then
            table.insert(sectorEnemies, {id = ship.id, distance = shipDistance})
        end
    end
end

function TorpedoAutoTargeter.getNextTargetId(torpedo)
    if not torpedo or not sectorEnemies or #(sectorEnemies) == 0 then return nil end

    local torpedoTemplate = torpedo:getTemplate()

    -- Collect all the in-sector enemies that are range of this torpedo
    local enemiesInRange = {}
    for i = 1, #(sectorEnemies), 1 do
        if sectorEnemies[i].distance <= torpedoTemplate.reach then
            table.insert(enemiesInRange, sectorEnemies[i])
        end
    end

    if not enemiesInRange or #(enemiesInRange) == 0 then return nil end

    -- Collect the targets of all recently retargeted torpedoes, as we don't want to select those
    -- until other targets in range get equal treatment
    local existingRetargetsInRange = {}

    for i = 1, #(retargetedThisCycle), 1 do
        if retargetedThisCycle[i].distance <= torpedoTemplate.reach then
            table.insert(existingRetargetsInRange, retargetedThisCycle[i])
        end
    end

    -- Loop over enemies in range until we find the first match with fewest existing retargets
    for i = 1, 9999, 1 do
        local wrappedIndex = 1 + (i % #(sectorEnemies))
        local candidateEnemy = sectorEnemies[wrappedIndex]
        local alreadySelected = false
        for j = 1, #(existingRetargetsInRange), 1 do
            if existingRetargetsInRange[j].id == candidateEnemy.id then
                alreadySelected = true
                table.remove(existingRetargetsInRange, j)
                break
            end
        end
        if not alreadySelected then
            table.insert(retargetedThisCycle, candidateEnemy)
            return candidateEnemy.id
        end
    end
end

end -- if onServer()