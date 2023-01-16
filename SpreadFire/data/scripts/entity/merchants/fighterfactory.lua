include ("weapontypeutility")

local spreadfireCannon_onCreatePressed = FighterFactory.onCreatePressed
function FighterFactory.onCreatePressed()
    local inventoryItem = turretSelection.selected
    if inventoryItem then
        local idx = inventoryItem.index
        local turret = Player():getInventory():find(idx)
        local tweapontype = legacyDetectWeaponType(turret)

        if tweapontype == WeaponType.SpreadFire then
            displayChatMessage("This weapon type cannot be used to create fighters.", "Fighter Factory"%_t, 1)
            return
        end
    end

    spreadfireCannon_onCreatePressed()
end