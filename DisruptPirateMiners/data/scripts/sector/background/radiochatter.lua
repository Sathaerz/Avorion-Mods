--Always add these.
if onClient() then

    local DisruptPirateMiners_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        DisruptPirateMiners_initialize()

        --General
        if self.GeneralShipChatter then
            --0x726164696F206368617474657220616C77617973205354415254
            --Disrupt Pirate Miners radio chatter
            table.insert(self.GeneralShipChatter, "I've heard of pirates running unlicensed mining operations as of late.")
            table.insert(self.GeneralShipChatter, "My sister commanded a ship that busted an illegal mining operation. She said their holds were bursting with ores.")
            table.insert(self.GeneralShipChatter, "Even if you take the ore from a pirate, it's still considered stolen. No good deed, huh?")
            --0x726164696F206368617474657220616C7761797320454E44

            if random():test(0.05) then
                --0x726164696F2063686174746572203035706374205354415254
                --Disrupt Pirate Miners radio chatter
                table.insert(self.GeneralShipChatter, "Tryna strike a chord and it's probably a minerrrrrr")
                --0x726164696F206368617474657220303570637420454E44
            end
        end
    end
end