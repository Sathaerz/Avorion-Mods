local getPossibleMissions_destroyproto = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = getPossibleMissions_destroyproto()

	local _Version = GameVersion()
	local _HighProbability = 0
	local _LowProbability = 0
	if _Version.major <= 1 then
		--1.3.8 and lower probability.
		_HighProbability = 0.2 			--Military outpost
		_LowProbability = 0.1 			--Shipyard / Research Station
	else
		--2.0 and higher probability.
		_HighProbability = 1 			--Military outpost
		_LowProbability = 0.5 			--Shipyard / Research Station
	end

	if stationTitle == "Research Station" or stationTitle == "Shipyard" then
		--print("adding 'destroy prototype' to table")
		table.insert(scripts, {path = "data/scripts/player/missions/destroyprototype.lua", prob = _LowProbability})
	end

	if stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroyprototype.lua", prob = _HighProbability})
	end

	return scripts
end