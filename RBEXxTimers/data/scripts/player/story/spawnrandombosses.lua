if onServer() then

local _ActiveMods = Mods()
local _swenks = false
for _, _mod in pairs(_ActiveMods) do
    if _mod.id == "2733586433" then --Swenks
        _swenks = true
    end
end

local bcds_SpawnRandomBosses_onSwoksDestroyed_original = SpawnRandomBosses.onSwoksDestroyed
function SpawnRandomBosses.onSwoksDestroyed()
    if bcds_SpawnRandomBosses_onSwoksDestroyed_original then
        bcds_SpawnRandomBosses_onSwoksDestroyed_original()
    end
    Player(callingPlayer):setValue("last_killed_swoks", Server().unpausedRuntime)
end

local bcds_SpawnRandomBosses_updateServer_original = SpawnRandomBosses.updateServer
function SpawnRandomBosses.updateServer(...)
    local aiWasPresent = aiPresent
    if bcds_SpawnRandomBosses_updateServer_original then
        bcds_SpawnRandomBosses_updateServer_original(...)
    end
    if aiWasPresent and not aiPresent then
        Player(callingPlayer):setValue("last_killed_ai", Server().unpausedRuntime)
    end
end

if _swenks then
    local bcds_SpawnRandomBosses_onSwenksDestroyed_original = SpawnRandomBosses.onSwenksDestroyed
    function SpawnRandomBosses.onSwenksDestroyed()
        if bcds_SpawnRandomBosses_onSwenksDestroyed_original then
            bcds_SpawnRandomBosses_onSwenksDestroyed_original()
        end
        Player(callingPlayer):setValue("last_killed_swenks", Server().unpausedRuntime)
    end
end

-- We're getting rid of (ignoring) the original timer logic that makes Swoks and the AI
-- share a timer that's completely different from all others bosses
local bcds_SpawnRandomBosses_onSectorEntered_original = SpawnRandomBosses.onSectorEntered
function SpawnRandomBosses.onSectorEntered(...)
    noSpawnTimer = 0
    bcds_SpawnRandomBosses_onSectorEntered_original(...)
end

-- ...And replacing it with a check on distinct "last killed" values that are more
-- consistent.
function bcds_checkKeyThenRun(key, func, ...)
    return function(...)
        local server = Server()
        local lastTime = Player():getValue(key)
        if lastTime then
            local elapsed = server.unpausedRuntime - lastTime
            if elapsed < 30 * 60 then return end
        end
        func(...)
    end
end

SpawnRandomBosses.trySpawningSwoks = bcds_checkKeyThenRun("last_killed_swoks", SpawnRandomBosses.trySpawningSwoks, ...)
SpawnRandomBosses.trySpawningAI = bcds_checkKeyThenRun("last_killed_ai", SpawnRandomBosses.trySpawningAI, ...)

if _swenks then
    SpawnRandomBosses.trySpawningSwenks = bcds_checkKeyThenRun("last_killed_swenks", SpawnRandomBosses.trySpawningSwenks, ...)
end


end -- if onServer()