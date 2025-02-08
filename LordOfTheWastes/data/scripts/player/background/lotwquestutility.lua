package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

mission._Debug = 0
mission._StoryStageValue = "_lotw_story_stage"

--mission.tracing = true
mission.data.silent = true

--globalphase is set to {} in structuredmission so we don't actually need to reset it here! Neat!
mission.globalPhase.updateInterval = 30 --Update every 30 seconds. As long as we don't set an update interval in the subsequent phaess it should always update every 30 seconds.
mission.globalPhase.updateServer = function()
    local methodName = "Global Phase Update Server"
    mission.Log(methodName, "Running...")

    local _player = Player()

    --Check faction OK
    --If the player somehow accepted the mission from their own station (or an ally's station... or another player's station, etc. just set it to the start ally)
    if not _player:getValue("_lotw_faction_verified") then
        if _player:getValue("_lotw_faction") then
            local _LOTWFaction = Faction(_player:getValue("_lotw_faction"))
            if _LOTWFaction.isPlayer or _LOTWFaction.isAlliance then
                local _StartFaction = _player:getValue("start_ally")
                _player:setValue("_lotw_faction", _StartFaction)
            end
            _player:setValue("_lotw_faction_verified", true)
        end
    end

    --Port old version if needed
    portOldVersion(_player)

    --Set Side mission values
    if not _player:getValue("_lotw_last_side1") then
        _player:setValue("_lotw_last_side1", 0)
    end
    if not _player:getValue("_lotw_last_side2") then
        _player:setValue("_lotw_last_side2", 0)
    end

    --Set mission phase
    if not _player:getValue(mission._StoryStageValue) then
        _player:setValue(mission._StoryStageValue, 1)
    else
        local phaseID = _player:getValue(mission._StoryStageValue)
        setPhase(phaseID)
    end
end

mission.globalPhase.onRestore = function()
    local _player = Player()

    --Port old version if needed
    portOldVersion(_player)

    if not _player:getValue(mission._StoryStageValue) then
        _player:setValue(mission._StoryStageValue, 1)
    end
end

mission.phases[1] = {}
mission.phases[1].onSectorEntered = function(x, y)
    local _MethodName = "Phase 1 On Sector Entered"
    mission.Log(_MethodName, "Running.")

    if onClient() then --We don't care about this on client.
        return
    end

    --Checks the distance already, so no need to run the other distance check.
    addMissionToStation(x, y, false, "data/scripts/player/missions/lotw/lotwstory1.lua")
end

mission.phases[2] = {}
mission.phases[2].updateServer = function()
    local _player = Player()
    local scriptPath = "missions/lotw/lotwstory2.lua"
    local stageReq = 2
    local x, y = Sector():getCoordinates()

    local frameworkStoryStage = _player:getValue(mission._StoryStageValue)
    if frameworkStoryStage and frameworkStoryStage == stageReq and checkDistanceOK(x, y) then
        if not _player:hasScript(scriptPath) then
            _player:addScriptOnce(scriptPath)
        end
    end
end

mission.phases[3] = {}
mission.phases[3].updateServer = function()
    local _player = Player()
    local scriptPath = "missions/lotw/lotwstory3.lua"
    local stageReq = 3
    local x, y = Sector():getCoordinates()

    local frameworkStoryStage = _player:getValue(mission._StoryStageValue)
    if frameworkStoryStage and frameworkStoryStage == stageReq and checkDistanceOK(x, y) then
        if not _player:hasScript(scriptPath) then
            _player:addScriptOnce(scriptPath)
        end
    end
end

mission.phases[4] = {}
mission.phases[4].updateServer = function()
    local _player = Player()
    local scriptPath = "missions/lotw/lotwstory4.lua"
    local stageReq = 4
    local x, y = Sector():getCoordinates()

    local frameworkStoryStage = _player:getValue(mission._StoryStageValue)
    if frameworkStoryStage and frameworkStoryStage == stageReq and checkDistanceOK(x, y) then
        if not _player:hasScript(scriptPath) then
            _player:addScriptOnce(scriptPath)
        end
    end
end

mission.phases[5] = {}
mission.phases[5].updateServer = function()
    local _player = Player()
    local scriptPath = "missions/lotw/lotwstory5.lua"
    local stageReq = 5
    local x, y = Sector():getCoordinates()

    local frameworkStoryStage = _player:getValue(mission._StoryStageValue)
    if frameworkStoryStage and frameworkStoryStage == stageReq and checkDistanceOK(x, y) then
        if not _player:hasScript(scriptPath) then
            _player:addScriptOnce(scriptPath)
        end
    end
end

mission.phases[6] = {}
mission.phases[6].onSectorEntered = function(x, y)
    local methodName = "Phase 6 On Sector Entered"
    mission.Log(methodName, "Running.")

    if onClient() then --We don't care about this on client.
        return
    end

    local _player = Player()

    --first, check to see if we even do this. First, we need to make sure that it has been at least 20 minutes since we last added the side mission.
    local nextValidSide1Time = (_player:getValue("_lotw_last_side1") or 0) + (20 * 60)
    local nextValidSide2Time = (_player:getValue("_lotw_last_side2") or 0) + (20 * 60)

    local currentTime = Server().unpausedRuntime
    local _random = random()

    mission.Log(methodName, "Current time is " .. tostring(currentTime) .. " next valid side 1 time is " .. tostring(nextValidSide1Time))
    mission.Log(methodName, "Current time is " .. tostring(currentTime) .. " next valid side 2 time is " .. tostring(nextValidSide2Time))

    if currentTime >= nextValidSide1Time and _random:test(0.5) then
        mission.Log(methodName, "Adding side 1 to board.")
        addMissionToStation(x, y, true, "data/scripts/player/missions/lotw/lotwside1.lua")
    end
    if currentTime >= nextValidSide2Time and _random:test(0.5) then
        mission.Log(methodName, "Adding side 2 to board.")
        addMissionToStation(x, y, true, "data/scripts/player/missions/lotw/lotwside2.lua")
    end
end

--region #SERVER CALLS

function portOldVersion(_player)
    if _player:getValue("_lotw_story_5_accomplished") then
        _player:setValue(mission._StoryStageValue, 6)
        _player:setValue("_lotw_story_complete", true)
        _player:setValue("_lotw_story_5_accomplished", nil)
    end
end

function checkDistanceOK(x, y)
    local _Dist = math.sqrt(x*x + y*y)
    local _MinDist = 430
    
    if _Dist < _MinDist then
        return false
    end

    return true
end

function addMissionToStation(x, y, militaryOutpostOnly, missionScript)
    local methodName = "Add Mission To Station"

    local dist = math.sqrt(x*x + y*y)
    local minDist = 430

    mission.Log(methodName, "Min Distance is " .. tostring(minDist) .. " military outpost only is " .. tostring(militaryOutpostOnly))

    if dist >= minDist then
        local stationCandidates = {Sector():getEntitiesByType(EntityType.Station)}
        local stations = {}
        for _, _Station in pairs(stationCandidates) do
            local canAdd = true
            if _Station.playerOrAllianceOwned then
                canAdd = false
            end

            if militaryOutpostOnly and _Station.title ~= "Military Outpost" then
                canAdd = false
            end

            if canAdd then
                table.insert(stations, _Station)
            end
        end

        if #stations > 0 then
            for _, _Station in pairs(stations) do
                local _ok, _bulletin = run(missionScript, "getBulletin", _Station)
                _Station:invokeFunction("bulletinboard", "removeBulletin", _bulletin.brief)
            end

            shuffle(random(), stations)
            stations[1]:invokeFunction("bulletinboard", "addMission", missionScript)
        else
            mission.Log(methodName, "No viable stations from the list of candidates.")
        end
    else
        mission.Log(methodName, "Distance is " .. tostring(dist) .. " which does not qualify")
    end
end

--endregion