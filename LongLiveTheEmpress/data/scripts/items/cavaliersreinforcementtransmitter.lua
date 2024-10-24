package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")
MissionUT = include("missionutility")

local ShipGenerator = include("shipgenerator")
local SpawnUtility = include ("spawnutility")

function create(item, rarity, allyIndex)
    --print("Creating item.")

    --This HAS to be exceptional, or it's not possible to buy it from the Cavaliers.
    rarity = Rarity(RarityType.Exceptional)

    --print("Found faction - setting tooltip.")

    item.stackable = false
    item.depleteOnUse = false
    item.name = "Cavaliers Reinforcements Transmitter"
    item.price = 12000000
    item.icon = "data/textures/icons/firing-ship.png"
    item.iconColor = rarity.color
    item.rarity = rarity
    item:setValue("subtype", "ReinforcementsTransmitter")
    item:setValue("factionIndex", allyIndex)

    local tooltip = Tooltip()
    tooltip.icon = item.icon
    tooltip.rarity = rarity

    local title = "Cavaliers Reinforcements Transmitter"

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = item.rarity.color
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Ally"
    line.rtext = "${faction:"..allyIndex.."}"
    line.icon = "data/textures/icons/flying-flag.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Ships"
    line.rtext = "5 - 7"
    line.icon = "data/textures/icons/ship.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Cooldown"
    line.rtext = "1h"
    line.icon = "data/textures/icons/recharge-time.png"
    line.iconColor = ColorRGB(0.8, 0.8, 0.8)
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "Can be activated by the player"
    tooltip:addLine(line)

    local line = TooltipLine(18, 14)
    line.ltext = "Calls in reinforcements from The Cavaliers"
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    --print("Tooltip set.")

    return item
end

function activate(item)
    -- check if the faction is in reach
    local _Player = Player()
    local allyIndex = item:getValue("factionIndex")
    if not allyIndex then
        _Player:sendChatMessage("", ChatMessageType.Information, "No response.")
        return false
    end

    local faction = Faction(allyIndex)
    if not faction then
        _Player:sendChatMessage("", ChatMessageType.Information, "No response.")
        return false
    end

    if not faction.isAIFaction then
        _Player:sendChatMessage("", ChatMessageType.Information, "No response.")
        return false
    end

    local sender = "The Cavaliers"

    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()

    local _Rank = _Player:getValue("_llte_cavaliers_ranklevel")
    local _PlayerInBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)
    local _CavsInBarrier = _Player:getValue("_llte_cavaliers_inbarrier")

    if _Rank < 2 then
        _Player:sendChatMessage(sender, ChatMessageType.Normal, "We only send out combat support to those who have proven themselves to us.")
        return false
    end

    if _PlayerInBarrier and not _CavsInBarrier then
        _Player:sendChatMessage(sender, ChatMessageType.Normal, "We can't send reinforcements to you!")
        return false
    end

    local craft = _Player.craft
    if not craft then
        _Player:sendChatMessage(sender, ChatMessageType.Error, "You must be in a ship to use this!")
        return false
    end

    local key = "reinforcements_requested_" .. faction.index
    local timeStamp = _Player:getValue(key)
    local now = Server().unpausedRuntime

    if timeStamp then
        local ago = now - timeStamp
        local wait = 60 * 60

        if ago < wait then
            _Player:sendChatMessage(sender, ChatMessageType.Normal, "We can't send out reinforcements that quickly again! You'll have to wait another %i minutes!", math.ceil((wait - ago)/60))
            return false
        end
    end

    _Player:setValue(key, now)

    local position = craft.translationf

    -- let the backup spawn behind the player
    local dir = normalize(normalize(position) + vec3(0.01, 0.0, 0.0))
    local pos = position + dir * 750
    local up = vec3(0, 1, 0)
    local look = -dir

    local right = normalize(cross(dir, up))

    local _Rgen = ESCCUtil.getRand()

    local _ShipsToSend = _Rgen:getInt(5, 7)
    --always add 3x defenders and 2x heavy defenders.
    local ships = {}
    table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos)))
    table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 100)))
    table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 100)))
    table.insert(ships, ShipGenerator.createHeavyDefender(faction, MatrixLookUpPosition(look, up, pos + right * 200)))
    table.insert(ships, ShipGenerator.createHeavyDefender(faction, MatrixLookUpPosition(look, up, pos - right * 200)))
    if _ShipsToSend >= 6 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos + right * 300)))
    end
    if _ShipsToSend >= 7 then
        table.insert(ships, ShipGenerator.createDefender(faction, MatrixLookUpPosition(look, up, pos - right * 300)))
    end

    SpawnUtility.addEnemyBuffs(ships)

    local _EnemyEntities = {_Sector:getEnemies(_Player.index)}

    for _, ship in pairs(ships) do
        local _ShipAI = ShipAI(ship)
        for _, enemy in pairs(_EnemyEntities) do
            if enemy.factionIndex then
                _ShipAI:registerEnemyFaction(enemy.factionIndex)
            end
        end

        local _WithdrawData = {
            _Threshold = 0.15
        }

        ship.title = "Cavaliers " .. ship.title
        MissionUT.deleteOnPlayersLeft(ship)
        ship:addScript("ai/withdrawatlowhealth.lua", _WithdrawData)
        ship:removeScript("antismuggle.lua")
        LLTEUtil.rebuildShipWeapons(ship, _Player:getValue("_llte_cavaliers_strength"))
        ship:setValue("npc_chatter", nil)
        ship:setValue("is_cavaliers", true)

        _ShipAI:setAggressive()
    end

    return true
end
