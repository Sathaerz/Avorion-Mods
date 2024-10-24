package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("galaxy")
include("callable")
include("productions")
local PirateGenerator = include("pirategenerator")
local AsyncPirateGenerator = include("asyncpirategenerator")
local SpawnUtility = include("spawnutility")
local ShipUtility = include("shiputility")
local TorpedoGenerator = include("torpedogenerator")
local Xsotan = include ("story/xsotan")
local EnvironmentalEffectUT = include("dlc/rift/sector/effects/environmentaleffectutility")
local EnvironmentalEffectType = include("dlc/rift/sector/effects/environmentaleffecttype")

--/run Entity():addScript("lib/esccdbg.lua")
local window

local numButtons = 0
function ButtonRect(w, h, p, wh)

    local width = w or 280
    local height = h or 35
    local padding = p or 10
    local wh = wh or window.size.y - 60

    local space = math.floor(wh / (height + padding))

    local row = math.floor(numButtons % space)
    local col = math.floor(numButtons / space)

    local lower = vec2((width + padding) * col, (height + padding) * row)
    local upper = lower + vec2(width, height)

    numButtons = numButtons + 1

    return Rect(lower, upper)
end

local function MakeButton(tab, rect, caption, func)
    local button = tab:createButton(rect, caption, func)
    button.uppercase = false
    return button
end

function interactionPossible(player)
    return true, ""
end

function initialize()
end

function initUI()
    --Up to TAB10
    local res = getResolution()
    local size = vec2(1200, 650)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    window.caption = "ESCC Debug"
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "~esccdev")

    -- create a tabbed window inside the main window
    local tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    local topLevelTab = tabbedWindow:createTab("Entity", "data/textures/icons/ship.png", "ESCC General")
    local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))
    local tab = window:createTab("", "data/textures/icons/ship.png", "ESCC Ships")
    numButtons = 0
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Jammer", "onSpawnJammerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Stinger", "onSpawnStingerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Scorcher", "onSpawnScorcherButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Bomber", "onSpawnBomberButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Sinner", "onSpawnSinnerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Prowler", "onSpawnProwlerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Pillager", "onSpawnPillagerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Devastator", "onSpawnDevastatorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Slammer", "onSpawnTorpedoSlammerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Deadshot", "onSpawnDeadshotButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "SeigeGun", "onSpawnSeigeGunButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Absolute PD", "onSpawnAbsolutePDButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Curtain", "onSpawnIronCurtainButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Eternal", "onSpawnEternalButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Overdrive", "onSpawnOverdriveButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Adaptive", "onSpawnAdaptiveButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Afterburn", "onSpawnAfterburnerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Avenger", "onSpawnAvengerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Meathook", "onSpawnMeathookButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Booster", "onSpawnBoosterButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Booster Healer", "onSpawnBoosterHealerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Phaser", "onSpawnPhaserButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Frenzied", "onSpawnFrenziedButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Secondaries", "onSpawnSecondariesButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Thorns", "onSpawnThornsButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Infestor", "onSpawnXsotanInfestorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Oppressor", "onSpawnXsotanOppressorButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Sunmaker", "onSpawnXsotanSunmakerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Ballistyx", "onSpawnXsotanBallistyxButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Longinus", "onSpawnXsotanLonginusButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Pulverizer", "onSpawnXsotanPulverizerButtonPressed")
    MakeButton(tab, ButtonRect(nil, nil, nil, tab.height), "Xsotan Warlock", "onSpawnXsotanWarlockButtonPressed")

    local tab3 = window:createTab("Entity", "data/textures/icons/edge-crack.png", "ESCC Bosses")
    numButtons = 0
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner", "onSpawnExecutionerButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner II", "onSpawnExecutioner2ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner III", "onSpawnExecutioner3ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner IV", "onSpawnExecutioner4ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner V", "onSpawnExecutioner5ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner VI", "onSpawnExecutioner6ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner VII", "onSpawnExecutioner7ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Executioner VIII", "onSpawnExecutioner8ButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Katana BOSS", "onKatanaBossButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Phoenix BOSS", "onPhoenixBossButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Hunter BOSS", "onHunterBossButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Hellcat BOSS", "onHellcatBossButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Goliath BOSS", "onGoliathBossButtonPressed")
    MakeButton(tab3, ButtonRect(nil, nil, nil, tab3.height), "Spawn Shield BOSS", "onShieldBossButtonPressed")

    local tab4 = window:createTab("Entity", "data/textures/icons/computation-mainframe.png", "AI Test")
    numButtons = 0
    MakeButton(tab4, ButtonRect(nil, nil, nil, tab4.height), "Fly to me", "onFlyToMeButtonPressed")
    MakeButton(tab4, ButtonRect(nil, nil, nil, tab4.height), "Shoot me", "onShootMeButtonPressed")
    MakeButton(tab4, ButtonRect(nil, nil, nil, tab4.height), "Use Pursuit", "onAttachTindalosButtonPressed")

    local tab6 = window:createTab("Entity", "data/textures/icons/solar-cell.png", "Data Dumps")
    numButtons = 0
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Turret Data Dump", "onTurretDataDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Upgrade Data Dump", "onUpgradeDataDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Trait Data Dump", "onTraitDataDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Station List Dump", "onStationListDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Server Value Dump", "onServerValueDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Player Value Dump", "onPlayerValueDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Material Value Dump", "onMaterialDumpButtonPressed")
    MakeButton(tab6, ButtonRect(nil, nil, nil, tab6.height), "Sector DPS Dump", "onSectorDPSDumpButtonPressed")

    local tab7 = window:createTab("Entity", "data/textures/icons/papers.png", "Other")
    numButtons = 0
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Run Scratch Script", "onRunScratchScriptButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Load Torpedoes", "onLoadTorpedoesButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Zero Resources", "onZeroOutResourcesButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Test Pariah Spawn", "onTestPariahSpawnButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Repair All Ships", "onRepairAllShipsButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Run SectorDPS", "onRunSectorDPSPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Get Position", "onGetPositionPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Center Position", "onCenterPositionPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Get Distance", "onDistanceButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Test OOS Attack", "onTestOOSButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Reset XWG", "onLLTEResetXWGButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Add Acid Fog Intensity 1", "onAcidFogIntensity1Pressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Add Acid Fog Intensity 2", "onAcidFogIntensity2Pressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Add Acid Fog Intensity 3", "onAcidFogIntensity3Pressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Add Radiation Intensity 1", "onRadiationIntensity1Pressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Remove All Weather", "onRemoveWeatherPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Run ESCC MinVec Test", "onRunESCCMinVecTestButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil, nil, tab7.height), "Get Distance To Center", "onRunGetDistToCenterButtonPressed")
    MakeButton(tab7, ButtonRect(nil, nil,nil, tab7.height), "Get Own Translation", "onGetTranslationButtonPressed")
    
    local tab8 = tabbedWindow:createTab("Entity", "data/textures/icons/gunner.png", "ESCC Turrets")
    numButtons = 0
    local _TurretNames = {
        "Tesla",
        "Salvage",
        "Launcher",
        "Repair",
        "Railgun",
        "Pulse",
        "Plasma",
        "Mining",
        "Lightning",
        "Laser",
        "Force",
        "Chaingun",
        "Cannon",
        "Bolter"
    }
    for _, _Name in pairs(_TurretNames) do
        local _Button = MakeButton(tab8, ButtonRect(nil, nil, nil, tab8.height), "Build " .. tostring(_Name), "onBuildATurretButtonPressed")
        _Button.tooltip = _Name
    end

    local _ModTable = getModTable()

    if _ModTable.hasAnyCampaignMods then

        local topLevelTab = tabbedWindow:createTab("Entity", "data/textures/icons/wormhole.png", "ESCC Campaigns")
        local window = topLevelTab:createTabbedWindow(Rect(topLevelTab.rect.size))

        if _ModTable.hasAnyBulletinMods then

            local missionTab = window:createTab("", "data/textures/icons/bars.png", "Bulletin Missions")
            numButtons = 0

            for _, _bulletinMission in pairs (_ModTable._BulletinMissionTable) do
                local _Button = MakeButton(missionTab, ButtonRect(nil, nil, nil, missionTab.height), _bulletinMission._Caption, "onAddBulletinButtonPressed")
                _Button.tooltip = _bulletinMission._Tooltip
            end
        end

        if _ModTable.hasIncreasingThreat then
        --print("adding Inreasing Threat tab to esccdbg")
            local tab2 = window:createTab("", "data/textures/icons/gunner.png", "Increasing Threat")
            numButtons = 0
            
            MakeButton(tab2, ButtonRect(nil, nil, nil, tab2.height), "Pirate Attack", "onPirateAttackButtonPressed")
            MakeButton(tab2, ButtonRect(nil, nil, nil, tab2.height), "Decapitation Strike", "onDecapStrikeButtonPressed")
            MakeButton(tab2, ButtonRect(nil, nil, nil, tab2.height), "Deepfake Distress Call", "onDeepfakeDistressButtonPressed")
            MakeButton(tab2, ButtonRect(nil, nil, nil, tab2.height), "Fake Distress Call", "onFakeDistressButtonPressed")
        end

        if _ModTable.hasLongLiveTheEmpress then
            local tab5 = window:createTab("", "data/textures/icons/cavaliers.png", "Long Live The Empress")
            numButtons = 0

            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Test Name Generator", "onNameGeneratorButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Regenerate Weapons", "onRegenWeaponsButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Story Mission 1", "onLLTEStoryMission1ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Story Mission 2", "onLLTEStoryMission2ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Story Mission 3", "onLLTEStoryMission3ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Story Mission 4", "onLLTEStoryMission4ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Story Mission 5", "onLLTEStoryMission5ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 1", "onLLTESideMission1ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 2", "onLLTESideMission2ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 3", "onLLTESideMission3ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 4", "onLLTESideMission4ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 5", "onLLTESideMission5ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Side Mission 6", "onLLTESideMission6ButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Cav Reinforcement Caller", "onCavReinforcementsCallerButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Cav Merchant", "onCavMerchantButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Get Excalibur", "onGetExcaliburButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Reset LLTE Vars", "onResetLLTEVarsButtonPressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Set Rep Level 1", "onLLTERep1Pressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Set Rep Level 3", "onLLTERep3Pressed")
            MakeButton(tab5, ButtonRect(nil, nil, nil, tab5.height), "Set Rep Level 5", "onLLTERep5Pressed")
        end

        if _ModTable.hasBusinessAsUsual then
            local BAUtab = window:createTab("", "data/textures/icons/family.png", "Business As Usual")
            numButtons = 0

            --Misison tabs.
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Story Mission 1", "onBAUStoryMission1ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Story Mission 2", "onBAUStoryMission2ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Story Mission 3", "onBAUStoryMission3ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Story Mission 4", "onBAUStoryMission4ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Story Mission 5", "onBAUStoryMission5ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 1", "onBAUSideMission1ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 2", "onBAUSideMission2ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 3", "onBAUSideMission3ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 4", "onBAUSideMission4ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 5", "onBAUSideMission5ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Side Mission 6", "onBAUSideMission6ButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Reset BAU Vars", "onResetBAUVarsButtonPressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Set Rep Level 1", "onBAURep1Pressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Set Rep Level 3", "onBAURep3Pressed")
            MakeButton(BAUtab, ButtonRect(nil, nil, nil, BAUtab.height), "Set Rep Level 5", "onBAURep5Pressed")
        end

        if _ModTable.hasRetrogradeCampaign then
            local tab9 = window:createTab("", "data/textures/icons/cannon.png", "Retrograde Solutions")
            numButtons = 0

            MakeButton(tab9, ButtonRect(nil, nil, nil, tab9.height), "Spawn Hellhound", "onSpawnHellhoundButtonPressed")
            MakeButton(tab9, ButtonRect(nil, nil, nil, tab9.height), "Spawn Cerberus", "onSpawnCerberusButtonPressed")
            MakeButton(tab9, ButtonRect(nil, nil, nil, tab9.height), "Spawn Tiberius", "onSpawnTiberiusButtonPressed")
        end

        if _ModTable.hasLOTW then
            local tab11 = window:createTab("", "data/textures/icons/silicium.png", "Lord of the Wastes")
            numButtons = 0

            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 1", "onLOTWMission1ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 2", "onLOTWMission2ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 3", "onLOTWMission3ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 4", "onLOTWMission4ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 5", "onLOTWMission5ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 6", "onLOTWMission6ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Mission 7", "onLOTWMission7ButtonPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Clear Values", "onLOTWClearValuesPressed")
            MakeButton(tab11, ButtonRect(nil, nil, nil, tab11.height), "Spawn Swenks", "onSpawnSwenksButtonPressed")
        end

        if _ModTable.hasHorizonKeepers then
            local HKTab = window:createTab("", "data/textures/icons/snowflake-2.png", "Horizon Keepers")
            numButtons = 0

            --MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "", "")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 1", "onHKTabMission1ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 2", "onHKTabMission2ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 3", "onHKTabMission3ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 4", "onHKTabMission4ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 5", "onHKTabMission5ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 6", "onHKTabMission6ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 7", "onHKTabMission7ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 8", "onHKTabMission8ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Mission 9", "onHKTabMission9ButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Frostbite Torp Loader", "onSpawnFrostbiteTorpLoaderButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Frostbite AWACS", "onSpawnFrostibteAWACSButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Frostbite Warship", "onSpawnFrostbiteWarshipButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Frostbite Relief", "onSpawnFrostbiteReliefButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Varlance", "onSpawnVarlanceButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Ice Nova", "onSpawnIceNovaButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Freighter", "onSpawnHKFreightButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Artillery Cruiser", "onSpawnHKACruiseButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Combat Cruiser", "onSpawnHKCCruiseButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK AWACS", "onSpawnHKAWACSButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Battleship", "onSpawnHKBshipButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Hansel", "onSpawnHKHanselButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn HK Gretel", "onSpawnHKGretelButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn XSOLOGIZE", "onSpawnXsologizeButtonPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Horizon Shipyard 1", "onHKShipyard1Pressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Horizon Shipyard 2", "onHKShipyard2Pressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Spawn Horizon Research 1", "onHKResearchPressed")
            MakeButton(HKTab, ButtonRect(nil, nil, nil, HKTab.height), "Clear Values", "onHKClearValuesPressed")
        end

    end
end

function getModTable()

    local _ModTable = {}
    local _BulletinMissionData = {}

    --MODDED CAMPAIGNS BELOW
    local xmods = Mods()

    for _, p in pairs(xmods) do
        if p.id == "2208370349" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasIncreasingThreat = true
        end
        if p.id == "2421751351" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasLongLiveTheEmpress = true
        end
        if p.id == "RetrogradeCampaign" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasRetrogradeCampaign = true
        end
        if p.id == "Emergence" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasEmergence = true
        end
        if p.id == "2733586433" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasLOTW = true
        end
        if p.id == "BusinessAsUsual" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasBusinessAsUsual = true
        end
        if p.id == "HorizonKeepers" then
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasHorizonKeepers = true
        end
        if p.id == "2746663587" then --Ambush Raiders
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true
            
            table.insert(_BulletinMissionData, {
                _Caption = "Ambush Pirate Raiders",
                _Tooltip = "ambushraiders"
            })
        end
        if p.id == "2439444436" then --Attack Research Base
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Attack Research Base",
                _Tooltip = "attackresearchbase"
            })
        end
        if p.id == "2133506910" then --Destroy Prototype
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Destroy Prototype Battleship",
                _Tooltip = "destroyprototype2"
            })
        end
        if p.id == "2379374382" then --Wrecking Havoc
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Wrecking Havoc",
                _Tooltip = "wreckinghavoc"
            })
        end
        if p.id == "2381708468" then --Collect Pirate Bounty
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Collect Pirate Bounty",
                _Tooltip = "piratebounty"
            })
        end
        if p.id == "2743848682" then --Escort Civilian Transports
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Escort Civilian Transports",
                _Tooltip = "escortcivilians"
            })
        end
        if p.id == "2750680477" then --Transfer Satellite
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Transfer Satellite",
                _Tooltip = "transfersatellite"
            })
        end
        if p.id == "2901149152" then --Xsotan Infestation
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Eradicate Xsotan Infestation",
                _Tooltip = "eradicatexsotan"
            })
        end
        if p.id == "3306700477" then --Defend Prototype
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Defend Prototype Battleship",
                _Tooltip = "defendprototype"
            })
        end
        if p.id == "3341419631" then --Rescue Slaves
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Rescue Slaves",
                _Tooltip = "rescueslaves"
            })
        end
        if p.id == "DestroyStronghold" then --Destroy Stronghold
            _ModTable.hasAnyCampaignMods = true
            _ModTable.hasAnyBulletinMods = true

            table.insert(_BulletinMissionData, {
                _Caption = "Destroy Pirate Stronghold",
                _Tooltip = "destroystronghold"
            })
        end
    end

    if _ModTable.hasAnyBulletinMods then
        _ModTable._BulletinMissionTable = _BulletinMissionData
    end

    return _ModTable    
end

--region #OTHER

local function getPositionInFrontOfPlayer()
    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 500

    return MatrixLookUpPosition(-dir, up, pos)
end

--Misc Callbacks
function onPiratesGenerated(generated)
    local _Debug = 0
    if _Debug == 1 then
        for _, _g in pairs(generated) do
            local _gShield = Shield(_g)
            if _gShield then
                print("Max dura factor of Shield is " .. tostring(_gShield.maxDurabilityFactor))
            end
            local _gDurability = Durability(_g)
            if _gDurability then
                print("Max dura factor of Durability is " .. tostring(_gDurability.maxDurabilityFactor))
            end
        end
    end
    SpawnUtility.addEnemyBuffs(generated)
end

function onMegaLaserPiratesGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        ShipUtility.addMegaLasers(_S, 10)
    end
end

function onMegaSeekerPiratesGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        ShipUtility.addMegaSeekers(_S, 10)
    end
end

function onSlammerGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        local _TorpSlammerValues = {}
        _TorpSlammerValues._ForwardAdjustFactor = 2.5
        _S:addScript("torpedoslammer.lua", _TorpSlammerValues)
        _S:addScript("icon.lua", "data/textures/icons/pixel/torpedoboatex.png")
    end
end

function onDeadshotGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        local _TitleArgs = _S:getTitleArguments()
        _S:setTitle("${toughness}${lasername}${title}", {toughness = _TitleArgs.toughness, title = _TitleArgs.title, lasername = "Deadshot "})

        _S:addScript("lasersniper.lua")
        _S:addScript("icon.lua", "data/textures/icons/pixel/laserboat.png")
    end
end

function onSpawnSeigeGunGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do

        local _sgargs = {}
        _sgargs._CodesCracked = true
        _sgargs._Velocity = 400
        _sgargs._ShotCycle = 30
        _sgargs._ShotCycleSupply = 0
        _sgargs._ShotCycleTimer = 30
        _sgargs._UseSupply = false
        _sgargs._FragileShots = false
        _sgargs._TargetPriority = 1 --Target a random enemy.
        _sgargs._UseEntityDamageMult = true --Use the entity damage multiplier. Fun with the overdrive / avenger scripts :)
        _sgargs._BaseDamagePerShot = 100000 --Enough to notice but not enough to really heck the player up

        _S:addScript("stationsiegegun.lua", _sgargs)
    end
end

function onAbsolutePDGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        _S:addScript("absolutepointdefense.lua")
    end
end

function onIronCurtainGenerated(_Generated)
    onPiratesGenerated(_Generated)
    for _, _S in pairs(_Generated) do
        _S:addScript("ironcurtain.lua")
    end
end

function onEternalEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding eternal script to enemy")
    for _, _S in pairs(_Generated) do
        _S:addScript("eternal.lua")
    end
end

function onOverdriveEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding overdrive script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("overdrive.lua")
    end
end

function onAdaptiveEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding adaptive defense script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("adaptivedefense.lua")
    end
end

function onAfterburnerEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding afterburner script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("afterburn.lua")
    end
end

function onAvengerEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding avenger script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("avenger.lua")
    end
end

function onMeathookEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding meathook script to enemy. Mmmmm... meaty...")
    for _, _S in pairs(_Generated) do
        _S:addScript("meathook.lua")
    end
end

function onBoosterEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding booster script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("allybooster.lua")
    end
end

function onBoosterHealerEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding booster + args script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("allybooster.lua", {_HealWhenBoosting = true, _HealPctWhenBoosting = 33, _MaxBoostCharges = 3})
    end
end

function onPhaserEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding phaser script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("phasemode.lua")
    end   
end

function onFrenziedEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding frenzy script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("frenzy.lua")
    end
end

function onSecondariedEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding secondary weapon script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("secondaryweapons.lua")
    end
end

function onThornsEnemyGenerated(_Generated)
    onPiratesGenerated(_Generated)
    print("adding thorns script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("thorns.lua")        
    end
end

--endregion

--region #TAB1

function onSpawnJammerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnJammerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledJammer(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnJammerButtonPressed")

function onSpawnStingerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnStingerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledStinger(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnStingerButtonPressed")

function onSpawnScorcherButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnScorcherButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledScorcher(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnScorcherButtonPressed")

function onSpawnBomberButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBomberButtonPressed")
        return
    end
    
    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledBomber(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnBomberButtonPressed")

function onSpawnSinnerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSinnerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledSinner(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnSinnerButtonPressed")

function onSpawnProwlerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnProwlerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledProwler(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnProwlerButtonPressed")

function onSpawnPillagerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnPillagerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledPillager(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnPillagerButtonPressed")

function onSpawnDevastatorButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnDevastatorButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnDevastatorButtonPressed")

--The following functions spawn Devastators with some special test scripts.
function onSpawnTorpedoSlammerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnTorpedoSlammerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onSlammerGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnTorpedoSlammerButtonPressed")

function onSpawnDeadshotButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnDeadshotButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onDeadshotGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnDeadshotButtonPressed")

function onSpawnSeigeGunButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSeigeGunButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onSpawnSeigeGunGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnSeigeGunButtonPressed")

function onSpawnAbsolutePDButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnAbsolutePDButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onAbsolutePDGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnAbsolutePDButtonPressed")

function onSpawnIronCurtainButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnIronCurtainButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onIronCurtainGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnIronCurtainButtonPressed")

function onSpawnEternalButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnEternalButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onEternalEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnEternalButtonPressed")

function onSpawnOverdriveButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnOverdriveButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onOverdriveEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnOverdriveButtonPressed")

function onSpawnAdaptiveButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnAdaptiveButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onAdaptiveEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnAdaptiveButtonPressed")

function onSpawnAfterburnerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnAfterburnerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onAfterburnerEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnAfterburnerButtonPressed")

function onSpawnAvengerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnAvengerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onAvengerEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnAvengerButtonPressed")

function onSpawnMeathookButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnMeathookButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onMeathookEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnMeathookButtonPressed")

function onSpawnBoosterButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnBoosterButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onBoosterEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()    
end
callable(nil, "onSpawnBoosterButtonPressed")

function onSpawnBoosterHealerButtonPressed()
    if onClient() then 
        invokeServerFunction("onSpawnBoosterHealerButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onBoosterHealerEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()    
end
callable(nil, "onSpawnBoosterHealerButtonPressed")

function onSpawnPhaserButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnPhaserButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onPhaserEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()    
end
callable(nil, "onSpawnPhaserButtonPressed")

function onSpawnFrenziedButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFrenziedButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onFrenziedEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()    
end
callable(nil, "onSpawnFrenziedButtonPressed")

function onSpawnSecondariesButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnSecondariesButtonPressed")
        return
    end

    local generator = AsyncPirateGenerator(nil, onSecondariedEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()   
end
callable(nil, "onSpawnSecondariesButtonPressed")

function onSpawnThornsButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnThornsButtonPressed")
        return
    end
    
    local generator = AsyncPirateGenerator(nil, onThornsEnemyGenerated)
    generator:startBatch()

    generator:createScaledDevastator(getPositionInFrontOfPlayer())

    generator:endBatch()
end
callable(nil, "onSpawnThornsButtonPressed")

function onSpawnXsotanInfestorButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanInfestorButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createInfestor(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanInfestorButtonPressed")

function onSpawnXsotanOppressorButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanOppressorButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createOppressor(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanOppressorButtonPressed")

function onSpawnXsotanSunmakerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanSunmakerButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createSunmaker(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanSunmakerButtonPressed")

function onSpawnXsotanBallistyxButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanBallistyxButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createBallistyx(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanBallistyxButtonPressed")

function onSpawnXsotanLonginusButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanLonginusButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createLonginus(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanLonginusButtonPressed")

function onSpawnXsotanPulverizerButtonPressed()
    if onClient() then 
        invokeServerFunction("onSpawnXsotanPulverizerButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createPulverizer(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanPulverizerButtonPressed")

function onSpawnXsotanWarlockButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsotanWarlockButtonPressed")
        return
    end

    local dir = Entity().look
    local up = Entity().up
    local position = Entity().translationf

    local pos = position + dir * 100
    Xsotan.createWarlock(MatrixLookUpPosition(-dir, up, pos))
end
callable(nil, "onSpawnXsotanWarlockButtonPressed")

--endregion

--region #TAB3

function tab3SpawnExecutioner(_Power)
    local generator = AsyncPirateGenerator(nil, onPiratesGenerated)
    generator:startBatch()

    generator:createScaledExecutioner(getPositionInFrontOfPlayer(), _Power)

    generator:endBatch()
end

function onSpawnExecutionerButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutionerButtonPressed")
        return
    end

    tab3SpawnExecutioner(0)
end
callable(nil, "onSpawnExecutionerButtonPressed")

function onSpawnExecutioner2ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner2ButtonPressed")
        return
    end

    tab3SpawnExecutioner(500)
end
callable(nil, "onSpawnExecutioner2ButtonPressed")

function onSpawnExecutioner3ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner3ButtonPressed")
        return
    end

    tab3SpawnExecutioner(1000)
end
callable(nil, "onSpawnExecutioner3ButtonPressed")

function onSpawnExecutioner4ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner4ButtonPressed")
        return
    end

    tab3SpawnExecutioner(10000)
end
callable(nil, "onSpawnExecutioner4ButtonPressed")

function onSpawnExecutioner5ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner5ButtonPressed")
        return
    end

    tab3SpawnExecutioner(50000)
end
callable(nil, "onSpawnExecutioner5ButtonPressed")

function onSpawnExecutioner6ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner6ButtonPressed")
        return
    end

    tab3SpawnExecutioner(100000)
end
callable(nil, "onSpawnExecutioner6ButtonPressed")

function onSpawnExecutioner7ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner7ButtonPressed")
        return
    end

    tab3SpawnExecutioner(1000000)
end
callable(nil, "onSpawnExecutioner7ButtonPressed")

function onSpawnExecutioner8ButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnExecutioner8ButtonPressed")
        return
    end

    tab3SpawnExecutioner(10000000)
end
callable(nil, "onSpawnExecutioner8ButtonPressed")

--endregion

--region #TAB2 (Increasing Threat)

function spawnITBoss(_BossType)
    local generator = AsyncPirateGenerator(nil, nil)
    local ESCCBoss = include("esccbossutil")
    ESCCBoss.spawnESCCBoss(generator:getPirateFaction(), _BossType)
end

function onPirateAttackButtonPressed()
    if onClient() then
        invokeServerFunction("onPirateAttackButtonPressed")
        return
    end

    Sector():addScript("pirateattack.lua")
end
callable(nil, "onPirateAttackButtonPressed")

function onDecapStrikeButtonPressed()
    if onClient() then
        invokeServerFunction("onDecapStrikeButtonPressed")
        return
    end

    Sector():addScript("decapstrike.lua")
end
callable(nil, "onDecapStrikeButtonPressed")

function onDeepfakeDistressButtonPressed()
    if onClient() then
        invokeServerFunction("onDeepfakeDistressButtonPressed")
        return
    end

    local player = Player(callingPlayer)
    player:addScript("events/deepfakedistress.lua", true)
end
callable(nil, "onDeepfakeDistressButtonPressed")

function onFakeDistressButtonPressed()
    if onClient() then
        invokeServerFunction("onFakeDistressButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    _Player:addScript("events/itfakedistresssignal.lua", true)
end
callable(nil, "onFakeDistressButtonPressed")

function onKatanaBossButtonPressed()
    if onClient() then
        invokeServerFunction("onKatanaBossButtonPressed")
        return
    end

    spawnITBoss(1)
end
callable(nil, "onKatanaBossButtonPressed")

function onPhoenixBossButtonPressed()
    if onClient() then
        invokeServerFunction("onPhoenixBossButtonPressed")
        return
    end

    spawnITBoss(6)
end
callable(nil, "onPhoenixBossButtonPressed")

function onHunterBossButtonPressed()
    if onClient() then
        invokeServerFunction("onHunterBossButtonPressed")
        return
    end

    spawnITBoss(4)
end
callable(nil, "onHunterBossButtonPressed")

function onHellcatBossButtonPressed()
    if onClient() then
        invokeServerFunction("onHellcatBossButtonPressed")
        return
    end

    spawnITBoss(3)
end
callable(nil, "onHellcatBossButtonPressed")

function onGoliathBossButtonPressed()
    if onClient() then
        invokeServerFunction("onGoliathBossButtonPressed")
        return
    end

    spawnITBoss(2)
end
callable(nil, "onGoliathBossButtonPressed")

function onShieldBossButtonPressed()
    if onClient() then
        invokeServerFunction("onShieldBossButtonPressed")
        return
    end

    spawnITBoss(5)
end
callable(nil, "onShieldBossButtonPressed")

--endregion

--region #TAB4

function onFlyToMeButtonPressed()
    if onClient() then
        invokeServerFunction("onFlyToMeButtonPressed")
        return
    end

    local craftidx = Player(callingPlayer).craftIndex
    local playerShip = Entity(craftidx)

    --Get the enemy ship components we need.
    local eCtlUnit = ControlUnit(Entity())
    local eAIUnit = ShipAI(Entity())
    local eEngUnit = Engine(Entity())

    --Set existing AI to idle.
    eAIUnit:setIdle()
    --Command it to fly to the player's position at maximum speed.
    print(
        "sending fly order... flying to " ..
            tostring(playerShip.translationf) .. " ... flying from " .. tostring(Entity().translationf)
    )
    eAIUnit:setFlyLinear(playerShip.translationf, 100, false)
    --eCtlUnit:flyToLocation(playerShip.translationf, eEngUnit.maxVelocity)
    local ctlActions = eCtlUnit:getAllControlActions()
end
callable(nil, "onFlyToMeButtonPressed")

function onShootMeButtonPressed()
    if onClient() then
        invokeServerFunction("onShootMeButtonPressed")
        return
    end

    local craftidx = Player(callingPlayer).craftIndex
    local playerShip = Entity(craftidx)

    --Get the enemy ship components we need.
    local eCtlUnit = ControlUnit(Entity())
    local eAIUnit = ShipAI(Entity())

    print("enabling shooting")
    eAIUnit:setPassiveShooting(true)
end
callable(nil, "onShootMeButtonPressed")

function onAttachTindalosButtonPressed()
    if onClient() then
        invokeServerFunction("onAttachTindalosButtonPressed")
        return
    end

    print("adding custom Tindalos AI to entity.")
    Entity():addScript("data/scripts/entity/ai/custom/pursuitai.lua")
end
callable(nil, "onAttachTindalosButtonPressed")

--endregion

--region #TAB5 (Long Live The Empress)

function onNameGeneratorButtonPressed()
    LLTEUtil = include("llteutil")
    local _TestName = LLTEUtil.getRandomName(true, true)

    print("Test Name is " .. tostring(_TestName.name))
    print("Test Gender is " .. tostring(_TestName.gender))
end
callable(nil, "onNameGeneratorButtonPressed")

function onRegenWeaponsButtonPressed()
    if onClient() then
        invokeServerFunction("onRegenWeaponsButtonPressed")
        return
    end

    local _Cavs = Galaxy():findFaction("The Cavaliers")
    if not _Cavs then
        print("Haven't found The Cavaliers")
        return
    end
    _Cavs:setValue("_llte_cavaliers_regenArsenal", 1)
end
callable(nil, "onRegenWeaponsButtonPressed")

function onLLTEStoryMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEStoryMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/empress/story/lltestorymission1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTEStoryMission1ButtonPressed")

function onLLTEStoryMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEStoryMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/empress/story/lltestorymission2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTEStoryMission2ButtonPressed")

function onLLTEStoryMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEStoryMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/empress/story/lltestorymission3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTEStoryMission3ButtonPressed")

function onLLTEStoryMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEStoryMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/empress/story/lltestorymission4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTEStoryMission4ButtonPressed")

function onLLTEStoryMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEStoryMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/empress/story/lltestorymission5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTEStoryMission5ButtonPressed")

function onLLTESideMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission1ButtonPressed")

function onLLTESideMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission2ButtonPressed")

function onLLTESideMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission3ButtonPressed")

function onLLTESideMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission4ButtonPressed")

function onLLTESideMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission5ButtonPressed")

function onLLTESideMission6ButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTESideMission6ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "data/scripts/player/missions/empress/side/lltesidemission6.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLLTESideMission6ButtonPressed")

function onCavReinforcementsCallerButtonPressed()
    if onClient() then
        invokeServerFunction("onCavReinforcementsCallerButtonPressed")
        return
    end

    print("Adding Cavaliers reinforcement beacon")
    local _Player = Player(callingPlayer)
    local _AllyFaction = Galaxy():findFaction("The Cavaliers")

    _Player:getInventory():addOrDrop(
        UsableInventoryItem("cavaliersreinforcementtransmitter.lua", Rarity(RarityType.Exotic), _AllyFaction.index)
    )
end
callable(nil, "onCavReinforcementsCallerButtonPressed")

function onCavMerchantButtonPressed()
    if onClient() then
        invokeServerFunction("onCavMerchantButtonPressed")
        return
    end

    print("Spawning Cavaliers Merchant")
    local _Player = Player(callingPlayer)
    _Player:addScript("events/spawncavaliersmerchant.lua")
end
callable(nil, "onCavMerchantButtonPressed")

function onGetExcaliburButtonPressed()
    if onClient() then
        invokeServerFunction("onGetExcaliburButtonPressed")
        return
    end

    print("Getting EXCALIBUR railgun")

    LLTEUtil = include("llteutil")

    local _Player = Player(callingPlayer)
    _Player:getInventory():addOrDrop(LLTEUtil.getSpecialRailguns())
end
callable(nil, "onGetExcaliburButtonPressed")

function onResetLLTEVarsButtonPressed()
    if onClient() then
        invokeServerFunction("onResetLLTEVarsButtonPressed")
        return
    end

    print("Resetting LLTE Vars")

    local player = Player(callingPlayer)

    player:setValue("_llte_cavaliers_ranklevel", nil)
    player:setValue("_llte_cavaliers_rank", nil)
    player:setValue("_llte_cavaliers_rep", nil)
    player:setValue("_llte_cavaliers_nextcontact", nil)
    player:setValue("_llte_cavaliers_startstory", nil)
    player:setValue("_llte_story_1_accomplished", nil)
    player:setValue("_llte_story_2_accomplished", nil)
    player:setValue("_llte_story_3_accomplished", nil)
    player:setValue("_llte_story_4_accomplished", nil)
    player:setValue("_llte_story_5_accomplished", nil)
    player:setValue("_llte_failedstory2", nil)
    player:setValue("_llte_pirate_faction_vengeance", nil)
    player:setValue("_llte_got_animosity_loot", nil)
    player:setValue("_llte_cavaliers_have_avorion", nil)
    player:setValue("_llte_cavaliers_strength", nil)
    player:setValue("_llte_cavaliers_inbarrier", nil)
    --Remove all scripts, and I mean ALL scripts.
    local _Scripts = {
        "missions/empress/story/lltestorymission1.lua",
        "missions/empress/story/lltestorymission2.lua",
        "missions/empress/story/lltestorymission3.lua",
        "missions/empress/story/lltestorymission4.lua",
        "missions/empress/story/lltestorymission5.lua",
        "missions/empress/side/lltesidemission1.lua",
        "missions/empress/side/lltesidemission2.lua",
        "missions/empress/side/lltesidemission3.lua",
        "missions/empress/side/lltesidemission4.lua",
        "missions/empress/side/lltesidemission5.lua",
        "missions/empress/side/lltesidemission6.lua"
    }
    for _, _Script in pairs(_Scripts) do
        if player:hasScript(_Script) then
            print("Invoking fail method of " .. _Script)
            player:invokeFunction(_Script, "fail")
        end
    end
end
callable(nil, "onResetLLTEVarsButtonPressed")

function onLLTERep1Pressed()
    if onClient() then
        invokeServerFunction("onLLTERep1Pressed")
        return
    end

    print("Resetting Reputational LLTE Vars")

    local player = Player(callingPlayer)

    player:setValue("_llte_cavaliers_ranklevel", 1)
    player:setValue("_llte_cavaliers_rank", "Squire")
    player:setValue("_llte_cavaliers_rep", 4)
end
callable(nil, "onLLTERep1Pressed")

function onLLTERep3Pressed()
    if onClient() then
        invokeServerFunction("onLLTERep3Pressed")
        return
    end

    print("Resetting Reputational LLTE Vars")

    local player = Player(callingPlayer)

    player:setValue("_llte_cavaliers_ranklevel", 3)
    player:setValue("_llte_cavaliers_rank", "Crusader")
    player:setValue("_llte_cavaliers_rep", 29)
end
callable(nil, "onLLTERep3Pressed")

function onLLTERep5Pressed()
    if onClient() then
        invokeServerFunction("onLLTERep5Pressed")
        return
    end

    print("Resetting Reputational LLTE Vars")

    local player = Player(callingPlayer)

    player:setValue("_llte_cavaliers_ranklevel", 5)
    player:setValue("_llte_cavaliers_rank", "Paladin")
    player:setValue("_llte_cavaliers_rep", 51)
end
callable(nil, "onLLTERep5Pressed")

--endregion

--region #TAB BAU (Business As Usual)

function onBAUStoryMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUStoryMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/story/baustory1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUStoryMission1ButtonPressed")

function onBAUStoryMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUStoryMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/story/baustory2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUStoryMission2ButtonPressed")

function onBAUStoryMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUStoryMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/story/baustory3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUStoryMission3ButtonPressed")

function onBAUStoryMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUStoryMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/story/baustory4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUStoryMission4ButtonPressed")

function onBAUStoryMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUStoryMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/story/baustory5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUStoryMission5ButtonPressed")

function onBAUSideMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUSideMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/side/bauside1.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUSideMission1ButtonPressed")

function onBAUSideMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUSideMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/side/bauside2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUSideMission2ButtonPressed")

function onBAUSideMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUSideMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/side/bauside3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUSideMission3ButtonPressed")

function onBAUSideMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUSideMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/side/bauside4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUSideMission4ButtonPressed")

function onBAUSideMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onBAUSideMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/family/side/bauside5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onBAUSideMission5ButtonPressed")

function onResetBAUVarsButtonPressed()
    if onClient() then
        invokeServerFunction("onResetBAUVarsButtonPressed")
        return
    end

    print("Resetting BAU Vars")

    local player = Player(callingPlayer)

    --Set all values to nil
    local _values = {
        "_bau_family_inbarrier",
        "_bau_family_ranklevel",
        "_bau_family_rank",
        "_bau_family_rep",
        "_bau_family_nextcontact",
        "_bau_family_startstory",
        "_bau_story_1_accomplished",
        "_bau_story_2_accomplished",
        "_bau_story_3_accomplished",
        "_bau_story_4_accomplished",
        "_bau_story_5_accomplished",
        "_bau_family_have_avorion",
        "_bau_family_strength",
        "_bau_family_inbarrier"
    }

    for _, _val in pairs(_values) do
        player:setValue(_val, nil)
    end

    --Remove all scripts, and I mean ALL scripts.
    local _Scripts = {
        "missions/family/story/baustory1.lua",
        "missions/family/story/baustory2.lua",
        "missions/family/story/baustory3.lua",
        "missions/family/story/baustory4.lua",
        "missions/family/story/baustory5.lua",
        "missions/family/side/bauside1.lua",
        "missions/family/side/bauside2.lua",
        "missions/family/side/bauside3.lua",
        "missions/family/side/bauside4.lua",
        "missions/family/side/bauside5.lua"
    }
    for _, _Script in pairs(_Scripts) do
        if player:hasScript(_Script) then
            print("Invoking fail method of " .. _Script)
            player:invokeFunction(_Script, "fail")
        end
    end
end
callable(nil, "onResetBAUVarsButtonPressed")

function onBAURep1Pressed()
    if onClient() then
        invokeServerFunction("onBAURep1Pressed")
        return
    end

    print("Resetting Reputational BAU Vars")

    local player = Player(callingPlayer)

    player:setValue("_bau_family_ranklevel", 1)
    player:setValue("_bau_family_rank", "Associate")
    player:setValue("_bau_family_rep", 4)
end
callable(nil, "onBAURep1Pressed")

function onBAURep3Pressed()
    if onClient() then
        invokeServerFunction("onBAURep3Pressed")
        return
    end

    player:setValue("_bau_family_ranklevel", 3)
    player:setValue("_bau_family_rank", "Capo")
    player:setValue("_bau_family_rep", 29)
end
callable(nil, "onBAURep3Pressed")

function onBAURep5Pressed()
    if onClient() then
        invokeServerFunction("onBAURep5Pressed")
        return
    end

    player:setValue("_bau_family_ranklevel", 5)
    player:setValue("_bau_family_rank", "Underboss")
    player:setValue("_bau_family_rep", 51)
end
callable(nil, "onBAURep5Pressed")

--endregion

--region #TAB6

function onTurretDataDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onTurretDataDumpButtonPressed")
        return
    end

    local _Ship = Entity()
    local _Faction = Faction(_Ship.factionIndex)

    local _TurretTemplates = _Faction:getInventory():getItemsByType(InventoryItemType.TurretTemplate)
    local _Items = {}
    for _, _Itm in pairs(_TurretTemplates) do
        local _Turret = _Itm.item
        table.insert(_Items, _Turret)
    end

    for _, _TurretItem in pairs(_Items) do
        print("=== NEW TURRET ===")
        print("name : " .. tostring(_TurretItem.name))
        print("icon : " .. tostring(_TurretItem.weaponIcon))
        print("weapon name : " .. tostring(_TurretItem.weaponName))
        print("avg tech : " .. tostring(_TurretItem.averageTech))
        print("max tech : " .. tostring(_TurretItem.maxTech))
        print("material : " .. tostring(_TurretItem.material))
        print("damage : " .. tostring(_TurretItem.damage))
        print("damage type : " .. tostring(_TurretItem.damageType))
        print("omicron : " .. tostring(_TurretItem.dps))
        print("rarity : " .. tostring(_TurretItem.rarity))
    end
end
callable(nil, "onTurretDataDumpButtonPressed")

function onUpgradeDataDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onUpgradeDataDumpButtonPressed")
        return
    end

    local _Ship = Entity()
    local _Faction = Faction(_Ship.factionIndex)

    local _UpgradeTemplates = _Faction:getInventory():getItemsByType(InventoryItemType.SystemUpgrade)
    local _Items = {}
    for _, _Itm in pairs(_UpgradeTemplates) do
        local _Upgrade = _Itm.item
        table.insert(_Items, _Upgrade)
    end

    for _, _UpgradeItem in pairs(_Items) do
        print("=== NEW UPGRADE ===")
        print("script : " .. tostring(_UpgradeItem.script))
    end
end
callable(nil, "onUpgradeDataDumpButtonPressed")

function onTraitDataDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onTraitDataDumpButtonPressed")
        return
    end

    local _Ship = Entity()
    local _Faction = Faction(_Ship.factionIndex)

    local _Traits = _Faction:getTraits()

    for _K, _T in pairs(_Traits) do
        print("name : " .. tostring(_K) .. " || value : " .. tostring(_T))
    end
end
callable(nil, "onTraitDataDumpButtonPressed")

function onStationListDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onStationListDumpButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _PlayerShipNames = {_Player:getShipNames()}
    print("This isn't that useful unfortunately since it is not possible to load entities remotely.")

    for _, _S in pairs(_PlayerShipNames) do
        local _ShipType = _Player:getShipType(_S)
        if _ShipType == EntityType.Station then
            --Yeah apparently the only way to do this is load the sector, then grab the sector and load the station out of it.
            local _X, _Y = _Player:getShipPosition(_S)
            print(tostring(_S) .. " is a station located at (" .. tostring(_X) .. ":" .. tostring(_Y) .. ")")
        end
    end
end
callable(nil, "onStationListDumpButtonPressed")

function onServerValueDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onServerValueDumpButtonPressed")
        return
    end

    local _Server = Server()
    local _ServerValues = _Server:getValues()
    for _K, _V in pairs(_ServerValues) do
        print("Server value name: " .. tostring(_K) .. " is: " .. tostring(_V))
    end
end
callable(nil, "onServerValueDumpButtonPressed")

function onPlayerValueDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onPlayerValueDumpButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _PlayerValues = _Player:getValues()
    for _K, _V in pairs(_PlayerValues) do
        print("Player value name: " .. tostring(_K) .. " is: " .. tostring(_V))
    end
end
callable(nil, "onPlayerValueDumpButtonPressed")

function onMaterialDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onMaterialDumpButtonPressed")
        return
    end

    local _MatlTable = Balancing_GetTechnologyMaterialProbability(Sector():getCoordinates())
    for _k, _v in pairs(_MatlTable) do
        print("key : " .. tostring(_k) .. " value : " .. tostring(_v))
    end
end
callable(nil, "onMaterialDumpButtonPressed")

function onSectorDPSDumpButtonPressed()
    if onClient() then
        invokeServerFunction("onSectorDPSDumpButtonPressed")
        return
    end

    for idx = 499, 0, -1 do
        local _dps = Balancing_GetSectorWeaponDPS(0, idx) --Just do 0, idx
        print("distance : " .. tostring(idx) .. " dps : " .. tostring(_dps))
    end
end
callable(nil, "onSectorDPSDumpButtonPressed")

--endregion

--region #TAB7 (Other tab)

function onRunScratchScriptButtonPressed()
    if onClient() then
        --Put client script here.

        invokeServerFunction("onRunScratchScriptButtonPressed")
        return
    end
    --Put server script here.
end
callable(nil, "onRunScratchScriptButtonPressed")

function onLoadTorpedoesButtonPressed()
    if onClient() then
        invokeServerFunction("onLoadTorpedoesButtonPressed")
        return
    end

    local _TorpGenerator = TorpedoGenerator()
    local _Player = Player(callingPlayer)
    local _Craft = _Player.craft
    local _Launcher = TorpedoLauncher(_Craft.index)
    local _Shafts = {_Launcher:getShafts()}
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()

    local _Torpedo = _TorpGenerator:generate(_X, _Y)

    print("Adding torpedos directly to all " .. tostring(#_Shafts) .. " launchers.")

    local _Shafts = {_Launcher:getShafts()}

    for _, _Shaft in pairs(_Shafts) do
        print(
            "K : " ..
                tostring(_) ..
                    " - V : " .. tostring(_Shaft) .. " - Frre Slots : " .. tostring(_Launcher:getFreeSlots(_Shaft))
        )
    end

    print("numShafts : " .. tostring(_Launcher.numShafts) .. " - maxShafts : " .. tostring(_Launcher.maxShafts))

    for _, _Shaft in pairs(_Shafts) do
        while _Launcher:getFreeSlots(_Shaft) > 0 and _Launcher:getFreeSlots(_Shaft) ~= 15 do
            print("Free slots in shaft " .. tostring(_) .. " : " .. tostring(_Launcher:getFreeSlots(_)))
            _Launcher:addTorpedo(_Torpedo, _Shaft)
        end
    end

    print("Adding torpeodes to storage.")

    while _Launcher.freeStorage > _Torpedo.size do
        print("Launcher storage remaining : " .. tostring(_Launcher.freeStorage))
        _Launcher:addTorpedo(_Torpedo)
    end
end
callable(nil, "onLoadTorpedoesButtonPressed")

function onZeroOutResourcesButtonPressed()
    if onClient() then
        invokeServerFunction("onZeroOutResourcesButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local money = 0
    _Player.money = money
    _Player:setResources(money, money, money, money, money, money, money, money, money, money, money) -- as Boxelware says, too much, don't care
end
callable(nil, "onZeroOutResourcesButtonPressed")

function onTestPariahSpawnButtonPressed()
    if onClient() then
        invokeServerFunction("onTestPariahSpawnButtonPressed")
        return
    end

    local PariahUtil = include("pariahutility")
    PariahUtil.spawnSuperWeapon()
end
callable(nil, "onTestPariahSpawnButtonPressed")

function onRepairAllShipsButtonPressed()
    if onClient() then
        invokeServerFunction("onRepairAllShipsButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _PlayerEntities = {Sector():getEntitiesByFaction(_Player.index)}
    for _, _Entity in pairs(_PlayerEntities) do
        if _Entity.type == EntityType.Ship then
            local _PerfectShipPlan = _Player:getShipPlan(_Entity.name)
            if _PerfectShipPlan then
                _PerfectShipPlan:resetDurability()
                _Entity:setMalusFactor(1.0, MalusReason.None)
                _Entity:setMovePlan(_PerfectShipPlan)
                _Entity.durability = _Entity.maxDurability
            end
        end
    end
end
callable(nil, "onRepairAllShipsButtonPressed")

function onRunSectorDPSPressed()
    if onClient() then
        invokeServerFunction("onRunSectorDPSPressed")
        return
    end

    local x, y = Sector():getCoordinates()
    local _MaxDPS = 0
    local _MinDPS = 0

    for _Attempts = 1, 10000 do
        local _dps, _tech = Balancing_GetSectorWeaponDPS(x, y)

        if _Attempts == 1 or _dps < _MinDPS then
            _MinDPS = _dps
        end

        if _dps > _MaxDPS then
            _MaxDPS = _dps
        end
    end

    print("MAX DPS -- " .. tostring(_MaxDPS) .. " -- MIN DPS -- " .. tostring(_MinDPS))
end
callable(nil, "onRunSectorDPSPressed")

function onGetPositionPressed()
    local _Ship = Player().craft
    print(tostring(_Ship.translationf))
end

function onCenterPositionPressed()
    local _Ship = Player().craft
    _Ship.position = Matrix()
end

function onDistanceButtonPressed()
    local _Ship = Player().craft
    local _Target = _Ship.selectedObject

    print("DISTANCE: " .. tostring(distance(_Ship.translationf, _Target.translationf)))
    print("DISTANCE2: " .. tostring(distance2(_Ship.translationf, _Target.translationf)))
end

function onTestOOSButtonPressed()
    if onClient() then
        invokeServerFunction("onTestOOSButtonPressed")
        return
    end

    print("Testing OOS attack")
    local _Player = Player(callingPlayer)
    _Player:addScriptOnce("events/passiveplayerattackstarter.lua")
end
callable(nil, "onTestOOSButtonPressed")

function onLLTEResetXWGButtonPressed()
    if onClient() then
        invokeServerFunction("onLLTEResetXWGButtonPressed")
        return
    end

    print("Resetting XWG! It will spawn in 1 second.")
    local _Server = Server()
    _Server:setValue("guardian_respawn_time", 1)
    _Server:setValue("xsotan_swarm_active", nil)
    _Server:setValue("xsotan_swarm_success", nil)
    _Server:setValue("xsotan_swarm_time", nil)
    _Server:setValue("xsotan_swarm_duration", nil)
end
callable(nil, "onLLTEResetXWGButtonPressed")

function onAcidFogIntensity1Pressed()
    if onClient() then
        invokeServerFunction("onAcidFogIntensity1Pressed")
        return
    end

    print("Adding acid fog @ 1")
    EnvironmentalEffectUT.addEffect(EnvironmentalEffectType.AcidFog, 1)
end
callable(nil, "onAcidFogIntensity1Pressed")

function onAcidFogIntensity2Pressed()
    if onClient() then
        invokeServerFunction("onAcidFogIntensity2Pressed")
        return
    end

    print("Adding acid fog @ 2")
    EnvironmentalEffectUT.addEffect(EnvironmentalEffectType.AcidFog, 2)
end
callable(nil, "onAcidFogIntensity2Pressed")

function onAcidFogIntensity3Pressed()
    if onClient() then
        invokeServerFunction("onAcidFogIntensity3Pressed")
        return
    end

    print("Adding acid fog @ 3")
    EnvironmentalEffectUT.addEffect(EnvironmentalEffectType.AcidFog, 3)
end
callable(nil, "onAcidFogIntensity3Pressed")

function onRadiationIntensity1Pressed()
    if onClient() then
        invokeServerFunction("onRadiationIntensity1Pressed")
        return
    end

    print("Adding radiation @ 1")
    EnvironmentalEffectUT.addEffect(EnvironmentalEffectType.Radiation, 1)
end
callable(nil, "onRadiationIntensity1Pressed")

function onRemoveWeatherPressed()
    if onClient() then
        invokeServerFunction("onRemoveWeatherPressed")
        return
    end

    print("Removing all weather")
    EnvironmentalEffectUT.removeAllEffects()
end
callable(nil, "onRemoveWeatherPressed")

function onRunESCCMinVecTestButtonPressed()
    if onClient() then
        invokeServerFunction("onRunESCCMinVecTestButtonPressed")
        return
    end

    local ESCCUtil = include("esccutil")
    local _mypos = Entity().translationf

    print("Testing at min dist 2000")
    local _testvec = ESCCUtil.getVectorAtDistance(_mypos, 2000, true)
    print("VECTOR IS " .. tostring(_testvec) .. " DISTANCE FROM _mypos is " .. tostring(distance(_mypos, _testvec)))

    print("Testing at max dist 2000")
    _testvec = ESCCUtil.getVectorAtDistance(_mypos, 2000, false)
    print("VECTOR IS " .. tostring(_testvec) .. " DISTANCE FROM _mypos is " .. tostring(distance(_mypos, _testvec)))
end
callable(nil, "onRunESCCMinVecTestButtonPressed")

function onRunGetDistToCenterButtonPressed()
    _Sector = Sector()
    local x, y = _Sector():getCoordinates()

    local cpos = vec2(x, y)
    print("Distance : " .. tostring(distance(cpos, vec2(0,0))))
end

function onGetTranslationButtonPressed()
    local _entity = Entity()

    print("Trnaslationf is " .. tostring(_entity.translationf))
end

--endregion

--region #TAB8 SUPPORT

function getGoodsForTurret(_TurretName)
    local _ExtendedGoodsTable = {}

    _ExtendedGoodsTable["Tesla"] = {
        "Industrial Tesla Coil",
        "Electromagnetic Charge",
        "Energy Inverter",
        "Conductor",
        "Power Unit",
        "Copper",
        "Energy Cell",
        "Targeting System"
    }
    _ExtendedGoodsTable["Salvage"] = {
        "Laser Compressor",
        "Laser Modulator",
        "High Capacity Lens",
        "Conductor",
        "Steel",
        "Targeting System"
    }
    _ExtendedGoodsTable["Launcher"] = {
        "Servo",
        "Rocket",
        "High Pressure Tube",
        "Fuel",
        "Targeting Card",
        "Steel",
        "Wire",
        "Targeting System"
    }
    _ExtendedGoodsTable["Repair"] = {
        "Nanobot",
        "Transformator",
        "Laser Modulator",
        "Conductor",
        "Gold",
        "Steel",
        "Targeting System"
    }
    _ExtendedGoodsTable["Railgun"] = {
        "Servo",
        "Electromagnetic Charge",
        "Electro Magnet",
        "Gauss Rail",
        "High Pressure Tube",
        "Steel",
        "Copper",
        "Targeting System"
    }
    _ExtendedGoodsTable["Pulse"] = {
        "Servo",
        "Steel Tube",
        "Ammunition S",
        "Steel",
        "Copper",
        "Energy Cell",
        "Targeting System"
    }
    _ExtendedGoodsTable["Plasma"] = {
        "Plasma Cell",
        "Energy Tube",
        "Conductor",
        "Energy Container",
        "Power Unit",
        "Steel",
        "Crystal",
        "Targeting System"
    }
    _ExtendedGoodsTable["Mining"] = {
        "Laser Compressor",
        "Laser Modulator",
        "High Capacity Lens",
        "Conductor",
        "Steel",
        "Targeting System"
    }
    _ExtendedGoodsTable["Lightning"] = {
        "Military Tesla Coil",
        "High Capacity Lens",
        "Electromagnetic Charge",
        "Conductor",
        "Power Unit",
        "Copper",
        "Energy Cell",
        "Targeting System"
    }
    _ExtendedGoodsTable["Laser"] = {
        "Laser Head",
        "Laser Compressor",
        "High Capacity Lens",
        "Laser Modulator",
        "Power Unit",
        "Steel",
        "Crystal",
        "Targeting System"
    }
    _ExtendedGoodsTable["Force"] = {
        "Force Generator",
        "Energy Inverter",
        "Energy Tube",
        "Conductor",
        "Steel",
        "Zinc",
        "Targeting System"
    }
    _ExtendedGoodsTable["Chaingun"] = {
        "Servo",
        "Steel Tube",
        "Ammunition S",
        "Steel",
        "Aluminum",
        "Lead",
        "Targeting System"
    }
    _ExtendedGoodsTable["Cannon"] = {
        "Servo",
        "Warhead",
        "High Pressure Tube",
        "Explosive Charge",
        "Steel",
        "Wire",
        "Targeting System"
    }
    _ExtendedGoodsTable["Bolter"] = {
        "Servo",
        "High Pressure Tube",
        "Ammunition M",
        "Explosive Charge",
        "Steel",
        "Aluminum",
        "Targeting System"
    }

    return _ExtendedGoodsTable[_TurretName]
end

--endregion

--region #TAB8

function onBuildATurretButtonPressed(_Button)
    if onClient() then
        invokeServerFunction("onBuildATurretButtonPressed", _Button.tooltip)
        return
    end

    local entity = Player(callingPlayer).craft

    local _GoodsTable = getGoodsForTurret(_Button)

    print("Adding goods for a " .. tostring(_Button))
    for _, _Good in pairs(_GoodsTable) do
        local _GoodsToAdd = 1000
        if _Good == "Targeting System" then
            _GoodsToAdd = 100
        end
        print("Adding " .. tostring(_GoodsToAdd) .. " : " .. tostring(_Good))
        CargoBay(entity):addCargo(goods[_Good]:good(), _GoodsToAdd)
    end
end
callable(nil, "onBuildATurretButtonPressed")

--endregion

--region #TAB9 (Retrograde Solutions)

function onSpawnHellhoundButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHellhoundButtonPressed")
        return
    end

    local _Position = getPositionInFrontOfPlayer()

    local RetrogradeUtil = include("retrogradeutil")
    RetrogradeUtil.spawnHellhound(_Position)
end
callable(nil, "onSpawnHellhoundButtonPressed")

function onSpawnCerberusButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnCerberusButtonPressed")
        return
    end

    local _Position = getPositionInFrontOfPlayer()

    local RetrogradeUtil = include("retrogradeutil")
    RetrogradeUtil.spawnCerberus(_Position)
end
callable(nil, "onSpawnCerberusButtonPressed")

function onSpawnTiberiusButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnTiberiusButtonPressed")
        return
    end

    local _Position = getPositionInFrontOfPlayer()

    local RetrogradeUtil = include("retrogradeutil")
    RetrogradeUtil.spawnTiberius(_Position)
end
callable(nil, "onSpawnTiberiusButtonPressed")

--endregion

--region #TAB11 (Lord of the Wastes)

function onLOTWMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission1ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwmission1.lua"
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
    local _Script = "missions/lotw/lotwmission2.lua"
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
    local _Script = "missions/lotw/lotwmission3.lua"
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
    local _Script = "missions/lotw/lotwmission4.lua"
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
    local _Script = "missions/lotw/lotwmission5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission5ButtonPressed")

function onLOTWMission6ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission6ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwmission6.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission6ButtonPressed")

function onLOTWMission7ButtonPressed()
    if onClient() then
        invokeServerFunction("onLOTWMission7ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/lotw/lotwmission7.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onLOTWMission7ButtonPressed")

function onLOTWClearValuesPressed()
    if onClient() then
        invokeServerFunction("onLOTWClearValuesPressed")
        return
    end

    local _Player = Player(callingPlayer)

    local _Scripts = {
        "missions/lotw/lotwmission1.lua",
        "missions/lotw/lotwmission2.lua",
        "missions/lotw/lotwmission3.lua",
        "missions/lotw/lotwmission4.lua",
        "missions/lotw/lotwmission5.lua",
        "missions/lotw/lotwmission6.lua",
        "missions/lotw/lotwmission7.lua",
    }

    for _k, _v in pairs(_Scripts) do
        _Player:removeScript(_v)
    end

    _Player:setValue("_lotw_story_1_accomplished", nil)
    _Player:setValue("_lotw_story_2_accomplished", nil)
    _Player:setValue("_lotw_story_3_accomplished", nil)
    _Player:setValue("_lotw_story_4_accomplished", nil)
    _Player:setValue("_lotw_story_5_accomplished", nil)
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
    boss:addScript("swenksspecial.lua")
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("avenger.lua", {_Multiplier = 1.1})
    boss:setValue("is_pirate", true)
    boss:setValue("is_swenks", true)

    Boarding(boss).boardable = false
end
callable(nil, "onSpawnSwenksButtonPressed")

--endregion

--region #HKTab (Horizon Keepers)

function onHKTabMission1ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission1ButtonPressed")
        return
    end

    local _station = Entity()
    if _station.type ~= EntityType.Station then
        print("Can't add missions to non-station entities.")
    else
        if _station.playerOrAllianceOwned then
            print("Can't add missions to player or alliance stations.")
        else
            print("Adding Horizon 1 bulletin.")
            local _MissionPath = "data/scripts/player/missions/horizon/horizonstory1.lua"
            local ok, bulletin=run(_MissionPath, "getBulletin", _station)
            _station:invokeFunction("bulletinboard", "postBulletin", bulletin)
        end
    end
end
callable(nil, "onHKTabMission1ButtonPressed")

function onHKTabMission2ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission2ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory2.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission2ButtonPressed")

function onHKTabMission3ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission3ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory3.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission3ButtonPressed")

function onHKTabMission4ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission4ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory4.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission4ButtonPressed")

function onHKTabMission5ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission5ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory5.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission5ButtonPressed")

function onHKTabMission6ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission6ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory6.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission6ButtonPressed")

function onHKTabMission7ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission7ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory7.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission7ButtonPressed")

function onHKTabMission8ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission8ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory8.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission8ButtonPressed")

function onHKTabMission9ButtonPressed()
    if onClient() then
        invokeServerFunction("onHKTabMission9ButtonPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local _Script = "missions/horizon/horizonstory9.lua"
    _Player:removeScript(_Script)
    _Player:addScript(_Script)
end
callable(nil, "onHKTabMission9ButtonPressed")

function onSpawnFrostbiteTorpLoaderButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFrostbiteTorpLoaderButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnFrostbiteTorpedoLoader(false)
end
callable(nil, "onSpawnFrostbiteTorpLoaderButtonPressed")

function onSpawnFrostibteAWACSButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFrostibteAWACSButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnFrostbiteAWACS(false)
end
callable(nil, "onSpawnFrostibteAWACSButtonPressed")

function onSpawnFrostbiteWarshipButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFrostbiteWarshipButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnFrostbiteWarship(false)
end
callable(nil, "onSpawnFrostbiteWarshipButtonPressed")

function onSpawnFrostbiteReliefButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnFrostbiteReliefButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnFrostbiteReliefShip(false)
end
callable(nil, "onSpawnFrostbiteReliefButtonPressed")

function onSpawnVarlanceButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnVarlanceButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnVarlanceNormal(false)
end
callable(nil, "onSpawnVarlanceButtonPressed")

function onSpawnIceNovaButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnIceNovaButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnVarlanceBattleship(false)
end
callable(nil, "onSpawnIceNovaButtonPressed")

function onSpawnHKFreightButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKFreightButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonFreighter(false, nil, nil)
end
callable(nil, "onSpawnHKFreightButtonPressed")

function onSpawnHKACruiseButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKACruiseButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonArtyCruiser(false, nil, nil)
end
callable(nil, "onSpawnHKACruiseButtonPressed")

function onSpawnHKCCruiseButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKCCruiseButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonCombatCruiser(false, nil, nil)
end
callable(nil, "onSpawnHKCCruiseButtonPressed")

function onSpawnHKAWACSButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKAWACSButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonAWACS(false, nil, nil)
end
callable(nil, "onSpawnHKAWACSButtonPressed")

function onSpawnHKBshipButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKBshipButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonBattleship(false, nil, nil)
end
callable(nil, "onSpawnHKBshipButtonPressed")

function onSpawnHKHanselButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKHanselButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnAlphaHansel(false, nil)
end
callable(nil, "onSpawnHKHanselButtonPressed")

function onSpawnHKGretelButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnHKGretelButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnBetaGretel(false, nil)
end
callable(nil, "onSpawnHKGretelButtonPressed")

function onSpawnXsologizeButtonPressed()
    if onClient() then
        invokeServerFunction("onSpawnXsologizeButtonPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnProjectXsologize(false, nil)
end
callable(nil, "onSpawnXsologizeButtonPressed")

function onHKShipyard1Pressed()
    if onClient() then
        invokeServerFunction("onHKShipyard1Pressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonShipyard1(false, nil)
end
callable(nil, "onHKShipyard1Pressed")

function onHKResearchPressed()
    if onClient() then
        invokeServerFunction("onHKResearchPressed")
        return
    end

    local HorizonUtil = include("horizonutil")
    HorizonUtil.spawnHorizonResearchStation(false, nil)
end
callable(nil, "onHKResearchPressed")

function onHKClearValuesPressed()
    if onClient() then
        invokeServerFunction("onHKClearValuesPressed")
        return
    end

    local _Player = Player(callingPlayer)
    local HorizonUtil = include("horizonutil")

    local _Scripts = {
        "missions/horizon/horizonstory1.lua",
        "missions/horizon/horizonstory2.lua"
    }

    for _k, _v in pairs(_Scripts) do
        _Player:removeScript(_v)
    end

    _Player:setValue("_horizonkeepers_story_stage", 1)
    _Player:setValue("_horizonkeepers_story3_cargolooted", nil)
    _Player:setValue("_horizonkeepers_killed_hansel", nil)
    _Player:setValue("_horizonkeepers_killed_gretel", nil)

    HorizonUtil.setFriendlyFactionRep(_Player, 0)

    local _msg = "All Horizon Keepers data cleared."
    print(_msg)
    _Player:sendChatMessage("Server", ChatMessageType.Information, _msg)
end
callable(nil, "onHKClearValuesPressed")

--endregion

--region #MISSION TAB

function onAddBulletinButtonPressed(_Button)
    if onClient() then
        invokeServerFunction("onAddBulletinButtonPressed", _Button.tooltip)
        return
    end

    local _station = Entity()
    if _station.type ~= EntityType.Station then
        print("Can't add missions to non-station entities.")
    else
        if _station.playerOrAllianceOwned then
            print("Can't add missions to player or alliance stations.")
        else
            print("Adding " .. tostring(_Button) .. " bulletin.")
            local _MissionPath = "data/scripts/player/missions/" .. _Button .. ".lua"
            local ok, bulletin=run(_MissionPath, "getBulletin", _station)
            _station:invokeFunction("bulletinboard", "postBulletin", bulletin)
        end
    end
end
callable(nil, "onAddBulletinButtonPressed")

--endregion