local TheDig_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = TheDig_getPossibleMissions()

    if not station.playerOrAllianceOwned and stationTitle == "Resource Depot" then
		table.insert(scripts, {path = "data/scripts/player/missions/thedig.lua", prob = 3})
	end

	return scripts
end