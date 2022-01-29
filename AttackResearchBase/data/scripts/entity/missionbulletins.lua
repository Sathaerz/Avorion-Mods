local AttackResearchBase_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = AttackResearchBase_getPossibleMissions()

	local _Version = GameVersion()
	local _Probability = 0
	if _Version.major <= 1 then
		--1.3.8 and lower probability.
		_Probability = 0.5
	else
		--2.0 and higher probability.
		_Probability = 3
	end

	if stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/attackresearchbase.lua", prob = _Probability})
	end

	return scripts
end