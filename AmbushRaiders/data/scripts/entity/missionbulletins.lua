local AmbushRaiders_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = AmbushRaiders_getPossibleMissions()

    --Everything but factories.
    local _Add = true
    if string.find(stationTitle, "factor") or string.find(stationTitle, "Factory") then
        _Add = false
    end

    if _Add then
        table.insert(scripts, {path = "data/scripts/player/missions/ambushraiders.lua", prob = 3})
    end

	return scripts
end