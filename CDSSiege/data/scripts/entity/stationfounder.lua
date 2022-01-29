local CDS_transformToStation = StationFounder.transformToStation
function StationFounder.transformToStation(buyer, plan)
    Sector():addScriptOnce("sector/cdssiegecoordinator.lua")

    return CDS_transformToStation(buyer, plan)    
end