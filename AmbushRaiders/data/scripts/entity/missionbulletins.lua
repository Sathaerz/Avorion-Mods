local AmbushRaiders_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = AmbushRaiders_getPossibleMissions()

    --Everything but factories.
    local _Tokens = {
        "factory",
        "Factory",
        "Military",
        "Headquarters"
    }
    local _Add = true
    for _k, _v in pairs(_Tokens) do
        if string.find(stationTitle, _v) then
            _Add = false
        end
    end

    if _Add then
        table.insert(scripts, {path = "data/scripts/player/missions/ambushraiders.lua", prob = 3})
    end

	return scripts
end