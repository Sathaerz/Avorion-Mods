--Always add these.
if onClient() then

    local expandOperations_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        expandOperations_initialize()

        --General
        if self.GeneralShipChatter then
            --0x726164696F206368617474657220616C77617973205354415254
            --Expand Operations
            table.insert(self.GeneralShipChatter, "I hear the smugglers pay pretty well if you help them build up their base. The extra facilities are nice, too.")
            --0x726164696F206368617474657220616C7761797320454E44
        end
    end
end