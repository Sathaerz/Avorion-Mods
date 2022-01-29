package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ITBackground
ITBackground = {}
local self = ITBackground

self._Debug = 0
self._OverallDecayTime = (24 * 60 * 60)
self._UnpauseFrames = 0

function ITBackground.getUpdateInterval()
    return 10 --Need to update every 10 seconds to handle unpausing.
end

function ITBackground.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    --We actually don't care about the timestep.
    local _ServerTime = Server().unpausedRuntime
    local _Player = Player()
    local _DecayTickValueName = "_increasingthreat_next_hatreddecay"
    local _HatredValueName = "_increasingthreat_hatred_"

    --Handle unpause frames.
    if self._UnpauseFrames > 0 then
        self.Log(_MethodName, "Unpausing events for " .. tostring(self._UnpauseFrames) .. " more update frames.")
        _Player:invokeFunction("player/events/eventscheduler.lua", "unPause")
        self._UnpauseFrames = self._UnpauseFrames - 1
    end

    --Handle decay ticks.
    local _DecayTick = Player():getValue(_DecayTickValueName) or 0
    if _ServerTime >= _DecayTick then
        self.Log(_MethodName, "Server time greater than decay tick time " .. tostring(_DecayTick) .. " decay hatred values.")
        local _PlayerValues = _Player:getValues()
        for _Key, _Val in pairs(_PlayerValues) do
            if string.match(_Key, _HatredValueName) then
                self.Log(_MethodName, "Key " .. tostring(_Key) .. " is a hatred value. Checking traits of faction it is associated with.")
                local _DecayBase = 0.01
                local _FactionIndex = _Key:split("_")[3]
                local _Faction = Faction(_FactionIndex)
                if _Faction then
                    local _Covetous = _Faction:getTrait("covetous")
                    local _Tempered = _Faction:getTrait("tempered")
                    if _Covetous and _Covetous >= 0.25 then
                        _DecayBase = _DecayBase * 1.5
                    else
                        self.Log(_MethodName, "Faction " .. tostring(_FactionIndex) .. " is not covetous.")
                    end
                    if _Tempered and _Tempered >= 0.25 then
                        _DecayBase = _DecayBase * 0.5
                    else
                        self.Log(_MethodName, "Faction " .. tostring(_FactionIndex) .. " is not tempered.")
                    end
                end
                local _NewHatredValue = math.floor(_Val * (1.0 - _DecayBase))
                self.Log(_MethodName, "Decaying hatred from faction " .. tostring(_FactionIndex) .. " from " .. tostring(_Val) .. " to " .. tostring(_NewHatredValue))
                _Player:setValue(_Key, _NewHatredValue)
            end
        end

        local _NextDecayTick = _ServerTime + self._OverallDecayTime
        _Player:setValue(_DecayTickValueName, _NextDecayTick)
    end
end

function ITBackground.unpauseEvents(_Frames)
    local _MethodName = "Unpause Events"
    
    _Frames = _Frames or 3
    self._UnpauseFrames = _Frames

    self.Log(_MethodName, "Running - frames is " .. tostring(_Frames))
end

function ITBackground.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[IT Background] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end