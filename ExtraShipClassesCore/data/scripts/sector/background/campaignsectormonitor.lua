package.path = package.path .. ";data/scripts/lib/?.lua"

--namespace CampaignSectorMonitor
CampaignSectorMonitor = {}
local self = CampaignSectorMonitor

self._Debug = 0

function CampaignSectorMonitor.initialize()
    local _MethodName = "Initailize"
    self.Log(_MethodName, "Beginning...")
end

function CampaignSectorMonitor.clearMissionAssets(_DeleteOtherAssets, _DeleteEverything)
    --We can't use sector/deleteentitiesonplayerleft.lua (Which is my new best friend.)
    local _MethodName = "Clear Mission Assets"
    local _Sector = Sector()

    self.Log(_MethodName, "Invoked...")
    local _Pirates = {_Sector:getEntitiesByScriptValue("is_pirate")}
    if not _Pirates then 
        self.Log(_MethodName, "WARNING - _Pirates is nil")
    end

    local _Xsotan = {_Sector:getEntitiesByScriptValue("is_xsotan")}
    if not _Xsotan then 
        self.Log(_MethodName, "WARNING - _Xsotan is nil")
    end

    self.Log(_MethodName, "Iterating through and clearing out all pirates.")
    for _, _Pir in pairs(_Pirates) do
        _Sector:deleteEntity(_Pir)
    end

    self.Log(_MethodName, "Iterating through and clearing out all xsotan.")
    for _, _Xso in pairs(_Xsotan) do
        _Sector:deleteXsotan(_Xso)
    end

    self.Log(_MethodName, "Removing defense / shipment controller scripts.")
    if _Sector:hasScript("sector/background/defensecontroller.lua") then
        _Sector:removeScript("sector/background/defensecontroller.lua")
    end

    if _Sector:hasScript("sector/background/shipmentcontroller.lua") then
        _Sector:removeScript("sector/background/shipmentcontroller.lua")
    end

    if _DeleteOtherAssets then
        self.Log(_MethodName, "Deleting all other non player-owned assets")
        local _EntityTypes = { EntityType.Ship, EntityType.Station, EntityType.Torpedo, EntityType.Fighter, EntityType.Asteroid }
        if _DeleteEverything then
            self.Log(_MethodName, "Adding non-permanent entities to deletion table.")
            table.insert(_EntityTypes, EntityType.Wreckage)
            table.insert(_EntityTypes, EntityType.Unknown)
            table.insert(_EntityTypes, EntityType.Other)
            table.insert(_EntityTypes, EntityType.Loot)
        end
        for _, _EntityType in pairs(_EntityTypes) do
            for _, _En in pairs({_Sector:getEntitiesByType(_EntityType)}) do
                if _En.playerOwned or _En.allianceOwned then
                    self.Log(_MethodName, "Found player or alliance owned entity. This will not be auto-cleaned.")
                else
                    _Sector:deleteEntity(_En)
                end
            end
        end
    end

    --Finally, the script removes itself.
    terminate()
end

--region #CLIENT / SERVER CALLS

function CampaignSectorMonitor.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[ESCC Sector Monitor] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion