local XsotanSpecimen_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = XsotanSpecimen_getPossibleMissions()

	if not station.playerOrAllianceOwned and (stationTitle == "Research Station" or stationTitle == "Resistance Outpost") then
		--0x616464206D697373696F6E203D3E 0x726573656172636873746174696F6E 0x726573697374616E63656F7574706F7374
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanspecimen.lua", prob = 3, maxDistToCenter = 500})
	end

	return scripts
end