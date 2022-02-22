package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

include ("randomext")
local DockAI = include ("ai/dock")

ESCCUtil = include("esccutil")

local _Debug = 0

local _WithdrawThreshold = nil
local _MinTime = 3
local _MaxTime = 6
local _ScriptAdded = false

function initialize(_Threshold, _MinWTime, _MaxWTime, _Invincibility)
    local _MethodName = "Initialize"
    Log(_MethodName, "Starting v4 of ESCC Low HP Withdraw script.")

    --Withdraw at 10% unless otherwise specified.
    _WithdrawThreshold = _Threshold or 0.1
    _MinTime = _MinWTime or 3
    _MaxTime = _MaxWTime or 6
    if _Invincibility then
        local _Dura = Durability()
        _Dura.invincibility = _Invincibility
    end
end

function getUpdateInterval()
    --Update every second.
    return 1
end

function updateServer(_TimeStep)
    local _MethodName = "Update Server"
    local _Entity = Entity()
    local _HPThreshold = _Entity.durability / _Entity.maxDurability
    Log(_MethodName, "HP threshold of entity " .. _Entity.name .. " is " .. tostring(_HPThreshold))
    if _Entity.playerOwned or _Entity.allianceOwned then
        print("[ERROR] Don't attach " .. WITHLog.ModName .. " to player or alliance entities!!!")
        terminate()
        return
    end
    if _HPThreshold <= _WithdrawThreshold then
        Log(_MethodName, "Entity withdrawing in " .. tostring(_MinTime) .. " to " .. tostring(_MaxTime))
        local _Rgen = ESCCUtil.getRand()
        --Add the script again(?), but likely with a shorter withdraw time.
        if not _ScriptAdded then
            _Entity:addScript("entity/utility/delayeddelete.lua", _Rgen:getFloat(_MinTime, _MaxTime))
            _ScriptAdded = true
        end
    end
end

function Log(_MethodName, _Msg)
    if _Debug == 1 then
        print("[ESCC Withdraw on Low HP AI] - [" .. _MethodName .. "] - " .. _Msg)
    end
end