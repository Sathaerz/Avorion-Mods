local LOTW_RefreshIcon = BulletinBoard.refreshIcon
function BulletinBoard.refreshIcon()
    local _MethodName = "Refresh Icon"

    LOTW_RefreshIcon()
    local containsLOTWBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()

    local patterns = {
        "lotwstory1.lua",
        "lotwside1.lua",
        "lotwside2.lua"
    }

    for _, bulletin in pairs(displayed) do
        --BulletinBoard.Log(_MethodName, "Script is " .. tostring(bulletin.script))
        for _, pattern in pairs(patterns) do
            if string.find(bulletin.script, pattern) then
                containsLOTWBulletin = true
                break
            end
        end

        if containsLOTWBulletin then
            break
        end
    end

    if containsLOTWBulletin then
        BulletinBoard.Log(_MethodName, "Station has LOTW mission - setting icon / color")
        EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission-white.png"
        local _ESCCUtil = include("esccutil")
        EntityIcon().secondaryIconColor = _ESCCUtil.getSaneColor(247, 247, 73)
    end
end