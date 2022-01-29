TorpUtil = include("torpedoutility")

local HydraTorpedoes_TorpedoPrice = TorpedoPrice
function TorpedoPrice(torpedo)
    local _TorpedoPrice = HydraTorpedoes_TorpedoPrice(torpedo)

    if TorpUtil.isHydra(torpedo.type) then
        _TorpedoPrice = _TorpedoPrice * 1.2
    end

    return _TorpedoPrice
end