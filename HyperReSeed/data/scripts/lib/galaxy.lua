local HyperReSeed_GetTechLevel = Balancing_GetTechLevel
function Balancing_GetTechLevel(x, y)
    local tech = math.random(1, 52)

    return math.floor(tech + 0.5)
end

local HyperReSeed_GetSectorWeaponDPS = Balancing_GetSectorWeaponDPS
function Balancing_GetSectorWeaponDPS(x, y)
    local _dps = math.random(18, 240)

    return _dps, Balancing_GetTechLevel(x, y)
end