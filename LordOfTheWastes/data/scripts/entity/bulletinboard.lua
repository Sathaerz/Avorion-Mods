local LOTW_RefreshIcon = BulletinBoard.refreshIcon
function BulletinBoard.refreshIcon()
    local _MethodName = "Refresh Icon"

    LOTW_RefreshIcon()
    local containsLOTWBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()
    for _, bulletin in pairs(displayed) do
        --BulletinBoard.Log(_MethodName, "Script is " .. tostring(bulletin.script))
        if string.find(bulletin.script, "lotwmission1.lua") then
            containsLOTWBulletin = true
        end
    end

    if containsLOTWBulletin then
        BulletinBoard.Log(_MethodName, "Station has LOTW mission - setting icon / color")
        EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission-white.png"
        local _ESCCUtil = include("esccutil")
        EntityIcon().secondaryIconColor = _ESCCUtil.getSaneColor(247, 247, 73)
    end
end