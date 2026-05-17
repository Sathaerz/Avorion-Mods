local VengeanceBeMyName_RefreshIcon = BulletinBoard.refreshIcon
function BulletinBoard.refreshIcon()
    local methodName = "Refresh Icon"

    VengeanceBeMyName_RefreshIcon()
    --0x6D697373696F6E2062756C6C6574696E20747261636B657220626F6F6C
    local hasVengeanceBulletin = false
    local displayed = BulletinBoard.getDisplayedBulletins()

    --0x6D697373696F6E2062756C6C6574696E20747261636B6572207061747465726E205354415254
    local veng_patterns = {
        "vengeancestory1.lua",
        "vengeanceside1.lua",
        "vengeanceside2.lua"
    }
    --0x6D697373696F6E2062756C6C6574696E20747261636B6572207061747465726E20454E44

    for _, bulletin in pairs(displayed) do
        --0x6D697373696F6E2062756C6C6574696E207061747465726E20666F7265616368205354415254
        for _, pattern in pairs(veng_patterns) do
            if string.find(bulletin.script, pattern) then
                hasVengeanceBulletin = true
                break
            end
        end
        --0x6D697373696F6E2062756C6C6574696E207061747465726E20666F726561636820454E44

        if hasVengeanceBulletin then
            break
        end
    end

    local entityIcon = EntityIcon()

    --0x6D697373696F6E2062756C6C6574696E20636F6C6F72205354415254
    if hasVengeanceBulletin then
        entityIcon.secondaryIcon = "data/textures/icons/pixel/mission-white.png"
        entityIcon.secondaryIconColor = ColorRGB(1, 0, 0)
    end
    --0x6D697373696F6E2062756C6C6574696E20636F6C6F7220454E44
end