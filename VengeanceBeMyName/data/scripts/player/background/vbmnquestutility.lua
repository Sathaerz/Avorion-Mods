package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

mission._Name = "VBMN Main Quest Mission"
mission._Debug = 0
mission._StoryStageValue = "_vengeancebmn_story_stage"
mission._Side1LastTimeValue = "_vengeancebmn_last_side1"
mission._Side2LastTimeValue = "_vengeancebmn_last_side2"

--mission.tracing = true
mission.data.silent = true

--region #GLOBAL PHASE CALLS

mission.globalPhase.updateInterval = 30
mission.globalPhase.updateServer = function()
    local _player = Player()

    --Set mission phase
    if not _player:getValue(mission._StoryStageValue) then
        _player:setValue(mission._StoryStageValue, 1)
    else
        local phaseID = _player:getValue(mission._StoryStageValue)
        setPhase(phaseID)
    end

    --Set side mission values
    if not _player:getValue(mission._Side1LastTimeValue) then
        _player:setValue(mission._Side1LastTimeValue, 0)
    end
    if not _player:getValue(mission._Side2LastTimeValue) then
        _player:setValue(mission._Side2LastTimeValue, 0)
    end
end

mission.globalPhase.onRestore = function()
    local _player = Player()

    if not _player:getValue(mission._StoryStageValue) then
        _player:setValue(mission._StoryStageValue, 1)
    end
end

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].onSectorEntered = function(x, y)
    local methodName = "Phase 1 On Sector Entered"
    mission.Log(methodName, "Running.")

    if onClient() then 
        return
    end

    vbmnQuestUtil_addMissionToStation(x, y, "data/scripts/player/missions/vengeance/vengeancestory1.lua")
end

mission.phases[2] = {}
mission.phases[2].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory2.lua", 2)
end

mission.phases[3] = {}
mission.phases[3].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory3.lua", 3)
end

mission.phases[4] = {}
mission.phases[4].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory4.lua", 4)
end

mission.phases[5] = {}
mission.phases[5].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory5.lua", 5)
end

mission.phases[6] = {}
mission.phases[6].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory6.lua", 6)
end

mission.phases[7] = {}
mission.phases[7].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory7.lua", 7)
end

mission.phases[8] = {}
mission.phases[8].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory8.lua", 8)
end

mission.phases[9] = {}
mission.phases[9].updateServer = function()
    vbmnQuestUtil_addStoryMissionSequence("data/scripts/player/missions/vengeance/vengeancestory9.lua", 9)
end

mission.phases[10] = {}
mission.phases[10].onSectorEntered = function(x ,y)
    local methodName = "Phase 10 On Sector Entered"
    mission.Log(methodName, "Running.")

    if onClient() then
        return
    end

    local _player = Player()

    local nextValidSide1Time = (_player:getValue(mission._Side1LastTimeValue) or 0) + (30 * 60)
    local nextValidSide2Time = (_player:getValue(mission._Side2LastTimeValue) or 0) + (30 * 60)

    local currentTime = Server().unpausedRuntime
    local _random = random()

    if currentTime >= nextValidSide1Time and _random:test(0.10) then
        mission.Log(methodName, "Adding side 1 to board.")
        vbmnQuestUtil_addMissionToStation(x, y, "data/scripts/player/missions/vengeance/vengeanceside1.lua")
    end
    if currentTime >= nextValidSide2Time and _random:test(0.10) then
        mission.Log(methodName, "Adding side 2 to board.")
        vbmnQuestUtil_addMissionToStation(x, y, "data/scripts/player/missions/vengeance/vengeanceside2.lua")
    end
end

--endregion

--region #SERVER CALLS

function vbmnQuestUtil_checkDistanceOK(x, y)
    local methodName = "Check Distance OK"

    local dist = math.sqrt(x*x + y*y)
    local minDist = 210 --Takes place over mid trin => xan (210 -> 290)
    local maxDist = 270

    if dist <= maxDist and dist >= minDist then
        mission.Log(methodName, "Min dist is " .. tostring(minDist) .. " player dist is " .. tostring(dist) .. " Max dist is " .. tostring(maxDist) .. "- this qualifies")
        return true
    else
        mission.Log(methodName, "Min dist is " .. tostring(minDist) .. " player dist is " .. tostring(dist) .. " Max dist is " .. tostring(maxDist) .. "- this does not qualify")
        return false
    end
end

function vbmnQuestUtil_addMissionToStation(x, y, missionScript)
    local methodName = "Add Mission To Station"

    if vbmnQuestUtil_checkDistanceOK(x, y) then
        local stationCandidates = {Sector():getEntitiesByType(EntityType.Station)}
        local stations = {}
        for _, _Station in pairs(stationCandidates) do
            if not _Station.playerOrAllianceOwned and checkCampaignStationOK(_Station.title) then
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
    end
end

function vbmnQuestUtil_addStoryMissionSequence(scriptPath, stageReq)
    local methodName = "Add Story Mission Sequence"

    mission.Log(methodName, "Adding script path " .. scriptPath .. " requiring stage " .. tostring(stageReq))

    local _player = Player()
    local x, y = Sector():getCoordinates()

    local currentStage = _player:getValue(mission._StoryStageValue)
    if currentStage and currentStage == stageReq and vbmnQuestUtil_checkDistanceOK(x,y) then
        if not _player:hasScript(scriptPath) then
            _player:addScriptOnce(scriptPath)
        end
    end
end

--endregion