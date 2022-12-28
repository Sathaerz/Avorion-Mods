local WreckingHavoc_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title
	local stationFaction = Faction(station.factionIndex)

	local scripts = WreckingHavoc_getPossibleMissions()

	local _Add = true
    --Don't add this mission to player / alliance stations.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

	if _Add and stationTitle == "Scrapyard" then
		print("inserting new mission")
		table.insert(scripts, {path = "data/scripts/player/missions/wreckinghavoc.lua", prob = 15})
	end

	return scripts
end