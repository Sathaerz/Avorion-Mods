package.path = package.path .. ";data/scripts/lib/?.lua"

--namespace SectorWreckageCleaner
SectorWreckageCleaner = {}
local self = SectorWreckageCleaner

self._Debug = 0
self._SizeLimit = 15        --Change this value if you want to mess with the size of the wreckage pieces being deleted. Bigger # = bigger wreckage, generally speaking.
self._MoneyLimit = 100000   --Change this value if you want to mess with the monetary value of the wreckage pieces being deleted.
self._CheckValue = true     --Change this value to false if you want to skip the money check entirely. Advised if you set _SizeLimit higher than 20 or so.
                            --!!! WARNING !!! SETTING THIS TO TRUE WILL CAUSE VALUABLE WRECKAGES WITH FEW BLOCKS TO BE DELETED !!! WARNING !!!

function SectorWreckageCleaner.getUpdateInterval()
    return 10
end

function SectorWreckageCleaner.updateServer()
    local _MethodName = "On Update Server"
    local _Sector = Sector()
    local _Wrecks = {_Sector:getEntitiesByType(EntityType.Wreckage)}
    local _WrecksDeletedCount = 0
    local _WrecksTaggedCount = 0

    for _, _Wreck in pairs(_Wrecks) do
        local _WreckPlan = Plan(_Wreck.id)
        if _WreckPlan.numBlocks and _WreckPlan.numBlocks <= self._SizeLimit then
            if not _Wreck:getValue("_WreckageCleaner_SKIP") then
                local _Delete = false
                if self._CheckValue then
                    local _BlockPlan = _WreckPlan:get()
                    if _BlockPlan:getMoneyValue() <= self._MoneyLimit then
                        _Delete = true
                    end
                else
                    _Delete = true
                end

                if _Delete then
                    _Sector:deleteEntity(_Wreck)
                    _WrecksDeletedCount = _WrecksDeletedCount + 1
                else
                    --Tag this so it won't copy the blockplan again.
                    _Wreck:setValue("_WreckageCleaner_SKIP", true)
                    _WrecksTaggedCount = _WrecksTaggedCount + 1
                end
            end
        end
    end

    self.Log(_MethodName, "Deleted " .. tostring(_WrecksDeletedCount) .. " wreckages and tagged " .. tostring(_WrecksTaggedCount) .. " this update.")
end

function SectorWreckageCleaner.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[SectorWreckageCleaner] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end