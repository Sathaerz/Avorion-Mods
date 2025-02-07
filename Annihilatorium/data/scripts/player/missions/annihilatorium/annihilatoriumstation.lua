package.path = package.path .. ";data/scripts/lib/?.lua"

include("callable")

--Don't remove / alter or else yo might break the script.
--namespace Annihilatorium
Annihilatorium = {}

Annihilatorium._Debug = 0

Annihilatorium.interactionThreshold = -50000

Annihilatorium.data = {}

function Annihilatorium.interactionPossible(playerIndex, option)
    local _Enemies = {Sector():getEnemies(playerIndex)}

    if #_Enemies > 0 then
        return false
    end

    if not Player():hasScript("annihilatorium.lua") then
        return false
    end

    return CheckFactionInteraction(playerIndex, Annihilatorium.interactionThreshold)
end

function Annihilatorium.initialize(dangerLevel)
    if onServer() then
        local _Station = Entity()
        _Station.title = "Annihilatorium"

        Annihilatorium.data = {}

        Annihilatorium.data.cleanWreckages = true
        Annihilatorium.data.pullLoot = true
        Annihilatorium.data.dangerLevel = dangerLevel

        Annihilatorium.sync()
    end

    if onClient() then
        EntityIcon().icon = "data/textures/icons/pixel/crossed_swords.png"
    end
end

function Annihilatorium.initUI()
    if Annihilatorium._Debug == 1 then
        print("Running initUI")
    end

    local res = getResolution()
    local menu = ScriptUI()

    --[[=====================================================
        CREATE NEXT WAVE WINDOW:
    =========================================================]]
    local nextWaveSize = vec2(600, 75)

    local nextWaveWindow = menu:createWindow(Rect(res * 0.5 - nextWaveSize * 0.5, res * 0.5 + nextWaveSize * 0.5))

    local nextWaveSplitter = UIArbitraryVerticalSplitter(Rect(nextWaveWindow.size), 10, 15, 325, 575)

    local nextWaveLabelRect = nextWaveSplitter:partition(0)
    local nextWavelrUpper = nextWaveLabelRect.topLeft
    local nextWavelrLower = nextWaveLabelRect.bottomRight
    nextWavelrUpper = nextWavelrUpper + vec2(0, 15)
    local descLabel = nextWaveWindow:createLabel(Rect(nextWavelrUpper, nextWavelrLower), "Make sure you're ready. There's no going back.", 14)

    local buttonRect = nextWaveSplitter:partition(1)
    local button = nextWaveWindow:createButton(buttonRect, "Start", "onStartPressed")

    nextWaveWindow.caption = "Start Next Wave"
    nextWaveWindow.showCloseButton = 1
    nextWaveWindow.moveable = 1

    --[[=====================================================
        REGISTER UI:
    =========================================================]]
    menu:registerWindow(nextWaveWindow, "Start Next Wave", 3)

    if Annihilatorium.data.dangerLevel > 5 then
        --[[=====================================================
            CREATE MASTER OF THE ARENA WINDOW:
        =========================================================]]
        local motaSize = vec2(600, 280)

        local motaWindow = menu:createWindow(Rect(res * 0.5 - motaSize * 0.5, res * 0.5 + motaSize * 0.5))

        local motaSplitter = UIArbitraryVerticalSplitter(Rect(motaWindow.size), 10, 15, 325, 575)

        local motaDescriptionSplitter = UIArbitraryHorizontalSplitter(motaSplitter:partition(0), 10, 15, 40, 65, 90, 115, 140, 165, 195)

        local labelTable = {
            "Enable Master Of The Arena Mode.",
            "This will do the following:",
            " - Normal enemies x4 hp / damage",
            " - All bosses replaced with Executioners",
            " - All bosses guaranteed to be Hardcore+",
            " - Leaving the sector results in defeat",
            " - x3 reward for bosses / finishing all waves",
            "Good luck!"
        }

        for idx, txt in pairs(labelTable) do
            local partitionidx = idx - 1
            local motaLabelRect = motaDescriptionSplitter:partition(partitionidx)
            local motalrUpper = motaLabelRect.topLeft
            local motalrLower = motaLabelRect.bottomRight

            local motaDescLabel = motaWindow:createLabel(Rect(motalrUpper, motalrLower), txt, 14)
        end

        local motaButtonSplitter = UIArbitraryHorizontalSplitter(motaSplitter:partition(1), 10, 15, 170)

        local motaButtonRect = motaButtonSplitter:partition(1)
        local motaButton = motaWindow:createButton(motaButtonRect, "Engage", "onEnableMOTAPressed")

        motaWindow.caption = "Master Of The Arena"
        motaWindow.showCloseButton = 1
        motaWindow.moveable = 1

        menu:registerWindow(motaWindow, "Master Of The Arena", 2)
    end
    
    menu:registerInteraction("Clean Wreckages", "onToggleCleanWrecks", 1)
end

function Annihilatorium.getUpdateInterval()
    return 2
end

function Annihilatorium.updateServer(timeStep)
    local _sector = Sector()
    local pirates = { _sector:getEntitiesByScriptValue("is_pirate") }

    if #pirates == 0 and Annihilatorium.data.cleanWreckages then
        local wreckages = { _sector:getEntitiesByType(EntityType.Wreckage) }
        local wreckCt = 0

        shuffle(random(), wreckages)

        for _, wreck in pairs(wreckages) do
            if wreckCt < 10 then
                broadcastInvokeClientFunction("zapWreckage", Entity().translationf, wreck.translationf, wreck.index, 5)
                _sector:deleteEntity(wreck)
            end
            wreckCt = wreckCt + 1
        end
    end

    Annihilatorium.sync()
end

--region #WAVE MANGEMENT

function Annihilatorium.onStartPressed()
    if Annihilatorium._Debug == 1 then
        print("Start pressed")
    end
    invokeServerFunction("sendNextWave")
    ScriptUI():stopInteraction()
end

function Annihilatorium.sendNextWave()
    if Annihilatorium._Debug == 1 then
        print("Sending wave")
    end

    local _sector = Sector()
    local players = {_sector:getPlayers()}
    local playerHasMissionScript = false
    for idx, _player in pairs(players) do
        if _player:hasScript("annihilatorium.lua") then
            playerHasMissionScript = true
        end
    end

    if playerHasMissionScript then
        _sector:sendCallback("onAnnihilatoriumSpawnWave")
    else
        _sector:broadcastMessage("", 3, "You've defeated all the waves!")
    end
end
callable(Annihilatorium, "sendNextWave")

--endregion

--region #MASTER OF THE ARENA

function Annihilatorium.onEnableMOTAPressed()
    if Annihilatorium._Debug == 1 then
        print("Enable MOTA pressed")
    end
    invokeServerFunction("enableMOTA")
    ScriptUI():stopInteraction()
end

function Annihilatorium.enableMOTA()
    if Annihilatorium._Debug == 1 then
        print("Enabling MOTA")
    end

    local _sector = Sector()
    local players = {_sector:getPlayers()}
    local playerHasMissionScript = false
    for idx, _player in pairs(players) do
        if _player:hasScript("annihilatorium.lua") then
            playerHasMissionScript = true
        end
    end

    if playerHasMissionScript then
        _sector:sendCallback("onEnableMOTAMode")
    end
end
callable(Annihilatorium, "enableMOTA")

--endregion

--region #WRECK MANAGEMENT

function Annihilatorium.onToggleCleanWrecks()
    if Annihilatorium._Debug == 1 then
        print("Calling onToggleCleanWrecks")
    end

    if onClient() then
        invokeServerFunction("onToggleCleanWrecks")

        local d0 = {}

        if Annihilatorium.data.cleanWreckages then
            d0.text = "We'll stop cleaning wreckages."
        else
            d0.text = "We'll start cleaning wrecks. Enjoy the light show!"
        end

        ScriptUI():showDialog(d0)
    else
        if Annihilatorium.data.cleanWreckages then
            Annihilatorium.data.cleanWreckages = false
        else
            Annihilatorium.data.cleanWreckages = true
        end

        if Annihilatorium._Debug == 1 then
            print("Clean wreckages is now: " .. tostring(Annihilatorium.data.cleanWreckages))
        end

        Annihilatorium.sync()
    end
end
callable(Annihilatorium, "onToggleCleanWrecks")

function Annihilatorium.zapWreckage(from, to, idx, anims)
    --Spams like crazy. Be careful enabling this.
    if Annihilatorium._Debug == 1 then
        --print("Zapping Wreckages")
    end

    local _Sector = Sector()

    local _entity = Entity(idx)
    local _random = random()
    for _ = 1, anims do
        local dir = _random:getDirection()
        _Sector:createHyperspaceJumpAnimation(_entity, dir, ColorRGB(0.5, 0.5, 1.0), 0.3)
    end

    local laser = _Sector:createLaser(from, to, ESCCUtil.getSaneColor(0, 27, 255), 12)

    laser.maxAliveTime = 1.0
    laser.collision = false
end

--endregion

--region #SYNC / SECURE / RESTORE

function Annihilatorium.sync(data_in)
    --This spams like crazy. Be careful enabling it.
    if Annihilatorium._Debug == 1 then
        --print("Syncing Annihilatorium data") 
    end

    if onServer() then
        broadcastInvokeClientFunction("sync", Annihilatorium.data)
    else
        if data_in then
            Annihilatorium.data = data_in
        else
            invokeServerFunction("sync")
        end
    end
end
callable(Annihilatorium, "sync")

function Annihilatorium.secure()
    if Annihilatorium._Debug == 1 then
        print("Securing Annihilatorium data")
    end

    return Annihilatorium.data
end

function Annihilatorium.restore(values)
    if Annihilatorium._Debug == 1 then
        print("Restoring Annihilatorium data")
    end

    Annihilatorium.data = values

    Annihilatorium.sync() --need to sync on restore.
end

--endregion