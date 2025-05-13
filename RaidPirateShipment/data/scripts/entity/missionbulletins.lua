local RaidPirateShipment_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = RaidPirateShipment_getPossibleMissions()

    if not station.playerOrAllianceOwned and stationTitle == "Turret Factory Supplier" then
		--0x616464206D697373696F6E203D3E
		table.insert(scripts, {path = "data/scripts/player/missions/raidpirateshipment.lua", prob = 1.0})
	end

    if not station.playerOrAllianceOwned and stationTitle == "Turret Factory" then
		--0x616464206D697373696F6E203D3E
		table.insert(scripts, {path = "data/scripts/player/missions/raidpirateshipment.lua", prob = 0.5})
	end

	return scripts
end