lltechapter = {
    title = "LLTE: Characters",
    articles = {
        {
            title = "The Cavaliers",
            picture = "data/textures/ui/encyclopedia/exploring/characters/cavaliers2.jpg",
            text = "After the defeat of The Family and The Commune, The \\c(0d0)Cavaliers\\c() have been able to increase the amount of pressure that they've been putting on the Pirates and the Xsotan to devastating levels. Pirate outposts across the galaxy have been vanishing without a trace, and powerful fleets of Cavaliers ships have been eradicating pirate and Xsotan attacks against faction outposts. It is only a matter of time until the balance tips...",
            isUnlocked = function()
                if Player():getValue("encyclopedia_llte_cav5_done") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Animosity",
            picture = "data/textures/ui/encyclopedia/exploring/characters/animosity.jpg",
            text = "After a devastating attack by The \\c(0d0)Cavaliers\\c() that wiped out a large pirate outpost and killed thousands, the pirates were crushed by a sense of loss and grief. How could they possibly fight against such power? Thier grief quickly hardened into rage, and the answer seemed obvious - what they had always done best: Piracy.\nIt was said to be impossible, but they did it regardless. A ship was successfully hijacked from the S.W.O.R.D. Private Military Corporation. This would be the tip of the spear in their fight for vengeance. The pirates named it after their hatred.\nThe Animosity is an upgraded \\c(0d0)Cleaver-Class Destroyer\\c(). It is larger than a normal Cleaver, and uses trinium armor and components instead of the standard titanium and naonite. It has also been fitted with a \\c(0d0)dangerous siege cannon\\c() that is designed for destroying large capital ships.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_llte_animosity_found") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Xsotan Artifact",
            picture = "data/textures/ui/encyclopedia/exploring/characters/artifact1.jpg",
            text = "During their journey to cross the barrier, The \\c(0d0)Cavaliers\\c() found a mysterious \\c(0d0)Xsotan artifact\\c(). It is unknown how it came to be embedded in a destroyed Xsotan craft in an out-of-the-way sector. Research is ongoing to discern the purpose of the artifact.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_llte_xsotan_artifact_found") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Xsotan Artifact (Cont.)",
            picture = "data/textures/ui/encyclopedia/exploring/characters/artifact2.jpg",
            text = "Further research on the artifact has revealed that it acts as \\c(0d0)a beacon to call Xsotan ships\\c() into the sector. Research is ongoing to find a suitable way to use this against the Xsotan.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_llte_xsotan_artifact_contd_found") then
                    return true
                else
                    return false
                end
            end
        }
    }
}

table.insert(category.chapters, lltechapter)