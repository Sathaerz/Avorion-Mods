local getPossibleMissions_defendproto = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions : defendproto")
	local station = Entity()
	local stationTitle = station.title
    local stationFaction = Faction(station.factionIndex)

	local scripts = getPossibleMissions_defendproto()

	local _Add = true
    --Don't add this mission to player / alliance stations.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

	if _Add and (stationTitle == "Research Station" or stationTitle == "Shipyard") then
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 0.5})
	end

	if _Add and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 1.0})
	end

	return scripts
end