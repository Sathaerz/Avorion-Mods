--[[
    Rank 1 side mission.
    Escort Weapon Shipment
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - N/A
    ROUGH OUTLINE
        - Go to the sector where the freighters intially are.
        - Fight off a wave of pirates.
        - Freighters will jump.
        - Follow the freighters.
        - Fight off another wave of pirates.
        - Repeat.
    DANGER LEVEL
        1+ - [These conditions are present regardless of danger level]
            - TBD
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run other includes.
include("callable")
include("randomext")
include("structuredmission")
include("stringutility")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include("asyncshipgenerator")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")

mission._Debug = 0
mission._Name = "Escort Weapon Shipment"

--Side mission is escorting a freighter. Follow the freighter from sector to sector. # of jumps and # of waves determined by danger level.
--region #INIT

local llte_sidemission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Escort Weapon Shipment Begin...")

    if onServer()then
        if not _restoring then
            --We don't have access to the mission bulletin for data, so we actually have to determine that here.
            local _Rgen = ESCCUtil.getRand()
            local x, y = Sector():getCoordinates()
            local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
            local target = {}
            target.x, target.y = MissionUT.getSector(x, y, 6, 18, false, false, false, false, insideBarrier)

            if not target then
                mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
                terminate()
                return
            end

            local _Name = "The Cavaliers" 
            local _Faction = Galaxy():findFaction(_Name)
            
            --Standard mission data.
            mission.data.brief = "Escort Weapon Shipment"
            mission.data.title = "Escort Weapon Shipment"
            mission.data.icon = "data/textures/icons/cavaliers.png"
            mission.data.description = { 
                "You were tasked with defending a Cavaliers weapon shipment that has lost its escort. Protect it until its relief can show up.",
                { text = "Meet the freighter in sector (${xLoc}:${yLoc})", arguments = {xLoc = target.x, yLoc = target.y}, bulletPoint = true, fulfilled = false }
            }

            local _RewardBase = 50000
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .cavaliersindex
                .isInsideBarrier
                .firstLocation
                .checkphasepirates
                .freighterid
                .freightername
                .freighterSpawned
                .nextlocation
                .jumpindex
            =========================================================]]
            mission.data.custom.cavaliersindex = _Faction.index
            mission.data.custom.isInsideBarrier = insideBarrier
            mission.data.custom.firstLocation = target
            mission.data.custom.checkphasepirates = {}

            mission.data.custom.dangerLevel = _Rgen:getInt(1, 10)
            if mission.data.custom.dangerLevel >= 8 then
                _RewardBase = _RewardBase + 3000
            end
            if mission.data.custom.dangerLevel == 10 then
                _RewardBase = _RewardBase + 5500
            end

            if insideBarrier then
                _RewardBase = _RewardBase * 2
            end

            local missionReward = ESCCUtil.clampToNearest(_RewardBase * Balancing.GetSectorRewardFactor(Sector():getCoordinates()), 5000, "Up")

            missionData_in = {location = target, reward = {credits = missionReward}}
    
            llte_sidemission_init(missionData_in)
            Player():sendChatMessage("The Cavaliers", 0, "Our freighter is located in \\s(%1%:%2%). Please go meet it there.", target.x, target.y)
        else
            --Restoring
            --updateFreighter()
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

mission.globalPhase = {}
mission.globalPhase.timers = {}
mission.globalPhase.onTargetLocationEntered = function(x, y)
    local _MethodName = "Global Phase On Target Location Entered"
    mission.Log(_MethodName, "Removing fail timer.")

    mission.globalPhase.timers[1] = nil
end

mission.globalPhase.onTargetLocationLeft = function(x, y)
    local _MethodName = "Global Phase On Target Location Left"
    mission.Log(_MethodName, "Beginning...")

    setFailTimer()
end

mission.globalPhase.onEntityDestroyed = function(_ID, _LastDamageInflictor)
    if Entity(_ID):getValue("_llte_escort_mission_freighter") then
        failMission(false)
    end
end

mission.globalPhase.onAbandon = function()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        --Abandoned in-sector.
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
        if mission.data.custom.freighterid then
            local _Freighter = Entity(mission.data.custom.freighterid)

            local _WithdrawData = {
                _Threshold = 0.8,
                _MinTime = 1,
                _MaxTime = 1,
                _Invincibility = 0.02
            }

            _Freighter:addScript("ai/withdrawatlowhealth.lua", _WithdrawData)
        end
    else
        --Abandoned out-of-sector.
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        --boop mission x/y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true)
    end
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    --Just in case the player leaves the first sector and then re-enters it for some reason?
    if not mission.data.custom.freighterSpawned then
        mission.Log(_MethodName, "Spawning Cavaliers Freighter...")
       --Spawn a cavalier freighter. 
       local shipGenerator = AsyncShipGenerator(nil, onFreighterFinished)
       --The standard freighters are destroyed so easily. Let's make this one a lot tougher.
       local cavFreighterVolume = Balancing_GetSectorShipVolume(x, y) * 8
       local faction = Faction(mission.data.custom.cavaliersindex)

       local look = vec3(1, 0, 0)
       local up = vec3(0, 1, 0)

       shipGenerator:startBatch()
       shipGenerator:createFreighterShip(faction, MatrixLookUpPosition(look, up, vec3(0, -50, 0)), cavFreighterVolume)
       shipGenerator:endBatch()

       mission.data.custom.freighterSpawned = true
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(x, y)
    local _MethodName = "Phase 1 on Target Location Arrival Confirmed"

    local ships = {Sector():getEntitiesByScriptValue("_llte_escort_mission_freighter")} if ships and #ships ~= 0 then
        mission.Log(_MethodName, "Found escort freighter - resetting mission data.")
        
        local lines = {
            "Thank goodness you're here! Our escort was destroyed and we barely managed to escape!"
        }

        local _Freighter = Entity(mission.data.custom.freighterid)
        Sector():broadcastChatMessage(_Freighter, ChatMessageType.Chatter, randomEntry(lines))

        --Start two timers. One to spawn the first wave of pirates, and one for the freighter to warn the player of the pirates.
        mission.Log(_MethodName, "Starting first wave countdown + warning timer")
        --Spawn first wave of pirates 20 seconds after we've gotten the freighter squared away.
        mission.phases[1].timers[1] = {time = 20, callback = function() spawnPirateWave() end, repeating = false}
        mission.phases[1].timers[2] = {time = 15, callback = function()
            local lines = {
                "Jump signatures detected! It looks like they found us!",
                "We should have known they wouldn't let us off that easily... get ready!",
                "They're coming for us! Get ready to intercept!",
                "Pirates incoming! We'll jump as soon as we can.",
                "Here they come! Please hold them off until we can jump."
            }

            local _Freighter = Entity(mission.data.custom.freighterid)
            Sector():broadcastChatMessage(_Freighter, ChatMessageType.Chatter, randomEntry(lines))
        end, repeating = false}
    else
        mission.Log(_MethodName, "ERROR - Could not find escorting freighter. Mission will not function properly.")
    end
end

mission.phases[1].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 1 Update Target Location"

    if mission.data.custom.checkphasepirates[1] then
        local count = countPirates()
        if count == 0 and not mission.phases[1].timers[3] then
            --Broadcast a message from the freigher.
            freighterReadyToJump()
            --Start a 2nd, shorter timer. At the end of the timer, we jump and advance.
            mission.Log(_MethodName, "No more pirates found. Starting 2nd timer.")
            mission.phases[1].timers[3] = { time = 5, callback = function() prepForPhaseAdvance(1) end, repeating = false }
        end
    end
end

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 2 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    --updateFreighter()
    mission.phases[2].timers[1] = { time = 15, callback = function() spawnPirateWave() end, repeating = false}
end

mission.phases[2].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 2 Update Target Location"

    if mission.data.custom.checkphasepirates[2] then
        local count = countPirates()
        if count == 0 and not mission.phases[2].timers[2] then
            --Broadcast a message from the freighter again.
            freighterReadyToJump()
            --Start a 2nd, shorter timer, etc.
            mission.Log(_MethodName, "No more pirates found. Starting 2nd timer.")
            mission.phases[2].timers[2] = { time = 5, callback = function() prepForPhaseAdvance(2) end, repeating = false }
        end
    end
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].showUpdateOnEnd = true
mission.phases[3].noBossEncountersTargetSector = true
mission.phases[3].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 3 On Target Location Entered"

    --updateFreighter()
    --This is where things start to get interesting.
    if mission.data.custom.dangerLevel == 10 then
        --If we ARE at danger level 10, we need to make one more jump. Start another pirate attack timer.
        mission.Log(_MethodName, "Starting last pirate timer")
        mission.phases[3].timers[1] = { time = 15, callback = function() spawnPirateWave() end, repeating = false}
    else
        --If we're NOT at danger level 10, we finish up here.
        mission.Log(_MethodName, "Finishing up")
        mission.phases[3].timers[1] = {time = 20, callback = function() spawnReliefDefenders() end, repeating = false}
    end
end

mission.phases[3].updateTargetLocationServer = function(timeStep)
    local _MethodName = "Phase 3 Update Target Location"

    if mission.data.custom.checkphasepirates[3] then
        local count = countPirates()
        if count == 0 and not mission.phases[3].timers[2] then
            --Broadcast a message from the freighter again.
            freighterReadyToJump()
            --Start a 2nd, shorter timer, etc.
            mission.Log(_MethodName, "No more pirates found. Starting 2nd timer.")
            mission.phases[3].timers[2] = { time = 5, callback = function() prepForPhaseAdvance(3) end, repeating = false }
        end
    end
end

mission.phases[4] = {}
mission.phases[4].timers = {}
mission.phases[4].showUpdateOnEnd = true
mission.phases[4].noBossEncountersTargetSector = true
mission.phases[4].onTargetLocationEntered = function(x, y)
    local _MethodName = "Phase 4 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    --updateFreighter()
    mission.phases[4].timers[1] = {time = 20, callback = function() spawnReliefDefenders() end, repeating = false}
end

--endregion

--region #SERVER CALLS

--Specific Callbacks
function onFreighterFinished(generated)
    local _MethodName = "On Freighter Spawned Callback"

    --There should only ever be 1 ship in this batch.
    mission.Log(_MethodName, "Resetting Freighter Name")
    local freighter = generated[1]
    freighter.name = LLTEUtil.getFreighterName()
    freighter.title = "Cavaliers " .. freighter.title
    freighter:removeScript("civilship.lua")
    freighter:removeScript("dialogs/storyhints.lua")
    freighter:setValue("_llte_escort_mission_freighter", true)
    freighter:setValue("is_civil", nil)
    freighter:setValue("npc_chatter", nil)
    freighter:setValue("is_freighter", nil)
    freighter:setValue("is_cavaliers", true)

    mission.data.custom.freighterid = freighter.id
    mission.data.custom.freightername = freighter.name

    mission.Log(_MethodName, "Updating mission objectives")
    mission.data.description[2].fulfilled = true
    mission.data.description[3] = { text = "Defend the " .. mission.data.custom.freightername .. " until it can make its first jump", bulletPoint = true, fulfilled = false }

    sync()
end

function onReliefFinished(generated)
    local _MethodName = "On relief generated"
    mission.Log(_MethodName, "Beginning...")

    local rgen = ESCCUtil.getRand()

    local ships = {Sector():getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(ships) do
        if ship.factionIndex == mission.data.custom.cavaliersindex then
            if ship:getValue("is_defender") then
                ship.title = "Cavaliers " .. ship.title
                ship:removeScript("antismuggle.lua")
                ship:setValue("npc_chatter", nil)
                ship:setValue("is_cavaliers", true)
            end

            local _WithdrawData = {
                    _Threshold = 0.8,
                    _MinTime = 1,
                    _MaxTime = 1,
                    _Invincibility = 0.02
            }

            ship:addScript("ai/withdrawatlowhealth.lua", _WithdrawData)
            MissionUT.deleteOnPlayersLeft(ship)
            ship:addScriptOnce("utility/delayeddelete.lua", rgen:getFloat(20, 22))
        end
    end

    local lines = {
        "Thanks for your help. We'll take things from here.",
        "We'll take over from here.",
        "Relief group is on station.",
        "Contact with freighter confirmed. Thanks for your help!"
    }

    Sector():broadcastChatMessage(generated[1], ChatMessageType.Chatter, randomEntry(lines))

    finishAndReward()
end

function onPiratesFinished(generated)
    local _MethodName = "On Pirates Finished"
    mission.Log(_MethodName, "Beginning...")

    SpawnUtility.addEnemyBuffs(generated)

    local phaseidx = mission.internals.phaseIndex
    mission.data.custom.checkphasepirates[phaseidx] = true
end

--Utility Functions
function countPirates()
    return ESCCUtil.countEntitiesByValue("is_pirate")
end

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

    local waveTable = ESCCUtil.getStandardWave(mission.data.custom.dangerLevel, waveShips, "Low")
    local generator = AsyncPirateGenerator(nil, onPiratesFinished)

    generator:startBatch()

    --No need for distance here - Devastators are not in the low threat table.
    local posCounter = 1
    local pirate_positions = generator:getStandardPositions(#waveTable)
    for _, p in pairs(waveTable) do
        generator:createScaledPirateByName(p, pirate_positions[posCounter])
        posCounter = posCounter + 1
    end

    generator:endBatch()
end

function spawnReliefDefenders()
    local _MethodName = "Spawn Relief Defenders"
    mission.Log(_MethodName, "Beginning...")

    --Spawn 2 defender ships for the Cavaliers.
    local shipGenerator = AsyncShipGenerator(nil, onReliefFinished)
    local faction = Faction(mission.data.custom.cavaliersindex)

    shipGenerator:startBatch()

    shipGenerator:createDefender(faction, shipGenerator:getGenericPosition())
    shipGenerator:createDefender(faction, shipGenerator:getGenericPosition())

    shipGenerator:endBatch()
end

function freighterReadyToJump()
    local _MethodName = "Freighter Ready To Jump"
    mission.Log(_MethodName, "Beginning...")

    if not mission.data.custom.freighterid then
        mission.Log(_MethodName, "ERROR - freighter id was not found. This function will error shortly.")
    end

    local lines = {
        "... Annnnd we're back online! Getting ready to jump now.",
        "Interference cleared! Getting ready to jump.",
        "Jump drives charged and warming up!",
        "Thanks for clearing the way! We'll be moving on shortly.",
        "Awesome job! We'll be heading to the next sector momentarily.",
        "Jump drive ready! Calculating the route now.",
        "We'll head out as soon as the jump route is calculated.",
        "That did it! Distortion cleared!"
    }

    local _Freighter = Entity(mission.data.custom.freighterid)
    Sector():broadcastChatMessage(_Freighter, ChatMessageType.Chatter, randomEntry(lines))
end

function prepForPhaseAdvance(jumpidx)
    local _MethodName = "Prep for Phase Advance"
    mission.Log(_MethodName, "Preparing for jumping and advancing the mission phase...")
    --Get the next location to jump to.
    local specs = SectorSpecifics()
    local _Rgen = ESCCUtil.getRand()
    local x, y = Sector():getCoordinates()
    local _OtherLocations = MissionUT.getMissionLocations() or {}
    local coords = specs.getShuffledCoordinates(_Rgen, x, y, 10, 18)
    local serverSeed = Server().seed
    local target = nil
    local _LastError = nil

    --Look for a new sector. All of this effort just to get a jumpable-to empty sector.
    for _, coord in pairs(coords) do
        mission.Log(_MethodName, "Evaluating Coord X: " .. tostring(coord.x) .. " - Y: " .. tostring(coord.y))
        local regular, offgrid, blocked, home = specs:determineContent(coord.x, coord.y, serverSeed)
        if mission.data.custom.isInsideBarrier == MissionUT.checkSectorInsideBarrier(coord.x, coord.y) and not _OtherLocations:contains(coord.y, coord.y) then
            local _PotentialTarget = false
            if not regular and not offgrid and not blocked and not home then
                _PotentialTarget = true
            end

            if _PotentialTarget then
                --We have a potential target. Check to see if the jump route is okay.
                mission.Log(_MethodName, "Setting Hyperspace range to 25") --Not sure why we can't just do it once at the start of the script but w/e
                local _HyperspaceEngine = HyperspaceEngine(mission.data.custom.freighterid)
                _HyperspaceEngine.range = 25.0

                local _Freighter = Entity(mission.data.custom.freighterid)
                local _JumpValid, _Error = _Freighter:isJumpRouteValid(x, y, coord.x, coord.y)

                if _JumpValid then
                    if not Galaxy():sectorExists(coord.x, coord.y) then
                        target = coord
                        break
                    end
                else
                    mission.Log(_MethodName, "Jump route to (" .. tostring(coord.x) .. ":" .. tostring(coord.y) .. ") is not valid because of " .. tostring(_Error) .. "Moving to next sector.")
                    _LastError = _Error
                end
            end
        end
    end

    --Once we're here, we MUST be able to continue. Enact a failsafe if we can't find a valid jump route via the above code.
    if not target then
        mission.Log(_MethodName, "[ERROR] Could not find a suitable jump route. Enacting failsafe. Last error was : " .. tostring(_LastError))
        target = {}
        target.x, target.y = MissionUT.getSector(x, y, 6, 12, false, false, false, false, mission.data.custom.isInsideBarrier)
    end

    mission.data.custom.nextlocation = target
    mission.data.custom.jumpindex = jumpidx

    mission.Log(_MethodName, "Invoking client function to open dialog.")
    invokeClientFunction(Player(), "onJumpingDialog", mission.data.custom.freighterid, tostring(target.x), tostring(target.y))
end

function jumpAndAdvancePhase() 
    local _MethodName = "Jump And Advance Phase"
    mission.Log(_MethodName, "Getting data to advance phase.")

    --Prep for jump
    local jumpidx = mission.data.custom.jumpindex
    local target = mission.data.custom.nextlocation

    mission.data.custom.nextlocation = nil
    mission.data.custom.jumpindex = nil

    mission.data.location = target

    --Update the description.
    local fulfill = 2 + jumpidx
    local jumpobjective = 3 + jumpidx
    local whichjump
    if jumpidx == 1 then
        whichjump = "second"
    elseif jumpidx == 2 then
        whichjump = "third"
    elseif jumpidx == 3 then
        whichjump = "fourth"
    end
    mission.data.description[fulfill].fulfilled = true
    mission.data.description[jumpobjective] = { 
        text = "Defend the ${freighter} in sector (${xLoc}:${yLoc}) until it can make its ${jump} jump", 
        arguments = {freighter = mission.data.custom.freightername, xLoc = target.x, yLoc = target.y, jump = whichjump},
        bulletPoint = true, 
        fulfilled = false 
    }
    --Set a deletion timer, then, finally, we jump.
    local _Freighter = Entity(mission.data.custom.freighterid)
    _Freighter:setValue("_escc_deletion_timestamp", Server().unpausedRuntime + 245)
    Sector():transferEntity(_Freighter, target.x, target.y, SectorChangeType.Jump)
    --Send message to player.
    Player():sendChatMessage("Nav Computer", 0, "The " .. mission.data.custom.freightername .. " has jumped to \\s(%1%,%2%).", target.x, target.y)
    --Advance phase. We fail if we don't jump after the freighter quickly enough.
    setFailTimer()
    --NextPhase automatically syncs, so no need to call sync() separately.
    nextPhase()
end
callable(nil, "jumpAndAdvancePhase")

function setFailTimer() 
    local _MethodName = "Set Failure Timer"
    mission.Log(_MethodName, "Setting failure timer")
    --4 minutes may be too generous, but people may be doing this mission with a massive ship with a huge hyperspace cooldown.
    mission.globalPhase.timers[1] = { time = 240, callback = function() failMission(true) end, repeating = false }
end

function failMission(remoteDelete) 
    local _MethodName = "Mission Failed"
    mission.Log(_MethodName, "Beginning...")

    if remoteDelete then
        mission.Log(_MethodName, "Player failed due to timer. Need to remotely delete the freighter.")
    end

    local player = Player()
    player:sendChatMessage("The Cavaliers", 0, "Contact with the " .. mission.data.custom.freightername .. " has been lost. What happened?")
    fail()
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
        "Thanks for escorting our shipment.",
        "Thanks for defending our freighter."
    }

    local _RepReward = 1
    if mission.data.custom.dangerLevel == 10 then
        _RepReward = _RepReward + 1
    end

    --Increase reputation by 1 (2 @ 10 danger)
    mission.data.reward.paymentMessage = "Earned %1% credits for escorting the weapon shipment."
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + _RepReward)
    _Player:sendChatMessage("The Cavaliers", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)] .. " We've transferred a reward to your account.")
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onJumpingDialog(id, xloc, yloc)
    local _MethodName = "On Jumping Dialog"
    mission.Log(_MethodName, "Beginning...")

    local dialog0 = {}
    dialog0.text = string.format("We'll be heading to (%s:%s) next. Please meet us there!", xloc, yloc)
    dialog0.answers = { { answer = "Acknowledged.", onSelect = "onJumpAcknowledged" } }
    
    ScriptUI(id):interactShowDialog(dialog0, false)
end

function onJumpAcknowledged()
    local _MethodName = "On Jump Acknowledged"
    mission.Log(_MethodName, "Invoking...")

    invokeServerFunction("jumpAndAdvancePhase")
end

--endregion