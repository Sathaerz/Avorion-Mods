local EradicateXsotan_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = EradicateXsotan_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/eradicatexsotan.lua", prob = 1})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Resistance Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/eradicatexsotan.lua", prob = 3})
	end

	return scripts
end