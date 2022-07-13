package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

ESCCUtil = include("esccutil")

-- namespace LaserSniper
LaserSniper = {}
local self = LaserSniper

self._Debug = 0

self._Data = {}

local laser = nil
local targetlaser = nil

local _LookConstant = 210

self._LaserData = {}
self._LaserData._From = nil
self._LaserData._To = nil
self._LaserData._TargetPoint = nil

function LaserSniper.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Initializing Laser Sniper v53 script on entity.")

    self._Data = _Values or {}

    --Values the player isn't meant to adjust.
    self._Data._TargetLaserActive = false
    self._Data._TargetBeamActiveTime = 0
    self._Data._MaxBeamActiveTime = 2
    self._Data._BeamActiveTime = 0
    self._Data._ShotLaserActive = false
    self._Data._BeamMisses = 0
    self._Data._CurrentTarget = nil
    self._Data._FireCycle = nil
    self._Data._DOTCycle = 0
    self._Data._TargetPoint = nil

    --Values the player can adjust.
    self._Data._MaxRange = self._Data._MaxRange or 20000
    self._Data._DamagePerFrame = self._Data._DamagePerFrame or 155000
    self._Data._ShieldPen = self._Data._ShieldPen or false
    self._Data._TargetCycle = self._Data._TargetCycle or 10
    self._Data._TargetingTime = self._Data._TargetingTime or 1.75
    self._Data._CreepingBeam = self._Data._CreepingBeam or true
    self._Data._CreepingBeamSpeed = self._Data._CreepingBeamSpeed  or 0.75
    self._Data._UseEntityDamageMult = self._Data._UseEntityDamageMult or false
    self._Data._IncreaseDamageOT = self._Data._IncreaseDamageOT or false
    self._Data._IncreaseDOTCycle = self._Data._IncreaseDOTCycle or 0
    self._Data._IncreaseDOTAmount = self._Data._IncreaseDOTAmount or 0
    self._Data._TimeToActive = self._Data._TimeToActive or 0
    self._Data._TargetPriority = self._Data._TargetPriority or 1

    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function LaserSniper.onDestroyed()
    LaserSniper.deleteCurrentLasers()
end

function LaserSniper.update(_TimeStep)
    local _MethodName = "Update"
    if self._Data._TimeToActive >= 0 then
        self._Data._TimeToActive = self._Data._TimeToActive - _TimeStep
        return
    end

    if self._Data._LookConstantOverride then
        _LookConstant = self._Data._LookConstantOverride
    end
    LaserSniper.updateLaser()

    if onServer() then
        if self._Data._BeamMisses >= 5 then
            self.Log(_MethodName, "Beam has missed too frequently. Picking a new target.")
            self._Data._CurrentTarget = nil
            self._Data._BeamMisses = 0
        end

        if self._Data._IncreaseDamageOT then
            self._Data._DOTCycle = (self._Data._DOTCycle or 0) + _TimeStep
            if self._Data._DOTCycle >= self._Data._IncreaseDOTCycle then
                self._Data._DamagePerFrame = self._Data._DamagePerFrame + self._Data._IncreaseDOTAmount
                self.Log(_MethodName, "Increasing damage per frame - new value is " .. tostring(self._Data._DamagePerFrame))
                self._Data._DOTCycle = 0
            end
        end

        if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
            self._Data._CurrentTarget = self.pickNewTarget()
            self._Data._FireCycle = 0
        else
            self._Data._FireCycle = (self._Data._FireCycle or 0) + _TimeStep
            if self._Data._FireCycle >= self._Data._TargetCycle then
                if not self._Data._TargetLaserActive then
                    self.Log(_MethodName, "No target laser active - creating one.")
                    self.createTargetingLaser()
                    self._Data._TargetLaserActive = true
                    self._Data._TargetBeamActiveTime = 0
                else
                    self._Data._TargetBeamActiveTime = (self._Data._TargetBeamActiveTime or 0) + _TimeStep
                    self.showChargeEffect()
                end
            end
            if self._Data._FireCycle >= self._Data._TargetCycle + self._Data._TargetingTime then --Target for X seconds, then fire.
                self.Log(_MethodName, "Firing big laser and resetting fire cycle.")
                self.createShotLaser()
                self._Data._BeamMisses = self._Data._BeamMisses + 1
                self._Data._TargetLaserActive = false
                self._Data._ShotLaserActive = true
                self._Data._FireCycle = 0
                self._Data._BeamActiveTime = 0
            end

            if self._Data._ShotLaserActive then
                LaserSniper.updateIntersection(_TimeStep)
                self._Data._BeamActiveTime = (self._Data._BeamActiveTime or 0) + _TimeStep
                if self._Data._BeamActiveTime >= self._Data._MaxBeamActiveTime then
                    self._Data._ShotLaserActive = false
                    self._Data._CreepTime = 0
                    self.deleteCurrentLasers()
                end
            end
        end
        --Send data to client.
        self.sync(self._Data)
    end
end

function LaserSniper.updateIntersection(_TimeStep)
    local _MethodName = "Update Intersection"
    if onClient() then return end

    local ray = Ray()
    ray.origin = vec3(self._LaserData._From) or vec3()
    ray.direction = (vec3(self._LaserData._To) or vec3()) - ray.origin
    ray.planeIntersectionThickness = 6
    if not ray then 
        return 
    end

    local boss = Entity()
    _Entity = Sector():intersectBeamRay(ray, boss, nil)
    if _Entity then
        if _Entity.type == EntityType.Asteroid or _Entity.type == EntityType.Wreckage then
            self.showExplosion(_Entity)
            _Entity:destroy(boss.id, 1, DamageType.Energy)
            if _Entity then Sector():deleteEntity(_Entity) end
        else
            self._Data._BeamMisses = 0
            local _Shield = Shield(_Entity.id)

            local _EntityDamageMultiplier = 1
            if self._Data._UseEntityDamageMult then
                _EntityDamageMultiplier = (boss.damageMultiplier or 1)
            end

            local _DamageToShield = self._Data._DamagePerFrame * _EntityDamageMultiplier
            local _DamageToHull = 0

            --We'll be nice and not bypass shields this time, unlike IHDTX-style lasers.
            if _Shield and not self._Data._ShieldPen then
                if _Shield.durability < _DamageToShield then
                    _DamageToHull = _DamageToShield - _Shield.durability
                    _DamageToShield = _Shield.durability
                end
                if _DamageToShield > 0 then
                    _Shield:inflictDamage(_DamageToShield, 1, DamageType.Energy, boss.translationf, boss.id)
                end
            else
                _DamageToHull = _DamageToShield
            end

            if _DamageToHull > 0 then
                local durability = Durability(_Entity.id)
                if not durability then return end
                durability:inflictDamage(_DamageToHull, 1, DamageType.Energy, boss.id)
            end
        end
    end
end

function LaserSniper.pickNewTarget()
    local _MethodName = "Pick New Target"
    local _Factionidx = Entity().factionIndex
    local _Rgen = ESCCUtil.getRand()

    --Pick a random target for now. I had this done by highest firepower, but I think it made the sniper too predictable.
    --local _Enemies = {}
    local _TargetCandidates = {Sector():getEnemies(_Factionidx)}

    if self._Data._TargetPriority == 2 then --Reset target candidates and add all ships / stations that are not Xsotan.
        _TargetCandidates = {}
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
    end

    if #_TargetCandidates > 0 then
        self.Log(_MethodName, "Found at least one suitable target. Picking a random one.")
        return _TargetCandidates[_Rgen:getInt(1, #_TargetCandidates)]
    else
        self.Log(_MethodName, "WARNING - Could not find any target candidates.")
        return nil
    end
end

--region #CLIENT CALLS

function LaserSniper.updateLaser()
    local _MethodName = "Update Laser"
    if onClient() then
        if not laser then
            return
        end

        local _boss = Entity()
        self._LaserData._TargetPoint = self._LaserData._TargetPoint or self._Data._TargetPoint

        if self._Data._CreepingBeam then
            --Creep the laser towards the target to make it harder to evade.
            local _CreepSpeed = self._Data._CreepingBeamSpeed
            if self._Data._ShotLaserActive then
                _CreepSpeed = _CreepSpeed * 0.8
            end

            local _Target = self._Data._CurrentTarget
            local _TargetLoc = _Target.translationf

            local _Dir = _TargetLoc - self._LaserData._TargetPoint
            local _Direction = normalize(_Dir) * _CreepSpeed
            self._LaserData._TargetPoint = self._LaserData._TargetPoint + _Direction
        end

        local _From = _boss.translationf
        local _TargetPoint = self._LaserData._TargetPoint
        local _Dir = _TargetPoint - _From 
        local _Direction = normalize(_Dir)

        laser.from = _From
        laser.to = _From + (_Direction * _LookConstant)
        laser.aliveTime = 0

        if not _From or not _Direction then
            self.Log(_MethodName, "WARNING - _From is " .. tostring(_From) .. " or _Direction is " .. tostring(_Direction))
        end

        targetlaser.from = laser.to
        targetlaser.to = laser.to + (_Direction * self._Data._MaxRange)
        targetlaser.aliveTime = 0

        self._LaserData._From = targetlaser.from
        self._LaserData._To = targetlaser.to

        --Send laser data back to the server.
        LaserSniper.syncLaserData(self._LaserData)
    end
end

--endregion

--region #CLIENT / SERVER CALLS

function LaserSniper.createTargetingLaser()
    local _MethodName = "Create Targeting Laser"
    laserActive = true

    local _Entity = Entity()
    local _TargetEntity = self._Data._CurrentTarget
    self._Data._TargetPoint = _TargetEntity.translationf

    if onServer() then
        self.Log(_MethodName, "Calling on Server - invoking on Client")
        broadcastInvokeClientFunction("createTargetingLaser")
        return
    else
        self.Log(_MethodName, "Calling on client")
    end

    self.Log(_MethodName, "Entity targeted is " .. tostring(_TargetEntity.name) .. " and its position is " .. tostring(self._Data._TargetPoint))

    LaserSniper.deleteCurrentLasers()
    LaserSniper.createLaser(1, ColorRGB(0, 1, 0), true, _Entity.translationf, self._Data._TargetPoint)
end

function LaserSniper.createShotLaser()
    local _MethodName = "Create Shot Laser"
    if onServer() then
        self.Log(_MethodName, "Calling on Server - invoking on Client")
        broadcastInvokeClientFunction("createShotLaser")
        return
    else
        self.Log(_MethodName, "Calling on client")
    end

    --Continue to shoot from the last point calculated by the targeting laser.
    local _Entity = Entity()
    local _TargetPoint = self._LaserData._TargetPoint

    self.Log(_MethodName, "Target point is " .. tostring(self._LaserData._TargetPoint))

    LaserSniper.deleteCurrentLasers()
    LaserSniper.createLaser(20, ColorRGB(1, 0, 0), false, _Entity.translationf, _TargetPoint)
end

function LaserSniper.createLaser(_Width, _Color, _Collision, _From, _TargetPoint)
    local _MethodName = "Create Laser"
    if onServer() then
        self.Log(_MethodName, "Calling on Server - invoking on Client")
        broadcastInvokeClientFunction("createLaser")
        return
    else
        self.Log(_MethodName, "Calling on client - values are : _Width : " .. tostring(_Width) .. " - _Color : " .. tostring(_Color) .. " - _Collision : " .. tostring(_Collision) .. " - _From : " .. tostring(_From) .. " - _TargetPoint : " .. tostring(_TargetPoint))
    end

    local _Color = _Color or ColorRGB(0.1, 0.1, 0.1)
    local _TargetColor = _Color or ColorRGB(0.1, 0.1, 0.1)

    local _Dir = _TargetPoint - _From
    local _Direction = normalize(_Dir)

    self.Log("Target point is : " .. tostring(_TargetPoint) .. " and from is : " .. tostring(_From))
    self.Log("_Dir is : " .. tostring(_Dir))

    local _lFrom = _From
    local _lTo = _From + (_Direction * _LookConstant)
    laser = Sector():createLaser(vec3(), vec3(), _Color, _Width or 1)
    laser.from = _lFrom
    laser.to = _lTo
    laser.collision = false

    self.Log(_MethodName, "Making laser from : " .. tostring(_lFrom) .. " to : " .. tostring(_lTo))
    if not laser then
        self.Log(_MethodName, "WARNING! laser is nil")
    end

    local _ltFrom = _lTo
    local _ltTo = _lTo + (_Direction * self._Data._MaxRange)
    targetlaser = Sector():createLaser(vec3(), vec3(), _Color, _Width or 1)
    targetlaser.from = _ltFrom
    targetlaser.to = _ltTo
    targetlaser.collision = _Collision

    self.Log(_MethodName, "Making target laser from : " .. tostring(_ltFrom) .. " to : " .. tostring(_ltTo))
    if not targetlaser then
        self.Log(_MethodName, "WARNING! targetlaser is nil")
    end

    self._LaserData._From = _ltFrom
    self._LaserData._To = _ltTo
    --Have to set this for both for it to sync properly.
    self._LaserData._TargetPoint = _TargetPoint
    self._Data._TargetPoint = _TargetPoint

    self.Log(_MethodName, "self._Data._TargetPoint is " .. tostring(self._Data._TargetPoint))

    laser.maxAliveTime = 5
    targetlaser.maxAliveTime = 5
end

function LaserSniper.showChargeEffect()
    if onServer() then
        broadcastInvokeClientFunction("showChargeEffect", entity)
        return
    end

    if not laser then return end
    local from = laser.from
    local look = laser.to
    local size = 75 + (75 * self._Data._TargetBeamActiveTime)

    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
    Sector():createGlow(from, size, ColorRGB(0.2,0.2,1))
end

function LaserSniper.showExplosion(entity)
    if onServer() then
        broadcastInvokeClientFunction("showExplosion", entity)
        return
    end

    if not entity then return end
    local position = entity.translationf
    local _Bounds = entity:getBoundingSphere()
    Sector():createExplosion(position, math.max(_Bounds.radius, 200), false)
end

function LaserSniper.deleteCurrentLasers()
    local _MethodName = "Delete Current Lasers"
    if onServer() then
        self.Log(_MethodName, "Calling on Server - invoking on Client")
        broadcastInvokeClientFunction("deleteCurrentLasers")
        return
    else
        self.Log(_MethodName, "Calling on client")
    end

    if valid(laser) then Sector():removeLaser(laser) end
    if valid(targetlaser) then Sector():removeLaser(targetlaser) end
end

function LaserSniper.sync(_Data_In)
    if onServer() then
        broadcastInvokeClientFunction("sync", self._Data)
    else
        if _Data_In then
            self._Data = _Data_In
        else
            invokeServerFunction("sync")
        end
    end
end
callable(LaserSniper, "sync")

function LaserSniper.syncLaserData(_Data_In)
    if onClient() then
        invokeServerFunction("syncLaserData", self._LaserData)
    else
        self._LaserData = _Data_In
    end
end
callable(LaserSniper, "syncLaserData")

function LaserSniper.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[LaserSniper] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function LaserSniper.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function LaserSniper.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion