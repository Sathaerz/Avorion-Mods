local RescueSlaves_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
    
	local scripts = RescueSlaves_getPossibleMissions()

    --Don't add this mission to player / alliance stations.
	if not station.playerOrAllianceOwned and stationTitle == "Habitat" then
		table.insert(scripts, {path = "data/scripts/player/missions/rescueslaves.lua", prob = 1, minDistToCenter = 25})
	end

    if not station.playerOrAllianceOwned and stationTitle == "Trading Post" then
        table.insert(scripts, {path = "data/scripts/player/missions/rescueslaves.lua", prob = 0.5, minDistToCenter = 25})
    end

	return scripts
end