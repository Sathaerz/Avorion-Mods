package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")

--namespace SwenksSpecial
SwenksSpecial = {}
local self = SwenksSpecial

self._Debug = 0

self._Data = {}

self._Data._Active = nil
self._Data._ReinforcementsToSpawn = 0
self._Data._Invoked = false
self._Data._Complained = false

self._Data._InvulnData = {
    { 
        _Message = "Think you have me, do you?",
        _Point = 0.75,
        _Activated = false,
        _RunUpdate = false,
        _TimeActive = 0,
        _MaxTimeActive = 30
    },
    { 
        _Message = "More! More!!",
        _Point = 0.5,
        _Activated = false,
        _RunUpdate = false,
        _TimeActive = 0,
        _MaxTimeActive = 35
    },
    { 
        _Message = "I'll tear you to pieces, wretch!",
        _Point = 0.25,
        _Activated = false,
        _RunUpdate = false,
        _TimeActive = 0,
        _MaxTimeActive = 40
    }
}

function SwenksSpecial.initialize()
    local methodName = "Initialize"
    if onServer() then
        local _entity = Entity()

        _entity:setValue("SDKExtendedShieldsDisabled", true) --Need to disable these to avoid messing with his invulnerability.
        _entity:registerCallback("onDamaged", "onDamaged")

        if Sector():registerCallback("onDestroyed", "swenksOnDestroyed") == 1 then
            self.Log(methodName, "Could not register onEntityDestroyed callback.")
        end
    end
end

function SwenksSpecial.getUpdateInterval()
    return 2
end

function SwenksSpecial.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    self._Data._Invoked = false

    local swenks = Entity()

    if self._Data._Active then
        for _, _data in pairs(self._Data._InvulnData) do
            if _data._Activated and _data._RunUpdate then
                local _TimeActive = _data._TimeActive
                local _MaxTimeActive = _data._MaxTimeActive
                self.Log(_MethodName, "Invuln is active - time active : " .. tostring(_TimeActive) .. " out of : " .. tostring(_MaxTimeActive))
                
                _TimeActive = _TimeActive + _TimeStep
                if _TimeActive >= _MaxTimeActive then
                    swenks.invincible = false
                    Sector():broadcastChatMessage("", 3, "${_SHIP}'s iron curtain expires!" % { _SHIP = swenks.translatedTitle })

                    self._Data._Active = false
                    _data._RunUpdate = false
                else
                    local _random = random()

                    local direction = _random:getDirection()
                    local direction2 = _random:getDirection()
                    local direction3 = _random:getDirection()
                    broadcastInvokeClientFunction("animation", direction, direction2, direction3)
                end
                _data._TimeActive = _TimeActive
            end
        end
    end

    --Spawn reinforcements each update.
    if self._Data._ReinforcementsToSpawn > 0 then
        local _ReinforcementCt = self._Data._ReinforcementsToSpawn
        self.spawnReinforcements(_ReinforcementCt)

        _ReinforcementCt = _ReinforcementCt - 1
        self._Data._ReinforcementsToSpawn = _ReinforcementCt
    end
end

function SwenksSpecial.onDamaged(selfIndex, amount, inflictor)
    if not self._Data._Active then
        local _Sector = Sector()
    
        local swenks = Entity()
        local _Ratio = swenks.durability / swenks.maxDurability

        for _, _data in pairs(self._Data._InvulnData) do
            if not _data._Activated and _Ratio <= _data._Point then
                _data._Activated = true
                _data._RunUpdate = true
                self._Data._Active = true
                swenks.invincible = true
                _Sector:broadcastChatMessage("", 3, "${_SHIP} activates his iron curtain!" % { _SHIP = swenks.translatedTitle })
                self.sendMessage(_data._Message)
                self._Data._ReinforcementsToSpawn = 4
            end
        end
    end
end

--Called in the Sector context.
function SwenksSpecial.swenksOnDestroyed(_Entityidx, _LastDamageInflictor)
    local _MethodName = "swenksOnDestroyed"
    self.Log(_MethodName, "Calling...")

    local _DestroyedEntity = Entity(_Entityidx)
    if _DestroyedEntity.type ~= EntityType.Ship and _DestroyedEntity.type ~= EntityType.Station then
        self.Log(_MethodName, "Destroyed entity type was not a ship or station - returning.")
        return
    end
    local _TargetFaction = _DestroyedEntity.factionIndex

    local _Ships = {Sector():getEntitiesByFaction(_TargetFaction)}
    for _, _Ship in pairs(_Ships) do
        if _Ship:hasScript("swenksspecial.lua") then
            _Ship:invokeFunction("data/scripts/entity/story/swenksspecial.lua", "reduceInvulnTime")
        end
    end
end

function SwenksSpecial.reduceInvulnTime()
    local methodName = "Reduce Invuln Time"
    self.Log(methodName, "Invoking...")

    if not self._Data._Invoked and self._Data._Active then
        self.Log(methodName, "Invuln is active & invoked is false - reducing all active points by 5 seconds.")

        if not self._Data._Complained then
            self.Log(methodName, "Complaining")
            self.sendMessage("The avenger system takes power from the iron curtain?! I'm gonna kill that junk slinger after I'm done with you!")
            self._Data._Complained = true
        end

        for _, _data in pairs(self._Data._InvulnData) do
            if _data._Activated then
                _data._TimeActive = _data._TimeActive + 5
            end
        end

        self._Data._Invoked = true
    end   
end

function SwenksSpecial.spawnReinforcements(_Ct)
    local _SpawnTable = {}
    if _Ct == 4 then
        table.insert(_SpawnTable, "Pirate")
    elseif _Ct == 3 then
        table.insert(_SpawnTable, "Pirate")
    elseif _Ct == 2 then
        table.insert(_SpawnTable, "Marauder")
    elseif _Ct == 1 then
        if random():getInt(1, 2) == 1 then
            table.insert(_SpawnTable, "Raider")
        else
            table.insert(_SpawnTable, "Ravager")
        end
    end

    local generator = AsyncPirateGenerator(SwenksSpecial, onReinforcementsFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    local pirate_positions = generator:getStandardPositions(#_SpawnTable, distance)
    for _, p in pairs(_SpawnTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function SwenksSpecial.onReinforcementsFinished(_Generated)
    SpawnUtility.addEnemyBuffs(_Generated)
end

function SwenksSpecial.sendMessage(_Msg)
    Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, _Msg)
end

--region #CLIENT FUNCTIONS

function SwenksSpecial.animation(direction, direction2, direction3)
    local _Sector = Sector()
    _Sector:createHyperspaceJumpAnimation(Entity(), direction, ColorRGB(0.25, 0.25, 0.25), 0.4)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction2, ColorRGB(0.25, 0.25, 0.25), 0.4)
    _Sector:createHyperspaceJumpAnimation(Entity(), direction3, ColorRGB(0.25, 0.25, 0.25), 0.4)
end

--endregion

--region #LOG SECURE / RESTORE

function SwenksSpecial.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[SwenksSpecial] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

function SwenksSpecial.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function SwenksSpecial.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion