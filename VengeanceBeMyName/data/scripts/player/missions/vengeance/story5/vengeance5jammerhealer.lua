package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Vengeance5JammerHealer
Vengeance5JammerHealer = {}

Vengeance5JammerHealer._Debug = 0

function Vengeance5JammerHealer.initialize()
    local _MethodName = "Initialize"
    Vengeance5JammerHealer.Log(_MethodName, "Initializing... _RegenFactor is : 0.01")

    Vengeance5JammerHealer._Data = {}

    Vengeance5JammerHealer._Data._RegenFactor = 0.01
end

function Vengeance5JammerHealer.getUpdateInterval()
    return 2 --Update every 2 seconds.
end

function Vengeance5JammerHealer.updateServer(_TimeStep)
    local _MethodName = "Update Server"

    local pirates = { Sector():getEntitiesByScriptValue("_vbmn5_pirate") }
    
    local entity = Entity()
    if not entity.invincible and #pirates == 0 then --Only heal if there are no pirates.
        local entityHull = entity.durability
        local entityMaxHull = entity.maxDurability
    
        if entityHull < entityMaxHull then
            local restoreHull = entityMaxHull * Vengeance5JammerHealer._Data._RegenFactor
            Vengeance5JammerHealer.Log(_MethodName, "Entity hull of " .. tostring(entityHull) .. " is less than max of " .. tostring(entityMaxHull) .. " - healing for " .. tostring(restoreHull))
                
            entity.durability = math.min(entity.durability + restoreHull, entityMaxHull)

            broadcastInvokeClientFunction("animation")
        end
    else
        Vengeance5JammerHealer.Log(_MethodName, "Entity is invincible or pirates were present.")
    end
end

function Vengeance5JammerHealer.animation()
    Sector():createHyperspaceJumpAnimation(Entity(), random():getDirection(), ColorRGB(0.0, 1.0, 0.6), 0.2)
end

function Vengeance5JammerHealer.Log(_MethodName, _Msg)
    if Vengeance5JammerHealer._Debug == 1 then
        print("[Vengeance5JammerHealer] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

function Vengeance5JammerHealer.secure()
    return Vengeance5JammerHealer._Data
end

function Vengeance5JammerHealer.restore(_Values)
    Vengeance5JammerHealer._Data = _Values
end