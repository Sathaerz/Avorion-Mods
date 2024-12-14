package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--namespace WarCountdown
WarCountdown = {}
local self = WarCountdown

self._Data = {}

self._Debug = 0

function WarCountdown.initialize()
    local methodName = "Initialize"
    self.Log(methodName, "Initializing War Countdown v2")

    self._Data._TimeToWar = 300
end

function WarCountdown.getUpdateInterval()
    return 1
end

function WarCountdown.updateServer(_TimeStep)
    local methodName = "Update Server"

    if not self._Data._RunDiplomacyCheck then
        self.checkDiplomacy() --Terminates script if already @ war with player.
        self._Data._RunDiplomacyCheck = true
    end

    local _sector = Sector()
    local _entity = Entity()

    self._Data._TimeToWar = self._Data._TimeToWar - _TimeStep

    if not self._Data._SentInitialMessage then
        self.Log(methodName, "Time to War is " .. tostring(self._Data._TimeToWar) .. " - sending initial message")
        _sector:broadcastChatMessage(_entity, ChatMessageType.Chatter, "You have five minutes to leave this sector, or we will declare hostilities! You have been warned.")
        self._Data._SentInitialMessage = true
    end

    if self._Data._TimeToWar <= 60 and not self._Data._SentOneMinuteMessage then
        self.Log(methodName, "Time to War is " .. tostring(self._Data._TimeToWar) .. " - sending one minute message")
        _sector:broadcastChatMessage(_entity, ChatMessageType.Chatter, "You have one minute remaining. Leave this sector or we will commence hostilities.")
        self._Data._SentOneMinuteMessage = true
    end

    if self._Data._TimeToWar <= 0 then
        self.Log(methodName, "Time to War is " .. tostring(self._Data._TimeToWar) .. " - declaring war!")
        _sector:broadcastChatMessage(_entity, ChatMessageType.Chatter, "Targets verified. Commencing hostilities.")
        self.declareWar()
        
        terminate()
        return
    end
end

function WarCountdown.checkDiplomacy()
    local methodName = "Check Diplomacy"
    self.Log(methodName, "Running Check Diplomacy")

    local anyNotAtWar = false

    local _Entity = Entity()
    local _EntityFaction = Faction(_Entity.factionIndex)
    local _Factions = {Sector():getPresentFactions()}

    for _, _Factionidx in pairs(_Factions) do
        local _Faction = Faction(_Factionidx)
        if _Faction.index ~= _Entity.factionIndex and (_Faction.isPlayer or _Faction.isAlliance) then
            self.Log(methodName, "Checking relations between faction : " .. tostring(_EntityFaction.name) .. " and faction : " .. tostring(_Faction.name))
            local _Relations = _EntityFaction:getRelation(_Faction.index)
            if _Relations.status ~= RelationStatus.War then
                self.Log(methodName, "A player is not at war with current faction - this script will not be terminated.")
                anyNotAtWar = true
            end
        end
    end

    if not anyNotAtWar then
        terminate()
        return
    end
end

function WarCountdown.declareWar()
    local _MethodName = "Declare War"
    self.Log(_MethodName, "Running...")
    --Declare war on every present player / alliance every 10 seconds.
    local _Entity = Entity()
    local _EntityFaction = Faction(_Entity.factionIndex)
    local _Galaxy = Galaxy()
    local _Factions = {Sector():getPresentFactions()}
    
    for _, _Factionidx in pairs(_Factions) do
        local _Faction = Faction(_Factionidx)
        if _Faction.index ~= _Entity.factionIndex and (_Faction.isPlayer or _Faction.isAlliance) then
            self.Log(_MethodName, "Checking relations between faction : " .. tostring(_EntityFaction.name) .. " and faction : " .. tostring(_Faction.name))
            local _Relations = _EntityFaction:getRelation(_Faction.index)
            if _Relations.status ~= RelationStatus.War then
                self.Log(_MethodName, "Relations not at war - declaring war.")
                _Galaxy:setFactionRelations(_EntityFaction, _Faction, -100000)
                _Galaxy:setFactionRelationStatus(_EntityFaction, _Faction, RelationStatus.War)
            end

            ShipAI(_Entity.id):registerEnemyFaction(_Faction.index)
        end
    end
end

--region #CLIENT / SERVER functions

function WarCountdown.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[WarCountdown] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function WarCountdown.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function WarCountdown.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion