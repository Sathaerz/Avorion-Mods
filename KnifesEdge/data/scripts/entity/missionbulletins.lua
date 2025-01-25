local knifesEdge_getPossibleMissions = MissionBulletins.getPossibleMissions
function MissionBulletins.getPossibleMissions()
	--print("getting possible missions")
	local station = Entity()
	local stationTitle = station.title

	local scripts = knifesEdge_getPossibleMissions()

	if not station.playerOrAllianceOwned and stationTitle == "Shipyard" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroyprototype2.lua", prob = 0.5})
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 0.5})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Military Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/destroyprototype2.lua", prob = 1.0})
		table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 2})
		table.insert(scripts, {path = "data/scripts/player/missions/transfersatellite.lua", prob = 2})
		table.insert(scripts, {path = "data/scripts/player/missions/eradicatexsotan.lua", prob = 1, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 1.0})
		table.insert(scripts, {path = "data/scripts/player/missions/destroystronghold.lua", prob = 1.0})
		table.insert(scripts, {path = "data/scripts/player/missions/scanxsotangroup.lua", prob = 2, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 1, maxDistToCenter = 400})
		table.insert(scripts, {path = "data/scripts/player/missions/piratebounty.lua", prob = 15})
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 15, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/attackresearchbase.lua", prob = 2})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Scrapyard" then
		table.insert(scripts, {path = "data/scripts/player/missions/scrapdelivery.lua", prob = 15})
		table.insert(scripts, {path = "data/scripts/player/missions/wreckinghavoc.lua", prob = 15})
		table.insert(scripts, {path = "data/scripts/player/missions/scrapscramble.lua", prob = 3})
	end

    if not station.playerOrAllianceOwned and stationTitle == "${faction} Headquarters" then
        table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 3})
    end

    if not station.playerOrAllianceOwned and stationTitle == "Research Station" then
		table.insert(scripts, {path = "data/scripts/player/missions/transfersatellite.lua", prob = 3})
		table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 0.5, maxDistToCenter = 400})
		table.insert(scripts, {path = "data/scripts/player/missions/destroyprototype2.lua", prob = 0.5})
		table.insert(scripts, {path = "data/scripts/player/missions/defendprototype.lua", prob = 0.5})
		table.insert(scripts, {path = "data/scripts/player/missions/scanxsotangroup.lua", prob = 3, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanspecimen.lua", prob = 3, maxDistToCenter = 500})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Resistance Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/eradicatexsotan.lua", prob = 3, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/destroyxsodread.lua", prob = 3, maxDistToCenter = 400})
		table.insert(scripts, {path = "data/scripts/player/missions/scanxsotangroup.lua", prob = 3, maxDistToCenter = 500})
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanspecimen.lua", prob = 3, maxDistToCenter = 500})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Resource Depot" then
		table.insert(scripts, {path = "data/scripts/player/missions/mineralmadness.lua", prob = 3})
		table.insert(scripts, {path = "data/scripts/player/missions/thedig.lua", prob = 3})
	end

	if not station.playerOrAllianceOwned and (stationTitle == "Smuggler Hideout" or stationTitle == "Smuggler's Market" or stationTitle == "Casino") then
		table.insert(scripts, {path = "data/scripts/player/missions/annihilatorium.lua", prob = 1})
	end

	if not station.playerOrAllianceOwned and stationTitle == "Habitat" then
		table.insert(scripts, {path = "data/scripts/player/missions/escortcivilians.lua", prob = 3})
		table.insert(scripts, {path = "data/scripts/player/missions/rescueslaves.lua", prob = 1, minDistToCenter = 25})
	end

    if not station.playerOrAllianceOwned and stationTitle == "Trading Post" then
        table.insert(scripts, {path = "data/scripts/player/missions/rescueslaves.lua", prob = 0.5, minDistToCenter = 25})
    end

	--Unlike other missions, you *can* get these from a player or alliance station.
	if stationTitle == "Smuggler Hideout" or stationTitle == "Smuggler's Market" then
		table.insert(scripts, {path = "data/scripts/player/missions/piratebounty.lua", prob = 15})
	end

	if stationTitle == "Research Station" or stationTitle == "Resistance Outpost" then
		table.insert(scripts, {path = "data/scripts/player/missions/xsotanbounty.lua", prob = 15, maxDistToCenter = 500})
	end

	--Ambush pirate raiders
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
    local _AddAmbushRaiders = false
    for _k, _v in pairs(_Tokens) do
        if string.find(stationTitle, _v) then
            _AddAmbushRaiders = true
            break --If one is true, don't need to check the rest.
        end
    end

    if _AddAmbushRaiders then
        table.insert(scripts, {path = "data/scripts/player/missions/ambushraiders.lua", prob = 3})
    end

	return scripts
end

local _Debug = 0

--Extra available missions implementation.
if onServer() then

    --Reset this to be every 15 mins instead of every 60 mins.
    local ExtraAvailableMissions_updateBulletins = MissionBulletins.updateBulletins
    function MissionBulletins.updateBulletins(timeStep)
        --Trick the function into updating 4x faster by passing in 4x the timestep.
        ExtraAvailableMissions_updateBulletins(timeStep * 4)
    end

    local ExtraAvailableMissions_addOrRemoveMissionBulletin = MissionBulletins.addOrRemoveMissionBulletin --Replaces this. Bye!
    function MissionBulletins.addOrRemoveMissionBulletin()
        local _Version = GameVersion()
        if _Debug == 1 then
            print("Running new addOrRemoveMissionBulletin function.")
        end
        local scripts = MissionBulletins.getPossibleMissions()
        if #scripts == 0 then return end

        local ostime = Server().unpausedRuntime
        --local ostime = os.time()
        local r = MissionBulletins.random()

        local _MissionCount = r:getInt(0, 5)
        if _MissionCount > 0 then
            for idx = 1, _MissionCount do
                if _Debug == 1 then
                    print("Getting script")
                end
                local scriptPath = MissionBulletins.getWeightedRandomEntry(scripts)
                local ok, bulletin = run(scriptPath, "getBulletin", Entity())

                if _Debug == 1 then
                    print("Script path is : " .. scriptPath)
                end

                if _Version.major > 1 then
                    if scriptPath == "data/scripts/player/missions/receivecaptainmission.lua" and r:test(0.75) then
                        if _Debug == 1 then
                            print("Removing captain mission from candidacy.")
                        end
                        ok = -1
                    end
                end

                if ok == 0 and bulletin then
                    bulletin["TimeAdded"] = ostime
                    Entity():invokeFunction("bulletinboard", "postBulletin", bulletin)
                end
            end
        end

        Entity():invokeFunction("bulletinboard", "checkRemoveBulletins", ostime, r)
    end

end