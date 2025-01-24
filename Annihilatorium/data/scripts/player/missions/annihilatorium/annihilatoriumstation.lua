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

function Annihilatorium.initialize()
    if onServer() then
        local _Station = Entity()
        _Station.title = "Annihilatorium"

        Annihilatorium.data = {}

        Annihilatorium.data.cleanWreckages = true
        Annihilatorium.data.pullLoot = true
    end

    if onClient() then
        EntityIcon().icon = "data/textures/icons/pixel/crossed_swords.png"
    end
end

function Annihilatorium.initUI()
    local res = getResolution()
    local size = vec2(600, 75)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    local _Splitter = UIArbitraryVerticalSplitter(Rect(window.size), 10, 15, 325, 575)

    local labelRect = _Splitter:partition(0)
    local lrUpper = labelRect.topLeft
    local lrLower = labelRect.bottomRight
    lrUpper = lrUpper + vec2(0, 15)
    local descLabel = window:createLabel(Rect(lrUpper, lrLower), "Make sure you're ready. There's no going back.", 14)

    local buttonRect = _Splitter:partition(1)
    local button = window:createButton(buttonRect, "Start", "onStartPressed")

    window.caption = "Start Next Wave"
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Start Next Wave", 3)
    menu:registerInteraction("Clean Wreckages", "onToggleCleanWrecks", 2)
 
    Annihilatorium.uiInitialized = true
end

function Annihilatorium.getUpdateInterval()
    return 2
end

function Annihilatorium.updateServer(timeStep)
    local _sector = Sector()
    local _entity = Entity()
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

    --local entityPos = _entity.translationf
    --if #pirates == 0 and Annihilatorium.data.pullLoot then
    --    local loots = { _sector:getEntitiesByType(EntityType.Loot) }
    --    local lootCt = 0
    --
    --    for _, loot in pairs(loots) do
    --        loot.translation = dvec3(entityPos.x, entityPos.y, entityPos.z)
    --    end
    --end

    --Sync after each update in addition to at set points.
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
    if Annihilatorium._Debug == 1 then
        print("Zapping Wreckages")
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
    if Annihilatorium._Debug == 1 then
        print("Syncing Annihilatorium data")
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
end

--endregion