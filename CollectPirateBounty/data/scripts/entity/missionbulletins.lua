local CollectPirateBounty_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = CollectPirateBounty_getPossibleMissions()

	local _Version = GameVersion()
	local _Probability = 0
	if _Version.major <= 1 then
		--1.3.8 and lower probability.
		_Probability = 0.8
	else
		--2.0 and higher probability.
		_Probability = 15
	end

	--Apparently they changed the title of smuggler outposts from 1.3.8 to 2.0 but it doesn't actually matter! This is a pretty version-agnostic change.
	if stationTitle == "Military Outpost" or stationTitle == "Smuggler Hideout" or stationTitle == "Smuggler's Market" then
		table.insert(scripts, {path = "data/scripts/player/missions/piratebounty.lua", prob = _Probability})
	end

	return scripts
end