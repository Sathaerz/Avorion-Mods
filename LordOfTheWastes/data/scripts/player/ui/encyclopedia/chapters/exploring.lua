local _SwenksArticle = {
    title = "Swenks",
    picture = "data/textures/ui/encyclopedia/exploring/characters/swenks.jpg",
    text = "\\c(0d0)Swenks\\c() is the self-styled Lord of the Iron Wastes. Despite his low-tech ship, he may have \\c(0d0)a few surprises\\c() in store.",

    isUnlocked = function()
        if Player():getValue("encyclopedia_swenks_met") then return true end

        local swoks = Sector():getEntitiesByScript("swenks.lua")
        if swoks then
            -- RemoteInvocations_Ignore
            invokeServerFunction("setValue", "swenks_met")
            return true
        end

        return false
    end
}

table.insert(category.chapters[10].articles, _SwenksArticle)