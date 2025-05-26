package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include ("randomext")

local Balancing = include("galaxy")

mission._Debug = 0
mission._Name = "Analyze Xsotan Specimen"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    {text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    {text = "..." },
    { text = "${_ANALYZED} / ${_TARGETS} ${_XSOTANTYPE} analyzed", bulletPoint = true, fulfilled = false },
}

mission.data.accomplishMessage = "Thank you for gathering the combat telemetry. We transferred the reward to your account."

mission.data.custom.scriptPath = "player/missions/analyzexsotan/analyzablexsotan.lua"
mission.data.custom.xsotanTypes = {
    { idx = 1, name = "Quantum", longName = "Quantum Xsotan", difficulty = "Easy", rewardFactor = 1.0 },
    { idx = 2, name = "Summoner", longName = "Xsotan Summoner", difficulty = "Medium", rewardFactor = 1.5 },
    { idx = 3, name = "Longinus", longName = "Xsotan Longinus", difficulty = "Difficult", rewardFactor = 2 },
    { idx = 4, name = "Sunmaker", longName = "Xsotan Sunmaker", difficulty = "Medium", rewardFactor = 1.5 },
    { idx = 5, name = "Ballistyx", longName = "Xsotan Ballistyx", difficulty = "Medium", rewardFactor = 1.5 },
    { idx = 6, name = "Warlock", longName = "Xsotan Warlock", difficulty = "Difficult", rewardFactor = 2 },
    { idx = 7, name = "Oppressor", longName = "Xsotan Oppressor", difficulty = "Extreme", rewardFactor = 3 }
}

local XsotanSpecimen_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer() and not _restoring then
        mission.Log(_MethodName, "Calling on server - dangerLevel : " .. tostring(_Data_in.dangerLevel))

        local _Sector = Sector()
        local _Giver = Entity(_Data_in.giver)
        --[[=====================================================
            CUSTOM MISSION DATA:
        =========================================================]]
        mission.data.custom.dangerLevel = _Data_in.dangerLevel
        mission.data.custom.inBarrier = _Data_in.insideBarrier
        mission.data.custom.targetXsotanType = _Data_in.targetType
        mission.data.custom.targets = 1 --always 1.
        mission.data.custom.analyzed = 0

        local xsotanType = mission.data.custom.xsotanTypes[mission.data.custom.targetXsotanType]

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _Sector.name, giverTitle = _Giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { _XSOTANTYPE = xsotanType.longName }
        mission.data.description[3].arguments = { _TARGETS = tostring(mission.data.custom.targets), _ANALYZED = tostring(mission.data.custom.analyzed), _XSOTANTYPE = xsotanType.longName }
    end

    XsotanSpecimen_init(_Data_in)
end

--endregion

--region #PHASE CALLS

mission.globalPhase.getRewardedItems = function()
    --25% of getting a random rarity radar upgrade.
    if random():test(0.25) then
        local _SeedInt = random():getInt(1, 20000)
        local _Rarities = {RarityType.Common, RarityType.Common, RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare}

        if mission.data.custom.inBarrier then
            _Rarities = {RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare, RarityType.Rare, RarityType.Exceptional, RarityType.Exotic}
        end

        shuffle(random(), _Rarities)

        return SystemUpgradeTemplate("data/scripts/systems/scannerbooster.lua", Rarity(_Rarities[1]), Seed(_SeedInt))
    end
end

mission.globalPhase.onAbandon = function()
    analyzeXsotanSpecimen_runSectorScriptAndValueCleanup()
end

mission.globalPhase.onAccomplish = function()
    analyzeXsotanSpecimen_runSectorScriptAndValueCleanup()
end

mission.phases[1] = {}
mission.phases[1].timers = {}
mission.phases[1].triggers = {}
mission.phases[1].updateInterval = function()
    if mission.data.custom.currentAnalysisXsotan then
        return 0
    else
        return 1
    end
end

mission.phases[1].onBegin = function()
    local methodName = "Phase 1 On Begin"
    mission.Log(methodName, "Setting stationId.")
    
    --Can't set this up until the init call, and we need this because otherwise you can't quit the game mid-mission and expect the dialog to work properly after coming back.
    mission.data.custom.stationId = mission.data.giver.id.string
end

mission.phases[1].onStartDialog = function(entityId)
    local methodName = "Phase 1 On Start Dialog"
    mission.Log(methodName, "Beginning...")

    if entityId == Uuid(mission.data.custom.stationId) then

        local td0 = { text = "We'll update your targeting computer to let you know when a Xsotan of the kind we need is in the sector." }

        local td1 = { text = "The Xsotan will be highlighted in orange - simply fly close to it and interact with it to start the analysis process." }

        local td2 = { text = "You'll need to stay close to the Xsotan for a couple of minutes while analyzing it. You can increase the scan range by using a scanner booster. Make sure it isn't blown up before you can finish the scan!" }

        local td3 = { text = "That depends on the Xsotan we're looking for. Some - like Quantum Xsotan - are relatively easy to find." }

        local td4 = { text = "Some of the others - like the Ballystix or Longinus - might more difficult. Try doing some other missions - you might be able to find them anywhere that you face down a Xsotan attack." }

        local td5 = { text = "Happy hunting!" }

        td0.followUp = td1
        td1.followUp = td2
        td2.answers = {
            { answer = "Understood." },
            { answer = "How do I find it?", followUp = td3 }
        }
        td3.followUp = td4
        td4.followUp = td5

        addDialogInteraction("How do I analyze the Xsotan?", td0)
    end
end

mission.phases[1].onPreRenderHud = function()
    analyzeXsotanSpecimen_onMarkAnalyzableXsotan()
end

mission.phases[1].updateServer = function(timeStep)
    local methodName = "Phase 1 Update Server"

    local sectorXsotan = { Sector():getEntitiesByScriptValue("is_xsotan") }

    local sentDetectionMessage = false

    --mission.Log(methodName, "Found " .. tostring(#sectorXsotan) .. " Xsotan") --Careful about enabling these - spam.
    --Find potential analysis targets
    for idx, xsotan in pairs(sectorXsotan) do
        if analyzeXsotanSpecimen_isTargetXsotan(mission.data.custom.targetXsotanType, xsotan) and not xsotan:hasScript(mission.data.custom.scriptPath) then
            --mission.Log(methodName, "Adding script to candidate Xsotan.") --Careful about enabling these - spam.
            xsotan:addScriptOnce(mission.data.custom.scriptPath)
            if not sentDetectionMessage then
                Player():sendChatMessage("", 3, "Your sensors detect the presence of a ${_XSOTANTYPE} in the sector." % { _XSOTANTYPE = xsotan.translatedTitle })
                sentDetectionMessage = true --avoid spam
            end
        end
    end

    --Scrub data if our currently analysis target is destroyed
    if mission.data.custom.currentAnalysisXsotan then
        local targetXsotan = Entity(Uuid(mission.data.custom.currentAnalysisXsotan))
        if not targetXsotan or not valid(targetXsotan) then
            --mission.Log(methodName, "Cannot find current analysis target any more - resetting analysis variables.") --Careful about enabling these - spam.

            mission.data.custom.currentAnalysisXsotan = nil
            mission.data.custom.currentAnalysisTime = nil
            sync()
        end
    end

    --Update time left if we do have an analysis target
    if mission.data.custom.currentAnalysisXsotan then
        local _player = Player()
        local craft = _player.craft
        local xsotan = Entity(Uuid(mission.data.custom.currentAnalysisXsotan))

        if craft and craft.type == EntityType.Ship and xsotan then
            local dist = craft:getNearestDistance(xsotan)
            if dist <= analyzeXsotanSpecimen_getAnalysisDistance(craft) then
                mission.data.custom.currentAnalysisTime = (mission.data.custom.currentAnalysisTime or 0) + timeStep
                sync()
            end
        end
    end

    --Finally, once we've hit 120 seconds on the Xsotan, bump the analysis time.
    if mission.data.custom.currentAnalysisTime and mission.data.custom.currentAnalysisTime >= 120 then
        mission.data.custom.analyzed = mission.data.custom.analyzed + 1
        --No need to keep this around - we've analyzed the xsotan.
        mission.data.custom.currentAnalysisXsotan = nil
        mission.data.custom.currentAnalysisTime = nil

        mission.data.description[3].arguments._ANALYZED = tostring(mission.data.custom.analyzed)

        sync()
    end
end

mission.phases[1].onSectorLeft = function(x, y)
    analyzeXsotanSpecimen_runSectorScriptAndValueCleanup()
end

mission.phases[1].onSectorArrivalConfirmed = function(x, y)
    --Something about adding the scripts before the sector is fully loaded absolutely borks the prerender call, so we clean them on jumping in.
    analyzeXsotanSpecimen_runSectorScriptAndValueCleanup()
end

--region #PHASE 1 TIMER CALLS

if onClient() then --Whoa. an onClient timer...

mission.phases[1].timers[1] = {
    time = 0.05,
    callback = function()
        if mission.data.custom.currentAnalysisXsotan then
            local _player = Player()
            local craft = _player.craft

            local targetXsotan = Entity(Uuid(mission.data.custom.currentAnalysisXsotan))

            if targetXsotan and valid(targetXsotan) and craft and craft.type == EntityType.Ship then
                
                local dist = craft:getNearestDistance(targetXsotan)

                if dist <= analyzeXsotanSpecimen_getAnalysisDistance(craft) then
                    local _random = random()
                    local dir = _random:getDirection()
                    local magnitude = _random:getInt(10, 25)

                    local lsr = Sector():createLaser(craft.translationf, targetXsotan.translationf + (dir * magnitude), ColorRGB(0, 0.1, 1.0), 1)
                    lsr.collision = false
                    lsr.maxAliveTime = 0.025
                end
            end
        end
    end,
    repeating = true
}

end

--endregion

--region #PHASE 1 PLAYER CALLBACKS

if onServer() then

mission.phases[1].playerCallbacks = {
    {
        name = "onMissionXsotanAnalysisStart",
        func = function(xid)
            local methodName = "On Mission Xsotan Analysis Start"

            mission.Log(methodName, "Starting...")

            local analysisXsotan = Entity(xid)
            mission.data.custom.currentAnalysisXsotan = xid

            analysisXsotan:setValue("analyzexsotan_analysis_in_progress", true)

            sync()
        end
    }
}

end
    
--endregion

--region #PHASE 1 TRIGGER CALLS

if onServer() then

mission.phases[1].triggers[1] = {
    condition = function()
        local _MethodName = "Phase 1 Trigger 1 Condition"
        return mission.data.custom.analyzed >= mission.data.custom.targets
    end,
    callback = function()
        local _MethodName = "Phase 1 Trigger 1 Callback"
        analyzeXsotanSpecimen_finishAndReward()
    end,
    repeating = false    
}

end

--endregion

--endregion

--region #SERVER CALLS

function analyzeXsotanSpecimen_isTargetXsotan(idx, xsotan)
    local funcTable = {
        function() --Quantum
            if xsotan:getValue("is_xsotan") and xsotan:hasScript("blinker.lua") then
                return true
            else
                return false
            end
        end,
        function() --Summoner
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_summoner") then
                return true
            else
                return false
            end
        end,
        function() --Longinus
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_longinus") then
                return true
            else
                return false
            end
        end,
        function() --Sunmaker
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_sunmaker") then
                return true
            else
                return false
            end
        end,
        function() --Ballistyx
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_ballistyx") then
                return true
            else
                return false
            end
        end,
        function() --Warlock
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_warlock") then
                return true
            else
                return false
            end
        end,
        function() --Oppressor
            if xsotan:getValue("is_xsotan") and xsotan:getValue("xsotan_oppressor") then
                return true
            else
                return false
            end
        end
    }

    return funcTable[idx]()
end

function analyzeXsotanSpecimen_modTableOK(idx)
    local methodName = "Mod Table OK"

    local xMods = Mods()

    local SpecialXsotanModTable = {
        "3373069547", --The Dig
        "3411023648", --Xsotan Dreadnought
        "3406545523", --Scan Xsotan Group
        "2901149152", --Eradicate Xsotan Infestation
        "3385251675" --Collect Xsotan Bounty
    }

    mission.Log(methodName, "Checking function table.")

    local funcTable = {
        function() --Quantum
            return true --always return true
        end,
        function() --Summoner
            return true --always return true
        end,
        function() --Longinus
            for idx, mod in pairs(xMods) do
                for idx2, id in pairs(SpecialXsotanModTable) do
                    if mod.id == id then
                        return true
                    end
                end
            end
            return false --Need any of the following mods: The Dig, Xsotan Dreadnought, Scan Xsotan Group, Eradicate Xsotan Infestation, Collect Xsotan Bounty
        end,
        function() --Sunmaker
            for idx, mod in pairs(xMods) do
                for idx2, id in pairs(SpecialXsotanModTable) do
                    if mod.id == id then
                        return true
                    end
                end
            end
            return false --Need any of the following mods: The Dig, Xsotan Dreadnought, Scan Xsotan Group, Eradicate Xsotan Infestation, Collect Xsotan Bounty
        end,
        function() --Ballistyx
            for idx, mod in pairs(xMods) do
                for idx2, id in pairs(SpecialXsotanModTable) do
                    if mod.id == id then
                        return true
                    end
                end
            end
            return false --Need any of the following mods: The Dig, Xsotan Dreadnought, Scan Xsotan Group, Eradicate Xsotan Infestation, Collect Xsotan Bounty
        end,
        function() --Warlock
            for idx, mod in pairs(xMods) do
                for idx2, id in pairs(SpecialXsotanModTable) do
                    if mod.id == id then
                        return true
                    end
                end
            end
            return false --Need any of the following mods: The Dig, Xsotan Dreadnought, Scan Xsotan Group, Eradicate Xsotan Infestation, Collect Xsotan Bounty
        end,
        function() --Oppressor
            for idx, mod in pairs(xMods) do
                for idx2, id in pairs(SpecialXsotanModTable) do
                    if mod.id == id then
                        return true
                    end
                end
            end
            return false --Need any of the following mods: The Dig, Xsotan Dreadnought, Scan Xsotan Group, Eradicate Xsotan Infestation, Collect Xsotan Bounty
        end
    }

    return funcTable[idx]()
end

function analyzeXsotanSpecimen_getAnalysisDistance(craft)
    local methodName = "Get Analysis Distance"

    local baseDistance = 1000

    local scannerBonus = 1

    --if the player has more than one scanner system, idk what happens. why would you have more than one scanner booster
    if craft:hasScript("scannerbooster.lua") or craft:hasScript("superscoutsystem.lua") then
        local scannerRarity = 0
        
        if craft:hasScript("scannerbooster.lua") then
            local ok, ret = craft:invokeFunction("scannerbooster.lua", "getRarity")
            if ok == 0 then
                scannerRarity = ret.value --Get the rarity tier value rather than the name.
            end
            scannerBonus = scannerBonus + ((5 + scannerRarity) * 0.1) --should give a 40% bonus @ petty, up to a 100% bonus @ legendary
        else
            local ok, ret = craft:invokeFunction("superscoutsystem.lua", "getRarity")
            if ok == 0 then
                scannerRarity = ret.value --Get the rarity tier value rather than the name.
            end
            scannerBonus = scannerBonus + (((5 + scannerRarity) * 0.1) * 0.8) --ITR upgrades are generally worth ~80% a normal upgrade.
        end

        mission.Log(methodName, "Craft has scanner booster - rarity is: " .. tostring(scannerRarity) .. " final bonus is: " .. tostring(scannerBonus))
    end

    return baseDistance * scannerBonus
end

function analyzeXsotanSpecimen_runSectorScriptAndValueCleanup()
    local sectorXsotan = { Sector():getEntitiesByScript(mission.data.custom.scriptPath) }

    for idx, xsotan in pairs(sectorXsotan) do
        if xsotan:hasScript(mission.data.custom.scriptPath) then
            xsotan:removeScript(mission.data.custom.scriptPath)
            xsotan:setValue("analyzexsotan_analysis_in_progress", nil)
            mission.data.custom.currentAnalysisXsotan = nil
            mission.data.custom.currentAnalysisTime = nil
            sync()
        end
    end
end

function analyzeXsotanSpecimen_finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function analyzeXsotanSpecimen_onMarkAnalyzableXsotan()
    local methodName = "On Mark Analyzable Xsotan"

    local _player = Player()
    if not _player then
        return
    end
    if _player.state == PlayerStateType.BuildCraft or _player.state == PlayerStateType.BuildTurret or _player.state == PlayerStateType.PhotoMode then
        return
    end

    local renderer = UIRenderer()

    local _sector = Sector()

    --Render an orange marker around xsotan that we can analyze
    local sectorXsotan = { _sector:getEntitiesByScriptValue("is_xsotan") }
    for idx, xsotan in pairs(sectorXsotan) do
        if xsotan:hasScript(mission.data.custom.scriptPath) then
            local color = ColorRGB(1.0, 0.67, 0.0)
            if xsotan and valid(xsotan) then
                local _, size = renderer:calculateEntityTargeter(xsotan)
    
                renderer:renderEntityTargeter(xsotan, color, size * 1.25)
                renderer:renderEntityArrow(xsotan, 30, 10, 250, color)
            end
        end
    end

    --Render text around xsotan currently being analyzed
    if mission.data.custom.currentAnalysisXsotan and mission.data.custom.currentAnalysisTime then
        local xsotan = Entity(Uuid(mission.data.custom.currentAnalysisXsotan))

        local craft = _player.craft

        if xsotan and valid(xsotan) and craft then
            local dist = craft:getNearestDistance(xsotan)

            local str = "ANALYSIS HALTED"
            if dist <= analyzeXsotanSpecimen_getAnalysisDistance(craft) and craft.type == EntityType.Ship then
                str = "ANALYSIS IN PROGRESS"
            end
    
            local v2, size = renderer:calculateEntityTargeter(xsotan)
    
            local rect = Rect(v2.x - size, v2.y - (size * 2.5), v2.x + size, v2.y + size)
            drawTextRect(str, rect, 0, 0, ColorRGB(1.0, 1.0, 1.0), 10, 0, 0, 0)
    
            local timeLeft = math.max(120 - mission.data.custom.currentAnalysisTime, 0)
    
            --Careful about enabling this - spam.
            --mission.Log(methodName, "Analysis time is : " .. tostring(mission.data.custom.currentAnalysisTime) .. " time left is : " .. tostring(timeLeft)) 
            --mission.Log(methodName, "Minutes : " .. tostring(minutes) .. " Seconds : " .. tostring(seconds))
    
            local rect2 = Rect(v2.x - size, v2.y + (size * 0.5), v2.x + size, v2.y + size)
            drawTextRect("${_TIME} REMAINING" % { _TIME = createDigitalTimeString(timeLeft)}, rect2, 0, 0, ColorRGB(1.0, 1.0, 1.0), 10, 0, 0, 0)
        end
    end

    renderer:display()
end

--endregion

--region #MAKEBULLETIN CALLS

function analyzeXsotanSpecimen_formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    local descriptionTable = {
        "Greetings, Captain. Our scientists are looking to find out more about a ${_XSOTANTYPE}, but our search for one has proven to be fruitless. We're willing to offer a bounty for any enterprising explorer that can find one and record its combat data. Once you transmit it to us, we'll send your payment. Thank you!", --Neutral
        "This is an emergency request! We've been trying to do more research on the ${_XSOTANTYPE}, but we've found that our recruits are too enthusiastic and blow them to space dust before our scientists can find out anything interesting. Record one in combat and transmit its data back to us. We'll pay you for it. Should be an easy job, yes?", --Aggressive
        "Peace be with you, Captain. We've long wanted to ascertain the full extent of a ${_XSOTANTYPE}'s capabilities, but our fleet has had trouble pinning one down for long enough to analyze its behavior. If you could record the Xsotan's combat telemetry and transmit it to us, it would aid us greatly. You will be duly rewarded, of course." --Peaceful
    }

    return descriptionTable[descriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"

    local _sector = Sector()
    local x, y = _sector:getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    local _Description = analyzeXsotanSpecimen_formatDescription(_Station)

    --Pick the Xsotan we're after.
    local possibleXsotanTypes = {}

    for _, xsotanType in pairs(mission.data.custom.xsotanTypes) do
        if analyzeXsotanSpecimen_modTableOK(xsotanType.idx) then
            table.insert(possibleXsotanTypes, xsotanType)
        end
    end

    local targetXsotanType = getRandomEntry(possibleXsotanTypes)

    local _Difficulty = targetXsotanType.difficulty

    local baseReward = 40000 * targetXsotanType.rewardFactor
    if insideBarrier then
        baseReward = baseReward * 2
    end

    reward = baseReward * Balancing.GetSectorRewardFactor(_sector:getCoordinates())

    missionReward = { credits = reward, relations = 6000, paymentMessage = "Earned %1% credits for analyzing the Xsotan." }

    local distToCenter = math.sqrt(x * x + y * y)
    local _MatlMin = 0 --7000
    local _MatlMax = 0 --8000
    if distToCenter > 400 then
        _MatlMin = 5000
        _MatlMax = 6000
    elseif distToCenter < 400 and distToCenter > 300 then
        _MatlMin = 10000
        _MatlMax = 12000
    else
        _MatlMin = 20000
        _MatlMax = 24000
    end
    
    mission.Log(_MethodName, "matlmin is ${MIN} and matlmax is ${MAX}" % { MIN = _MatlMin, MAX = _MatlMax }) 

    local materialAmount = round(random():getInt(_MatlMin, _MatlMax) / 100) * 100
    MissionUT.addSectorRewardMaterial(x, y, missionReward, materialAmount)

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = _Difficulty,
        reward = "¢${reward}",
        script = "missions/xsotanspecimen.lua",
        formatArguments = {reward = createMonetaryString(reward), _XSOTANTYPE = targetXsotanType.longName },
        msg = "Thank you! We'll send your reward when you send the data.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = nil,
            reward = missionReward,
            initialDesc = _Description,
            targetType = targetXsotanType.idx,
            insideBarrier = insideBarrier
        }},
    }

    return bulletin
end

--endregion