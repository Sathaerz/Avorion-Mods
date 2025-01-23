local XsotanSpecimen_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = XsotanSpecimen_getPossibleMissions()

	if not station.playerOrAllianceOwned and (stationTitle == "Research Station" or stationTitle == "Resistance Outpost") then
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanspecimen.lua", prob = 3, maxDistToCenter = 500})
	end

	return scripts
end