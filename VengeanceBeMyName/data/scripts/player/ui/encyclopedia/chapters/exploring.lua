--0x656E6379636C6F7065646961206368205354415254
vbmnchapter = {
    title = "VBMN: Characters",
    articles = {
        {
            title = "Pirates: An Essay",
            picture = "data/textures/ui/encyclopedia/exploring/characters/pirate1.jpg",
            text = "What are pirates, truly? Some are menacing thugs, as quick to shoot as they are to ask questions. Yet others are silly goofballs that any captain would be hard-pressed to take seriously. The truth lies somewhere between these extremes - that with a mass defection from the galactic economic order, people of all sorts are swept into piracy. Scholars posit that in fact the average faction citizen has more in common with the average pirate than with any faction executive or member of royalty.\nStill, the negative light cast by certain pirates is hard to escape, and there are little to no records of notable pirates willingly giving up a life in the shadows. In spite of the larger state of the galaxy providing ample reason for pirates to endure as a force, scholars wonder if there are other forces at play that keep such people stuck in this life.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_pirates") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Nescient",
            picture = "data/textures/ui/encyclopedia/exploring/characters/nescient.jpg",
            text = "nescient (NESS-ee-uhnt) adj.\n- Lack of knowledge or awareness: \\c(0d0)ignorance\\c()",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_nescient") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Spears of Adrasteia",
            picture = "data/textures/ui/encyclopedia/exploring/characters/spearsofadrasteia.jpg",
            text = "The \\c(0d0)Spears of Adrasteia\\c() are a small, independent mercenary fleet. Unlike most other mercenary fleets, they seem uninterested in contract work for the various galactic factions and hunt pirates with an almost single-minded ferocity. While they are cold and standoffish to neutral ships, the savagery and brutality that they show towards pirate crews is shocking. It is a common occurence for a \\c(0d0)Spears of Adrasteia\\c() warship to vaporize pirate ships that are attempting to surrender, killing all on board. There has been wild speculation across faction networks as to why the \\c(0d0)Spears of Adrasteia\\c() maintain a strict code of no quarter against pirate forces, but no clear answers have been forthcoming.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_spears") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Allison Vannier",
            picture = "data/textures/ui/encyclopedia/exploring/characters/allisonvannier.jpg",
            text = "Captain \\c(0d0)Allison Vannier\\c() is the commander of the \\c(0d0)Spears of Adrasteia\\c(). Not much is known about her past, and any inquiries pursued have quickly run into dead ends. She is a terse and aggressive woman, proficient with a wide variety of weapons and an expert ship commander. Despite her tactical and logistical acumen, she seems interested in little other than killing pirates. Her relatively recent emrgence has sparked large amounts of rumors and speculation. Who is she? Where could she have come from? And what happens when her interest in killing pirates finally wanes?",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_allison") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Pirate Jammer",
            picture = "data/textures/ui/encyclopedia/exploring/characters/piratejammer.jpg",
            text = "The jammer ship is a small vessel that has a significant technological overlap with the \\c(0d0)Hyperspace Blocker\\c() ships employed by \\c(0d0)The Galactic Bounty Hunters Guild\\c(). Jammers are equipped with a short-range hyperspace engine jammer, and are otherwise packed to the gills with ECM equipment. It is capable of almost completely masking a ship's radio and infrared readings, leaving visual confirmation as the only option for confirming the presence of an enemy ship. It is also capable of blocking inbound and outbound transmissions. The disadvantages of the jammer are twofold - first, it is extremely expensive to produce, meaning that it is an uncommon sight on galactic battlefields. The second is that it is quite fragile and tends to be under-armed compared to similarly sized military ships. Despite its flaws, the presence of a jammer is always cause for concern, as it means that the pirates are willing to commit a significant amount of resources to accomplishing their objective, and any ships caught by the jammer will have difficulties escaping.\nAt the time of writing, it is unknown how the pirates obtained the proprietary \\c(0d0)Hyperspace Blocker\\c() technology from the \\c(0d0)Bounty Hunters\\c().",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_jammer") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Hijacking Ship",
            picture = "data/textures/ui/encyclopedia/exploring/characters/hijackingship.jpg",
            text = "\\c(0d0)Boarding\\c() is a tactic seen infrequently among the factions, as they are typically rich enough to build as many ships as they need. It is a much more commonly used tactic among \\c(0d0)independent captains\\c(), who can run up against the limits of their resources or building knowledge. As a smaller mercenary fleet, the \\c(0d0)Spears of Adrasteia\\c() find themselves in a position closer to an \\c(0d0)independent captain\\c() than a faction. The \\c(0d0)Hijacking Ship\\c() contains numerous large hangar bays, as well as an ovesized crew quarters that can support over 1000 boarders if necessary. When the \\c(0d0)Spears of Adrasteia\\c() need a little extra edge, they're not above boarding a pirate ship and violently seizing it. From there, the ship is either refitted and joins the fleet, or sold off for parts and resources. Boarding actions by the \\c(0d0)Spears of Adrasteia\\c() are carried out without mercy, and it's not uncommon to see the corpses of several dozen pirates get jettisoned into space afterwards.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_hijacking") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Brute Gruznier",
            picture = "data/textures/ui/encyclopedia/exploring/characters/dagruzier.jpg",
            text = "\\c(0d0)Gruznier\\c() is \\c(0d0)Boss Xinull's\\c() top enforcer and right-hand man. He is well-known and feared for his heavy-handed tactics and approach to resolving problems for \\c(0d0)Xinull\\c(). A monstrous, four-limbed alien with a jutting skull and a muscular frame, he looks exactly how you'd expect someone's enforcer to appear. His ship of choice is a heavily modified and upgraded \\c(0d0)Firebrand class marine frigate\\c(). Changes made include reinforced armor, the addition of a shield generator, sensor suites, and external bridge, and various decorations strewn about the hull. It has an \\c(0d0)ultra-dense core\\c() that makes his ship far heavier than others of its class. Most importantly, however, are the extensive changes to the engine systems that allow them to be \\c(0d0)supercharged\\c() for short periods of time, allowing for incredible velocity and acceleration. \\c(0d0)Gruznier\\c() is known to take delight in smashing through the hull of other ships, whooping and cheering as the spikes on the front of his own ship pierce deep into the enemy's hull and the armored bulk of his ship tears his opponent to pieces. This behavior has earned him the \"\\c(0d0)Brute\\c()\" moniker.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_gruznier") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Boss Xinull",
            picture = "data/textures/ui/encyclopedia/exploring/characters/xinull.jpg",
            text = "\\c(0d0)Xinull\\c() is a ruthless and widely feared pirate that operates deep in the \\c(0d0)Trinium\\c() region of the galaxy. His bulbous head, bulging eyes, and tall, gangly frame, coupled with his sophisticated manner of speaking, give him an otherworldy aura. Pirates under his command frequently launch well-organized raids on multiple sectors at once, which enables them to successfully plunder systems while faction forces are distracted. \\c(0d0)Xinull\\c() is a harsh and demanding leader, frequently executing his subordinates for even trivial failures.\nHis ship is a modified \\c(0d0)Tesla Industries T3 Heavy Assault Destroyer\\c() that features numerous prototype upgrades. It has a \\c(0d0)Frenzy system\\c(), which slowly increases the power of the ship's weapons over time. It has an \\c(0d0)Avenger system\\c(), which boosts weapon output in response to the destruction of an allied ship. Defensively, it features a combination of an \\c(0d0)Adaptive Defender system\\c() and an \\c(0d0)Armor Booster system\\c(). These two systems work in tandem to make \\c(0d0)Xinull's\\c() armor partially absorb damage, and allows his ship to adapt to resist his enemy's most powerful weapons. As if this weren't enough, it also features a standard recharging shield booster and a \\c(0d0)ship cannibalizaton system\\c() based on the dangerous \\c(0d0)Xsotan Oppressor\\c(), which can eat other ships to boost its own power. All of these features together are \\c(0d0)somewhat unstable\\c(), however, and occasially a \\c(0d0)weak spot\\c() exposes itself where energy concentrates in the system. Damage to the \\c(0d0)weak spot\\c() will reset all of the associated systems. In addition, the overloaded systems tend to make his torpedo launchers function eratically.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_xinull") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Allison Vannier (cont'd)",
            picture = "data/textures/ui/encyclopedia/exploring/characters/allisonvannier2.jpg",
            text = "Further research has yielded additional information about the background of Captain \\c(0d0)Allison Vannier\\c(). A former human, her body shows signs of heavy genetic and surgical alteration. She was born into a family of ordinary means, and would have lived an unremarkable life if not for the fact that years ago she was abducted to serve in \\c(0d0)Xinull's crew\\c() while still a child. It is unknown why he chose to spare her - a combination of motives is theorized, including paternal ideation, reinforcement of control over his crews, and to have a dedicated attack dog. After attempting to adopt another being in the same manner that \\c(0d0)Xinull\\c() adopted her, \\c(0d0)Allison\\c() attempted to flee with the indivudal, only for the individual to be killed and \\c(0d0)Allison\\c() to be marooned in an asteroid belt. In the asteroid belt, she found an abandoned \\c(0d0)Nyi Roro class destroyer\\c() and was able to make rudimentary repairs. From there, she was able to return to civilized space and form the \\c(0d0)Spears of Adrasteia\\c().\nEver since then, she has been laser-focused on killing as many pirates as she can find. Even after killing \\c(0d0)Xinull\\c(), her goals don't seem to have shifted and she mercilessly hunts pirate crews to this day. This is considered fortunate, as faction analysis projects that the \\c(0d0)Spears of Adrasteia\\c() could pose a significant tactical threat despite the small size of their fleet. Her stints in civilized space do not last long as she is wanted for the violation of multiple humanitarian statutes, and she often sends new captains from the \\c(0d0)Spears of Adrasteia\\c() who are not yet wanted to conduct dealings in her stead.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_vbmn_allison2") then
                    return true
                else
                    return false
                end
            end
        }
    }
}
--0x656E6379636C6F706564696120636820454E44

--0x656E6379636C6F70656469612063682074626C20696E73
table.insert(category.chapters, vbmnchapter)