local ScrapScramble_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = ScrapScramble_getPossibleMissions()

    if not station.playerOrAllianceOwned and stationTitle == "Scrapyard" then
		table.insert(scripts, {path = "data/scripts/player/missions/scrapscramble.lua", prob = 5})
	end

	return scripts
end