package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace Unreal
Unreal = {}
local self = Unreal

--The namespace is "Unreal" because this script was attached to unreal enemies.
self.phaseMode = false
self.timeInPhase = 0

function Unreal.getUpdateInterval()
    return 2 --Update every 2 seconds.
end

function Unreal.updateServer(timeStep)
    self.timeInPhase = self.timeInPhase + timeStep
    local entity = Entity()
    if entity.playerOwned or entity.allianceOwned then
        terminate()
        return
    end
    
    local shield = Shield(entity)
    local showAnimation = false
    local activeIronCurtain = entity:getValue("escc_active_ironcurtain")
    
    --1 minute out, 10 seconds in.
    if self.phaseMode then
        if not activeIronCurtain then
            entity.invincible = true
            shield.invincible = true
        end

        if self.timeInPhase >= 10 then
            --10 seconds have passed. Flip us to being OUT of the phaseMode.
            self.phaseMode = false
            self.timeInPhase = 0
        else
            --blink to give a visual indication of the ship being phased out.
            showAnimation = true
        end
    else
        if not activeIronCurtain then
            entity.invincible = false
            shield.invincible = false
        end

        if self.timeInPhase >= 30 then
            --30 seconds have passed. Flip us to being IN the phaseMode.
            self.phaseMode = true
            self.timeInPhase = 0
            
            showAnimation = true
        end
    end

    if showAnimation then
        local direction = random():getDirection()

        broadcastInvokeClientFunction("animation", direction)
    end
end

function Unreal.animation(direction)
    local _Sector = Sector()
    local _Version = GameVersion()
    if _Version.major > 1 then
        _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(0.0, 0.75, 1.0), 0.2)
    else
        _Sector:createHyperspaceAnimation(Entity(), direction, ColorRGB(0.0, 0.75, 1.0), 0.2)
    end
end