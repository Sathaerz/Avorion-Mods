package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Unreal
Unreal = {}
local self = Unreal

--The namespace is "Unreal" because this script was attached to unreal enemies.
self.phaseMode = false
self.timeInPhase = 0

self._Debug = 0

function Unreal.initialize()
    if onServer() then
        Entity():setValue("SDKExtendedShieldsDisabled", true) --Need to disable SDK extended docking shields.
    end
end

function Unreal.getUpdateInterval()
    return 2 --Update every 2 seconds.
end

function Unreal.updateServer(timeStep)
    local _MethodName = "Update Server"

    self.timeInPhase = self.timeInPhase + timeStep
    local entity = Entity()
    local shield = Shield(entity)
    local showAnimation = false
    local activeIronCurtain = entity:getValue("escc_active_ironcurtain")
    --1 minute out, 10 seconds in.
    if self.phaseMode then
        if not activeIronCurtain then
            --In phasemode and no iron curtain active - set ship to invincible.
            entity.invincible = true
            shield.invincible = true
        end

        if self.timeInPhase >= 10 then
            --10 seconds have passed. Flip us to being OUT of the phaseMode.
            self.Log(_MethodName, "Exiting PhaseMode")
            self.phaseMode = false
            self.timeInPhase = 0
        else
            --blink to give a visual indication of the ship being phased out.
            showAnimation = true
        end
    else
        if not activeIronCurtain then
            --Not in phasemode and no iron curtain active - ship is no longer invincible.
            entity.invincible = false
            shield.invincible = false
        end

        if self.timeInPhase >= 30 then
            --30 seconds have passed. Flip us to being IN the phaseMode.
            self.Log(_MethodName, "Entering PhaseMode")
            self.phaseMode = true
            self.timeInPhase = 0
            
            showAnimation = true
        end
    end
    self.Log(_MethodName, "Enity invincibility is : " .. tostring(entity.invincible))

    if showAnimation then
        local direction = random():getDirection()

        broadcastInvokeClientFunction("animation", direction)
    end
end

function Unreal.animation(direction)
    Sector():createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(0.0, 0.75, 1.0), 0.2)
end

function Unreal.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[PhaseMode] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end