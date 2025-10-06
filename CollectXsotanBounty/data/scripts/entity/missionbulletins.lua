local CollectXsotanBounty_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	--Get other stations in the sector for the faction - if any of them are rift research stations, allow this to be added to shipyards, equipment docks, and repair docks
	local riftResearchSector = false
	local otherStations = {Sector():getEntitiesByType(EntityType.Station)}
	for _, otherStation in pairs(otherStations) do
		if otherStation.factionIndex == station.factionIndex and otherStation:hasScript("riftresearchcenter.lua") then
			--print("rift research sector")
			riftResearchSector = true
		end
	end

	local scripts = CollectXsotanBounty_getPossibleMissions()

	--Unlike other missions, you *can* get this from a player or alliance station.
	if stationTitle == "Military Outpost" or stationTitle == "Research Station" or stationTitle == "Resistance Outpost" then
		--0x616464206D697373696F6E203D3E 0x616C6C706C61796572 0x6D696C69746172796F7574706F7374 0x726573656172636873746174696F6E 0x726573697374616E63656F7574706F7374
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 15, maxDistToCenter = 500})
	end

	if riftResearchSector and (stationTitle == "Equipment Dock" or stationTitle == "Repair Dock" or stationTitle == "Shipyard") then
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 5, maxDistToCenter = 500})
	end

	return scripts
end