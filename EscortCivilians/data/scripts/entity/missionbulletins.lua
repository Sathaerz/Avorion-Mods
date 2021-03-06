local EscortCivilians_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
    local stationFaction = Faction(station.factionIndex)

	local scripts = EscortCivilians_getPossibleMissions()

	local _Add = true
    --Don't add this mission to player / alliance stations.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

	if _Add and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 3})
	end

    --Slightly more likely to show up @ hq / habitats
    if _Add and stationTitle == "${faction} Headquarters" or stationTitle == "Habitat" then
        table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 3.5})
    end

	return scripts
end