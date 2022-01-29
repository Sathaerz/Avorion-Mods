package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

TorpUtil = include("torpedoutility")

--namespace HydraController
HydraController = {}
local self = HydraController

self._Debug = 0

self._Torpedoes = {}
self._SubmunitionDamageFactor = 0.375
self._BaseAccelerationFactor = 12
self._KineticAccelerationFactor = 14
self._BaseTurnFactor = 2
self._KineticTurnFactor = 4

function HydraController.initialize()
    local _MethodName = "Initialize"
    
    self.Log(_MethodName, "Hydra Controller v46 Initialized")
    if onServer() then
        Entity():registerCallback("onTorpedoLaunched", "onTorpedoLaunched")
    end
end

function HydraController.getUpdateInterval()
    return 1
end

--region #ONUPDATE

function HydraController.updateServer(_TimeStep)
    local _MethodName = "Update Server"

    for _TorpedoID, _ in pairs(self._Torpedoes) do
        self.Log(_MethodName, "Updating torpedo ID " .. tostring(_TorpedoID))
        local _FuseTime = self._Torpedoes[_TorpedoID]
        _FuseTime = _FuseTime - _TimeStep

        --Check if the torpedo is valid.
        local _Torpedo = Torpedo(_TorpedoID)
        if valid(_Torpedo) then
            --If it is, we update the fuse time.
            if _FuseTime <= 0 then
                self.Log(_MethodName, "Torpedo fuse expired - destroying and creating smaller warheads.")
                self._Torpedoes[_TorpedoID] = nil
                HydraController.launchHydras(_TorpedoID)
            else
                self._Torpedoes[_TorpedoID] = _FuseTime
            end
        else
            --If it isn't, we clear it from the list.
            self.Log(_MethodName, "Torpedo is no longer valid - clearing it from the list.")
            self._Torpedoes[_TorpedoID] = nil
        end
    end
end

--endregion

--region #CALLBACKS

function HydraController.onTorpedoLaunched(_EntityID, _TorpedoID)
    local _MethodName = "On Torpedo Fired"

    local _TorpedoType = Torpedo(_TorpedoID):getTemplate().type

    self.Log(_MethodName, "Torpedo fired! - type is " .. tostring(_TorpedoType))
    if TorpUtil.isHydra(_TorpedoType) then
        --11 through 20 are Hydra warheads. 31 is a Hydra warhead if Napalm Torpedoes is installed.
        self.Log(_MethodName, "Hydra Torpedo fired - adding fuse.")
        self._Torpedoes[_TorpedoID] = 4
    end
end

--endregion

--region #SERVER FUNCTIONS

function HydraController.launchHydras(_TorpedoID)
    local _MethodName = "Launch Hydras"

    local _CurrentTorpEntity =       Entity(_TorpedoID)
    local _CurrentTorp =             Torpedo(_TorpedoID)
    local _CurrentTorpTemplate =     _CurrentTorp:getTemplate()
    local _CurrentTorpAI =           TorpedoAI(_TorpedoID)
    local _CurrentTorpOwner =        Owner(_TorpedoID)
    local _CurrentTorpFlight =       DirectFlightPhysics(_TorpedoID)
    local _CurrentTorpDura =         Durability(_TorpedoID)
    local _CurrentTorpVelocity =     Velocity(_TorpedoID)

    local _Sector = Sector()

    --Edit properties of current torp template to make it a Hydra warhead.
    _CurrentTorpTemplate.type = TorpUtil.getStandardWarhead(_CurrentTorpTemplate.type)
    _CurrentTorpTemplate.prefix = TorpUtil.getWarheadNameByType(_CurrentTorpTemplate.type)
    local _AccelerationFactor = self._BaseAccelerationFactor
    local _TurnFactor = self._BaseTurnFactor
    if _CurrentTorpTemplate.type == 5 then --Kinetic torpedoes get better acceleration / turn rates to make up for the fact that they need to reaccelerate to do damage.
        _AccelerationFactor = self._KineticAccelerationFactor
        _TurnFactor = self._KineticTurnFactor
    end
    _CurrentTorpTemplate.acceleration = _CurrentTorpTemplate.acceleration * _AccelerationFactor
    _CurrentTorpTemplate.hullDamage = _CurrentTorpTemplate.hullDamage * self._SubmunitionDamageFactor
    _CurrentTorpTemplate.shieldDamage = _CurrentTorpTemplate.shieldDamage * self._SubmunitionDamageFactor

    self.Log(_MethodName, "Name : " .. _CurrentTorpTemplate.name)
    self.Log(_MethodName, "Pfx : " .. _CurrentTorpTemplate.prefix)
    self.Log(_MethodName, "Type : " .. tostring(_CurrentTorpTemplate.type))
    self.Log(_MethodName, "vsHull : " .. tostring(_CurrentTorpTemplate.hullDamage))
    self.Log(_MethodName, "vsShield : " .. tostring(_CurrentTorpTemplate.shieldDamage))
    self.Log(_MethodName, "velFactor : " .. tostring(_CurrentTorpTemplate.damageVelocityFactor))

    local _PosAdj = {}
    local _Adj = 11
    _PosAdj[1] = vec3(_Adj, 0, 0)
    _PosAdj[2] = vec3(_Adj*-1, 0, 0)
    _PosAdj[3] = vec3(0, _Adj, 0)
    _PosAdj[4] = vec3(0, _Adj*-1, 0)

    for idx = 1, 4 do 
        local _NewTorpDesc =    TorpedoDescriptor()
        local _NewTorpAI =      _NewTorpDesc:getComponent(ComponentType.TorpedoAI)
        local _NewTorp =        _NewTorpDesc:getComponent(ComponentType.Torpedo)
        local _NewTorpVel =     _NewTorpDesc:getComponent(ComponentType.Velocity)
        local _NewTorpOwn =     _NewTorpDesc:getComponent(ComponentType.Owner)
        local _NewTorpFlight =  _NewTorpDesc:getComponent(ComponentType.DirectFlightPhysics)
        local _NewTorpDura =    _NewTorpDesc:getComponent(ComponentType.Durability)

        _NewTorpAI.target = _CurrentTorpAI.target
        _NewTorp.intendedTargetFaction = _CurrentTorp.intendedTargetFaction

        _NewTorpAI.driftTime = _CurrentTorpAI.driftTime

        local _Out = _CurrentTorpEntity.position
        _Out.position = _Out.position + _PosAdj[idx]

        _NewTorpDesc.position = _Out

        _NewTorp.shootingCraft = _CurrentTorp.shootingCraft
        _NewTorp.firedByAIControlledPlayerShip = _CurrentTorp.firedByAIControlledPlayerShip
        _NewTorp.collisionWithParentEnabled = _CurrentTorp.collisionWithParentEnabled
        _NewTorp:setTemplate(_CurrentTorpTemplate)

        _NewTorpOwn.factionIndex = _CurrentTorpOwner.factionIndex

        _NewTorpFlight.drifting = _CurrentTorpFlight.drifting    
        _NewTorpFlight.maxVelocity = _CurrentTorpFlight.maxVelocity
        _NewTorpFlight.turningSpeed = _CurrentTorpFlight.turningSpeed * _TurnFactor --Let the Hydra warheads be more maneuverable.

        _NewTorpVel.velocityf = _CurrentTorpVelocity.velocityf
        _NewTorpVel:addVelocity(_PosAdj[idx])

        _NewTorpDura.maximum = _CurrentTorpDura.maximum
        _NewTorpDura.durability = _CurrentTorpDura.maximum

        _Sector:createEntity(_NewTorpDesc)
    end

    _CurrentTorpDura:inflictDamage(999999, 1, DamageType.Fragments, Entity().id)
end

--endregion

--region #CLIENT / SERVER FUNCTIONS

function HydraController.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[HydraController] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

