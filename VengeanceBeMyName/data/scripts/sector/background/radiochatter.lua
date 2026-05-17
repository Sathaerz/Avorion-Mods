--Only add these if the player is far enough from the center
if onClient() then

    local vbmn_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        vbmn_initialize()

        local x, y = Sector():getCoordinates()
        local dist = length(vec2(x, y))

        local vbmn_minDist = 210
        local vbmn_maxDist = 270

        --VBMN Radio Chatter
        if self.GeneralShipChatter and dist > vbmn_minDist and dist < vbmn_maxDist then
            table.insert(self.GeneralShipChatter, "I got attacked by pirates yesterday. A black and red ship showed up and destroyed all of them, then left without saying anything.")
            table.insert(self.GeneralShipChatter, "There were two black and red ships parked next to the pirate ship. I'm going to have nightmares about the screams we heard over the radio...")
            table.insert(self.GeneralShipChatter, "... they say she's hellbent on killing pirates.")
            table.insert(self.GeneralShipChatter, "At the last station we stopped at, there was a captain asking about any pirates in the area. I'm glad I'm not a pirate - she was scary!")
            table.insert(self.GeneralShipChatter, "Did you hear about the pirate outpost that got attacked? My cousin said it was creepy as hell - not a single survivor.")

            if random():test(0.25) then
                table.insert(self.GeneralShipChatter, "She's got horns? What is she, some sort of space demon? I'd believe it with how merciless her reputation is.")
            end

            if random():test(0.05) then
                table.insert(self.GeneralShipChatter, "I've never seen a male captain from the Spears of Adrasteia, but they don't say that men can't join... that's a little suspicious, don't you think?")
            end
        end
    end
end