local LOTW_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = LOTW_getPossibleMissions()

	if stationTitle == "Military Outpost" then
		local _AddBulletins = true
		local _Players = {Sector():getPlayers()}
		for _, _Player in pairs(_Players) do
			if not _Player:getValue("_lotw_story_5_accomplished") then
				_AddBulletins = false
			end
		end

		local distanceFromCenter = length(vec2(Sector():getCoordinates()))
		if distanceFromCenter < 430 then
			_AddBulletins = false
		end

		if _AddBulletins then
			table.insert(scripts, {path = "data/scripts/player/missions/lotw/lotwmission6.lua", prob = 5})
			table.insert(scripts, {path = "data/scripts/player/missions/lotw/lotwmission7.lua", prob = 5})
		end
	end

	return scripts
end