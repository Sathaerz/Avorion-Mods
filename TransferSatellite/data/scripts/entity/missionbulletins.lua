local TransferSatellite_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
    local stationFaction = Faction(station.factionIndex)

	local scripts = TransferSatellite_getPossibleMissions()

    local _Add = true
    --Don't add this mission to player / alliance stations since this actually makes a unit similar to the energy suppression satellite. 
	--We don't want to clutter the player's fleet with this.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

	if _Add and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/transfersatellite.lua", prob = 3})
	end

    if _Add and stationTitle == "Research Station" then
		table.insert(scripts, {path = "data/scripts/player/missions/transfersatellite.lua", prob = 3.5})
	end

	return scripts
end