package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

ESCCUtil = include("esccutil")

local TorpedoGenerator = include ("torpedogenerator")

--namespace TorpedoSlammer
TorpedoSlammer = {}
local self = TorpedoSlammer

self._Debug = 0

self._Data = {}
--[[
    Some of these values are self-explanatory, but here's a guide to how this thing works:
        _ROF                    = Time in seconds that a torpedo is fired.
        _TimeToActive           = Time in seconds until this script becomes active.
        _CurrentTarget          = The current target of the script
        _PreferWarheadType      = This script will always use this warhead type if this value is supplied. Otherwise a random type is used.
        _PreferBodyType         = This script will always use this body type if this value is supplied. Otherwise a random type is used.
        _UpAdjust               = Adjusts the spawned torpedo upwards or not. Used for not spawning a torpedo in the ship's bounding box which does weird shit to the AI.
        _DamageFactor           = Multiplies the amount of damage the torpedo does.
        _ForwardAdjustFactor    = Adjusts how far forward a torpedo spawns relative to the attached entity. Used for not spawning a torpedo in the ship's bounding box which does weird shit to the AI.
        _DurabilityFactor       = Multiplies the durability of torpedoes by this amount. Useful for making torpedoes that are hard to shoot down.
        _UseEntityDamageMult    = Multiplies the damage of the torpedoes by the attached entity's damage multiplier. Useful for overdrive or avenger enemies.
        _TargetPriority         = 1 = most firepower, 2 = by script value
        _TargetScriptValue      = The script value to target by - "xtest1" for example would target by Sector():getByScriptValue("xtest1")
]]
self._Data._ROF = nil
self._Data._TimeToActive = nil
self._Data._CurrentTarget = nil
self._Data._PreferWarheadType = nil
self._Data._PreferBodyType = nil
self._Data._UpAdjust = nil
self._Data._DamageFactor = nil
self._Data._ForwardAdjustFactor = nil --Consider setting this to a value greater than 1 if you put this on a smaller ship.
self._Data._DurabilityFactor = nil
self._Data._UseEntityDamageMult = nil
self._Data._TargetPriority = nil
self._Data._TargetScriptValue = nil

function TorpedoSlammer.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Beginning...")

    self._Data = _Values

    --Preferred warhead / body type aren't set - if they are nil, that is fine.

    self._Data._TimeToActive = self._Data._TimeToActive or 10
    self._Data._ROF = self._Data._ROF or 1
    self._Data._UpAdjust = self._Data._UpAdjust or false
    self._Data._DamageFactor = self._Data._DamageFactor or 1
    self._Data._ForwardAdjustFactor = self._Data._ForwardAdjustFactor or 1
    self._Data._DurabilityFactor = self._Data._DurabilityFactor or 1
    self._Data._UseEntityDamageMult = self._Data._UseEntityDamageMult or false
    self._Data._TargetPriority = self._Data._TargetPriority or 1

    self.Log(_MethodName, "Setting UpAdjust to : " .. tostring(self._Data._UpAdjust))
end

function TorpedoSlammer.getUpdateInterval()
    return self._Data._ROF
end

function TorpedoSlammer.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self.Log(_MethodName, "Running...")

    if self._Data._TimeToActive >= 0 then
        self._Data._TimeToActive = self._Data._TimeToActive - _TimeStep
    else
        if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
            self._Data._CurrentTarget = self.pickNewTarget()
        else
            self.fireAtTarget()
        end
    end
end

function TorpedoSlammer.pickNewTarget()
    local _MethodName = "Pick New Target"
    local _Factionidx = Entity().factionIndex
    local _Rgen = ESCCUtil.getRand()
    local _TargetPriority = self._Data._TargetPriority

    local _Enemies = {Sector():getEnemies(_Factionidx)}
    local _TargetCandidates = {}

    if _TargetPriority == 1 then --Go through and find the highest firepower total of all enemies, then put any enemies that match that into a table.
        local _TargetValue = 0
        for _, _Candidate in pairs(_Enemies) do
            if _Candidate.firePower > _TargetValue then
                _TargetValue = _Candidate.firePower
            end
        end
    
        for _, _Candidate in pairs(_Enemies) do
            if _Candidate.firePower == _TargetValue then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 2 then --Go through and find all enemies with a specific script value - those go in the table.
        for _, _Candidate in pairs(_Enemies) do
            if _Candidate:getValue(self._Data._TargetScriptValue) then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    end

    if #_TargetCandidates > 0 then
        self.Log(_MethodName, "Found at least one suitable target. Picking a random one.")
        return _TargetCandidates[_Rgen:getInt(1, #_TargetCandidates)]
    else
        self.Log(_MethodName, "WARNING - Could not find any target candidates.")
        return nil
    end
end

function TorpedoSlammer.fireAtTarget()
    local _MethodName = "Fire At Target"
    local _Torpedo = self.generateTorpedo()

    local _Entity = Entity()

    local _Desc = TorpedoDescriptor()
    local _TorpAI = _Desc:getComponent(ComponentType.TorpedoAI)
    local _Torp = _Desc:getComponent(ComponentType.Torpedo)
    local _TorpVel = _Desc:getComponent(ComponentType.Velocity)
    local _TorpOwn = _Desc:getComponent(ComponentType.Owner)
    local _Flight = _Desc:getComponent(ComponentType.DirectFlightPhysics)
    local _Dura = _Desc:getComponent(ComponentType.Durability)

    _TorpAI.target = self._Data._CurrentTarget.id
    _Torp.intendedTargetFaction = self._Data._CurrentTarget.factionIndex

    _TorpAI.driftTime = 1

    local _EnemyPosition = self._Data._CurrentTarget.translationf
    local _OwnPosition = _Entity.translationf

    local _DVec = _EnemyPosition - _OwnPosition
    local _NDVec = normalize(_DVec)

    local _Bounds = _Entity:getBoundingSphere()
    local _Mat = _Entity.position
    local _Out = Matrix()
    local _SpawnPos = _Mat.position + (_NDVec * _Bounds.radius * 1.25 * self._Data._ForwardAdjustFactor)
    if self._Data._UpAdjust then
        self.Log(_MethodName, "Adjusting up position.")
        _SpawnPos = _SpawnPos + (_Mat.up * _Bounds.radius * 0.1)
    end

    local _EntityDamageMultiplier = 1
    if self._Data._UseEntityDamageMult then
        _EntityDamageMultiplier = (_Entity.damageMultiplier or 1)
    end

    _Torpedo.shieldDamage = _Torpedo.shieldDamage * self._Data._DamageFactor * _EntityDamageMultiplier
    _Torpedo.hullDamage = _Torpedo.hullDamage * self._Data._DamageFactor * _EntityDamageMultiplier

    _Out.position = _SpawnPos
    _Out.look = _Mat.look
    _Out.up = _Mat.up
    _Desc.position = _Out

    _Torp.shootingCraft = _Entity.id
    _Torp.firedByAIControlledPlayerShip = false
    _Torp.collisionWithParentEnabled = false
    _Torp:setTemplate(_Torpedo)

    _TorpOwn.factionIndex = _Entity.factionIndex

    _Flight.drifting = true
    _Flight.maxVelocity = _Torpedo.maxVelocity
    _Flight.turningSpeed = _Torpedo.turningSpeed * 2

    _TorpVel.velocityf = vec3(1,1,1) * 10

    _Dura.maximum = _Torpedo.durability * self._Data._DurabilityFactor
    _Dura.durability = _Torpedo.durability * self._Data._DurabilityFactor

    Sector():createEntity(_Desc)
end

function TorpedoSlammer.generateTorpedo()
    local _Rgen = ESCCUtil.getRand()
    local _Coordinates = {Sector():getCoordinates()}
    local _Generator = TorpedoGenerator()

    local _WarheadType = self._Data._PreferWarheadType
    if not _WarheadType then
        _WarheadType = _Rgen:getInt(1, 10)
    end

    local _BodyType = self._Data._PreferBodyType
    if not _BodyType then
        _BodyType = _Rgen:getInt(1, 9)
    end

    return _Generator:generate(_Coordinates.x, _Coordinates.y, 0, Rarity(RarityType.Exotic), _WarheadType, _BodyType)
end

--region #CLIENT / SERVER CALLS

function TorpedoSlammer.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[TorpedoSlammer] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function TorpedoSlammer.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function TorpedoSlammer.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion