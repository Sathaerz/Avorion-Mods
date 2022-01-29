TorpUtil = include("torpedoutility")

local _SubmunitionDamageFactor = 0.375
local _BaseAccelerationFactor = 12
local _KineticAccelerationFactor = 14
local _BaseTurnFactor = 2
local _KineticTurnFactor = 4

local HydraTorpedoes_makeTorpedoTooltip = makeTorpedoTooltip
function makeTorpedoTooltip(torpedo, other)
    local _Version = GameVersion()
    if TorpUtil.isHydra(torpedo.type) then
        if _Version.major <= 1 then
            return make138HydraTorpedoTooltip(torpedo, other)
        else
            return make200HydraTorpedoTooltip(torpedo, other)
        end
    else
        return HydraTorpedoes_makeTorpedoTooltip(torpedo, other)
    end
end

function make138HydraTorpedoTooltip(torpedo, other)
    -- create tool tip
    local tooltip = Tooltip()
    tooltip.icon = torpedo.icon

    -- title
    local title

    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = torpedo.name % _t % {warhead = torpedo.warheadClass % _t, speed = torpedo.bodyClass % _t}
    line.ccolor = torpedo.rarity.color
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 14
    local lineHeight = 20

    -- rarity name
    local line = TooltipLine(5, 12)
    line.ctext = tostring(torpedo.rarity)
    line.ccolor = torpedo.rarity.color
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 14
    local lineHeight = 20

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Tech" % _t
    line.rtext = torpedo.tech
    line.icon = "data/textures/icons/circuitry.png"
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    if torpedo.hullDamage > 0 and torpedo.damageVelocityFactor == 0 then
        local _TorpedoBaseDamage = toReadableValue(round(torpedo.hullDamage), "")
        local _TorpedoSubMunitionDamge = toReadableValue(round(torpedo.hullDamage * _SubmunitionDamageFactor), "")

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage" % _t
        line.rtext = _TorpedoBaseDamage .. " (" .. _TorpedoSubMunitionDamge .. "  x4)"
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor
        applyMoreBetter(
            line,
            torpedo,
            other,
            "hullDamage",
            0,
            (other and other.hullDamage > 0 and other.damageVelocityFactor == 0)
        )
        tooltip:addLine(line)
    elseif torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Damage" % _t
        line.rtext =
            "up to ${damage}" % _t %
            {damage = toReadableValue(round(torpedo.maxVelocity * torpedo.damageVelocityFactor), "")}
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor

        local a = {damage = round(torpedo.maxVelocity * torpedo.damageVelocityFactor)}
        local b = {}
        if other then
            b.damage = round(other.maxVelocity * other.damageVelocityFactor)
        end

        applyMoreBetter(
            line,
            a,
            b,
            "damage",
            nil,
            (other and not (other.hullDamage > 0 and other.damageVelocityFactor == 0) and other.damageVelocityFactor > 0)
        )
        tooltip:addLine(line)
    end

    if torpedo.shieldDamage > 0 and torpedo.shieldDamage ~= torpedo.hullDamage then
        local _TorpedoBaseShieldDamage = toReadableValue(round(torpedo.shieldDamage), "")
        local _TorpedoShieldSubMunitionDamge =
            toReadableValue(round(torpedo.shieldDamage * _SubmunitionDamageFactor), "")

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield Damage" % _t
        line.rtext = _TorpedoBaseShieldDamage .. " (" .. _TorpedoShieldSubMunitionDamge .. "  x4)"
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor
        applyMoreBetter(
            line,
            torpedo,
            other,
            "shieldDamage",
            0,
            (other and other.shieldDamage > 0 and other.shieldDamage ~= other.hullDamage)
        )
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- damage type
    if torpedo.damageType ~= DamageType.None then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Type" % _t
        line.rtext = getDamageTypeName(torpedo.damageType)
        line.rcolor = getDamageTypeColor(torpedo.damageType)
        line.lcolor = getDamageTypeColor(torpedo.damageType)
        line.icon = getDamageTypeIcon(torpedo.damageType)
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

    -- maneuverability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Maneuverability" % _t

    local _TurnFactor = _BaseTurnFactor
    if torpedo.type == 15 then
        _TurnFactor = _KineticTurnFactor
    end

    local _TorpedoBaseTurnSpeed = round(torpedo.turningSpeed, 2)
    local _TorpedoSubMunitionTurnSpeed = round(torpedo.turningSpeed * _TurnFactor, 2)

    line.rtext = _TorpedoBaseTurnSpeed .. " (" .. _TorpedoSubMunitionTurnSpeed .. ")"
    line.icon = "data/textures/icons/dodge.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "turningSpeed", 2, (other))
    tooltip:addLine(line)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Speed" % _t
    line.rtext = round(torpedo.maxVelocity * 10.0)
    line.icon = "data/textures/icons/speedometer.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "maxVelocity", 1, (other))
    tooltip:addLine(line)

    if torpedo.acceleration > 0 then
        local _Accelerationfactor = _BaseAccelerationFactor
        if torpedo.type == 15 then
            _Accelerationfactor = _KineticAccelerationFactor
        end

        local _TorpedoBaseAcceleration = round(torpedo.acceleration * 10.0)
        local _TorpedoSubMunitionAcceleration = round(torpedo.acceleration * 10.0 * _Accelerationfactor)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Acceleration" % _t
        line.rtext = _TorpedoBaseAcceleration .. " (" .. _TorpedoSubMunitionAcceleration .. ")"
        line.icon = "data/textures/icons/acceleration.png"
        line.iconColor = iconColor
        applyMoreBetter(line, torpedo, other, "acceleration", 1, (other and other.acceleration > 0))
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Range" % _t
    line.rtext = "${range} km" % {range = round(torpedo.reach * 10 / 1000, 2)}
    line.icon = "data/textures/icons/target-shot.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "reach", 1, (other))
    tooltip:addLine(line)

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Storage Energy" % _t
        line.rtext = toReadableValue(round(torpedo.storageEnergyDrain), "W")
        line.icon = "data/textures/icons/electric.png"
        line.iconColor = iconColor
        applyLessBetter(line, torpedo, other, "storageEnergyDrain", 0, (other))
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- size
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Size" % _t
    line.rtext = round(torpedo.size, 1)
    line.icon = "data/textures/icons/missile-pod.png"
    line.iconColor = iconColor
    applyLessBetter(line, torpedo, other, "size", 1, (other))
    tooltip:addLine(line)

    -- durability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Durability" % _t
    line.rtext = round(torpedo.durability)
    line.icon = "data/textures/icons/health-normal.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "durability", 0, (other))
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))
    tooltip:addLine(TooltipLine(15, 15))

    -- specialties
    local extraLines = 0

    if torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Dependent on Velocity" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldDeactivation then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Briefly Deactivates Shields" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.energyDrain then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Drains Target's Energy" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldPenetration then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Penetrates Shields" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldAndHullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damages Both Shield and Hull" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Requires Energy in Storage" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    tooltip:addLine(TooltipLine(15, 15))

    local _HydraLine = TooltipLine(lineHeight, fontSize)
    _HydraLine.ltext = "Splits into four sub-munitions after four seconds of flight time."

    local _HydraLine2 = TooltipLine(lineHeight, fontSize)
    _HydraLine2.ltext = "Sub-munition statistics are in parenthesis."

    tooltip:addLine(_HydraLine)
    tooltip:addLine(_HydraLine2)

    extraLines = extraLines + 2

    for i = 1, 3 - extraLines do
        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

    replaceFactionNames(tooltip)
    return tooltip
end

function make200HydraTorpedoTooltip(torpedo, other)
    -- create tool tip
    local tooltip = Tooltip()
    tooltip.icon = torpedo.icon
    tooltip.rarity = torpedo.rarity

    -- title
    local title

    local line = TooltipLine(headLineSize, headLineFont)
    line.ctext = torpedo.name%_t % {warhead = torpedo.warheadClass%_t, speed = torpedo.bodyClass%_t}
    line.ccolor = torpedo.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local fontSize = 13
    local lineHeight = 18

    -- rarity name
    local line = TooltipLine(5, 12)
    line.ctext = string.upper(tostring(torpedo.rarity))
    line.ccolor = torpedo.rarity.tooltipFontColor
    tooltip:addLine(line)

    -- primary stats, one by one
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Tech"%_t
    line.rtext = torpedo.tech
    line.icon = "data/textures/icons/circuitry.png";
    line.iconColor = iconColor
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    if torpedo.hullDamage > 0 and torpedo.damageVelocityFactor == 0 then
        local _TorpedoBaseDamage = toReadableValue(round(torpedo.hullDamage), "")
        local _TorpedoSubMunitionDamge = toReadableValue(round(torpedo.hullDamage * _SubmunitionDamageFactor), "")

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage" % _t
        line.rtext = _TorpedoBaseDamage .. " (" .. _TorpedoSubMunitionDamge .. "  x4)"
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor
        applyMoreBetter(
            line,
            torpedo,
            other,
            "hullDamage",
            0,
            (other and other.hullDamage > 0 and other.damageVelocityFactor == 0)
        )
        tooltip:addLine(line)
    elseif torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Hull Damage" % _t
        line.rtext =
            "up to ${damage}" % _t %
            {damage = toReadableValue(round(torpedo.maxVelocity * torpedo.damageVelocityFactor), "")}
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor

        local a = {damage = round(torpedo.maxVelocity * torpedo.damageVelocityFactor)}
        local b = {}
        if other then
            b.damage = round(other.maxVelocity * other.damageVelocityFactor)
        end

        applyMoreBetter(
            line,
            a,
            b,
            "damage",
            nil,
            (other and not (other.hullDamage > 0 and other.damageVelocityFactor == 0) and other.damageVelocityFactor > 0)
        )
        tooltip:addLine(line)
    end

    if torpedo.shieldDamage > 0 and torpedo.shieldDamage ~= torpedo.hullDamage then
        local _TorpedoBaseShieldDamage = toReadableValue(round(torpedo.shieldDamage), "")
        local _TorpedoShieldSubMunitionDamge =
            toReadableValue(round(torpedo.shieldDamage * _SubmunitionDamageFactor), "")

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Shield Damage" % _t
        line.rtext = _TorpedoBaseShieldDamage .. " (" .. _TorpedoShieldSubMunitionDamge .. "  x4)"
        line.icon = "data/textures/icons/screen-impact.png"
        line.iconColor = iconColor
        applyMoreBetter(
            line,
            torpedo,
            other,
            "shieldDamage",
            0,
            (other and other.shieldDamage > 0 and other.shieldDamage ~= other.hullDamage)
        )
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- damage type
    if torpedo.damageType ~= DamageType.None then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Type" % _t
        line.rtext = getDamageTypeName(torpedo.damageType)
        line.rcolor = getDamageTypeColor(torpedo.damageType)
        line.lcolor = getDamageTypeColor(torpedo.damageType)
        line.icon = getDamageTypeIcon(torpedo.damageType)
        line.iconColor = iconColor
        tooltip:addLine(line)

        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

    -- maneuverability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Maneuverability" % _t

    local _TurnFactor = _BaseTurnFactor
    if torpedo.type == 15 then
        _TurnFactor = _KineticTurnFactor
    end

    local _TorpedoBaseTurnSpeed = round(torpedo.turningSpeed, 2)
    local _TorpedoSubMunitionTurnSpeed = round(torpedo.turningSpeed * _TurnFactor, 2)

    line.rtext = _TorpedoBaseTurnSpeed .. " (" .. _TorpedoSubMunitionTurnSpeed .. ")"
    line.icon = "data/textures/icons/dodge.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "turningSpeed", 2, (other))
    tooltip:addLine(line)

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Speed" % _t
    line.rtext = round(torpedo.maxVelocity * 10.0)
    line.icon = "data/textures/icons/speedometer.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "maxVelocity", 1, (other))
    tooltip:addLine(line)

    if torpedo.acceleration > 0 then
        local _Accelerationfactor = _BaseAccelerationFactor
        if torpedo.type == 15 then
            _Accelerationfactor = _KineticAccelerationFactor
        end

        local _TorpedoBaseAcceleration = round(torpedo.acceleration * 10.0)
        local _TorpedoSubMunitionAcceleration = round(torpedo.acceleration * 10.0 * _Accelerationfactor)

        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Acceleration" % _t
        line.rtext = _TorpedoBaseAcceleration .. " (" .. _TorpedoSubMunitionAcceleration .. ")"
        line.icon = "data/textures/icons/acceleration.png"
        line.iconColor = iconColor
        applyMoreBetter(line, torpedo, other, "acceleration", 1, (other and other.acceleration > 0))
        tooltip:addLine(line)
    end

    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Range" % _t
    line.rtext = "${range} km" % {range = round(torpedo.reach * 10 / 1000, 2)}
    line.icon = "data/textures/icons/target-shot.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "reach", 1, (other))
    tooltip:addLine(line)

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Storage Energy" % _t
        line.rtext = toReadableValue(round(torpedo.storageEnergyDrain), "W")
        line.icon = "data/textures/icons/electric.png"
        line.iconColor = iconColor
        applyLessBetter(line, torpedo, other, "storageEnergyDrain", 0, (other))
        tooltip:addLine(line)
    end

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))

    -- size
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Size" % _t
    line.rtext = round(torpedo.size, 1)
    line.icon = "data/textures/icons/missile-pod.png"
    line.iconColor = iconColor
    applyLessBetter(line, torpedo, other, "size", 1, (other))
    tooltip:addLine(line)

    -- durability
    local line = TooltipLine(lineHeight, fontSize)
    line.ltext = "Durability" % _t
    line.rtext = round(torpedo.durability)
    line.icon = "data/textures/icons/health-normal.png"
    line.iconColor = iconColor
    applyMoreBetter(line, torpedo, other, "durability", 0, (other))
    tooltip:addLine(line)

    -- empty line
    tooltip:addLine(TooltipLine(15, 15))
    tooltip:addLine(TooltipLine(15, 15))

    -- specialties
    local extraLines = 0

    if torpedo.damageVelocityFactor > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damage Dependent on Velocity" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldDeactivation then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Briefly Deactivates Shields" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.energyDrain then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Drains Target's Energy" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldPenetration then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Penetrates Shields" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.shieldAndHullDamage then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Damages Both Shield and Hull" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    if torpedo.storageEnergyDrain > 0 then
        local line = TooltipLine(lineHeight, fontSize)
        line.ltext = "Requires Energy in Storage" % _t
        tooltip:addLine(line)

        extraLines = extraLines + 1
    end

    tooltip:addLine(TooltipLine(15, 15))

    local _HydraLine = TooltipLine(lineHeight, fontSize)
    _HydraLine.ltext = "Splits into four sub-munitions after four seconds of flight time."

    local _HydraLine2 = TooltipLine(lineHeight, fontSize)
    _HydraLine2.ltext = "Sub-munition statistics are in parenthesis."

    tooltip:addLine(_HydraLine)
    tooltip:addLine(_HydraLine2)

    extraLines = extraLines + 2

    for i = 1, 3 - extraLines do
        -- empty line
        tooltip:addLine(TooltipLine(15, 15))
    end

    replaceTooltipFactionNames(tooltip)
    return tooltip
end
