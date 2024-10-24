package.path = package.path .. ";data/scripts/lib/?.lua"

include ("randomext")

local Xsotan = include("story/xsotan")

--namespace Reanimator
Reanimator = {}
local self = Reanimator

self._Data = {}
self._Data._MaxRevenants = nil

self._Debug = 0

function Reanimator.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Adding v2 of reanimator.lua to entity.")

    self._Data = _Values or {}

    self._Data._MaxRevenants = self._Data._MaxRevenants or 5
end

function Reanimator.getUpdateInterval()
    return 30
end

function Reanimator.updateServer(_TimeStep)
    local _MethodName = "On Update Server"
    self.Log(_MethodName, "Running.")

    local _Revenants = {Sector():getEntitiesByScriptValue("is_revenant")}
    local _RevenantCt = #_Revenants
    if _RevenantCt < self._Data._MaxRevenants then
        --Find a suitable wreckage.
        local _Wreck = Reanimator.findSuitableWreck()
        if _Wreck then
            self.Log(_MethodName, "Found wreck - creating Revenant")
            local _WreckPosition = _Wreck.translationf
            --Make a revenant out of it.
            Xsotan.createRevenant(_Wreck)
            --Make the laser.
            self.createLaser(Entity().translationf, _WreckPosition)
        end
    end
end

function Reanimator.findSuitableWreck()
    --Get table of candidate wreckages
    local _Wreckages = {Sector():getEntitiesByType(EntityType.Wreckage)}

    --Pick all candidate wrecks that are above 200 blocks.
    shuffle(random(), _Wreckages)
    local _CandidateWrecks = {}
    for _, _Wreck in pairs(_Wreckages) do
        local _Pl = Plan(_Wreck.id)
        if _Pl.numBlocks >= 200 then
            table.insert(_CandidateWrecks, _Wreck)
        end
    end

    if #_CandidateWrecks > 0 then
        return getRandomEntry(_CandidateWrecks)
    else
        return
    end
end

--region #CLIENT functions

function Reanimator.createLaser(_From, _To)
    if onServer() then
        broadcastInvokeClientFunction("createLaser", _From, _To)
        return
    end

    local _Color = ColorRGB(0.8, 0.0, 0.8)

    local _Sector = Sector()
    local _Laser = _Sector:createLaser(_From, _To, _Color, 16)

    _Laser.maxAliveTime = 1.5
    _Laser.collision = false
end

--endregion

--region #CLIENT / SERVER functions

function Reanimator.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[Reanimator] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function Reanimator.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function Reanimator.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion