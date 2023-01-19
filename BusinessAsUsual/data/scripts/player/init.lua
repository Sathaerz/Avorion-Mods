if onServer() then

    local player = Player()
    
    -- Add the framework mission to the player. We don't have access to all the good stuff in the DLC so this will have to continuously run in the background.
    if player.ownsBlackMarketDLC then
        player:addScriptOnce("background/businessframeworkmission.lua")
    end

end