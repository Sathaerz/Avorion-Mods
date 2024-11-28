local EscortCivilians_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = EscortCivilians_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 2})
	end

    --Slightly more likely to show up @ hq / habitats
    if not station.playerOrAllianceOwned and stationTitle == "${faction} Headquarters" or stationTitle == "Habitat" then
        table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 3})
    end

	return scripts
end