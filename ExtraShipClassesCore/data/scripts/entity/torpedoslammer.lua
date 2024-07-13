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
        _ROF                    = A torpedo is fired once per _ROF seconds.
        _FireCycle              = Keeps track of how much time has passed. Sets to 0 every time a torp fires.
        _TimeToActive           = Time in seconds until this script becomes active.
        _CurrentTarget          = The current target of the script
        _PreferWarheadType      = This script will always use this warhead type if this value is supplied. Otherwise a random type is used.
        _PreferBodyType         = This script will always use this body type if this value is supplied. Otherwise a random type is used.
        _UpAdjust               = Adjusts the spawned torpedo upwards or not. Used for not spawning a torpedo in the ship's bounding box which does weird shit to the AI.
        _UpAdjustFactor         = Determines how much upwards to adjust the spawned torpedo. Defaults to 1.
        _DamageFactor           = Multiplies the amount of damage the torpedo does.
        _ForwardAdjustFactor    = Adjusts how far forward a torpedo spawns relative to the attached entity. Used for not spawning a torpedo in the ship's bounding box which does weird shit to the AI.
        _DurabilityFactor       = Multiplies the durability of torpedoes by this amount. Useful for making torpedoes that are hard to shoot down.
        _UseEntityDamageMult    = Multiplies the damage of the torpedoes by the attached entity's damage multiplier. Useful for overdrive or avenger enemies.
        _UseStaticDamageMult    = Sets a multiplier on the first update and does not dynamically use the entity's damage multiplier.
        _TargetPriority         = 1 = most firepower, 2 = by script value, 3 = random non-xsotan, 4 = random enemy
        _TargetScriptValue      = The script value to target by - "xtest1" for example would target by Sector():getByScriptValue("xtest1")
        _TorpOffset             = Applies an offset to torpedo generation. Defaults to 0. Set to a negative value for higher tech level torpedoes.

        Example:

        local _TorpSlammerValues = {}
        _TorpSlammerValues._TimeToActive = 12
        _TorpSlammerValues._ROF = 2
        _TorpSlammerValues._UpAdjust = false
        _TorpSlammerValues._DamageFactor = _TorpedoFactor
        _TorpSlammerValues._DurabilityFactor = _TorpDuraFactor
        _TorpSlammerValues._ForwardAdjustFactor = 1

        _Boss:addScriptOnce("torpedoslammer.lua", _TorpSlammerValues)

        Alternate example:

        local TorpedoUtility = include ("torpedoutility")
        _Boss:addScriptOnce("torpedoslammer.lua", { _ROF = 1, _TimeToActivate = 5, _PreferWarheadType = TorpedoUtility.WarheadType.EMP, _PreferBodyType = TorpedoUtility.BodyType.Hawk})
]]
        
--Brief overview of the values available w/o documentation.

--self._Data._ROF = nil
--self._Data._FireCycle = nil
--self._Data._TimeToActive = nil
--self._Data._CurrentTarget = nil
--self._Data._PreferWarheadType = nil
--self._Data._PreferBodyType = nil
--self._Data._UpAdjust = nil
--self._Data._DamageFactor = nil
--self._Data._ForwardAdjustFactor = nil --Consider setting this to a value greater than 1 if you put this on a smaller ship.
--self._Data._DurabilityFactor = nil
--self._Data._UseEntityDamageMult = nil
--self._Data._UseStaticDamageMult = nil
--self._Data._StaticDamageMultSet = nil
--self._Data._TargetPriority = nil
--self._Data._TargetScriptValue = nil

function TorpedoSlammer.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Initializing Torpedo Slammer v10 script on entity.", 1)

    self._Data = _Values or {}

    local self_is_xsotan = Entity():getValue("is_xsotan")
    local defaultTargetPriority = 1
    if self_is_xsotan then
        defaultTargetPriority = 3
    end

    --Stuff the player can't mess with.
    self._Data._FireCycle = 0
    self._Data._CurrentTarget = nil
    self._Data._StaticDamageMultSet = false
    self._Data._StaticDamageMultValue = 1

    --Preferred warhead / body type aren't set - if they are nil, that is fine.

    self._Data._TimeToActive = self._Data._TimeToActive or 10
    self._Data._ROF = self._Data._ROF or 1
    self._Data._UpAdjust = self._Data._UpAdjust or false
    self._Data._UpAdjustFactor = self._Data._UpAdjustFactor or 1
    self._Data._DamageFactor = self._Data._DamageFactor or 1
    self._Data._ForwardAdjustFactor = self._Data._ForwardAdjustFactor or 1
    self._Data._DurabilityFactor = self._Data._DurabilityFactor or 1
    self._Data._UseEntityDamageMult = self._Data._UseEntityDamageMult or false
    self._Data._UseStaticDamageMult = self._Data._UseStaticDamageMult or false
    self._Data._TargetPriority = self._Data._TargetPriority or defaultTargetPriority
    self._Data._PreferWarheadType = self._Data._PreferWarheadType or nil
    self._Data._PreferBodyType = self._Data._PreferBodyType or nil
    self._Data._TargetScriptValue = self._Data._TargetScriptValue or nil
    self._Data._TorpOffset = self._Data._TorpOffset or 0

    --Fix the target priority - if the ship isn't Xsotan make it use 4 instead of 3.
    if self._Data._TargetPriority == 3 and not self_is_xsotan then
        self._Data._TargetPriority = 4 --Just use 4. It's functionally the same as 3 but you won't target yourself due to the list of non-xsotan including you.
    end

    self.Log(_MethodName, "Setting UpAdjust to : " .. tostring(self._Data._UpAdjust), 1)
    self.Log(_MethodName, "Preferred warhead type is : " .. tostring(self._Data._PreferWarheadType), 1)
    self.Log(_MethodName, "Preferred bodty type is : " .. tostring(self._Data._PreferBodyType), 1)
end

function TorpedoSlammer.getUpdateInterval()
    return 1
end

function TorpedoSlammer.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self.Log(_MethodName, "Running...", 3)
    if self._Data._UseStaticDamageMult and not self._Data._StaticDamageMultSet then
        local _Mult = (Entity().damageMultiplier or 1)
        self.Log(_MethodName, "Setting static multiplier to: " .. tostring(_Mult), 1)
        self._Data._StaticDamageMultValue = _Mult
        self._Data._StaticDamageMultSet = true
    end

    if self._Data._TimeToActive >= 0 then
        self._Data._TimeToActive = self._Data._TimeToActive - _TimeStep
    else
        self._Data._FireCycle = self._Data._FireCycle + _TimeStep
        if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
            self._Data._CurrentTarget = self.pickNewTarget()
        else
            if self._Data._FireCycle >= self._Data._ROF then
                self.fireAtTarget()
                self._Data._FireCycle = 0
            end
        end
    end
end

function TorpedoSlammer.pickNewTarget()
    local _MethodName = "Pick New Target"
    local _Factionidx = Entity().factionIndex
    local _Rgen = ESCCUtil.getRand()
    local _TargetPriority = self._Data._TargetPriority

    --Get the list of enemies. This is a bit of work since it includes wacky crap like turrets.
    local _RawEnemies = {Sector():getEnemies(_Factionidx)}
    local _Enemies = {}
    for _, _RawEnemy in pairs(_RawEnemies) do
        if _RawEnemy.type == EntityType.Ship or _RawEnemy.type == EntityType.Station then
           table.insert(_Enemies, _RawEnemy) 
        end
    end
    local _TargetCandidates = {}

    if self._Debug == 1 then
        for _, _Enemy in pairs(_Enemies) do
            self.Log(_MethodName, "Enemy is a : " .. tostring(_Enemy.typename), 1)
        end
    end

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
    elseif _TargetPriority == 3 then --Pick a random non-xsotan.
        local _Ships = {Sector():getEntitiesByType(EntityType.Ship)}
        local _Stations = {Sector():getEntitiesByType(EntityType.Station)}

        for _, _Candidate in pairs(_Ships) do
            if not _Candidate:getValue("is_xsotan") then
                table.insert(_TargetCandidates, _Candidate)
            end
        end

        for _, _Candidate in pairs(_Stations) do
            if not _Candidate:getValue("is_xsotan") then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 4 then
        for _, _Candidate in pairs(_Enemies) do
            table.insert(_TargetCandidates, _Candidate)            
        end
    end

    if #_TargetCandidates > 0 then
        self.Log(_MethodName, "Found at least one suitable target. Picking a random one.", 1)
        return _TargetCandidates[_Rgen:getInt(1, #_TargetCandidates)]
    else
        self.Log(_MethodName, "WARNING - Could not find any target candidates.", 1)
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
        self.Log(_MethodName, "Adjusting up position.", 1)
        _SpawnPos = _SpawnPos + (_Mat.up * _Bounds.radius * 0.1 * self._Data._UpAdjustFactor)
    end

    local _EntityDamageMultiplier = 1
    if self._Data._UseEntityDamageMult then
        if self._Data._UseStaticDamageMult then
            _EntityDamageMultiplier = (self._Data._StaticDamageMultValue or 1)
        else
            _EntityDamageMultiplier = (_Entity.damageMultiplier or 1)
        end
    end

    local _BaseShieldDamage = _Torpedo.shieldDamage
    local _BaseHullDamage = _Torpedo.hullDamage

    _Torpedo.shieldDamage = _Torpedo.shieldDamage * self._Data._DamageFactor * _EntityDamageMultiplier
    _Torpedo.hullDamage = _Torpedo.hullDamage * self._Data._DamageFactor * _EntityDamageMultiplier

    self.Log(_MethodName, "Torpedo has tech of : " .. tostring(_Torpedo.tech) .. " and base shield damage of : " .. tostring(_BaseShieldDamage) .. " and base hull damage of : " .. tostring(_BaseHullDamage), 1)
    self.Log(_MethodName, "Torpedo has final shield damage of " .. tostring(_Torpedo.shieldDamage) .. " and final hull damage of : " .. tostring(_Torpedo.hullDamage), 1)

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
    local _MethodName = "Generate Torepedo"
    local _Rgen = ESCCUtil.getRand()
    local _TorpX, _TorpY = Sector():getCoordinates()
    local _Generator = TorpedoGenerator()

    local _WarheadType = self._Data._PreferWarheadType
    if not _WarheadType then
        _WarheadType = _Rgen:getInt(1, 10)
    end

    local _BodyType = self._Data._PreferBodyType
    if not _BodyType then
        _BodyType = _Rgen:getInt(1, 9)
    end

    --The offest value does weird crap in the torp gen. It's calculated via length so if you're not careful and you put in too high of an offset, 
    --you actually make your desired tech level worse. We solve this wacky unintuitive case by handling things ourselves. If you're an avo dev and you happen
    --to read this, I'm not sorry for getting a little snarky here. Fix this by putting 'sector = math.max(sector, 0)' on line 106 of torpedogenerator.lua.
    --I guarantee you that nobody is expecting to see the tech level wrapping from higher/lower offset values. Guarantee it. Especially since the Turret
    --generator does it correctly. Look at line 95 in turretgenerator.lua! That's the correct approach!!!!
    local _SimSector = math.floor(length(vec2(_TorpX, _TorpY))) + self._Data._TorpOffset
    _SimSector = math.max(_SimSector, 0) --Don't let it go below 0, otherwise we get an unexpected tech value.

    self.Log(_MethodName, "x is : " .. tostring(_TorpX) .. " and y is : " .. tostring(_TorpY) .. " and offset is : " .. tostring(self._Data._TorpOffset) .. " and Warhead type is : " .. tostring(_WarheadType) .. " and body type is : " .. tostring(_BodyType), 1)
    self.Log(_MethodName, "Simulated sector is " .. tostring(_SimSector) .. " : 0", 2)

    return _Generator:generate(_SimSector, 0, 0, Rarity(RarityType.Exotic), _WarheadType, _BodyType)
end

function TorpedoSlammer.resetTimeToActive(_Time)
    self._Data._TimeToActive = _Time
end

--region #CLIENT / SERVER CALLS

function TorpedoSlammer.Log(_MethodName, _Msg, _RequireLogLevel)
    if self._Debug >= _RequireLogLevel then
        print("[TorpedoSlammer] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function TorpedoSlammer.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data", 1)
    return self._Data
end

function TorpedoSlammer.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data", 1)
    self._Data = _Values
end

--endregion