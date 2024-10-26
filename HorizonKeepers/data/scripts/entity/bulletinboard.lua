local HorizonKeepers_RefreshIcon = BulletinBoard.refreshIcon
function BulletinBoard.refreshIcon()
    local _MethodName = "Refresh Icon"

    HorizonKeepers_RefreshIcon()
    local hasHorizonBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()

    local patterns = {
        "horizonstory1.lua",
        "horizonside1.lua",
        "horizonside2.lua"
    }

    for _, bulletin in pairs(displayed) do
        for _, pattern in pairs(patterns) do
            if string.find(bulletin.script, pattern) then
                hasHorizonBulletin = true
                break
            end
        end
    end

    if hasHorizonBulletin then
        EntityIcon().secondaryIcon = "data/textures/icons/pixel/mission-white.png"
        local _ESCCUtil = include("esccutil")
        EntityIcon().secondaryIconColor = _ESCCUtil.getSaneColor(230, 230, 255)
    end
end