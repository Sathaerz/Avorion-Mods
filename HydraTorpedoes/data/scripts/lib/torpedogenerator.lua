local HydraTorpedoes_getWarheadProbability = TorpedoGenerator.getWarheadProbability
function TorpedoGenerator:getWarheadProbability(x, y)
    local _WarheadProbabilities = HydraTorpedoes_getWarheadProbability(self, x, y)
    local distFromCenter = length(vec2(x, y)) / Balancing_GetMaxCoordinates()

    local data = {}

    data[WarheadType.NuclearHydra] =    {p = 1}
    data[WarheadType.NeutronHydra] =    {d = 0.75, p = 0.9}
    data[WarheadType.FusionHydra] =     {d = 0.75, p = 0.9}
    data[WarheadType.TandemHydra] =     {d = 0.60, p = 0.8}
    data[WarheadType.KineticHydra] =    {d = 0.60, p = 0.8}
    data[WarheadType.IonHydra] =        {d = 0.45, p = 0.7}
    data[WarheadType.PlasmaHydra] =     {d = 0.45, p = 0.7}
    data[WarheadType.SabotHydra] =      {d = 0.30, p = 0.6}
    data[WarheadType.EMPHydra] =        {d = 0.30, p = 0.6}
    data[WarheadType.AntiMatterHydra] = {d = 0.20, p = 0.5}

    for t, specs in pairs(data) do
        if not specs.d or distFromCenter < specs.d then
            _WarheadProbabilities[t] = specs.p
        end
    end

    return _WarheadProbabilities
end