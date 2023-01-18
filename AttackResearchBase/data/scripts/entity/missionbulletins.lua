local AttackResearchBase_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
	local stationFaction = Faction(station.factionIndex)

	local scripts = AttackResearchBase_getPossibleMissions()

	local _Add = true
    --Don't add this mission to player / alliance stations.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

	if _Add and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/attackresearchbase.lua", prob = 3})
	end

	return scripts
end