include ("weapontypeutility")

local helixCannon_onCreatePressed = FighterFactory.onCreatePressed
function FighterFactory.onCreatePressed()
    local inventoryItem = turretSelection.selected
    if inventoryItem then
        local _Buyer
        local _Player = Player()
        local _Ship = Sector():getEntity(_Player.craftIndex)
        if _Ship and _Ship.factionIndex == _Player.allianceIndex then
            _Buyer = _Player.alliance
        else
            _Buyer = _Player
        end

        local idx = inventoryItem.index
        local turret = _Buyer:getInventory():find(idx)
        local tweapontype = legacyDetectWeaponType(turret)

        if tweapontype == WeaponType.HelixCannon then
            displayChatMessage("This weapon type cannot be used to create fighters.", "Fighter Factory"%_t, 1)
            return
        end
    end

    helixCannon_onCreatePressed()
end