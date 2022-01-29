local WreckingHavoc_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = WreckingHavoc_getPossibleMissions()

	local _Version = GameVersion()
	local _Probability = 0
	if _Version.major <= 1 then
		--1.3.8 and lower probability.
		_Probability = 0.9
	else
		--2.0 and higher probability.
		_Probability = 15
	end

	if stationTitle == "Scrapyard" then
		print("inserting new mission")
		table.insert(scripts, {path = "data/scripts/player/missions/wreckinghavoc.lua", prob = _Probability})
	end

	return scripts
end