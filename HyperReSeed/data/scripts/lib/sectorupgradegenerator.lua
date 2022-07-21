local HyperReSeed_UpgradeGenerator_getUpgradeSeed = UpgradeGenerator.getUpgradeSeed
function UpgradeGenerator:getUpgradeSeed(x, y, script, rarity)
    local seedString = tostring(GameSeed().int32) .. tostring(math.random()) .. tostring(script) .. tostring(rarity.type)
    return Seed(seedString), x, y
end