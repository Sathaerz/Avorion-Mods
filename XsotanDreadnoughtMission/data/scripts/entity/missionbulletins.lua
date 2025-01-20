local XsotanDreadnought_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = XsotanDreadnought_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Research Station" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 0.5, maxDistToCenter = 400})
	end

    if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 1, maxDistToCenter = 400})
	end

    if not station.playerOrAllianceOwned and stationTitle == "Resistance Outpost" then
        table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 3, maxDistToCenter = 400})
    end

	return scripts
end