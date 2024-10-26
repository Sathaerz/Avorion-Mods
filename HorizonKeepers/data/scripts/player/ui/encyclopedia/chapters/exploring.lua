kothchapter = {
    title = "KOTH: Characters",
    articles = {
        {
            title = "Frostbite Company",
            picture = "data/textures/ui/encyclopedia/exploring/characters/frostbitecompany.jpg",
            text = "\\c(0d0)Frostbite Company\\c() is a mercenary fleet under the leadership of Captain \\c(0d0)Varlance Calder\\c().\nThey take care of odd jobs for the various factions around the galaxy, doing the dirty work that nobody else is willing or able to do. While their ships aren't anything particularly impressive technologically, a combination of fearless leadership and tried-and-true tactics have made \\c(0d0)Frostbite Company\\c() a force to be reckoned with. The group has recently made a name for themselves busting several of the larger pirate operations around the galaxy.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_frostbite") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Varlance Calder",
            picture = "data/textures/ui/encyclopedia/exploring/characters/varlance.jpg",
            text = "\\c(0d0)Varlance Calder\\c() is the stoic and fearless leader of Frostbite Company.\nWhile he is widely considered to be standoffish and cold, he's also fair - this lets him have a good working relationship with his subordinate officers in \\c(0d0)Frostbite Company\\c(). \\c(0d0)Varlance\\c() got his start working as a captain for a mercenary fleet, but quickly became disillusioned with the trail of death and destruction his fleet tore through the galaxy. After two long years of service, he broke off to form \\c(0d0)Frostbite Company\\c(), where he could operate as he pleased - fighting for the sake of the powerless instead of massacring them wholesale. With over ten years of experience leading \\c(0d0)Frostbite Company\\c() into battle, there are few situations he's not ready to handle.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_varlance") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Horizon Keepers, LTD.",
            picture = "data/textures/ui/encyclopedia/exploring/characters/horizonltd.jpg",
            text = "A shady and powerful company that seems to have an interest in the \\c(0d0)Xsotan\\c().\n\\c(0d0)Horizon Keepers, LTD.\\c() is a large, multi-system corporation in the galaxy. Their public facing front is selling probes, radar units, and other sensory equipments for ships and stations. Rumors abound about their other lines of business - anything from selling superliminal performance enhancing drugs to illegal humnan experimentation to hiring out hit squads. Anyone who starts asking questions about their other lines of business quickly finds their inquiries lead to many dead ends. Sometimes in a dead inquirer. However, it doesn't take too much digging to know that they frequently hire \\c(0d0)pirates\\c() to ensure their business interests.\n\nThe ships in their main battle fleet are built using the \\c(0d0)T 1.0 line\\c() of modular parts from \\c(0d0)TESLA Industries\\c().",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_horizonkeepers") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Hansel and Gretel",
            picture = "data/textures/ui/encyclopedia/exploring/characters/hanselgretel.jpg",
            text = "A pair of prototype weapons designed and deployed by \\c(0d0)Horizon Keepers, LTD.\\c() in reponse to Frostbite Company and an independent captain crushing their main battle fleet. The \\c(0d0)Hansel\\c() features a \\c(0d0)powerful point-defense system\\c() capable of shooting torpedoes down at an extraordinary rate and distance, while the \\c(0d0)Gretel\\c() is fitted with a \\c(0d0)powerful shield booster\\c() that can continuously replenish its shields, even under the harshest of punishment. It also features a \\c(0d0)LONGINUS\\c()-type laser. Both ships are equipped with prototype plasma mortars and long-range heavy cannons.\n\nUnlike the standard Horizon Keepers ships, these weapons were built using the \\c(0d0)T 2.0 line\\c() of modular parts from \\c(0d0)TESLA Industries\\c().",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_hanselgretel") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Torpedo Loaders",
            picture = "data/textures/ui/encyclopedia/exploring/characters/torpedoloaders.jpg",
            text = "Originally pioneered by The \\c(0d0)Cavaliers\\c(), the \\c(0d0)Torpedo Loader\\c() is a specialized ship containing large ordinance bays and a \\c(0d0)high-speed transfer system\\c() that is capable of quickly loading a ship's torpedo tubes and hold with torpedoes of a selected type. \\c(0d0)Frostbite Company\\c() got their hands on several of the proprietary loading systems and have since been fielding torpedo loaders of their own. While the loaders themselves tend to be slow and vulnerable, proper deployment ensures that a fleet of ships will stay well-supplied with munitions even in a prolonged engagement.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_torploader") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Sophie Netreba",
            picture = "data/textures/ui/encyclopedia/exploring/characters/sophie.jpg",
            text = "\\c(0d0)Sophie Netreba\\c() is \\c(0d0)Varlance\\c()'s executive officer and right-hand woman.\nWhere \\c(0d0)Varlance\\c() is stoic and standoffish, \\c(0d0)Sophie\\c() is warm and energetic. The two of them compliment each other well, and have a solid professional relationship. \\c(0d0)Sophie\\c() has proven her worth time and time again, ensuring that the operations of \\c(0d0)Frostbite Company\\c() are smooth and seamless as the fleet hops between pirate busts. She studied advanced computational technology for several years before her work as a mercenary, eventually dropping out of her studies because it \"didn't hold [her] interest.\"",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_sophie") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "Project XSOLOGIZE",
            picture = "data/textures/ui/encyclopedia/exploring/characters/xsologize.jpg",
            text = "A powerful prototype vessel designed and deployed by \\c(0d0)Horizon Keepers, LTD.\\c() in their ambitions of galactic conquest. The \\c(0d0)XSOLOGIZE\\c() is an old Xsotan ship that has been loaded with a number of highly advanced modules, including the terrifying \\c(0d0)HIEROPHANT system\\c(). The \\c(0d0)HIEROPHANT\\c() pulls local pirates out of subspace via a wormhole contaminated with Xsotan material. It then fires a secondary beam that activates the latent Xsotan infection and subverts control of the ship, overcharging its jump capacitors and allowing it to make a few short-range jumps before they are burned out. The \\c(0d0)HIEROPHANT\\c() is also capable of reanimating destroyed ships via rejuvinating Xsotan infection. Much like the \\c(0d0)Gretel\\c(), the \\c(0d0)XSOLOGIZE\\c() also features a \\c(0d0)LONGINUS\\c()-type laser.\n\nBut perhaps the most dangerous module of all is the advanced \\c(0d0)QUANTUM\\c() system, which allows the ship to rapidly execute a series of short-range jumps when struck by weapons fire similar to \\c(0d0)QUANTUM\\c() type Xsotan. By comparison, its armament of plasma mortars and standard cannons seems almost quaint. The massive amount of technology present on the ship is a delicate balancing act, and it is prone to electrical overloads and short-circuiting. The \\c(0d0)QUANTUM\\c() system is especially vulnerable.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_xsologize") then
                    return true
                else
                    return false
                end
            end
        },
        {
            title = "01Macedon",
            picture = "data/textures/ui/encyclopedia/exploring/characters/01macedon.jpg",
            text ="\\c(0d0)Alexander \"Mace\" Laporte\\c() is a skilled hacker. Cautious almost to the point of paranoia, they prefer to work behind the scenes when possible.\nSeveral years ago, \\c(0d0)Varlance\\c() met \\c(0d0)Mace\\c() when he needed a hacker to run a penetration test of a major corporation. After discovering that the company was issuing scrip that the employees would be forced to redeem at a company-owned station rather than paying the employees universal credits, \\c(0d0)Varlance\\c() decided to turn the penetration test into an actual cyberattack over \\c(0d0)Mace\\c()'s objections. The job went off without a hitch and the company was completely ruined, but \\c(0d0)Mace\\c() was forced into hiding for a year afterwards to evade the persecutors hired by the angry ex-CEOs. They prefer to go by their online handle \\c(0d0)01Macedon\\c() (or just \\c(0d0)\"Mace\"\\c()) when possible.",
            isUnlocked = function()
                if Player():getValue("encyclopedia_koth_01macedon") then
                    return true
                else
                    return false
                end
            end
        }
    }
}

table.insert(category.chapters, kothchapter)