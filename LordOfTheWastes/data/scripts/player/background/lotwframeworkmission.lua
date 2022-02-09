package.path = package.path .. ";data/scripts/lib/?.lua"

local MissionUT = include("missionutility")
local AsyncShipGen = include("asyncshipgenerator")

--Don't remove this or else the script might break.
--namespace LOTWFrameworkMission
LOTWFrameworkMission = {}
local self = LOTWFrameworkMission

self._Debug = 0

--region #INIT

function LOTWFrameworkMission.initialize()
    local _MethodName = "initialize"
    self.Log(_MethodName, "Beginning...")

    if Player():registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed") == 1 then
        self.Log(_MethodName, "Failed To Register Callback: onSectorArrivalConfirmed")
    end
end

--endregion

function LOTWFrameworkMission.getUpdateInterval()
    return 30
end

--region #SERVER CALLS

function LOTWFrameworkMission.updateServer(_TimeStep) 
    local _MethodName = "On Update Server"
    self.Log(_MethodName, "Beginning...")

    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    
    local _Dist = math.sqrt(_X*_X + _Y*_Y)
    local _MinDist = 430
    
    if _Dist < _MinDist then
        self.Log(_MethodName, "Player too close to center - do not give more missions.")
        return
    end

    local _Player = Player()

    --If the player somehow accepted the mission from their own station (or an ally's station... or another player's station, etc. just set it to the start ally)
    if not _Player:getValue("_lotw_faction_verified") then
        if _Player:getValue("_lotw_faction") then
            local _LOTWFaction = Faction(_Player:getValue("_lotw_faction"))
            if _LOTWFaction.isPlayer or _LOTWFaction.isAlliance then
                local _StartFaction = _Player:getValue("start_ally")
                _Player:setValue("_lotw_faction", _StartFaction)
            end
            _Player:setValue("_lotw_faction_verified", true)
        end
    end

    local _Story1Done = _Player:getValue("_lotw_story_1_accomplished")
    local _Story2Done = _Player:getValue("_lotw_story_2_accomplished")
    local _Story3Done = _Player:getValue("_lotw_story_3_accomplished")
    local _Story4Done = _Player:getValue("_lotw_story_4_accomplished")
    local _Story5Done = _Player:getValue("_lotw_story_5_accomplished")

    if _Story1Done and not _Story2Done and not _Player:hasScript("missions/lotw/lotwmission2.lua") then
        _Player:addScript("missions/lotw/lotwmission2.lua")
    end

    if _Story2Done and not _Story3Done and not _Player:hasScript("missions/lotw/lotwmission3.lua") then
        _Player:addScript("missions/lotw/lotwmission3.lua")
    end

    if _Story3Done and not _Story4Done and not _Player:hasScript("missions/lotw/lotwmission4.lua") then
        _Player:addScript("missions/lotw/lotwmission4.lua")
    end

    if _Story4Done and not _Story5Done and not _Player:hasScript("missions/lotw/lotwmission5.lua") then
        _Player:addScript("missions/lotw/lotwmission5.lua")
    end
end

function LOTWFrameworkMission.onSectorArrivalConfirmed(_PlayerIndex, _X, _Y)
    local _MethodName = "On Sector Arrival Confirmed"
    self.Log(_MethodName, "Beginning...")
    local _Player = Player()
    local _Story1Done = _Player:getValue("_lotw_story_1_accomplished")

    if not _Story1Done then
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()
    
        local _Dist = math.sqrt(_X*_X + _Y*_Y)
        local _MinDist = 430
    
        if _Dist >= _MinDist then
            self.Log(_MethodName, "Distance is " .. tostring(_Dist) .. " - which is inside the " .. tostring(_MinDist) .. " to 707 range")
            
            local _StationCandidates = {_Sector:getEntitiesByType(EntityType.Station)}
            local _Stations = {}
            for _, _Station in pairs(_StationCandidates) do
                local _StationFaction = Faction(_Station.factionIndex)
                if not _StationFaction.isPlayer and not _StationFaction.isAlliance then
                    table.insert(_Stations, _Station)
                end
            end
        
            if #_Stations > 0 then
                --Find a random station and add it to the bulletin board of that station.
                --Remove it from all stations first so we only have it on one station a time.
                local _ScriptPath = "data/scripts/player/missions/lotw/lotwmission1.lua"
                
                for _, _Statio in pairs(_Stations) do
                    local _lOk, _lBulletin = run(_ScriptPath, "getBulletin", _Statio)
                    _Statio:invokeFunction("bulletinboard", "removeBulletin", _lBulletin.brief)
                end
        
                local _Rgen = ESCCUtil.getRand()
                local _Station = _Stations[_Rgen:getInt(1, #_Stations)]

                _Station:invokeFunction("bulletinboard", "addMission", _ScriptPath)
            else
                self.Log(_MethodName, "No viable stations from the list of candidates.")
            end
        else
            self.Log(_MethodName, "Distance is " .. tostring(_Dist) .. " - which is NOT inside the " .. tostring(_MinDist) .. " to 707 range")
        end
    end
end

--endregion

--region #CLIENT / SERVER CALLS

function LOTWFrameworkMission.Log(_MethodName, _Msg, _OverrideDebug)
    local _UseDebug = _OverrideDebug or self._Debug
    if _UseDebug == 1 then
        print("[LOTW Framework Mission] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion

--All of the following values are altered by this script:
--[[
_lotw_story_1_accomplished
_lotw_story_2_accomplished
_lotw_story_3_accomplished
_lotw_story_4_accomplished
_lotw_story_5_accomplished
]]