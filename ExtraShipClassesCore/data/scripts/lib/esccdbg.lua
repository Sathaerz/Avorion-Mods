package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("callable")
include("productions")
local Placer = include("placer")
local AsyncPirateGenerator = include("asyncpirategenerator")
local UpgradeGenerator = include("upgradegenerator")
local SectorTurretGenerator = include("sectorturretgenerator")
local SpawnUtility = include("spawnutility")
local ShipUtility = include("shiputility")
local EventUT = include("eventutility")
local TorpedoGenerator = include("torpedogenerator")

local _ai = 1

--/run Entity():addScript("lib/esccdbg.lua")
local window

local numButtons = 0
function ButtonRect(w, h, p)
    local width = w or 280
    local height = h or 35
    local padding = p or 10

    local space = math.floor((window.size.y - 60) / (height + padding))

    local row = math.floor(numButtons % space)
    local col = math.floor(numButtons / space)

    local lower = vec2((width + padding) * col, (height + padding) * row)
    local upper = lower + vec2(width, height)

    numButtons = numButtons + 1

    return Rect(lower, upper)
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

    local tab = tabbedWindow:createTab("Entity", "data/textures/icons/ship.png", "ESCC Ships")
    numButtons = 0
    tab:createButton(ButtonRect(), "Jammer", "onSpawnJammerButtonPressed")
    tab:createButton(ButtonRect(), "Stinger", "onSpawnStingerButtonPressed")
    tab:createButton(ButtonRect(), "Scorcher", "onSpawnScorcherButtonPressed")
    tab:createButton(ButtonRect(), "Bomber", "onSpawnBomberButtonPressed")
    tab:createButton(ButtonRect(), "Sinner", "onSpawnSinnerButtonPressed")
    tab:createButton(ButtonRect(), "Prowler", "onSpawnProwlerButtonPressed")
    tab:createButton(ButtonRect(), "Pillager", "onSpawnPillagerButtonPressed")
    tab:createButton(ButtonRect(), "Devastator", "onSpawnDevastatorButtonPressed")
    tab:createButton(ButtonRect(), "Slammer", "onSpawnTorpedoSlammerButtonPressed")
    tab:createButton(ButtonRect(), "Absolute PD", "onSpawnAbsolutePDButtonPressed")
    tab:createButton(ButtonRect(), "Curtain", "onSpawnIronCurtainButtonPressed")
    tab:createButton(ButtonRect(), "Eternal", "onSpawnEternalButtonPressed")
    tab:createButton(ButtonRect(), "Overdrive", "onSpawnOverdriveButtonPressed")
    tab:createButton(ButtonRect(), "Adaptive", "onSpawnAdaptiveButtonPressed")
    tab:createButton(ButtonRect(), "Afterburn", "onSpawnAfterburnerButtonPressed")
    tab:createButton(ButtonRect(), "Avenger", "onSpawnAvengerButtonPressed")
    tab:createButton(ButtonRect(), "Meathook", "onSpawnMeathookButtonPressed")
    tab:createButton(ButtonRect(), "Booster", "onSpawnBoosterButtonPressed")
    tab:createButton(ButtonRect(), "Booster Healer", "onSpawnBoosterHealerButtonPressed")

    local tab3 = tabbedWindow:createTab("Entity", "data/textures/icons/edge-crack.png", "Executioner")
    numButtons = 0
    tab3:createButton(ButtonRect(), "Executioner", "onSpawnExecutionerButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner II", "onSpawnExecutioner2ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner III", "onSpawnExecutioner3ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner IV", "onSpawnExecutioner4ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner V", "onSpawnExecutioner5ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner VI", "onSpawnExecutioner6ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner VII", "onSpawnExecutioner7ButtonPressed")
    tab3:createButton(ButtonRect(), "Executioner VIII", "onSpawnExecutioner8ButtonPressed")

    local tab8 = tabbedWindow:createTab("Entity", "data/textures/icons/gunner.png", "Turret Builder")
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
        local _Button = tab8:createButton(ButtonRect(), "Build " .. tostring(_Name), "onBuildATurretButtonPressed")
        _Button.tooltip = _Name
    end

    local tab6 = tabbedWindow:createTab("Entity", "data/textures/icons/solar-cell.png", "Data Dumps")
    numButtons = 0
    tab6:createButton(ButtonRect(), "Turret Data Dump", "onTurretDataDumpButtonPressed")
    tab6:createButton(ButtonRect(), "Trait Data Dump", "onTraitDataDumpButtonPressed")
    tab6:createButton(ButtonRect(), "Station List Dump", "onStationListDumpButtonPressed")
    tab6:createButton(ButtonRect(), "Server Value Dump", "onServerValueDumpButtonPressed")
    tab6:createButton(ButtonRect(), "Player Value Dump", "onPlayerValueDumpButtonPressed")

    local tab7 = tabbedWindow:createTab("Entity", "data/textures/icons/papers.png", "Other")
    numButtons = 0
    tab7:createButton(ButtonRect(), "Load Torpedoes", "onLoadTorpedoesButtonPressed")
    tab7:createButton(ButtonRect(), "Zero Resources", "onZeroOutResourcesButtonPressed")
    tab7:createButton(ButtonRect(), "Test Pariah Spawn", "onTestPariahSpawnButtonPressed")
    tab7:createButton(ButtonRect(), "Repair All Ships", "onRepairAllShipsButtonPressed")
    tab7:createButton(ButtonRect(), "Run SectorDPS", "onRunSectorDPSPressed")
    tab7:createButton(ButtonRect(), "Get Position", "onGetPositionPressed")
    tab7:createButton(ButtonRect(), "Center Position", "onCenterPositionPressed")
    tab7:createButton(ButtonRect(), "Get Distance", "onDistanceButtonPressed")
    tab7:createButton(ButtonRect(), "Test CDS Bombers", "onTestCDSBombersButtonPressed")

    if _ai == 1 then
        local tab4 = tabbedWindow:createTab("Entity", "data/textures/icons/computation-mainframe.png", "AI Test")
        numButtons = 0
        tab4:createButton(ButtonRect(), "Fly to me", "onFlyToMeButtonPressed")
        tab4:createButton(ButtonRect(), "Shoot me", "onShootMeButtonPressed")
        tab4:createButton(ButtonRect(), "Use Pursuit", "onAttachTindalosButtonPressed")
    end

    local xmods = Mods()

    local hasIncreasingThreat = false
    local hasLongLiveTheEmpress = false
    local hasRetrogradeCampaign = false
    local hasEmergence = false
    local hasLOTW = false
    for _, p in pairs(xmods) do
        if p.id == "2208370349" then
            hasIncreasingThreat = true
        end
        if p.id == "2421751351" then
            hasLongLiveTheEmpress = true
        end
        if p.id == "RetrogradeCampaign" then
            hasRetrogradeCampaign = true
        end
        if p.id == "Emergence" then
            hasEmergence = true
        end
        if p.id == "2733586433" then
            hasLOTW = true
        end
    end

    if hasIncreasingThreat then
        --print("adding Inreasing Threat tab to esccdbg")
        local tab2 = tabbedWindow:createTab("Entity", "data/textures/icons/gunner.png", "Increasing Threat")
        numButtons = 0
        tab2:createButton(ButtonRect(), "Pirate Attack", "onPirateAttackButtonPressed")
        tab2:createButton(ButtonRect(), "Decapitation Strike", "onDecapStrikeButtonPressed")
        tab2:createButton(ButtonRect(), "Deepfake Distress Call", "onDeepfakeDistressButtonPressed")
        tab2:createButton(ButtonRect(), "Fake Distress Call", "onFakeDistressButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Katana BOSS", "onKatanaBossButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Phoenix BOSS", "onPhoenixBossButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Hunter BOSS", "onHunterBossButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Hellcat BOSS", "onHellcatBossButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Goliath BOSS", "onGoliathBossButtonPressed")
        tab2:createButton(ButtonRect(), "Spawn Shield BOSS", "onShieldBossButtonPressed")
    end

    if hasLongLiveTheEmpress then
        local tab5 = tabbedWindow:createTab("Entity", "data/textures/icons/cavaliers.png", "Long Live The Empress")
        numButtons = 0
        tab5:createButton(ButtonRect(), "Test Name Generator", "onNameGeneratorButtonPressed")
        tab5:createButton(ButtonRect(), "Regenerate Weapons", "onRegenWeaponsButtonPressed")
        --Misison tabs.
        tab5:createButton(ButtonRect(), "Story Mission 1", "onLLTEStoryMission1ButtonPressed")
        tab5:createButton(ButtonRect(), "Story Mission 2", "onLLTEStoryMission2ButtonPressed")
        tab5:createButton(ButtonRect(), "Story Mission 3", "onLLTEStoryMission3ButtonPressed")
        tab5:createButton(ButtonRect(), "Story Mission 4", "onLLTEStoryMission4ButtonPressed")
        tab5:createButton(ButtonRect(), "Story Mission 5", "onLLTEStoryMission5ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 1", "onLLTESideMission1ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 2", "onLLTESideMission2ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 3", "onLLTESideMission3ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 4", "onLLTESideMission4ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 5", "onLLTESideMission5ButtonPressed")
        tab5:createButton(ButtonRect(), "Side Mission 6", "onLLTESideMission6ButtonPressed")
        tab5:createButton(ButtonRect(), "Reset XWG", "onLLTEResetXWGButtonPressed")
        tab5:createButton(ButtonRect(), "Cav Reinforcement Caller", "onCavReinforcementsCallerButtonPressed")
        tab5:createButton(ButtonRect(), "Cav Merchant", "onCavMerchantButtonPressed")
        tab5:createButton(ButtonRect(), "Get Excalibur", "onGetExcaliburButtonPressed")
    end

    if hasRetrogradeCampaign then
        local tab9 = tabbedWindow:createTab("Entity", "data/textures/icons/cannon.png", "Retrograde Solutions")
        numButtons = 0
        tab9:createButton(ButtonRect(), "Spawn Hellhound", "onSpawnHellhoundButtonPressed")
        tab9:createButton(ButtonRect(), "Spawn Cerberus", "onSpawnCerberusButtonPressed")
        tab9:createButton(ButtonRect(), "Spawn Tiberius", "onSpawnTiberiusButtonPressed")
    end

    if hasEmergence then
        local tab10 = tabbedWindow:createTab("Entity", "data/textures/icons/aggressive.png", "Emergence")
        numButtons = 0
        tab10:createButton(ButtonRect(), "Reset", "onResetEmergenceButtonPressed")
    end

    if hasLOTW then
        local tab11 = tabbedWindow:createTab("Entity", "data/textures/icons/silicium.png", "Lord of the Wastes")
        numButtons = 0
        tab11:createButton(ButtonRect(), "Mission 1", "onLOTWMission1ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 2", "onLOTWMission2ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 3", "onLOTWMission3ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 4", "onLOTWMission4ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 5", "onLOTWMission5ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 6", "onLOTWMission6ButtonPressed")
        tab11:createButton(ButtonRect(), "Mission 7", "onLOTWMission7ButtonPressed")
    end 
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
    print("adding booster + healer script to enemy.")
    for _, _S in pairs(_Generated) do
        _S:addScript("allybooster.lua", {_HealWhenBoosting = true, _HealPctWhenBoosting = 33})
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

--endregion

--region #TAB7

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

function onTestCDSBombersButtonPressed()
    if onClient() then
        invokeServerFunction("onTestCDSBombersButtonPressed")
        return
    end

    Sector():addScriptOnce("sector/cdssiegeevent.lua")
end
callable(nil, "onTestCDSBombersButtonPressed")

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

--region #TAB10 Emergence

function onResetEmergenceButtonPressed()
    if onClient() then
        invokeServerFunction("onResetEmergenceButtonPressed")
        return
    end

    print("Resetting emergence.")
    Galaxy():removeScript("emergencebackground.lua")
    Galaxy():addScriptOnce("emergencebackground.lua")
end
callable(nil, "onResetEmergenceButtonPressed")

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

--endregion