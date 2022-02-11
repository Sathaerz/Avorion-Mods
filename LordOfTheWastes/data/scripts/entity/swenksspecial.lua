package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")

--namespace SwenksSpecial
SwenksSpecial = {}
local self = SwenksSpecial

self._Data = {}

self._Data._Active = nil

self._Data._InvulnData = {
    { 
        _Message = "Think you have me, do you?",
        _Point = 0.75,
        _Activated = false,
        _TimeActive = 0,
        _MaxTimeActive = 30
    },
    { 
        _Message = "More! More!!",
        _Point = 0.5,
        _Activated = false,
        _TimeActive = 0,
        _MaxTimeActive = 35
    },
    { 
        _Message = "I'll tear you to pieces, wretch!",
        _Point = 0.25,
        _Activated = false,
        _TimeActive = 0,
        _MaxTimeActive = 40
    }
}

self._Debug = 1

function SwenksSpecial.initialize(_MaxDuration, _MinDurability, _Message)
    if onServer() then
        Entity():registerCallback("onDamaged", "onDamaged")
    end
end

function SwenksSpecial.getUpdateInterval()
    return 5
end

function SwenksSpecial.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    if self._Data._Active then
        for _, _data in pairs(self._Data._InvulnData) do
            if _data._Activated and _data._TimeActive <= _data._MaxTimeActive then
                local _TimeActive = _data._TimeActive
                local _MaxTimeActive = _data._MaxTimeActive
                self.Log(_MethodName, "Invuln is active - time active : " .. tostring(_TimeActive) .. " out of : " .. tostring(_MaxTimeActive))
                
                _TimeActive = _TimeActive + _TimeStep
                if _TimeActive >= _MaxTimeActive then
                    Entity().invincible = false
                    self._Data._Active = false
                end
                _data._TimeActive = _TimeActive
            end
        end
    end
end

function SwenksSpecial.onDamaged(selfIndex, amount, inflictor)
    if not self._Data._Active then
        local _Sector = Sector()
    
        local _Entity = Entity()
        local _Ratio = _Entity.durability / _Entity.maxDurability

        for _, _data in pairs(self._Data._InvulnData) do
            if not _data._Activated and _Ratio <= _data._Point then
                _data._Activated = true
                self._Data._Active = true
                _Entity.invincible = true
                self.sendMessage(_data._Message)
                self.spawnReinforcements()
            end
        end
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

function SwenksSpecial.sendMessage(_Msg)
    Sector():broadcastChatMessage(Entity(), ChatMessageType.Chatter, _Msg)
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