local WreckingHavoc_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = WreckingHavoc_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Scrapyard" then
		table.insert(scripts, {path = "data/scripts/player/missions/wreckinghavoc.lua", prob = 15})
	end

	return scripts
end