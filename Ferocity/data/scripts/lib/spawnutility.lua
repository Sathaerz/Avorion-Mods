package.path = package.path .. ";?"

local extraTierDistributions = {}
extraTierDistributions[Difficulty.Insane] = 0.33
extraTierDistributions[Difficulty.Hardcore] = 0.31
extraTierDistributions[Difficulty.Expert] = 0.29
extraTierDistributions[Difficulty.Veteran] = 0.27
extraTierDistributions[Difficulty.Normal] = 0.25
extraTierDistributions[Difficulty.Easy] = 0.21
extraTierDistributions[Difficulty.Beginner] = 0.19

SpawnUtility._Debug = 0

local xmods = Mods()
local hasIncreasingThreat = false
for _, p in pairs(xmods) do
    if p.id == "2208370349" then
        hasIncreasingThreat = true
        break
    end
end

local Ferocity_addToughness = SpawnUtility.addToughness
function SpawnUtility.addToughness(entity, level)
    local _MethodName = "Add Toughness"
    if not entity or not valid(entity) then return end
    SpawnUtility.Log(_MethodName, "Adding toughness.")

    local _Difficulty = GameSettings().difficulty
    local _dt = extraTierDistributions[_Difficulty]
    local _Hatred = 0
    
    local players = {Sector():getPlayers()}
    local _PlayerCt = #players

    if _PlayerCt > 0 and hasIncreasingThreat then
        local ITUtil = include("increasingthreatutility")
        local hatedplayers = ITUtil.getSectorPlayersByHatred(entity.factionIndex)
        _Hatred = math.min(hatedplayers[1].hatred, 1000) --cap at +20% @ 1000
        _dt = _dt + ((_Hatred / 50) / 100)
    end

    local _EnemyTier = 1
    if random():test(_dt) then
        _EnemyTier = _EnemyTier + 1 --T2
        if random():test(_dt) then
            _EnemyTier = _EnemyTier + 1 --T3
            if random():test(_dt) then
                _EnemyTier = _EnemyTier + 1 --T4
            end
        end
    end

    SpawnUtility.Log(_MethodName, "Adding tier " .. tostring(_EnemyTier) .. " enemy.")

    if _EnemyTier == 1 then
        SpawnUtility.Log(_MethodName, "adding a standard buff.")
        Ferocity_addToughness(entity, level)
    elseif _EnemyTier == 2 then
        SpawnUtility.Log(_MethodName, "adding a tier 2 buff.")
        SpawnUtility.addTier2Buff(entity, level)
    elseif _EnemyTier == 3 then
        SpawnUtility.Log(_MethodName, "adding a tier 3 buff.")
        SpawnUtility.addTier3Buff(entity, level)
    elseif _EnemyTier == 4 then
        SpawnUtility.Log(_MethodName, "adding a tier 4 buff.")
        SpawnUtility.addTier4Buff(entity, level, _Hatred)
    end
end

function SpawnUtility.addTier2Buff(entity, level)
    local _MethodName = "Add Tier 2 Buff"
    if not entity or not valid(entity) then 
        SpawnUtility.Log(_MethodName, "ERROR - Entity not valid - returning.")
        return 
    else
        SpawnUtility.Log(_MethodName, "Adding buff...")
    end

    local hpFactor = 4
    local dmgFactor = 2
    local isUnreal = false

    if level == 1 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Deadly "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Deadly "%_T .. entity.title
            end
        end
        hpFactor = 4
        dmgFactor = 2
    elseif level == 2 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Ferocious "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Ferocious "%_T .. entity.title
            end
        end
        hpFactor = 5
        dmgFactor = 3
    elseif level == 3 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Unreal "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Unreal "%_T .. entity.title
            end
        end
        isUnreal = true
        hpFactor = 5
        dmgFactor = 4
    end

    local durability = Durability(entity)
    if durability then durability.maxDurabilityFactor = (durability.maxDurabilityFactor or 0) + hpFactor end

    local shield = Shield(entity)
    if shield then shield.maxDurabilityFactor = (shield.maxDurabilityFactor or 0) + hpFactor end

    if dmgFactor ~= 1 then entity.damageMultiplier = (entity.damageMultiplier or 1) * dmgFactor end

    -- increase resistances if existing
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    SpawnUtility.applyResistanceFactorBuff(entity, level, distToCenter)

    if isUnreal then
        --Add a special script.
        entity:addScriptOnce("ferocityphasemode.lua")
    end
end

function SpawnUtility.addTier3Buff(entity, level)
    if not entity or not valid(entity) then return end

    local hpFactor = 5
    local dmgFactor = 3
    local isEternal = false

    if level == 1 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Ultimate "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Ultimate "%_T .. entity.title
            end
        end
        hpFactor = 5
        dmgFactor = 3
    elseif level == 2 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Paragon "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Paragon "%_T .. entity.title
            end
        end
        hpFactor = 5
        dmgFactor = 4
    elseif level == 3 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Eternal "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Eternal "%_T .. entity.title
            end
        end
        isEternal = true
        hpFactor = 6
        dmgFactor = 5
    end

    local durability = Durability(entity)
    if durability then durability.maxDurabilityFactor = (durability.maxDurabilityFactor or 0) + hpFactor end

    local shield = Shield(entity)
    if shield then shield.maxDurabilityFactor = (shield.maxDurabilityFactor or 0) + hpFactor end

    if dmgFactor ~= 1 then entity.damageMultiplier = (entity.damageMultiplier or 1) * dmgFactor end

    -- increase resistances if existing
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    SpawnUtility.applyResistanceFactorBuff(entity, level, distToCenter)

    if isEternal then
        --Add a special script.
        entity:addScriptOnce("ferocityeternal.lua")
    end
end

function SpawnUtility.addTier4Buff(entity, level, highestHatred)
    if not entity or not valid(entity) then return end

    local hatredFactor = highestHatred / 100
    local hpFactor = 6
    local dmgFactor = 5
    local addUnreal = false
    local addEternal = false

    if level == 1 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Cataclysmic "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Cataclysmic "%_T .. entity.title
            end
        end
        hpFactor = hpFactor + (hatredFactor * 0.01)
        dmgFactor = dmgFactor + (hatredFactor * 0.01)
    elseif level == 2 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Apocalyptic "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Apocalyptic "%_T .. entity.title
            end
        end
        hpFactor = hpFactor + (hatredFactor * 0.015)
        dmgFactor = dmgFactor + (hatredFactor * 0.015)
        addUnreal = true
    elseif level == 3 then
        if entity.title then
            local titleArgs = entity:getTitleArguments()
            if titleArgs then
                titleArgs.toughness = "Eschaton "%_T
                entity:setTitleArguments(titleArgs)
            else
                entity.title = "Eschaton "%_T .. entity.title
            end
        end
        hpFactor = hpFactor + (hatredFactor * 0.02)
        dmgFactor = dmgFactor + (hatredFactor * 0.02)
        addUnreal = true
        addEternal = true
    end

    local durability = Durability(entity)
    if durability then durability.maxDurabilityFactor = (durability.maxDurabilityFactor or 0) + hpFactor end

    local shield = Shield(entity)
    if shield then shield.maxDurabilityFactor = (shield.maxDurabilityFactor or 0) + hpFactor end

    if dmgFactor ~= 1 then entity.damageMultiplier = (entity.damageMultiplier or 1) * dmgFactor end

    -- increase resistances if existing
    local x, y = Sector():getCoordinates()
    local distToCenter = math.sqrt(x * x + y * y)
    SpawnUtility.applyResistanceFactorBuff(entity, level, distToCenter)

    if addUnreal then
        entity:addScriptOnce("ferocityphasemode.lua")
    end
    if addEternal then
        --Add a special script.
        entity:addScriptOnce("ferocityeternal.lua")
    end
end

function SpawnUtility.Log(_MethodName, _Msg)
    if SpawnUtility._Debug == 1 then
        print("[Ferocity] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end