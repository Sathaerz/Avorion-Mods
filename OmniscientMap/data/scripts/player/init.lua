if onServer() then

    local player = Player()

    local _xValue = "got_omnimap"
    if not player:getValue(_xValue) then
        local _Item = UsableInventoryItem("omnimap.lua", Rarity(RarityType.Legendary))
        player:getInventory():addOrDrop(_Item)

        player:setValue(_xValue, true)
    end
end