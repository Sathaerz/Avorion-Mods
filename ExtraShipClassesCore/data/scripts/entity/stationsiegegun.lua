package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("stringutility")
include ("callable")
include ("relations")
ESCCUtil = include("esccutil")

--Also known as the "Blob Gun" - this will shoot glowing blobs at the player, essentially simulating a projectile.
--Don't remove this or else the script might break. You know the drill by now.
--namespace StationSiegeGun
StationSiegeGun = {}
local self = StationSiegeGun

self._Debug = 0

self._Data = {}
--[[
    Some of these values are fairly self-explanatory, but for a handy guide for setting this thing up:
    THESE VALUES ARE REQUIRED - YOU SHOULD BE SETTING ALL OF THEM IN THE FIRST INITIALIZE CALL, OTHERWISE THE SCRIPT MAY NOT WORK CORRECTLY
        _CodesCracked           ==  Whether hints are broadcast from the entity that is using this script.
        _BaseDamagePerShot      ==  Exactly what it looks like. Base damage per shot.
        _Velocity               ==  The shot velocity.
        _ShotCycle              ==  At least this many seconds must pass between each shot, regardless if we are using supply mechanics or not.
        _UseSupply*             ==  Tells the script to use the supply mechanic. See the shipmentcontroller.lua to see how a station gets supplied. 
                                        - Note that you can attach this script to a ship, but it won't be able to use the supply mechanic properly.
                                        - Defaults to TRUE if _SupplyPerLevel is greater than 0. False otherwise. Can be overridden regardless.
        _ShotCycleSupply*       ==  This will determine how many supplies are required to fire a shot. Set this to 0 to bypass the supply mechanic.
        _ShotCycleTimer*        ==  This is the value that gets incremented and compared against _ShotCycle every serverupdate.
        _ShotSupplyConsumed*    ==  This will increment every time a shot is fired. This is used so that we only shoot 1 time per _ShotCycleSupply. Again, set this to 0 to bypass the supply mechanic.
                                ==      - For both of the above values (_ShotCycleSupply / _ShotCycleSupplyConsumed), look at shipmentcontroller.lua to see how a station gets supply.
        _SupplyPerLevel         ==  How many supplies constitute a "level" - default is 500.
        _SupplyFactor           ==  How much each supply level buffs base damage.
        _TargetPriority*        ==  Targeting priority - 1 = random, 2 = most max shield + hp, 3 = most firepower, 4 = lowest % health, 5 = highest % health, 6 = script value / tag, 7 = station, 8 = random non-xsotan
        _FragileShots           ==  Setting this to true changes it so that the shot will self-terminate when hitting a wreckage or asteroid. False means it plows through them.
        _TargetTag              ==  When _TargetPriority is set to 6, entities with this script value / tag will be targeted.
        _UseEntityDamageMult*   ==  Multiply the damage of the outgoing shot by the damage multiplier of the entity this script is attached to. Defaults to false.
        _TimeToActive*          ==  Sets the amount of time until this script becomes active. Defaults to 0.

    * - This value is set in the initialize call if it is not included.
]]

--//********** EXAMPLE SETUP OF A SIEGE GUN SCRIPT FROM LONG LIVE THE EMPRESS **********

--[[
    if not _MilitaryStation:hasScript("entity/stationsiegegun.lua") then
        --Siege Gun Data
        local _SGD = {}
        _SGD._CodesCracked = mission.data.custom.optionalObjectiveCompleted
        _SGD._Velocity = 150
        _SGD._ShotCycle = 30
        _SGD._ShotCycleSupply = 1000
        _SGD._ShotCycleTimer = 30
        _SGD._SupplyPerLevel = 4000 --This ratchets the damage up way too quickly at 500 per level - it will already be doing +40% damage by shot #2.
        _SGD._SupplyFactor = 0.1
        _SGD._FragileShots = false

        local _Dist = ESCCUtil.getDistanceToCenter(_X, _Y)
        --Clamp lowest damage to 10k
        local _Damage = math.max((500 - _Dist) * 10000, 10000)
        if _Dist < 80 then
            _Damage = _Damage + ((80 - _Dist) * 125000)
        end
        _Damage = _Damage * (1 + (mission.data.custom.dangerLevel / 20))
        _SGD._BaseDamagePerShot = _Damage

        _MilitaryStation:addScript("entity/stationsiegegun.lua", _SGD)
        mission.Log(_MethodName, "Attached siege gun script to military outpost.")
    else
        _MilitaryStation:invokeFunction("entity/stationsiegegun.lua", "setCodesCracked", mission.data.custom.optionalObjectiveCompleted)
    end
]]
self._Data._CodesCracked = nil
self._Data._BaseDamagePerShot = nil
self._Data._Velocity = nil
self._Data._ShotCycle = nil
self._Data._UseSupply = nil
self._Data._ShotCycleSupply = nil
self._Data._ShotCycleTimer = nil
self._Data._ShotSupplyConsumed = nil
self._Data._SupplyPerLevel = nil
self._Data._SupplyFactor = nil
self._Data._TargetPriority = nil
self._Data._FragileShots = nil
self._Data._TargetTag = nil
self._Data._UseEntityDamageMult = nil
self._Data._TimeToActive = nil
--All of these values can be generated on the fly / defaulted internally and do not need to be passed.
self._NextTarget = nil --This will be an issue on the unlikely chance the player manages to unload the script in the 5 seconds between the pick + shot.
self._CanShoot = nil

--region #INIT

function StationSiegeGun.initialize(_Values)
    local _MethodName = "inizialize"
    if onServer() then
        if not _restoring then
            self.Log(_MethodName, "Beginning on Sever")
            --Set values
            self._Data = _Values or {}

            local self_is_xsotan = Entity():getValue("is_xsotan")
            local defaultTargetPriority = 1
            if self_is_xsotan then
                defaultTargetPriority = 8
            end

            --We can reasonably set some of these.
            self._Data._TimeToActive = self._Data._TimeToActive or 0
            self._Data._ShotCycleTimer = self._Data._ShotCycleTimer or 0
            self._Data._TargetPriority = self._Data._TargetPriority or defaultTargetPriority --Random enemy / random non-xsotan if not specified.
            self._Data._ShotCycleSupply = self._Data._ShotCycleSupply or 0 --Set this to 0 if the user doesn't specify.
            self._Data._ShotSupplyConsumed = self._Data._ShotSupplyConsumed or 0 --Obviously we have consumed 0 supply.
            self._Data._UseEntityDamageMult = self._Data._UseEntityDamageMult or false --Set this to false unless otherwise specified.
            if self._Data._UseSupply == nil then
                --We have to specifically do a nil check here - it could be false.
                self._Data._UseSupply = self._Data._SupplyPerLevel > 0
            end
        else
            self.Log(_MethodName, "Values would have been restored in restore()")
        end
        self.getTags()
    else
        self.Log(_MethodName, "Beginning on Client")
    end
end

--endregion

function StationSiegeGun.getUpdateInterval()
    return 1.0
end

function StationSiegeGun.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    if self._Data._TimeToActive >= 0 then
        self._Data._TimeToActive = self._Data._TimeToActive - _TimeStep
        return
    end

    --Had frequent memory issues while dealing with this script. Added an emergency killswitch because of that.
    local _EmergencyKill = 0
    if _EmergencyKill == 1 then
        terminate()
        return
    end
    --Every _ShotCycle seconds, we pick a target + broadcast, then 5 seconds later we fire off a shot.
    self._Data._ShotCycleTimer = self._Data._ShotCycleTimer + _TimeStep

    if math.floor(self._Data._ShotCycleTimer % 30) == 0 then
        self.Log(_MethodName, "Blob cannon has run 30 update ticks.")
    end

    if self._Data._ShotCycleTimer > (self._Data._ShotCycle - 5) then
        --JUST BECAUSE WE CAN SHOOT DOESN'T MEAN WE SHOULD. Check supply levels.
        local _Supplies = Entity():getValue(self._SupplyTag) or 0
        --Remember, if you set _ShotCycleSupply to 0, you will bypass this entirely.
        if _Supplies - self._Data._ShotSupplyConsumed >= self._Data._ShotCycleSupply then
            self.Log(_MethodName, "Picking target and broadcasting shot.")
            self._NextTarget = self.getNextTarget()
            if self._NextTarget then
                self.Log(_MethodName, "Shot Cycle Timer is " .. tostring(self._Data._ShotCycleTimer) .. "/" .. tostring(self._Data._ShotCycle) .. "Successfully picked a target. Broadcasting and firing.")
                if self._Data._CodesCracked then
                    self.broadcastPrepForShotCall(self._NextTarget)
                end
                self.Log(_MethodName, "Setting CanShoot to true.")
                self._CanShoot = true
            end
        end
    end
    if self._Data._ShotCycleTimer > self._Data._ShotCycle then
        if self._CanShoot then
            self.fireMainGun()
        end
        self._Data._ShotCycleTimer = 0 --Reset the timer anyways and catch it on the next pass. The supply is the main bottleneck.
    end
end

--region #SERVER CALLS

function StationSiegeGun.getNextTarget()
    local _MethodName = "Get Next Target"
    local _Station = Entity()
    local _TargetPriority = self._Data._TargetPriority
    local _Rgen = ESCCUtil.getRand()

    local _Enemies = {Sector():getEnemies(_Station.factionIndex)}
    local _TargetCandidates = {}

    self.Log(_MethodName, "Beginning... _TargetPriority is " .. tostring(_TargetPriority))

    if _TargetPriority == 1 then --This is a random pick, so just add all enemies as candidates.
        for _, _Candidate in pairs(_Enemies) do
            table.insert(_TargetCandidates, _Candidate)
        end
    elseif _TargetPriority == 2 then --Go through and find the highest combined max HP + shield total of all enemies, then put any enemies that match that into a table.
        local _TargetValue = 0
        for _, _Candidate in pairs(_Enemies) do
            if self.getEntityMaxHP(_Candidate) > _TargetValue then
                _TargetValue = self.getEntityMaxHP(_Entity)
            end
        end

        for _, _Candidate in pairs(_Enemies) do
            if self.getEntityMaxHP(_Candidate) == _TargetValue then 
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 3 then --Go through and find the highest firepower total of all enemies, then put any enemies that match that into a table.
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
    elseif _TargetPriority == 4 then --Go through and find the lowest % health, then put any enemies that match that into a table.
        local _TargetValue = 0
        for _, _Candidate in pairs(_Enemies) do
            local _HPFactor = self.getEntityCurrentHP(_Candidate) / self.getEntityMaxHP(_Candidate)
            if _HPFactor > _TargetValue then
                _TargetValue = _HPFactor
            end
        end

        for _, _Candidate in pairs(_Enemies) do
            local _HPFactor = self.getEntityCurrentHP(_Candidate) / self.getEntityMaxHP(_Candidate)
            if _HPFactor == _TargetValue then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 5 then --Go through and find the highest % health, then put any enemies that match that into a table.
        local _TargetValue = 1.0
        for _, _Candidate in pairs(_Enemies) do
            local _HPFactor = self.getEntityCurrentHP(_Candidate) / self.getEntityMaxHP(_Candidate)
            if _HPFactor < _TargetValue then
                _TargetValue = _HPFactor
            end
        end

        for _, _Candidate in pairs(_Enemies) do
            local _HPFactor = self.getEntityCurrentHP(_Candidate) / self.getEntityMaxHP(_Candidate)
            if _HPFactor == _TargetValue then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 6 then --Go through and find all enemies with a specific script value - those go in the table.
        for _, _Candidate in pairs(_Enemies) do
            --If _TargetTag is not defined (or is set to false???? (not sure why you'd do this)) no candidates will be added
            if self._Data._TargetTag and _Candidate:getValue(self._Data._TargetTag) then
                table.insert(_TargetCandidates, _Candidate)
            end
        end
    elseif _TargetPriority == 7 then --stations only.
        for _, _Candidate in pairs(_Enemies) do
            if _Candidate.type == EntityType.Station then
                table.insert(_TargetCandidates, _Candidate)
            end 
        end
    elseif _TargetPriority == 8 then --random non-xsotan.
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

function StationSiegeGun.getEntityMaxHP(_Entity)
    local _TotalMHP = 0
    local _Dura = Durability(_Entity.id)
    local _Shield = Shield(_Entity.id)
    
    if _Dura then _TotalMHP = _TotalMHP + _Dura.maximum end
    if _Shield then _TotalMHP = _TotalMHP + _Shield.maximum end

    return _TotalMHP
end

function StationSiegeGun.getEntityCurrentHP(_Entity)
    local _TotalCHP = 0
    local _Dura = Durability(_Entity.id)
    local _Shield = Shield(_Entity.id)
    
    if _Dura then _TotalCHP = _TotalCHP + _Dura.durability end
    if _Shield then _TotalCHP = _TotalCHP + _Shield.durability end

    return _TotalCHP
end

function StationSiegeGun.broadcastPrepForShotCall(_Target)
    local _MethodName = "Broadcast Shot Call"
    self.Log(_MethodName, "Calling Shot.")

    local _Lines = {
        "CHRRK....Secure...main....CHRRRK...pass...CHRRRK...FIRE!...CHRRK", --Zone of the Enders 2 reference that people aren't going to get.
        "CHRRK...Main...CHRRRK...gun...CHRRRK",
        "CHRRK...Targeting...CHRRRK..." .. _Target.name .. "...CHRRRK...die...CHRRK",
        "CHRRK...Round...CHRRRK...loaded...CHRRK....main....CHRRRRRK",
        "CHRRK...Destroy...CHRRRRK...enemy....CHRRK"
    }

    Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, randomEntry(_Lines))
end

function StationSiegeGun.getTags()
    self._SupplyTag = "_escc_Mission_Supply"
end

function StationSiegeGun.fireMainGun()
    local _MethodName = "Fire Main Gun"
    --Shoot the blob gun!
    local _Station = Entity()
    --Get the target.
    local _Enemy = self._NextTarget
    if not _Enemy or not valid(_Enemy) then
        self.Log(_MethodName, "Could not find enemy. Returning.")
        return
    end
    --Calculate the difference between the ORIGIN position and the ENEMY position.
    local _DVec = _Enemy.translationf - _Station.translationf
    local _NDVec = normalize(_DVec)

    local _ShotDamage = self._Data._BaseDamagePerShot

    --Increase shot damage according to supply level.
    local _ShotLevel = 0
    local _ShotMultiplier = 0
    local _SupplyValue = 0
    if self._Data._UseSupply and _Station:getValue("_escc_Mission_Supply") then
        _SupplyValue = _Station:getValue("_escc_Mission_Supply")
        _ShotLevel = math.floor(_SupplyValue / self._Data._SupplyPerLevel)
        _ShotMultiplier = self._Data._SupplyFactor
    end

    local _EntityDamageMultiplier = 1
    if self._Data._UseEntityDamageMult then
        _EntityDamageMultiplier = (_Station.damageMultiplier or 1)
    end

    _ShotDamage = _ShotDamage * (1 + (_ShotLevel * _ShotMultiplier)) * _EntityDamageMultiplier
    
    self.Log(_MethodName, "Fire level " .. tostring(_ShotLevel) .. " shot")
    self.Log(_MethodName, tostring(_SupplyValue) .. " supply available. " .. tostring(self._Data._ShotSupplyConsumed) .. " supply consumed. Incrementing consumed and firing.", 0)
    Sector():addScript("sector/siegegunshot.lua", _Station.translationf, _NDVec * self._Data._Velocity, 30, _ShotDamage, _Station.id, self._Data._FragileShots)

    self._Data._ShotSupplyConsumed = self._Data._ShotSupplyConsumed + self._Data._ShotCycleSupply
end

function StationSiegeGun.setCodesCracked(_Val)
    self._Data._CodesCracked = _Val
end

function StationSiegeGun.resetTimeToActive(_Time)
    self._Data._TimeToActive = _Time
end

--endregion

--region #CLIENT / SERVER CALLS

function StationSiegeGun.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[ESCC Station Siege Gun] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion

--region #SECURE / RESTORE

function StationSiegeGun.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function StationSiegeGun.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
    self.getTags()
end

--endregion