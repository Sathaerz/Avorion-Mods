package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("randomext")

function create(item, rarity)
    local _rarity = Rarity(RarityType.Exotic)
    local _rarity2 = Rarity(RarityType.Uncommon)
    
    item.stackable = false
    item.depleteOnUse = true
    item.droppable = false
    item.tradeable = false
    item.missionRelevant = true
    item.name = "Pirate Map"
    item.price = 0
    item.icon = "data/textures/icons/map-fragment.png"
    item.iconColor = _rarity2.color
    item.rarity = _rarity
    item:setValue("subtype", "VbmnStoryPirateMap")

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.borderColor = _rarity.color
    tooltip.rarity = _rarity2

    local title = "Pirate Map"

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = _rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "A map of local star systems. Contains several different coordinates."
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)
    Player():sendCallback("_vbmn8_read_map")
    
    return true
end