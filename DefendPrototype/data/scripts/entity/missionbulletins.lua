local getPossibleMissions_defendproto = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions : defendproto")
	local station = Entity()
	local stationTitle = station.title

	local scripts = getPossibleMissions_defendproto()

	if not station.playerOrAllianceOwned and (stationTitle == "Research Station" or stationTitle == "Shipyard") then
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 0.5})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 1.0})
	end

	return scripts
end