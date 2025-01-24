local Annihilatorium_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = Annihilatorium_getPossibleMissions()

	if not station.playerOrAllianceOwned and (stationTitle == "Smuggler Hideout" or stationTitle == "Smuggler's Market" or stationTitle == "Casino") then
		table.insert(scripts, {path = "data/scripts/player/missions/annihilatorium.lua", prob = 1})
	end

	return scripts
end