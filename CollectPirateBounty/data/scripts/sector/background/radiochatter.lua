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
            table.insert(self.GeneralShipChatter, "... I heard some captain whining about constant bounty hunter attacks the other day. I guess he didn't know they'd stop if he abandoned the contract.")
            table.insert(self.GeneralShipChatter, "Getting paid for killing pirates? If I was gonna do that anyways it's basically free money right?")
            --0x726164696F206368617474657220616C7761797320454E44
        end
    end
end