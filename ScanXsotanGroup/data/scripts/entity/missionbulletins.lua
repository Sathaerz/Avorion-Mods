local ScanXsotanGroup_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = ScanXsotanGroup_getPossibleMissions()

    --Don't add this mission to player / alliance stations.
	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/scanxsotangroup.lua", prob = 2, maxDistToCenter = 500})
	end

    if not station.playerOrAllianceOwned and (stationTitle == "Research Station" or stationTitle == "Resistance Outpost") then
		table.insert(scripts, {path = "data/scripts/player/missions/scanxsotangroup.lua", prob = 3, maxDistToCenter = 500})
	end

	return scripts
end