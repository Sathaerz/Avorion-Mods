local MineralMadness_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = MineralMadness_getPossibleMissions()

    if not station.playerOrAllianceOwned and stationTitle == "Resource Depot" then
		table.insert(scripts, {path = "data/scripts/player/missions/mineralmadness.lua", prob = 3})
	end

	return scripts
end