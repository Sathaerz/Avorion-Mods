--Only add these if the player is far enough from the center
if onClient() then

    local koth_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        koth_initialize()

        local x, y = Sector():getCoordinates()
        local dist = length(vec2(x, y))

        --0x726164696F2063686174746572206469737420646566696E6974696F6E
        local koth_minDist = Balancing_GetBlockRingMax()
        --0x726164696F2063686174746572206469737420646566696E6974696F6E
        local koth_maxDist = koth_minDist + 25

        --0x726164696F20636861747465722063616D706169676E205354415254
        --KOTH Radio Chatter
        if self.GeneralShipChatter and dist > koth_minDist and dist < koth_maxDist then
            table.insert(self.GeneralShipChatter, "Do you ever wonder why the pirates don't use those reviving shielders? What's up with that?") --hansel / gretel
            table.insert(self.GeneralShipChatter, "I heard some mercenary asking around Quantum Xsotan the other day. He seemed really interested in the short-range jump system.") --xsologize
            table.insert(self.GeneralShipChatter, "The pirates out here have been using more sophisticated tactics lately. ... Do you think they're getting outside help?")
            table.insert(self.GeneralShipChatter, "Frostbite Company? They're a rough bunch, but I've heard you can usually trust them to do the right thing.")
            table.insert(self.GeneralShipChatter, "... why would a company that sells satellites kill anyone who asks questions about their line of business? You sound crazy.")

            if random():test(0.25) then
                table.insert(self.GeneralShipChatter, "My cousin's former roommate heard a rumor about salvaged Xsotan parts showing up on shady corporate freighters. That's creepy as hell if you ask me.")
            end

            if random():test(0.05) then
                --A nod to the fact that Varlance's name is a reference to Hans Maxwell Calder from FS2: Blue Planet.
                table.insert(self.GeneralShipChatter, "I heard he's descended from some admiral from Jupiter. ... What's 'Jupiter'?")
                --Sophie's name is a reference to Kyle Netreba (Also from FS2: Blue Planet)
                table.insert(self.GeneralShipChatter, "Netreba? I think I've heard that name before. Wasn't he an ancient warrior from Mars?")
            end
        end
        --0x726164696F20636861747465722063616D706169676E20454E44
    end
end