local AmbushRaiders_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title

	local scripts = AmbushRaiders_getPossibleMissions()

    --Everything but factories and military outposts, basically.
    local _Tokens = {
        "Habitat",
        "Research Station",
        "Trading Post",
        "Shipyard",
        "Repair Dock",
        "Smuggler",
        "Equipment Dock",
        "Casino",
        "Biotope",
        "Fighter Factory",
        "Resource Depot",
        "Turret Factory",
        "Mine",
        "Scrapyard"
    }
    local _Add = false
    for _k, _v in pairs(_Tokens) do
        if string.find(stationTitle, _v) then
            _Add = true
            break --If one is true, don't need to check the rest.
        end
    end

    if _Add then
        table.insert(scripts, {path = "data/scripts/player/missions/ambushraiders.lua", prob = 3})
    end

	return scripts
end