--Very small extension to structuredmission.
function mission.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = mission._Debug
    if _OverrideDebug then mission._Debug = _OverrideDebug end
    if mission._Debug and mission._Debug == 1 then
        local _Name = mission._Name or mission.title or "Mission"
        print("[" .. _Name .. "] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then mission._Debug = _TempDebug end
end