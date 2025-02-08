--Always add these.
if onClient() then

    local Annihilatorium_initialize = RadioChatter.initialize
    function RadioChatter.initialize()
        Annihilatorium_initialize()

        --General
        if self.GeneralShipChatter then
            table.insert(self.GeneralShipChatter, "... An 'Annihilatorium'? Is that like... where you send things to be annihilated?")
            table.insert(self.GeneralShipChatter, "My buddy tried the Master of the Arena challenge and lost his ship on the first wave.")
            table.insert(self.GeneralShipChatter, "My cousin tried fighting at the Annihilatorium. She made it to wave 30 before her ship got blown up by a Juggernaut Pillager.")
            table.insert(self.GeneralShipChatter, "They make you fight fifty waves? Wow! That sounds like a huge grind.")
            table.insert(self.GeneralShipChatter, "... I heard there's over thirty different kinds. The fact that there's that many out there is terrifying.")

            if random():test(0.25) then
                table.insert(self.GeneralShipChatter, "I thought I'd never see an Executioner again after Increasing Threat. How did they get so many for what's basically a circus?")
            end
        end
    end
end