package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

include ("randomext")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace TheDigMinerAI
TheDigMinerAI = {}
local self = TheDigMinerAI

self._Debug = 0

self._Data = {}

local endpoint

function TheDigMinerAI.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Starting v9 of The Dig Miner AI Script.")

    self._Data = _Values or {}

    self._Data.timeInSector = 0
    self._Data.withdrawCommandSent = false
    self._Data.jumping = false

    local dir = random():getDirection()
    endpoint = dir * 20000
end

function TheDigMinerAI.getUpdateInterval()
    --Update every 5 seconds.
    return 5
end

--region #SERVER CALLS

function TheDigMinerAI.updateServer(timeStep)
    local _MethodName = "Update Server"

    self._Data.timeInSector = self._Data.timeInSector + timeStep
    self.sync() --send timeInSector to client.

    local _Entity = Entity()
    local _HPThreshold = _Entity.durability / _Entity.maxDurability

    if self._Data.timeInSector >= 240 and _HPThreshold < 0.25 and not self._Data.withdrawCommandSent then
        self.Log(_MethodName, "Ship below HP threshold and requisite time has passed. Withdrawing.")
        self._Data.withdrawCommandSent = true
    end

    if self._Data.withdrawCommandSent then
        --Get rid of the mine script if applicable.
        local safetyBreakout = 0
        while _Entity:hasScript("ai/mine.lua") and safetyBreakout < 10 do
            _Entity:removeScript("ai/mine.lua")
            safetyBreakout = safetyBreakout + 1
        end

        --set endpoint if applicable
        if not endpoint then
            local dir = random():getDirection()
            endpoint = dir * 20000
        end

        --fly to endpoint
        local shipAI = ShipAI()
        shipAI:setFlyLinear(endpoint, 0, false)

        --Check for nearby asteroids. If there are none, jump out.
        local _EntitySphere = _Entity:getBoundingSphere()
        local _AsteroidCheckSphere = Sphere(_EntitySphere.center, _EntitySphere.radius * 10)
        local _NearbyEntities = {Sector():getEntitiesByLocation(_AsteroidCheckSphere)}
        local _NearbyAsteroids = 0

        for _, nearbyEntity in pairs(_NearbyEntities) do
            if nearbyEntity.type == EntityType.Asteroid then
                _NearbyAsteroids = _NearbyAsteroids + 1
            end
        end

        self.Log(_MethodName, "Withdrawing. Asteroids nearby: " .. tostring(_NearbyAsteroids))

        if _NearbyAsteroids == 0 and not self._Data.jumping then
            _Entity:addScript("utility/delayeddelete.lua", random():getFloat(5, 10))
            self._Data.jumping = true
        end
    end
end

--endregion

--region #CLIENT CALLS

function TheDigMinerAI.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)
    local _Entity = Entity()
    local _Faction = Faction()

    local craft = _Player.craft
    if craft == nil then
        self.Log(_MethodName, "Player does not have a craft - returning false.")
        return false 
    end

    local craftFaction = _Player.craftFaction

    if craftFaction and _Faction then
        local relation = craftFaction:getRelation(_Faction.index)
        if relation.status == RelationStatus.War then
            self.Log(_MethodName, "Player is at war with the faction - returning false.")
            return false 
        end
        if relation.level <= -80000 then 
            self.Log(_MethodName, "Player's relation with faction is bad - returning false.")
            return false 
        end
    end

    local targetplayerid = _Entity:getValue("_thedig_player")

    if playerIndex ~= targetplayerid then
        self.Log(_MethodName, "Player index does not match - returning false.")
        return false
    end

    if self._Data.withdrawCommandSent then
        self.Log(_MethodName, "Ship is already withdrawing.")
        return false
    end

    local _HPThreshold = _Entity.durability / _Entity.maxDurability
    if _HPThreshold > 0.5 then
        self.Log(_MethodName, "Miner HP threshold is too high - returning false.")
        return false
    end

    return true
end

function TheDigMinerAI.initUI()
    ScriptUI():registerInteraction("Your ship is damaged. Please withdraw.", "onPleaseWithdraw", 99)
end

function TheDigMinerAI.onPleaseWithdraw()
    local methodName = "On Please Withdraw"
    local d0 = {}

    self.Log(methodName, "Time in sector is " .. tostring(self._Data.timeInSector))

    if self._Data.timeInSector < 210 then
        d0.text = "But we just got here. Let us do some mining before we pull out!"
    else
        d0.text = "Understood! Withdrawing from the asteroid field. We'll activate our hyperdrive when we're clear."
        d0.onEnd = "sendWithdrawCommand"
    end

    ScriptUI():showDialog(d0)
end

function TheDigMinerAI.sendWithdrawCommand()
    local methodName = "Send Withdraw Command"

    if onClient() then
        self.Log(methodName, "Called on client => invoking on server.")
        invokeServerFunction("sendWithdrawCommand")
    else
        self.Log(methodName, "Called on server.")
        Entity():removeScript("ai/mine.lua")
        local dir = random():getDirection()
        local endpoint = dir * 20000

        local shipAI = ShipAI()
        shipAI:setFlyLinear(endpoint, 0, false) --Avoid obstacles so we don't blow ourselves up.
        self._Data.withdrawCommandSent = true
    end
end
callable(TheDigMinerAI, "sendWithdrawCommand")

--endregion

--region #SECURE / RESTORE / LOG / SYNC CALLS

function TheDigMinerAI.sync(_Data_In)
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
callable(TheDigMinerAI, "sync")

function TheDigMinerAI.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function TheDigMinerAI.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

function TheDigMinerAI.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[The Dig Miner AI] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion