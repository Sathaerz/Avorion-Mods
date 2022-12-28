local AmbushRaiders_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	local station = Entity()
	local stationTitle = station.title
    local stationFaction = Faction(station.factionIndex)

	local scripts = AmbushRaiders_getPossibleMissions()

    --Everything but factories, basically.
    local _Tokens = {
        "Habitat",
        "Research Station",
        "Trading Post",
        "Shipyard",
        "Repair Dock",
        "Smuggler's Market",
        "Smuggler Hideout",
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
        end
    end

    --Don't add this mission to player / alliance stations.
    if stationFaction.isPlayer or stationFaction.isAlliance then
        _Add = false
    end

    if _Add then
        table.insert(scripts, {path = "data/scripts/player/missions/ambushraiders.lua", prob = 3})
    end

	return scripts
end