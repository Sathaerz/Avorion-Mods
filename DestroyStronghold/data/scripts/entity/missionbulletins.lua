local DestroyStronghold_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = DestroyStronghold_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroystronghold.lua", prob = 1.0})
	end

	return scripts
end