local ScrapDelivery_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = ScrapDelivery_getPossibleMissions()

    if not station.playerOrAllianceOwned and stationTitle == "Scrapyard" then
		table.insert(scripts, {path = "data/scripts/player/missions/scrapdelivery.lua", prob = 10})
	end

	return scripts
end