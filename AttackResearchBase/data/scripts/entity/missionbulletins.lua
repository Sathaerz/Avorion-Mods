local AttackResearchBase_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
	
	local scripts = AttackResearchBase_getPossibleMissions()

    --Don't add this mission to player / alliance stations.
	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/attackresearchbase.lua", prob = 3})
	end

	return scripts
end