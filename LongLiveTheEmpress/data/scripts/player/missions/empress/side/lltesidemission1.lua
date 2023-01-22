--[[
    Rank 1 side mission.
    Ambush Pirate Raiders
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - N/A
    ROUGH OUTLINE
        - Player goes to designated location.
        - Player waits for a short period of time.
        - Pirates start jumping in after a short wait.
        - Player kills all of the pirates. That's it. This is a very straightforward mission.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - Pirates will use standard threat ships from the corresponding danger table.
            - There will be at least 3 waves of pirates.
        6 - [These conditions are present at danger level 6 and above]
            - +1 wave of pirates (4 waves total)
        10 - [These conditions are present at danger level 10]
            - +1 wave of pirates (5 waves total)
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes.
include ("callable")
include("structuredmission")

ESCCUtil = include("esccutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Ambush Pirate Raiders"

--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Ambush Pirate Raiders Begin...")

    if onServer()then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local specs = SectorSpecifics()
            local rgen = ESCCUtil.getRand()
            local templateBlacklist = ESCCUtil.getStandardTemplateBlacklist()
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local _OtherLocations = MissionUT.getMissionLocations() or {}
            local coords = specs.getShuffledCoordinates(rgen, x, y, 5, 12)
            local serverSeed = Server().seed
            local target = nil

            --Look for a sector that's not on the blacklist.
            for _, coord in pairs(coords) do
                mission.Log(_MethodName, "Evaluating Coord X: " .. tostring(coord.x) .. " - Y: " .. tostring(coord.y))
                local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)

                if insideBarrier == MissionUT.checkSectorInsideBarrier(coord.x, coord.y) and not _OtherLocations:contains(coord.x, coord.y) then
                    if not regular and not offgrid and not blocked and not home then
                        if not Galaxy():sectorExists(coord.x, coord.y) then
                            target = coord
                            break
                        end
                    end

                    if offgrid and not blocked then
                        local coordSpecs = SectorSpecifics(coord.x, coord.y, serverSeed)
    
                        local avoid = false
                        for _, bt in pairs(templateBlacklist) do
                            if coordSpecs.generationTemplate.path and coordSpecs.generationTemplate.path == bt then
                                mission.Log(_MethodName, "Sector has blacklisted template " .. coordSpecs.generationTemplate.path)
                                avoid = true
                                break
                            end
                        end
                        if not avoid and not Galaxy():sectorExists(coord.x, coord.y) then
                            target = coord
                            break
                        end
                    end
                end
            end

            if not target then
                mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
                terminate()
                return
            end

            --Standard mission data.
            mission.data.brief = "Ambush Pirate Raiders"
            mission.data.title = "Ambush Pirate Raiders"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "You were tasked with destroying a group of pirates that are gathering to raid a nearby sector.",
                { text = "Head to (${location.x}:${location.y})", bulletPoint = true, fulfilled = false }
            }

            local _RewardBase = 50000
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .maxwaves
                .waves
                .startSpawningPirates
                .piratesFound
                .firstWaveTaunt
            =========================================================]]
            mission.data.custom.dangerLevel = rgen:getInt(1, 10)
            mission.data.custom.maxwaves = 3
            mission.data.custom.waves = 0
            --4 waves.
            if mission.data.custom.dangerLevel >= 6 then
                _RewardBase = _RewardBase + 3000
            end
            --4 waves with maybe 5 ships each.
            if mission.data.custom.dangerLevel == 10 then
                mission.data.custom.maxwaves = mission.data.custom.maxwaves + 1
                _RewardBase = _RewardBase + 5500
            end

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRichnessFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = target, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, "They're gathering in \\s(%1%:%2%).", target.x, target.y)
        else
            --Restoring
            llte_sidemission_init()
        end
    end
    
    if onClient() then
        if not _restoring then
            initialSync()
        else
            sync()
        end
    end
end

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y) 
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    mission.data.description[2].fulfilled = true
    mission.data.description[3] = {text = "Destroy the arriving pirates", bulletPoint = true, fulfilled = false}

    mission.phases[1].timers[1] = {time = 12, callback = function() mission.data.custom.startSpawningPirates = true end, repeating = false}
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 1 Update Target Location"

    local count = ESCCUtil.countEntitiesByValue("is_pirate")
    mission.data.custom.piratesFound = mission.data.custom.piratesFound or count > 0

    --If there's 1 pirate or less left, spawn the next wave.
    if count <= 1 and mission.data.custom.waves < mission.data.custom.maxwaves and mission.data.custom.startSpawningPirates then
        mission.Log(_MethodName, "Spawning Pirate Wave.")
        mission.data.custom.waves = mission.data.custom.waves + 1
        spawnPirateWave()
    end

    --If there are no pirates left and the players found the pirates, we win.
    if mission.data.custom.piratesFound and count == 0 then
        finishAndReward()
    end
end

mission.phases[1].onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        --Abandoned out-of-sector.
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        --boop mission x/y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY)
    end
end

--endregion

--region #SERVER CALLS

function spawnPirateWave() 
    local _MethodName = "Spawn Pirate Wave"
    mission.Log(_MethodName, "Beginning...")

    local waveShips = 3
    local rgen = ESCCUtil.getRand()
    if mission.data.custom.dangerLevel == 10 then
        waveShips = waveShips + rgen:getInt(1, 2)
    else
        waveShips = waveShips + 1
    end

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, waveShips, "Standard")
    local generator = AsyncPirateGenerator(nil, onPiratesFinished)

    generator:startBatch()

    local posCounter = 1
    local distance = 100
    --200 distance allows for Devastators to move comfortably.
    if mission.data.custom.dangerLevel == 10 then
        distance = 250 --_#DistAdj
    end
    local pirate_positions = generator:getStandardPositions(#waveTable, distance)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function onPiratesFinished(_Generated)
    local _MethodName = "On Pirates Generated (Server)"
    mission.Log(_MethodName, "Beginning...")

    SpawnUtility.addEnemyBuffs(_Generated)

    if not mission.data.custom.firstWaveTaunt then
        mission.Log(_MethodName, "Broadcasting Pirate Taunt to Sector")
        mission.Log(_MethodName, "Entity: " .. tostring(_Generated[1].id))

        local _Lines = {
            "Who sold us out? We're going to kill you after we deal with this!",
            "... Who are you? How dare you interrupt!",
            "Well, I guess you'll be the first one we kill.",
            "How did you find us? No matter, we'll kill you and move on to better targets.",
            "You're a long way from home, aren't you?",
            "No one was supposed to be here.",
            "They said there'd be no witnesses - and there won't be.",
            "... Who the hell are you?",
            "Looks like we found a stray one."
        }

        Sector():broadcastChatMessage(_Generated[1], ChatMessageType.Chatter, randomEntry(_Lines))
        mission.data.custom.firstWaveTaunt = true
    end
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "The Empress will be pleased to hear of this.",
        "Thank you for making the galaxy safer.",
        "Your support is appreciated, as always.",
        "Amazing work, " .. _Player.name .. "!",
        "Great job, " .. _Rank .. "!",
        "Thanks for destroying those pirates!",
        "Thanks for taking out those pirates!",
        "Thank you for your help with those pirates!"
    }

    local _RepReward = 1
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end

    --Increase reputation by 1 (2 @ 10 danger)
    mission.data.reward.paymentMessage = "Earned %1% credits for destroying the pirate raiders."
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + _RepReward)
    _Player:sendChatMessage("The Cavaliers", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion