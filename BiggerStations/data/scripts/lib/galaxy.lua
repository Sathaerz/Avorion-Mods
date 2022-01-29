local BiggerStations_Balancing_GetSectorStationVolume = Balancing_GetSectorStationVolume
function Balancing_GetSectorStationVolume(x, y)
    return BiggerStations_Balancing_GetSectorStationVolume() * 1.5
end