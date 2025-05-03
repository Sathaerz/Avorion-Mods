--[[
    Lord of the Wastes
    NOTES:
        - NOTES HERE
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Have completed the fourth LOTW mission.
    ROUGH OUTLINE
        - Go to the location, fight Swenks. Easy enough!
    DANGER LEVEL
        5 - Swenks + 7 buddies
        5 - Every 25%, Swenks goes immune for 30-40 seconds and summons 4 more buddies.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("structuredmission")

ESCCUtil = include("esccutil")

local PirateGenerator = include("pirategenerator")
local Balancing = include ("galaxy")
local SectorTurretGenerator = include ("sectorturretgenerator")

mission._Debug = 0
mission._Name = "Lord of the Wastes"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.icon = "data/textures/icons/silicium.png"
mission.data.description = {
    { text = "You received the following request from ${factionName}:" },
    { text = "At last. The losses that the pirates have taken over the last few ops have been so heavy that their boss is finally exposed. Our intel last has them in sector (${location.x}:${location.y}). Find them and exterminate them once and for all." },
    { text = "Head to sector (${location.x}:${location.y})", bulletPoint = true, fulfilled = false },
    { text = "Destroy Swenks", bulletPoint = true, fulfilled = false, visible = false }
}
mission.data.accomplishMessage = "Incredible! You've done it! The outer sectors are safer for your efforts. We've transmitted the reward to your account."

local LOTW_Mission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        if not _restoring then
            local _Player = Player()
            
            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .friendlyFaction
            =========================================================]]
            mission.data.custom.dangerLevel = 5 --This is a story mission, so we keep things predictable.
            mission.data.custom.friendlyFaction = _Player:getValue("_lotw_faction")

            local missionReward = ESCCUtil.clampToNearest(200000 + (50000 * Balancing.GetSectorRewardFactor(_Sector:getCoordinates())), 5000, "Up")

            missionData_in = {location = lotwStory5_getNextLocation(), reward = {credits = missionReward, relations = 12000, paymentMessage = "Earned %1% credits for destroying Swenks."}}
    
            LOTW_Mission_init(missionData_in)

            lotwStory5_setMissionFactionData(_X, _Y) --Have to be sneaky about this. Normaly this SHOULD be set by the init function, but since it's not from a station it will get funky.
        else
            --Restoring
            LOTW_Mission_init()
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

--Just for consistency's sake.
mission.globalPhase.noBossEncountersTargetSector = true
mission.globalPhase.noPlayerEventsTargetSector = true
mission.globalPhase.noLocalPlayerEventsTargetSector = true

mission.phases[1] = {}
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Target Location Entered"
    mission.Log(_MethodName, "Beginning...")

    local _Faction = Faction(mission.data.custom.friendlyFaction) --The phase is already set to 1 by the time we hit this, so it has to be done it this way.

    mission.data.description[1].arguments = { factionName = _Faction.name }
    mission.data.description[2].arguments = { x = mission.data.location.x, y = mission.data.location.y }
    mission.data.description[3].arguments = { x = mission.data.location.x, y = mission.data.location.y }
end

mission.phases[1].onTargetLocationEntered = function(x, y)
    local _sector = Sector()

    mission.data.description[3].fulfilled = true
    mission.data.description[4].visible = true

    --Stop all player ships.
    local ships = { _sector:getEntitiesByType(EntityType.Ship)}
    for _, ship in pairs(ships) do
        if ship.playerOrAllianceOwned then
            local ai = ShipAI(ship)
            ai:stop()
        end
    end

    lotwStory5_spawnSwenks()
    _sector:addScriptOnce("deleteentitiesonplayersleft.lua")
end

mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 2 on Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")

    local _Entity = Entity(_ID)

    if _Entity:getValue("is_swenks") then
        Player():setValue("swenks_beaten", true)
        mission.Log(_MethodName, "Was an objective.")
        ESCCUtil.allPiratesDepart()
        lotwStory5_finishAndReward()
    end
end

--endregion

--region #SERVER CALLS

function lotwStory5_setMissionFactionData(_X, _Y)
    local _MethodName = "Set Mission Faction Data"
    mission.Log(_MethodName, "Beginning...")
    --We're going to have to do some sneaky stuff w/ credits here.
    local _Faction = Faction(Player():getValue("_lotw_faction"))
    mission.data.giver = {}
    mission.data.giver.id = _Faction.index
    mission.data.giver.factionIndex = _Faction.index
    mission.data.giver.coordinates = { x = _X, y = _Y }
    mission.data.giver.baseTitle = _Faction.name
end

function lotwStory5_getNextLocation()
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
    local target = {}

    target.x, target.y = MissionUT.getSector(x, y, 4, 10, false, false, false, false, false)

    mission.Log(_MethodName, "X coordinate of next location is : " .. tostring(target.x) .. " Y coordinate of next location is : " .. tostring(target.y))
    if not target or not target.x or not target.y then
        mission.Log(_MethodName, "Could not find a suitable mission location. Terminating script.")
        terminate()
        return
    end

    return target
end

function lotwStory5_spawnSwenks()
    local _MethodName = "Spawn Swenks"

    local function piratePosition()
        local pos = random():getVector(-1000, 1000)
        return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
    end

    -- spawn
    local boss = PirateGenerator.createFlagship(piratePosition())
    boss:setTitle("Boss Swenks"%_T, {})
    boss.dockable = false

    local _pirates = {}
    table.insert(_pirates, boss)
    table.insert(_pirates, PirateGenerator.createRaider(piratePosition()))
    table.insert(_pirates, PirateGenerator.createRavager(piratePosition()))
    table.insert(_pirates, PirateGenerator.createMarauder(piratePosition()))
    table.insert(_pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(_pirates, PirateGenerator.createPirate(piratePosition()))
    table.insert(_pirates, PirateGenerator.createBandit(piratePosition()))
    table.insert(_pirates, PirateGenerator.createBandit(piratePosition()))

    local _Sector = Sector()
    local x, y = _Sector:getCoordinates()

    -- adds legendary turret drop
    local _random = random()
    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, 0, Rarity(RarityType.Exotic))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exceptional), Seed(_random:getInt(1, 20000))))
    Loot(boss.index):insert(SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), Seed(_random:getInt(1, 20000))))

    for _, pirate in pairs(_pirates) do
        MissionUT.deleteOnPlayersLeft(pirate)

        local _Player = Player()
        if not _Player then break end
        local allianceIndex = _Player.allianceIndex
        local ai = ShipAI(pirate.index)
        ai:registerFriendFaction(_Player.index)
        if allianceIndex then
            ai:registerFriendFaction(allianceIndex)
        end
    end

    if Server():getValue("swoks_beaten") then
        mission.Log(_MethodName, "Setting Swoks beaten")
        boss:setValue("swoks_beaten", true)
    end
    
    boss:removeScript("icon.lua")
    boss:addScript("icon.lua", "data/textures/icons/pixel/skull_big.png")
    boss:addScript("player/missions/lotw/mission5/swenks.lua")
    boss:addScript("story/swenksspecial.lua")
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("avenger.lua")
    boss:setValue("is_pirate", true)
    boss:setValue("is_swenks", true)

    Boarding(boss).boardable = false
end

function lotwStory5_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local runTime = Server().unpausedRuntime

    _Player:setValue("_lotw_story_stage", 6)
    _Player:setValue("_lotw_story_complete", true)
    _Player:setValue("_lotw_last_side1", runTime)
    _Player:setValue("_lotw_last_side2", runTime)

    reward()
    accomplish()
end

--endregion