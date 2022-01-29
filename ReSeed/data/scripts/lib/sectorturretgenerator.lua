local ReSeed_SectorTurretGenerator_getTurretSeed = SectorTurretGenerator.getTurretSeed
function SectorTurretGenerator:getTurretSeed(x, y, weaponType, rarity)
    --rewire how randomness works.
    --no more 15x15 quadrants. Each 1x1 quadrant now only has a single seed.
    if rarity.type >= RarityType.Exotic and self.random:test(0.5) then
        return self.random:createSeed(), x, y
    end

    local seedString = tostring(GameSeed().int32) .. tostring(x) .. tostring(y) .. tostring(weaponType) .. tostring(rarity.type)
    return Seed(seedString), x, y
end