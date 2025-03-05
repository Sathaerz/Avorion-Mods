--Only add these if the player is far enough from the center
if onClient() then

    local lotw_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        lotw_initialize()

        local x, y = Sector():getCoordinates()
        local dist = length(vec2(x, y))

        --0x726164696F2063686174746572206469737420646566696E6974696F6E
        local lotw_maxdist = 430

        --0x726164696F20636861747465722063616D706169676E205354415254
        --LOTW Radio Chatter
        if self.GeneralShipChatter and dist > lotw_maxdist then
            table.insert(self.GeneralShipChatter, "I didn't think the pirates out here were well organized, but I guess I was wrong about that.")
            table.insert(self.GeneralShipChatter, "... what do you mean 'there's another pirate boss'? I didn't think Swoks had any influence this far out.")
            table.insert(self.GeneralShipChatter, "I've heard rumors of a highly organized pirate operation. But this far on the outskirts? Crazy.")
            table.insert(self.GeneralShipChatter, "... does he really call it 'the iron wastes'? We're civilized too, you know!")
            table.insert(self.GeneralShipChatter, "Our very own pirate boss! And I thought this area was too desolate for anything exciting to happen.")

            if random():test(0.25) then
                table.insert(self.GeneralShipChatter, "I overheard a pirate boasting about putting an Avenger System and an Iron Curtain on his ship the other day. The power draw must be insane - hope he's got a good reactor on board.")
            end

            if random():test(0.05) then
                table.insert(self.GeneralShipChatter, "They say he gets really angry if you compare him to Swoks.")
            end
        end
        --0x726164696F20636861747465722063616D706169676E20454E44
    end
end