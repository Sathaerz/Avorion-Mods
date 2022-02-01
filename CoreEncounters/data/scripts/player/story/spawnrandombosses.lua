ESCCUtil = include("esccutil")

local CoreBoss = include("story/coreboss")

local noCoreSpawnTimer = 0

self._Debug = 0

local CoreEncounters_onSectorEntered = SpawnRandomBosses.onSectorEntered
function SpawnRandomBosses.onSectorEntered(_Player, _X, _Y, _ChangeType)
    CoreEncounters_onSectorEntered(_Player, _X, _Y, _ChangeType)

    if noCoreSpawnTimer <= 0 then
        self.trySpawningCoreBoss(_Player, _X, _Y)        
    else
        if self._Debug == 1 then
            print("noCoreSpawnTimer is active - skipping.")
        end
    end
end

local CoreEncounters_updateServer = SpawnRandomBosses.updateServer
function SpawnRandomBosses.updateServer(timeStep)
    CoreEncounters_updateServer(timeStep)

    noCoreSpawnTimer = noCoreSpawnTimer - timeStep
    if self._Debug == 1 then
        print("noCoreSpawnTimer value : " .. tostring(noCoreSpawnTimer))
    end
end

function SpawnRandomBosses.trySpawningCoreBoss(_Player, _X, _Y)
    local _Dist = length(vec2(_X, _Y))
    local _Spawn
    local _Sector = Sector()
    local _PlayerObj = Player(_Player)

    --Don't do anything here unless the player has already completed the story.
    if ESCCUtil.playerBeatStory(_PlayerObj) then
        --Check to see if the player is inside the barrier.
        local MissionUT = include("missionutility")
        if MissionUT.checkSectorInsideBarrier(_X, _Y) then
            local _Specs = SectorSpecifics()
            local _Regular, _Offgrid, _Blocked, _Home = _Specs:determineContent(_X, _Y, Server().seed)

            if not _Regular and not _Offgrid and not _Blocked and not _Home then
                self.consecutiveJumps = self.consecutiveJumps + 1
                if random():test(0.04) or self.consecutiveJumps >= 22 then
                    _Spawn = true
                    -- on spawn reset the jump counter
                    self.consecutiveJumps = 0
                end
            elseif _Regular then
                -- when jumping into the "wrong" sector, reset the jump counter
                self.consecutiveJumps = 0
                if self._Debug == 1 then
                    print("Setting consecutive jumps to 0")
                end
            end
        end
    end
    if self._Debug == 1 then
        print("Consecutive jumps is " .. tostring(self.consecutiveJumps))
    end

    if not _Spawn then
        return
    end
    if _Sector:getEntitiesByScript("data/scripts/entity/story/missionadventurer.lua") then
        return
    end
    --Don't spawn these in a sector with stations - they will wreck house.
    local _Stations = {_Sector:getEntitiesByType(EntityType.Station)}
    if #_Stations > 0 then
        return
    end

    self.spawnCoreBoss(_PlayerObj, _X, _Y)
end

function SpawnRandomBosses.spawnCoreBoss(_Player, _X, _Y)
    if self._Debug == 1 then
        print("Spawning core boss.")
    end
    CoreBoss.spawn(_Player, _X, _Y)
end

function SpawnRandomBosses.onCoreBossDestroyed()
    --You really don't want these guys to spawn more often, trust me.
    noSpawnTimer = 30 * 60
    noCoreSpawnTimer = 180 * 60

    if self._Debug == 1 then
        print("Core boss destroyed - setting noSpawnTimer : " .. tostring(noSpawnTimer) .. " / noCoreSpawnTimer : " .. tostring(noCoreSpawnTimer))
    end
end