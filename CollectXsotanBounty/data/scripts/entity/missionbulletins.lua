local CollectXsotanBounty_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = CollectXsotanBounty_getPossibleMissions()

	--Unlike other missions, you *can* get this from a player or alliance station.
	if stationTitle == "Military Outpost" or stationTitle == "Research Station" or stationTitle == "Resistance Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 15, maxDistToCenter = 500})
	end

	return scripts
end