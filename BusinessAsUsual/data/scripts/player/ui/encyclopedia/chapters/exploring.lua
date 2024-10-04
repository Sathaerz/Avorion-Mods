bauchapter = {
    title = "BAU: Characters",
    articles = {
        {
            title = "The Family",
            picture = "data/textures/ui/encyclopedia/exploring/characters/pirate1.jpg",
            text = "After the defeat of The Cavaliers and The Commune, The \\c(0d0)Family\\c() are everywhere. Not a single business transaction goes by without their watchful eyes and their meticuous ledgers noticing. With a monopoly on black market trading and providing illicit services, it is only a matter of time until the balance tips...",
            isUnlocked = function()
                if Player():getValue("encyclopedia_bau_fam5_done") then
                    return true
                else
                    return false
                end
            end
        }
    }
}

table.insert(category.chapters, bauchapter)