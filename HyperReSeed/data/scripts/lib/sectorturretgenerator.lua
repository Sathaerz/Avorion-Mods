local HyperReSeed_SectorTurretGenerator_getTurretSeed = SectorTurretGenerator.getTurretSeed
function SectorTurretGenerator:getTurretSeed(x, y, weaponType, rarity)
    local seedString = tostring(GameSeed().int32) .. tostring(math.random()) .. tostring(weaponType) .. tostring(rarity.type)
    return Seed(seedString), x, y
end