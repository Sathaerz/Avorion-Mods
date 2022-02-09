package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")

--namespace SwenksSpecial
SwenksSpecial = {}
local self = SwenksSpecial

self._Data = {}
self._Data._Duration = nil
self._Data._TimeActive = nil
self._Data._MinDura = nil
self._Data._Active = nil
self._Data._SentMessage = false
self._Data._Message = nil

self._Debug = 0

function SwenksSpecial.initialize(_MaxDuration, _MinDurability, _Message)
    _MaxDuration = _MaxDuration or 30
    _MinDurability = _MinDurability or 0.25
    _Message = _Message or "Iron curtain activated!"

    if onServer() then
        Entity():registerCallback("onDamaged", "onDamaged")
    end

    self._Data._Duration = _MaxDuration
    self._Data._MinDura = _MinDurability
    self._Data._TimeActive = 0
    self._Data._Active = false
    self._Data._Message = _Message
end

function SwenksSpecial.getUpdateInterval()
    return 5
end

function SwenksSpecial.updateServer(_TimeStep)
    if self._Data._Active then
        self._Data._TimeActive = self._Data._TimeActive + _TimeStep
        if self._Data._TimeActive > self._Data._Duration then
            Entity().invincible = false
            terminate()
            return
        end
    end
end

function SwenksSpecial.onDamaged(selfIndex, amount, inflictor)
    local _Sector = Sector()
    
    local _Entity = Entity()
    local _Ratio = _Entity.durability / _Entity.maxDurability
    local _MinRatio = self._Data._MinDura

    if _Ratio < _MinRatio then
        if not self._Data._SentMessage then
            self.sendMessage()
            self.spawnReinforcements()
            self._Data._SentMessage = true
        end
        _Entity.invincible = true
        self._Data._Active = true
    end    
end

function SwenksSpecial.spawnReinforcements()
    local _SpawnTable = {}
    table.insert(_SpawnTable, "Pirate")
    table.insert(_SpawnTable, "Pirate")
    table.insert(_SpawnTable, "Marauder")
    if random():getInt(1, 2) == 1 then
        table.insert(_SpawnTable, "Raider")
    else
        table.insert(_SpawnTable, "Ravager")
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

function SwenksSpecial.sendMessage()
    Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, self._Data._Message)
end

--region #CLIENT / SERVER functions

function SwenksSpecial.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[SwenksSpecial] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

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