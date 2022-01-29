package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Don't remove the namespace comment!!! The script could break.
--namespace AdaptiveDefense
AdaptiveDefense = {}

AdaptiveDefense._Data = {}
AdaptiveDefense._Data._Resistance = 0.55
AdaptiveDefense._Data._PhysDamageTaken = 0
AdaptiveDefense._Data._AntiDamageTaken = 0
AdaptiveDefense._Data._PlasDamageTaken = 0
AdaptiveDefense._Data._EnRGDamageTaken = 0
AdaptiveDefense._Data._ElecDamageTaken = 0
AdaptiveDefense._Data._OverallDamageTaken = 0
AdaptiveDefense._Data._FirstUpdateRun = false
AdaptiveDefense._Data._HullAdapted = false

local _DamageTaken = 0
local _DamageTakenTable = {}

AdaptiveDefense._Debug = 0

function AdaptiveDefense.initialize()
    local _MethodName = "Initialize"
    local _Entity = Entity()

    if onServer() then
        --Pulse cannon gang sit down.
        _Entity:addAbsoluteBias(StatsBonuses.ShieldImpenetrable, 1)

        if _Entity:registerCallback("onShieldDamaged", "onShieldDamaged") == 1 then
            AdaptiveDefense.Log(_MethodName, "Could not attach onShieldDamaged callback.")
        end
        if _Entity:registerCallback("onDamaged", "onDamaged") == 1 then
            AdaptiveDefense.Log(_MethodName, "Could not attach onDamaged callback.")
        end
    end
end

function AdaptiveDefense.getUpdateInterval()
    if AdaptiveDefense._Data._FirstUpdateRun then 
        return 20
    else
        return 1
    end
end

function AdaptiveDefense.updateServer(_TimeStep)
    local _MethodName = "Update Server"
    AdaptiveDefense.Log("Amount of damage taken: " .. tostring(_DamageTaken))
    if _DamageTaken > 0 then
        AdaptiveDefense.Log(_MethodName, "Adapting defenses to offensive pressure...")

        local _AdaptToDamage = 0
        local _AdaptToType = DamageType.Physical
        for _DmgType, _DmgTaken in pairs(_DamageTakenTable) do
            if _DmgTaken > _AdaptToDamage then
                _AdaptToDamage = _DmgTaken
                _AdaptToType = _DmgType
            end
        end

        AdaptiveDefense.Log(_MethodName, "Setting shield resistance to " .. tostring(_AdaptToType))

        local _Shield = Shield()
        if _Shield then
            AdaptiveDefense.Log(_MethodName, "Shield exists - setting resistance amount.")
            _Shield:setResistance(_AdaptToType, AdaptiveDefense._Data._Resistance)
        end

        AdaptiveDefense._Data._FirstUpdateRun = true
    else
        AdaptiveDefense.Log(_MethodName, "Have not taken damage yet - nothing to adapt to.")
    end
end

function AdaptiveDefense.adaptHull()
    local _AdaptToDamage = 0
    local _AdaptToType = DamageType.Physical
    for _DmgType, _DmgTaken in pairs(_DamageTakenTable) do
        if _DmgTaken > _AdaptToDamage then
            local _DmgFactor = 1
            --Weight plasma less heavily and antimatter more heavily when factoring in what to resist on the hull.
            if _DmgType == DamageType.AntiMatter then
                _DmgFactor = 1.5
            elseif _DmgType == DamageType.Plasma then
                _DmgFactor = 0.5
            end

            _AdaptToDamage = _DmgTaken * _DmgFactor
            _AdaptToType = _DmgType
        end
    end

    AdaptiveDefense.Log(_MethodName, "Setting hull resistance to " .. tostring(_AdaptToType))

    local _Durability = Durability()
    if _Durability then
        AdaptiveDefense.Log(_MethodName, "Durability exists - setting resistance amount.")
        _Durability:setWeakness(_AdaptToType, AdaptiveDefense._Data._Resistance * -1.1)
    end
end

function AdaptiveDefense.onShieldDamaged(_ObjectIndex, _Amount, _DamageType, _InflictorID)
    local _MethodName = "On Shield Damaged"
    AdaptiveDefense.Log(_MethodName, "Running On Shield Damage callback - damage amount is " .. tostring(_Amount) .. " and damage type is " .. tostring(_DamageType))
    if not _DamageType or not _Amount then
        return
    else
        AdaptiveDefense.adaptDefense(_DamageType, _Amount)
    end
end

function AdaptiveDefense.onDamaged(_ObjectIndex, _Amount, _Inflictor, _DamageSource, _DamageType)
    local _MethodName = "On Damaged"
    if not _DamageType or not _Amount then
        return
    else
        AdaptiveDefense.adaptDefense(_DamageType, _Amount)
    end

    if not AdaptiveDefense._Data._HullAdapted then
        --AdaptiveDefense.Log(_MethodName, "Shield deactivated - permanently adapting hull to offensive pressure...")
        --AdaptiveDefense.adaptHull()
        --AdaptiveDefense._Data._HullAdapted = true --Per Koonschi, this lag bombs the game, so we should only do this once for performance reasons.
    end
end

function AdaptiveDefense.adaptDefense(_DamageType, _Amount)
    _DamageTaken = (_DamageTaken or 0) + _Amount
    _DamageTakenTable[_DamageType] = (_DamageTakenTable[_DamageType] or 0) + _Amount
end

--region #CLIENT / SERVER functions

function AdaptiveDefense.Log(_MethodName, _Msg)
    if AdaptiveDefense._Debug == 1 then
        print("[AdaptiveDefense] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function AdaptiveDefense.secure()
    local _MethodName = "Secure"
    AdaptiveDefense.Log(_MethodName, "Securing AdaptiveDefense._Data")

    AdaptiveDefense._Data._OverallDamageTaken = _DamageTaken
    AdaptiveDefense._Data._PhysDamageTaken = _DamageTakenTable[DamageType.Physical]
    AdaptiveDefense._Data._AntiDamageTaken = _DamageTakenTable[DamageType.AntiMatter]
    AdaptiveDefense._Data._PlasDamageTaken = _DamageTakenTable[DamageType.Plasma]
    AdaptiveDefense._Data._EnRGDamageTaken = _DamageTakenTable[DamageType.Energy]
    AdaptiveDefense._Data._ElecDamageTaken = _DamageTakenTable[DamageType.Electric]

    return AdaptiveDefense._Data
end

function AdaptiveDefense.restore(_Values)
    local _MethodName = "Restore"
    AdaptiveDefense.Log(_MethodName, "Restoring AdaptiveDefense._Data")
    AdaptiveDefense._Data = _Values

    _DamageTaken = AdaptiveDefense._Data._OverallDamageTaken
    _DamageTakenTable[DamageType.Physical] = AdaptiveDefense._Data._PhysDamageTaken
    _DamageTakenTable[DamageType.AntiMatter] = AdaptiveDefense._Data._AntiDamageTaken
    _DamageTakenTable[DamageType.Plasma] = AdaptiveDefense._Data._PlasDamageTaken
    _DamageTakenTable[DamageType.Energy] = AdaptiveDefense._Data._EnRGDamageTaken
    _DamageTakenTable[DamageType.Electric] = AdaptiveDefense._Data._ElecDamageTaken
end

--endregion