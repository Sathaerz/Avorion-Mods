local huntTheHunters_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
    local station = Entity()
    local stationTitle = station.title

    local scripts = huntTheHunters_getPossibleMissions()

    if not station.playerOrAllianceOwned and (stationTitle == "Smuggler Hideout" or stationTitle == "Smuggler's Market") then
		table.insert(scripts, {path = "data/scripts/player/missions/huntthehunters.lua", prob = 2})
	end

    return scripts
end