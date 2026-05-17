local VengeUtil = include("vbmnutil")

local vbmn_getDebugModules = getDebugModules
function getDebugModules(modTable)
    --0x6573636320646267206370676E7461622066756E63205354415254
    local vbmn_dbgmodule = function(window)
        numButtons = 0
        local VBMNTab = window:createTab("", "data/textures/icons/firing-ship.png", "Vengeance Be My Name")

        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 1", "onVBMNTabMission1ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 2", "onVBMNTabMission2ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 3", "onVBMNTabMission3ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 4", "onVBMNTabMission4ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 5", "onVBMNTabMission5ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 6", "onVBMNTabMission6ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 7", "onVBMNTabMission7ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 8", "onVBMNTabMission8ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Mission 9", "onVBMNTabMission9ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Side Mission 1", "onVBMNTabSideMission1ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Side Mission 2", "onVBMNTabSideMission2ButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Picket Ship", "onVBMNTabCreatePicketShipPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Allison", "onVBMNTabSpawnAllisonButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Adrasteia Warship", "onVBMNTabSpawnWarshipButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Missile Ship", "onVBMNTabSpawnMissileShipButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Hijack Ship", "onVBMNTabSpawnHijackShipButtonPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Test Boarding Scenario", "onVBMNTabTestingBoardingScenarioPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Brute Gruznier", "onVBMNTabSpawnGruznierPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Brute Gruznier Attacks", "onVBMNTabGruznierAttacksPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Spawn Boss Xinull", "onVBMNTabSpawnBossXinullPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Boss Xinull Attacks", "onVBMNTabBossXinullAttacksPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Test Reward Mail", "onVBMNTabTestRewardMailPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Unlock Encyclopedia", "onUnlockAllVBMNEncyclopediaPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Dump Values", "onVBMNDumpValuesPressed")
        MakeButton(VBMNTab, ButtonRect(nil, nil, nil, VBMNTab.height), "Clear Values", "onVBMNClearValuesPressed")
    end
    --0x6573636320646267206370676E7461622066756E6320454E44

    --0x6573636320646267206370676E7461622074626C20696E73
   table.insert(modTable, vbmn_dbgmodule)
   
   return vbmn_getDebugModules(modTable)
end

--0x657363632064656275672074616220726567696F6E205354415254
--region #VBMN tab

--Pick an alias that's unlikely to be taken
_vengeancebemyname_campaign_script_values = {
    "_vengeancebmn_story_stage",
    "_vengeancebmn_last_side1",
    "_vengeancebmn_last_side2",
    "_vbmn3_loot_transports_killed",
    "_vbmn5_heardplan",
    "_vbmn5_hold_you_to_it",
    "_vbmn5_complained_about_crimes",
    "_vbmn6_killed_gruznier",
    "_vbmn6_complained_about_crimes",
    "_vbmn7_multiple_attempts",
    "_vbmn8_complained_about_crimes",
    "_vbmn_story_complete",
    "_vbmn_gruznier_kills",
    "_vbmn_xinull_kills",
    "encyclopedia_vbmn_pirates",
    "encyclopedia_vbmn_nescient",
    "encyclopedia_vbmn_spears",
    "encyclopedia_vbmn_allison",
    "encyclopedia_vbmn_jammer",
    "encyclopedia_vbmn_hijacking",
    "encyclopedia_vbmn_gruznier",
    "encyclopedia_vbmn_xinull",
    "encyclopedia_vbmn_allison2"
}

_vengeancebemyname_campaign_mission_scripts = {
    "missions/vengeance/vengeancestory1.lua",
    "missions/vengeance/vengeancestory2.lua",
    "missions/vengeance/vengeancestory3.lua",
    "missions/vengeance/vengeancestory4.lua",
    "missions/vengeance/vengeancestory5.lua",
    "missions/vengeance/vengeancestory6.lua",
    "missions/vengeance/vengeancestory7.lua",
    "missions/vengeance/vengeancestory8.lua",
    "missions/vengeance/vengeancestory9.lua",
    "missions/vengeance/vengeanceside1.lua",
    "missions/vengeance/vengeanceside2.lua"
}

function onVBMNTabMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission1ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToStation(Entity(), "data/scripts/player/missions/vengeance/vengeancestory1.lua")
end
callable(nil, "onVBMNTabMission1ButtonPressed")

function onVBMNTabMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission2ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory2.lua")
end
callable(nil, "onVBMNTabMission2ButtonPressed")

function onVBMNTabMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission3ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory3.lua")
end
callable(nil, "onVBMNTabMission3ButtonPressed")

function onVBMNTabMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission4ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory4.lua")
end
callable(nil, "onVBMNTabMission4ButtonPressed")

function onVBMNTabMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission5ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory5.lua")
end
callable(nil, "onVBMNTabMission5ButtonPressed")

function onVBMNTabMission6ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission6ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory6.lua")
end
callable(nil, "onVBMNTabMission6ButtonPressed")

function onVBMNTabMission7ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission7ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory7.lua")
end
callable(nil, "onVBMNTabMission7ButtonPressed")

function onVBMNTabMission8ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission8ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory8.lua")
end
callable(nil, "onVBMNTabMission8ButtonPressed")

function onVBMNTabMission9ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabMission9ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToPlayer(Player(callingPlayer), "missions/vengeance/vengeancestory9.lua")
end
callable(nil, "onVBMNTabMission9ButtonPressed")

function onVBMNTabSideMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSideMission1ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToStation(Entity(), "data/scripts/player/missions/vengeance/vengeanceside1.lua")
end
callable(nil, "onVBMNTabSideMission1ButtonPressed")

function onVBMNTabSideMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSideMission2ButtonPressed")
        return
    end

    onVBMNAddMissionScriptToStation(Entity(), "data/scripts/player/missions/vengeance/vengeanceside2.lua")
end
callable(nil, "onVBMNTabSideMission2ButtonPressed")

function onVBMNTabCreatePicketShipPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabCreatePicketShipPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onVBMNPicketPirateGenerated)

    local dir = random():getDirection()
    local matrix = MatrixLookUpPosition(-dir, vec3(0,1,0), Entity().translationf + dir * 2000)

    generator:createPirate(matrix)
end
callable(nil, "onVBMNTabCreatePicketShipPressed")

function onVBMNTabSpawnAllisonButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnAllisonButtonPressed")
        return
    end

    VengeUtil.spawnAllison(false, false)
end
callable(nil, "onVBMNTabSpawnAllisonButtonPressed")

function onVBMNTabSpawnWarshipButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnWarshipButtonPressed")
        return
    end

    VengeUtil.spawnAdrasteiaWarship(false)
end
callable(nil, "onVBMNTabSpawnWarshipButtonPressed")

function onVBMNTabSpawnMissileShipButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnMissileShipButtonPressed")
        return
    end

    VengeUtil.spawnAdrasteiaMissileShip(false)
end
callable(nil, "onVBMNTabSpawnMissileShipButtonPressed")

function onVBMNTabSpawnHijackShipButtonPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnHijackShipButtonPressed")
        return
    end

    VengeUtil.spawnAdrasteiaHijackingShip(false)
end
callable(nil, "onVBMNTabSpawnHijackShipButtonPressed")

function onVBMNTabTestingBoardingScenarioPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabTestingBoardingScenarioPressed")
        return
    end

    local hijackShip = VengeUtil.spawnAdrasteiaHijackingShip(false)

    local function piratePosition()
        local pos = random():getVector(-1000, 1000)
        return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
    end

    -- spawn jammer
    local jammer = PirateGenerator.createJammer(piratePosition())
    jammer.durability = jammer.maxDurability * 0.05 --Set to an absurdly low HP
    
    print("adding 1500 security to jammer.")
    jammer:addCrew(1500, CrewMan(CrewProfessionType.Security))

    local jammerAI = ShipAI(jammer)
    jammerAI:setPassive()

    print("setting jammer as boarding target.")
    local hijackAI = ShipAI(hijackShip)
    hijackAI:setBoard(jammer)
end
callable(nil, "onVBMNTabTestingBoardingScenarioPressed")

function onVBMNTabSpawnGruznierPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnGruznierPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local pLevel = Balancing_GetPirateLevel(x, y)
    local pFaction = Galaxy():getPirateFaction(pLevel)

    VengeUtil.spawnGruznier(pFaction, false, 1, 0)
end
callable(nil, "onVBMNTabSpawnGruznierPressed")

function onVBMNTabGruznierAttacksPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabGruznierAttacksPressed")
        return
    end

    local gruzs = { Sector():getEntitiesByScriptValue("is_gruznier") }
    local gruz = gruzs[1]

    if gruz then
        VengeUtil.setGruznierAttack(gruz, false)
    else
        local _player = Player(callingPlayer)
        _player:sendChatMessage("Server", ChatMessageType.Information, "Spawn Brute Gruznier before ordering him to attack!")
    end
end
callable(nil, "onVBMNTabGruznierAttacksPressed")

function onVBMNTabSpawnBossXinullPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabSpawnBossXinullPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local pLevel = Balancing_GetPirateLevel(x, y)
    local pFaction = Galaxy():getPirateFaction(pLevel)

    VengeUtil.spawnXinull(pFaction, 1, 0)
end
callable(nil, "onVBMNTabSpawnBossXinullPressed")

function onVBMNTabBossXinullAttacksPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabBossXinullAttacksPressed")
        return
    end

    local xinulls = { Sector():getEntitiesByScriptValue("is_xinull") }
    local xinull = xinulls[1]

    if xinull then
        VengeUtil.setXinullAttack(xinull, false)
    else
        local _player = Player(callingPlayer)
        _player:sendChatMessage("Server", ChatMessageType.Information, "Spawn Boss Xinull before ordering him to attack!")
    end
end
callable(nil, "onVBMNTabBossXinullAttacksPressed")

function onVBMNTabTestRewardMailPressed()
    if onClient() then
        invokeServerFunction("onVBMNTabTestRewardMailPressed")
        return
    end

    local _player = Player(callingPlayer)

    local _mail = Mail()

    local exmtcs = SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Exotic), random():createSeed())
    _mail:addItem(exmtcs)

    print("testing seed 15100")

    local exhyp = SystemUpgradeTemplate("data/scripts/systems/hyperspacebooster.lua", Rarity(RarityType.Exotic), Seed(15100))
    _mail:addItem(exhyp)

    _mail.text = Format("Hello, ${_PLAYERNAME}.\n\nI found these while my crew was sweeping Xinull's ship. I thought you might be able to make use of them on your journey. Thank you once again for your help, and safe travels.\n\nAllison Vannier" % {_PLAYERNAME = _player.name})
    _mail.header = "A Parting Gift"
    _mail.sender = "Allison @SpearsOfAdrasteia"
    _mail.id = "_vbmn_story9_mail2"
    _player:addMail(_mail)
end
callable(nil, "onVBMNTabTestRewardMailPressed")

function onUnlockAllVBMNEncyclopediaPressed()
    if onClient() then
        invokeServerFunction("onUnlockAllVBMNEncyclopediaPressed")
        return
    end

    print("Unlocking Vengeance Be My Name Encyclopedia entries")

    local _player = Player(callingPlayer)
    _player:setValue("encyclopedia_vbmn_pirates", true)
    _player:setValue("encyclopedia_vbmn_nescient", true)
    _player:setValue("encyclopedia_vbmn_spears", true)
    _player:setValue("encyclopedia_vbmn_allison", true)
    _player:setValue("encyclopedia_vbmn_jammer", true)
    _player:setValue("encyclopedia_vbmn_hijacking", true)
    _player:setValue("encyclopedia_vbmn_gruznier", true)
    _player:setValue("encyclopedia_vbmn_xinull", true)
    _player:setValue("encyclopedia_vbmn_allison2", true)
end
callable(nil, "onUnlockAllVBMNEncyclopediaPressed")

function onVBMNDumpValuesPressed()
    if onClient() then
        invokeServerFunction("onVBMNDumpValuesPressed")
        return
    end

    local _player = Player(callingPlayer)
    for k, v in pairs(_vengeancebemyname_campaign_script_values) do
        print("Name : " .. tostring(v) .. " // Value : " .. tostring(_player:getValue(v)))
    end
end
callable(nil, "onVBMNDumpValuesPressed")

function onVBMNClearValuesPressed()
    if onClient() then
        invokeServerFunction("onVBMNClearValuesPressed")
        return
    end

    local _player = Player(callingPlayer)

    for k, v in pairs(_vengeancebemyname_campaign_mission_scripts) do
        _player:removeScript(v)
    end

    for k, v in pairs(_vengeancebemyname_campaign_script_values) do
        _player:setValue(v, nil)
    end
    _player:setValue("_vengeancebmn_story_stage", 1) --Have to reset this one indiviudally b/c the loop nils them all out.
   
    VengeUtil.setFriendlyFactionRep(_player, 0)

    local _msg = "All Vengeance Be My Name data cleared."
    print(_msg)
    _player:sendChatMessage("Server", ChatMessageType.Information, _msg)
end
callable(nil, "onVBMNClearValuesPressed")

--endregion

--region #VBMN Helper Funcs

function onVBMNAddMissionScriptToPlayer(_player, script)
    local _Script = script
    _player:removeScript(_Script)
    _player:addScript(_Script)
end

function onVBMNAddMissionScriptToStation(_station, script)
    if _station.type ~= EntityType.Station then
        print("Can't add missions to non-station entities.")
    else
        if _station.playerOrAllianceOwned then
            print("Can't add missions to player or alliance stations.")
        else
            print("Adding Vengeance bulletin: " .. script)
            local ok, bulletin = run(script, "getBulletin", _station)
            _station:invokeFunction("bulletinboard", "postBulletin", bulletin)
        end
    end
end

function onVBMNPicketPirateGenerated(generated)
    local _player = Player(CallingPlayer)

    local picketValues = {
        _pindex = _player.index
    }

    generated:addScriptOnce("player/missions/vengeance/story1/vengeance1picket.lua", picketValues)
end

--endregion
--0x657363632064656275672074616220726567696F6E20454E44