--Always add these.
if onClient() then

    local huntTheHunters_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        huntTheHunters_initialize()

        --General
        if self.GeneralShipChatter then
            --0x726164696F206368617474657220616C77617973205354415254
            --Hunt The Hunters
            table.insert(self.GeneralShipChatter, "Those bounty hunters, huh? They can dish it out but they can't take it.")
            table.insert(self.GeneralShipChatter, "... I heard the bounty hunters get super mad if someone turns the tables on them.")
            table.insert(self.GeneralShipChatter, "Getting paid to kill bounty hunters? I'll pass, thanks. Those guys are scary.")
            --0x726164696F206368617474657220616C7761797320454E44

            if random():test(0.05) then
                --0x726164696F2063686174746572203035706374205354415254
                --Hunt The Hunters
                table.insert(self.GeneralShipChatter, "I wanna be the hunter, not the hunted. I wanna be the killer, not the prey.")
                --0x726164696F206368617474657220303570637420454E44
            end
        end
    end
end