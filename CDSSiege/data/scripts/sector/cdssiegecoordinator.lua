include ("randomext")

--Don't remove or alter the following comment.
--namespace CDSSiegeCoordinator
CDSSiegeCoordinator = {}
local self = CDSSiegeCoordinator

self._Data = {}

local _MinTime = 21600
local _MaxTime = 43200
local _MinRetryInterdiction = 1800
local _MaxRetryInterdiction = 3600

function CDSSiegeCoordinator.initialize()
    local _rand = random()

    self._Data._TimeLeft = self._Data._TimeLeft or _rand:getInt(_MinTime, _MaxTime)
end

function CDSSiegeCoordinator.getUpdateInterval()
    return 300 --Update every 5 minutes.
end

function CDSSiegeCoordinator.updateServer(_TimeStep)
    local _Sector = Sector()
    local _Stations = {_Sector:getEntitiesByType(EntityType.Station)}

    if #_Stations == 0 then
        terminate()
        return
    end

    self._Data._TimeLeft = self._Data._TimeLeft - _TimeStep
    if self._Data._TimeLeft <= 0 then
        --add event script
        local _rand = random()

        if self.eventInterdicted() or self.eventNotAllowed() then
            self._Data._TimeLeft = _rand:getInt(_MinRetryInterdiction, _MaxRetryInterdiction)
        else
            --Attach event to sector.
            self._Data._TimeLeft = _rand:getInt(_MinTime, _MaxTime)
            _Sector:addScriptOnce("data/scripts/sector/cdssiegeevent.lua")
        end
    end
end

function CDSSiegeCoordinator.eventNotAllowed()
    local _Sector = Sector()

    if _Sector:getValue("neutral_zone") then
        --No attacks in neutral zones.
        return true
    end

    if _Sector:getEntitiesByScriptValue("no_attack_events") then
        --No attacks vs. energy suppression satellites
        return true
    end

    if _Sector:getEntitiesByScriptValue("is_bomber") then
        --No attacks if one is already going on.
        return true
    end

    return false
end

function CDSSiegeCoordinator.eventInterdicted()
    local _Sector = Sector()

    local _X, _Y = _Sector:getCoordinates()
    local _Players = {_Sector:getPlayers()}
    for _, _xPlayer in pairs(_Players) do
        local _Status, _Interdictions = _xPlayer:invokeFunction("player/events/eventscheduler.lua", "getInterdictions")
        if _Status == 0 then
            for _, _Interdiction in pairs(_Interdictions) do
                if _Interdiction.coordinates.x == _X and _Interdiction.coordinates.y == _Y then
                    return true
                end
            end
        end
    end

    return false
end

function CDSSiegeCoordinator.secure()
    return self._Data
end

function CDSSiegeCoordinator.restore(_Values)
    self._Data = _Values
end