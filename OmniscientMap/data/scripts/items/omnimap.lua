package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")
include("galaxy")

local toYesNo = function(line, value)
    if value then
        line.rtext = "Y E S"%_t
        line.rcolor = ColorRGB(0.3, 1.0, 0.3)
    else
        line.rtext = "No"%_t
        line.rcolor = ColorRGB(1.0, 0.3, 0.3)
    end

    return line
end

function create(item, rarity, factionIndex, hx, hy, x, y)

    item.name = "Omniscient Map"
    item.stackable = false
    item.depleteOnUse = true
    item.icon = "data/textures/icons/map-fragment.png"
    item.rarity = rarity
    item:setValue("subtype", "FactionMapSegment")
    item:setValue("factionIndex", factionIndex)

    local price = 0

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = item.name

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = rarity.tooltipFontColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Area"%_t
    line.icon = "data/textures/icons/map-fragment.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    line.rcolor = ColorRGB(0.3, 1.0, 0.3)

    line.rtext = "E V E R Y T H I N G"

    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Gate Network"%_t
    line.icon = "data/textures/icons/patrol.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, true))

    local line = TooltipLine(18, 14)
    line.ltext = "Additional Sectors"%_t
    line.icon = "data/textures/icons/diamonds.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, true))

    local line = TooltipLine(18, 14)
    line.ltext = "Sector Stations"%_t
    line.icon = "data/textures/icons/checklist.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(toYesNo(line, true))

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(20, 15)
    line.ltext = "Depleted on Use"%_t
    line.lcolor = ColorRGB(1.0, 1.0, 0.3)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be activated by the player"
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Unveils a A L L."
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "A chip T H A T  S E E S  E V E R Y T H I N G."
    line.lcolor = ColorRGB(0.4, 0.4, 0.4)
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function run(playerIndex)

    local FactoryPredictor = include ("factorypredictor")
    local SectorSpecifics = include ("sectorspecifics")
    local GatesMap = include ("gatesmap")

    local timer = HighResolutionTimer()
    timer:start()

    local gatesMap = GatesMap(GameSeed())

    local player = Player(playerIndex)

    local startX = -500
    local endX = 500
    local startY = -500
    local endY = 500

    -- print ("h: %i %i, s: %i %i, e: %i %i, q: %i", hx, hy, startX, startY, endX, endY, quadrant)

    local specs = SectorSpecifics()

    local seed = GameSeed()
    for x = startX, endX do
        for y = startY, endY do
            local regular, offgrid, dust = specs.determineFastContent(x, y, seed)

            if regular or offgrid then
                specs:initialize(x, y, seed)

                if specs.regular
                        and specs.generationTemplate
                        and (withOffgrid or specs.gates) then
                    local view = player:getKnownSector(x, y) or SectorView()

                    if not view.visited then
                        specs:fillSectorView(view, gatesMap, true)

                        player:updateKnownSectorPreserveNote(view)
                    end
                end
            end
            ::continuey::
        end
        ::continuex::
    end

    player:setValue("block_async_execution", nil)

    player:sendChatMessage("", ChatMessageType.Information, "A L L  I S  N O W  S E E N.")
end

function activate(item)

    local player = Player()

    if player:getValue("block_async_execution") then
        player:sendChatMessage("", ChatMessageType.Error, "Still updating.")
        return false
    end

    -- ensure that players don't start all their map updaters at once
    player:setValue("block_async_execution", true)

    asyncf("", "data/scripts/items/omnimap.lua", player.index)

    return true
end
