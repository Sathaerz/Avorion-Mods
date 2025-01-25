package.path = package.path .. ";data/scripts/lib/story/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("stringutility")

ESCCUtil = include("esccutil")
MissionUT = include("missionutility")

function create(item, rarity, _Ally)

    local _Rgen = ESCCUtil.getRand()

    rarity = Rarity(RarityType.Legendary)

    item.stackable = false
    item.depleteOnUse = true
    item.name = "Superweapon Data Chip"
    item.price = 0
    item.icon = "data/textures/icons/bounty-chip.png"
    item.rarity = rarity
    item:setValue("subtype", "SuperweaponDataChip")
    item:setValue("factionIndex", _Ally)
    
    local _SWMT = _Rgen:getInt(1, 2) --Super Weapon Main Type - 1 is siege gun, 2 is laser
    local _SWSW = _Rgen:getInt(1, 2) --Super Weapon Secondary Weapons - 1 is mega lasers, 2 is hyper seekers (if siege) / velocity cannons (if lasers).

    item:setValue("_SWMT", _SWMT)
    item:setValue("_SWSW", _SWSW)

    local tooltip = Tooltip()
    tooltip.icon = item.icon

    local title = "Superweapon Data Chip"

    local headLineSize = 25
    local headLineFontSize = 15
    local line = TooltipLine(headLineSize, headLineFontSize)
    line.ctext = title
    line.ccolor = item.rarity.color
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(14, 14))

    local line = TooltipLine(18, 14)
    line.ltext = "This appears to contain data laying out the schematics of a powerful superweapon."
    tooltip:addLine(line)

    local _WeaponTypeMSG = ""
    if _SWMT == 1 then
        _WeaponTypeMSG = "a siege cannon"
    else
        _WeaponTypeMSG = "a shipkiller laser"
    end

    local _SWeaponTypeMSG = ""
    if _SWSW == 1 then
        _SWeaponTypeMSG = "high-focus lasers"
    else
        if _SWMT == 1 then
            _SWeaponTypeMSG = "seeker missiles"
        else
            _SWeaponTypeMSG = "high-velocity cannons"
        end
    end

    line.ltext = "The superweapon appears to be equipped with a " .. _WeaponTypeMSG .. " and a battery of " .. _SWeaponTypeMSG .. "."
    tooltip:addLine(line)
    line.ltext = "This chip also appears to contain extensive data on the superweapon's subspace emissions "
    tooltip:addLine(line)
    line.ltext = "and hyperspace profile. Using this, you should be able to track it down."
    tooltip:addLine(line)

    item:setTooltip(tooltip)

    return item
end

function activate(item)

    if onServer() then
        local _Player = Player()
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        local _Data_in = {}
        _Data_in.friendlyFaction = item:getValue("factionIndex")
        _Data_in.superweaponMain = item:getValue("_SWMT")
        _Data_in.superweaponSecondary = item:getValue("_SWSW")

        local _MX, _MY = MissionUT.getSector(_X, _Y, 20, 50, false, false, false, false, true)
        if _MX and _MY then
            local _Target = {}
            _Target.x = _MX
            _Target.y = _MY
            _Data_in.location = _Target
        else
            _Player:sendChatMessage("", ChatMessageType.Information, "No response.")
            return false
        end

        --Only one of this mission at a time, bucko.
        _Player:removeScript("data/scripts/player/missions/destroysuperweapon.lua")
        _Player:addScript("data/scripts/player/missions/destroysuperweapon.lua", _Data_in)
    end

    return true
end