package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("randomext")

-- namespace Vengeance1Picket
Vengeance1Picket = {}
local self = Vengeance1Picket

--All of the various messages come with a _RequireDebugLevel parameter baked in. If you wish to see some specific messages, you can find those and set
--_RequireDebugLevel to 0 for those messages. You can also set self._Debug to match it. Most messages are going to require level 1 but some require more.
self._Debug = 0
self._DebugLevel = 1

self._Data = {}

local laser = nil
local targetlaser = nil

local _LookConstant = 120

self._LaserData = {}
self._LaserData._From = nil
self._LaserData._To = nil

function Vengeance1Picket.initialize(_Values)
    local methodName = "Initialize"
    self.Log(methodName, "Initializing Vengeance 1 Picket v4 script on entity.", 1)

    self._Data = _Values or {}

    if onServer() then
        local _entity = Entity()
    
        Boarding(_entity).boardable = false
    
        if not _restoring then
            self.Log(methodName, "_restore is not set - setting initial data.")

            --Values the player isn't meant to adjust.
            self._Data._TimeToActive = self._Data._TimeToActive or 0
            self._Data._TargetLaserActive = false
            self._Data._CurrentTarget = nil
            self._Data._TargetTrackedTime = 0
            self._Data._PlayerSentWarning = false
            self._Data._KillSwitchSet = false
            self._Data._VelocityZeroTimer = 0
        
            --Values the player can adjust.
            self._Data._MaxRange = self._Data._MaxRange or 20000
            self._Data._MaxAlertTime = self._Data._MaxAlertTime or 12 --Player has 10 seconds after the warning to get back under cover.
            --_pindex is needed for targeting. This can be nil and I did not miss it.
        else
            self.Log(methodName, "Restoring data from self.Restore()")
        end
    else
        --onClient()
        self._Data._TimeToActive = self._Data._TimeToActive or 0 --Need this or it spams the hell out of client logs.
    end

    Entity():registerCallback("onDestroyed", "onDestroyed")
end

function Vengeance1Picket.onDestroyed()
    Vengeance1Picket.deleteCurrentLasers()
end

function Vengeance1Picket.update(timeStep)
    local methodName = "Update"

    if self._Data._KillSwitchSet then
        self._Data._CurrentTarget = nil
        Vengeance1Picket.deleteCurrentLasers()
        terminate()
        return
    end

    if self._Data._TimeToActive >= 0 then
        self._Data._TimeToActive = self._Data._TimeToActive - timeStep
        return
    end

    if self._Data._LookConstantOverride then
        _LookConstant = self._Data._LookConstantOverride
    end
    Vengeance1Picket.updateLaser()

    if onServer() then
        local selfVelocity = Velocity()
        if selfVelocity.linear == 0 then
            self._Data._VelocityZeroTimer = self._Data._VelocityZeroTimer + timeStep
        else
            self._Data._VelocityZeroTimer = 0
        end

        if self._Data._VelocityZeroTimer > 10 then
            self.Log(methodName, "Was still for too long. Deleting local asteroids.")
            local _sector = Sector()
            local _entity = Entity()

            local selfSphere = _entity:getBoundingSphere()
            local asteroidRemovalSphere = Sphere(selfSphere.center, selfSphere.radius * 10) 
            local removalCandidates = {_sector:getEntitiesByLocation(asteroidRemovalSphere)}
            mission.Log(methodName, "Found " .. tostring(#removalCandidates) .. " candidates for removal. Any asteroids in this list will be removed.")
            for _, _En in pairs(removalCandidates) do
                if _En.isAsteroid then
                    _sector:deleteEntity(_En)
                end
            end
            self._Data._VelocityZeroTimer = 0 --Reset timer.
        end

        if self._Data._CurrentTarget == nil or not valid(self._Data._CurrentTarget) then
            self._Data._CurrentTarget = self.pickNewTarget()
        else
            if not self._Data._TargetLaserActive then
                self.Log(methodName, "No target laser active - creating one.", 1)
                self.createTargetingLaser()
                self._Data._TargetLaserActive = true
            else
                self.updateIntersection(timeStep)
            end
        end

        if self._Data._TargetTrackedTime > 2 and not self._Data._PlayerSentWarning then
            Sector():sendCallback("vbmnStory1WarnPicket")
            self._Data._PlayerSentWarning = true
            self.Log(methodName, "Player tracked for more than 2 seconds. Send warning.", 1)
        end

        if self._Data._TargetTrackedTime > self._Data._MaxAlertTime then
            Sector():sendCallback("vbmnStory1FailPicket")
            self.Log(methodName, "Player tracked for more than _MaxAlertTime seconds. Fail mission.", 1)
        end

        --Send data to client.
        self.sync(self._Data)
    end
end

function Vengeance1Picket.updateIntersection(timeStep)
    local methodName = "Update Intersection"
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
        if _Entity.type == EntityType.Ship then
            if _Entity.playerOrAllianceOwned then
                local entityFactionIndex = _Entity.factionIndex
                if entityFactionIndex == self._Data._pindex then
                    self._Data._TargetTrackedTime = self._Data._TargetTrackedTime + timeStep
                else --Not the same player we are tracking.
                    self.Log(methodName, "Beam break achieved - not same player.", 5)
                    self._Data._TargetTrackedTime = 0
                    self._Data._PlayerSentWarning = false
                end
            else --Not player or alliance owned.
                self.Log(methodName, "Beam break achieved - entity not player or alliance owned.", 5)
                self._Data._TargetTrackedTime = 0
                self._Data._PlayerSentWarning = false
            end
        else --Something other than a ship.
            self.Log(methodName, "Beam break achieved - entity something other than a ship.", 5)
            self._Data._TargetTrackedTime = 0
            self._Data._PlayerSentWarning = false
        end
    else --no _Entity - reset timer.
        self.Log(methodName, "Beam break achieved - no entities intersecting.", 5)
        self._Data._TargetTrackedTime = 0
        self._Data._PlayerSentWarning = false
    end
end

function Vengeance1Picket.pickNewTarget()
    local methodName = "Pick New Target"
    --Pick a random target for now. I had this done by highest firepower, but I think it made the sniper too predictable.
    --Now remodeled to make it harder for my dumb ass to put an infinite loop in and explode my computer :3
    local _TargetCandidates = {}

    if self._Data._pindex then
        local _PlayerTarget = Player(self._Data._pindex)
        local _PlayerTargetShip = Entity(_PlayerTarget.craft.id)

        if _PlayerTargetShip and valid(_PlayerTargetShip) then
            table.insert(_TargetCandidates, _PlayerTargetShip)
        end
    end

    if #_TargetCandidates > 0 then
        local chosenCandidate = randomEntry(_TargetCandidates)
        
        return chosenCandidate
    else
        self.Log(methodName, "WARNING - Could not find any target candidates.", 1)
        return nil
    end
end

--region #SERVER => EXTERNAL ADJ METHODS

function Vengeance1Picket.resetTimeToActive(_Time)
    self._Data._TimeToActive = _Time
end

function Vengeance1Picket.setKillSwitch()
    self._Data._KillSwitchSet = true
end

--endregion

--region #CLIENT CALLS

function Vengeance1Picket.updateLaser()
    local methodName = "Update Laser"
    if onClient() then
        local _Entity = Entity()
        if not laser or not valid(laser) or not _Entity or not valid(_Entity) then
            --Set this to log level 7 - highly reccommend keeping it there unless you absolutely need this message. The spam is unreal.
            self.Log(methodName, "Laser not valid!!! Returning immediately.", 7)
            return
        end
        if not self._Data.CurrentTarget or not valid(self._Data._CurrentTarget) then
            self.Log(methodName, "Target not valid! Returning immediately.", 7)
        end

        local _boss = Entity()

        local _From = _boss.translationf
        local _TargetPoint = self._Data._CurrentTarget.translationf
        local _Dir = _TargetPoint - _From 
        local _Direction = normalize(_Dir)

        laser.from = _From
        laser.to = _From + (_Direction * _LookConstant)
        laser.aliveTime = 0

        if not _From or not _Direction then
            self.Log(methodName, "WARNING - _From is " .. tostring(_From) .. " or _Direction is " .. tostring(_Direction), 1)
        end

        targetlaser.from = laser.to
        targetlaser.to = laser.to + (_Direction * self._Data._MaxRange)
        targetlaser.aliveTime = 0

        self._LaserData._From = targetlaser.from
        self._LaserData._To = targetlaser.to

        --Send laser data back to the server.
        Vengeance1Picket.syncLaserData(self._LaserData)
    end
end

--endregion

--region #CLIENT / SERVER CALLS

function Vengeance1Picket.createTargetingLaser()
    local methodName = "Create Targeting Laser"
    laserActive = true

    local _Entity = Entity()
    local _TargetEntity = self._Data._CurrentTarget
    local targetPoint = _TargetEntity.translationf

    if onServer() then
        self.Log(methodName, "Calling on Server - invoking on Client", 1)
        broadcastInvokeClientFunction("createTargetingLaser")
        return
    else
        self.Log(methodName, "Calling on client", 1)
    end

    self.Log(methodName, "Entity targeted is " .. tostring(_TargetEntity.name) .. " and its position is " .. tostring(targetPoint), 1)

    Vengeance1Picket.deleteCurrentLasers()
    Vengeance1Picket.createLaser(1, ColorRGB(0, 1, 0), true, _Entity.translationf, targetPoint)
end

--Creating the laser
function Vengeance1Picket.createLaser(_Width, _Color, _Collision, _From, _TargetPoint)
    local methodName = "Create Laser"
    if onServer() then
        self.Log(methodName, "Calling on Server - invoking on Client", 1)
        broadcastInvokeClientFunction("createLaser")
        return
    else
        self.Log(methodName, "Calling on client - values are : _Width : " .. tostring(_Width) .. " - _Color : " .. tostring(_Color) .. " - _Collision : " .. tostring(_Collision) .. " - _From : " .. tostring(_From) .. " - _TargetPoint : " .. tostring(_TargetPoint), 1)
    end

    local _Color = _Color or ColorRGB(0.1, 0.1, 0.1)

    local _Dir = _TargetPoint - _From
    local _Direction = normalize(_Dir)

    self.Log(methodName, "Target point is : " .. tostring(_TargetPoint) .. " and from is : " .. tostring(_From), 1)
    self.Log(methodName, "_Dir is : " .. tostring(_Dir), 1)

    local _lFrom = _From
    local _lTo = _From + (_Direction * _LookConstant)
    laser = Sector():createLaser(vec3(), vec3(), _Color, _Width or 1)
    laser.from = _lFrom
    laser.to = _lTo
    laser.collision = false

    self.Log(methodName, "Making laser from : " .. tostring(_lFrom) .. " to : " .. tostring(_lTo), 1)
    if not laser then
        self.Log(methodName, "WARNING! laser is nil", 1)
    end

    local _ltFrom = _lTo
    local _ltTo = _lTo + (_Direction * self._Data._MaxRange)
    targetlaser = Sector():createLaser(vec3(), vec3(), _Color, _Width or 1)
    targetlaser.from = _ltFrom
    targetlaser.to = _ltTo
    targetlaser.collision = _Collision

    self.Log(methodName, "Making target laser from : " .. tostring(_ltFrom) .. " to : " .. tostring(_ltTo), 1)
    if not targetlaser then
        self.Log(methodName, "WARNING! targetlaser is nil", 1)
    end

    self._LaserData._From = _ltFrom
    self._LaserData._To = _ltTo

    laser.maxAliveTime = 5
    targetlaser.maxAliveTime = 5
end

--Removes laser and targetlaser. Broadcast invokes the client function if it is called on the server.
function Vengeance1Picket.deleteCurrentLasers()
    local methodName = "Delete Current Lasers"
    if onServer() then
        self.Log(methodName, "Calling on Server - invoking on Client", 1)
        broadcastInvokeClientFunction("deleteCurrentLasers")
        return
    else
        self.Log(methodName, "Calling on client", 1)
    end

    if valid(laser) then Sector():removeLaser(laser) end
    if valid(targetlaser) then Sector():removeLaser(targetlaser) end
end

--Sends _Data from the server to the client. If this is called on the client it will either set _Data, OR it will attempt to get _Data again.
function Vengeance1Picket.sync(_Data_In)
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
callable(Vengeance1Picket, "sync")

--Sends _LaserData from the client to the server.
function Vengeance1Picket.syncLaserData(_Data_In)
    if onClient() then
        invokeServerFunction("syncLaserData", self._LaserData)
    else
        self._LaserData = _Data_In
    end
end
callable(Vengeance1Picket, "syncLaserData")

--endregion

--region #LOG / SECURE / RESTORE

function Vengeance1Picket.Log(methodName, _Msg, _RequireDebugLevel)
    _RequireDebugLevel = _RequireDebugLevel or 1

    if self._Debug == 1 and self._DebugLevel >= _RequireDebugLevel then
        print("[Vengeance1Picket] - [" .. tostring(methodName) .. "] - " .. tostring(_Msg))
    end
end

function Vengeance1Picket.secure()
    local methodName = "Secure"
    self.Log(methodName, "Securing self._Data", 1)
    return self._Data
end

function Vengeance1Picket.restore(_Values)
    local methodName = "Restore"
    self.Log(methodName, "Restoring self._Data", 1)
    self._Data = _Values
end

--endregion