--Always add these.
if onClient() then

    local CollectPirateBounty_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        CollectPirateBounty_initialize()

        --General
        if self.GeneralShipChatter then
            --0x726164696F206368617474657220616C77617973205354415254
            --Collect Pirate Bounty radio chatter
            table.insert(self.GeneralShipChatter, "I've heard some pirates will put out a bounty on captains that hunt them.")
            --0x726164696F206368617474657220616C7761797320454E44
        end
    end
end