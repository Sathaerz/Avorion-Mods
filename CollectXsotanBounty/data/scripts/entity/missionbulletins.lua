local CollectXsotanBounty_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = CollectXsotanBounty_getPossibleMissions()

	--Unlike other missions, you *can* get this from a player or alliance station.
	if stationTitle == "Military Outpost" or stationTitle == "Research Station" or stationTitle == "Resistance Outpost" then
		--0x616464206D697373696F6E203D3E 0x616C6C706C61796572 0x6D696C69746172796F7574706F7374 0x726573656172636873746174696F6E 0x726573697374616E63656F7574706F7374
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 15, maxDistToCenter = 500})
	end

	return scripts
end