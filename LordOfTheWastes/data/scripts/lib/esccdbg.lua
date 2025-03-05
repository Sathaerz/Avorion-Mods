local lotw_getDebugModules = getDebugModules
function getDebugModules(modTable)
    --0x6573636320646267206370676E7461622066756E63205354415254
    local lotw_dbgmodule = function(window)
        numButtons = 0
        local tab11 = window:createTab("", "data/textures/icons/silicium.png", "Lord of the Wastes")

        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 1", "onLOTWMission1ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 2", "onLOTWMission2ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 3", "onLOTWMission3ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 4", "onLOTWMission4ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 5", "onLOTWMission5ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Side Mission 1", "onLOTWSide1ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Side Mission 2", "onLOTWSide2ButtonPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Clear Values", "onLOTWClearValuesPressed")
        MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Spawn Swenks", "onSpawnSwenksButtonPressed")
    end
    --0x6573636320646267206370676E7461622066756E6320454E44

    --0x6573636320646267206370676E7461622074626C20696E73
    table.insert(modTable, lotw_dbgmodule)

    return lotw_getDebugModules(modTable)
end

--0x657363632064656275672074616220726567696F6E205354415254
--region #LOTW tab

function onLOTWMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwstory1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission1ButtonPressed")

function onLOTWMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwstory2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission2ButtonPressed")

function onLOTWMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwstory3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission3ButtonPressed")

function onLOTWMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwstory4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission4ButtonPressed")

function onLOTWMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwstory5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission5ButtonPressed")

function onLOTWSide1ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWSide1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwside1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWSide1ButtonPressed")

function onLOTWSide2ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWSide2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwside2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWSide2ButtonPressed")

function onSpawnSwenksButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSwenksButtonPressed")
        return
    end

    local function piratePosition()
        local pos = random():getVector(-1000, 1000)
        return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
    end

    -- spawn
    local boss = PirateGenerator.createBoss(piratePosition())
    boss:setTitle("Boss Swenks"%_T, {})
    boss.dockable = false

    local _pirates = {}
    table.insert(_pirates, boss)

    for _, pirate in pairs(_pirates) do
        pirate:addScript("deleteonplayersleft.lua")

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
callable(nil, "onSpawnSwenksButtonPressed")

function onLOTWClearValuesPressed()
    if onClient() then
        invokeServerFunction("onLOTWClearValuesPressed")
        return
    end

    local _Player = Player(callingPlayer)

    local _Scripts = {
        "missions/lotw/lotwstory1.lua",
        "missions/lotw/lotwstory2.lua",
        "missions/lotw/lotwstory3.lua",
        "missions/lotw/lotwstory4.lua",
        "missions/lotw/lotwstory5.lua",
        "missions/lotw/lotwside1.lua",
        "missions/lotw/lotwside2.lua",
    }

    for _k, _v in pairs(_Scripts) do
        _Player:removeScript(_v)
    end

    _Player:setValue("_lotw_story_stage", nil)
    _Player:setValue("_lotw_story_complete", nil)
    _Player:setValue("_lotw_last_side1", nil)
    _Player:setValue("_lotw_last_side2", nil)
    _Player:setValue("_lotw_faction", nil)
    _Player:setValue("_lotw_mission2_failures", nil)
    _Player:setValue("_lotw_mission2_freighterskilled", nil)
    _Player:setValue("_lotw_mission3_failures", nil)
    _Player:setValue("_lotw_mission3_freighterskilled", nil)
    _Player:setValue("_lotw_mission4_failures", nil)
    _Player:setValue("swenks_beaten", nil)
    _Player:setValue("_lotw_faction_verified", nil)

    local _msg = "All Lord of the Wastes data cleared."
    print(_msg)
    _Player:sendChatMessage("Server", ChatMessageType.Information, _msg)
end
callable(nil, "onLOTWClearValuesPressed")

--endregion
--0x657363632064656275672074616220726567696F6E20454E44