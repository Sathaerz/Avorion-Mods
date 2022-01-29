BulletinBoard._Debug = 0

local LOTW_RefreshIcon = BulletinBoard.refreshIcon
function BulletinBoard.refreshIcon()
    local _MethodName = "Refresh Icon"
    LOTW_RefreshIcon()
    local containsLOTWBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()
    for _, bulletin in pairs(displayed) do
        if bulletin.script == "data/scripts/player/missions/lotw/lotwmission1.lua" then
            containsLOTWBulletin = true
        end
    end

    if containsLOTWBulletin then
        BulletinBoard.Log(_MethodName, "Station has LOTW mission - setting icon / color")
        EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission-white.png"
        EntityIcon().secondaryIconColor = ColorRGB(1, 0.1, 0.4) -- same color as blackmarket mask but slightly lighter for better contrast
    end
end

function BulletinBoard.Log(_MethodName, _Msg, _OverrideDebug)
    local _UseDebug = _OverrideDebug or BulletinBoard._Debug
    if _UseDebug == 1 then
        print("[LOTW BulletinBoard] - [" .. _MethodName .. "] - " .. _Msg)
    end
end