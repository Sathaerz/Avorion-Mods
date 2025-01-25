package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include("player") --needed to use MissionUT.dockedDialogSelector

local Balancing = include ("galaxy")
local SectorTurretGenerator = include ("sectorturretgenerator")

mission._Debug = 0
mission._Name = "Scrap Scramble"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "" }, --Placeholder
    { text = "Drop scrap off in sector (${_X}:${_Y}) - Delivered so far:", bulletPoint = true, fulfilled = false },
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_SCRAPAMT} ${_SCRAPTYPE}", bulletPoint = true, fulfilled = false } --placeholder
}
mission.data.timeLimit = 30 * 60 --Player has 30 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.
--Can't set mission.data.reward.paymentMessage here since we are using a funky setup for doing the rewards.
mission.data.custom.accomplishMessage = "Thank you for the scrap! We transferred the reward to your account."
mission.data.custom.failMessage = "We see that you weren't able to drop off any scrap. That's a shame. Better luck next time!"
mission.data.custom.scrapTypes = {
    { name = "Scrap Iron", amount = 0 },
    { name = "Scrap Titanium", amount = 0 },
    { name = "Scrap Naonite", amount = 0 },
    { name = "Scrap Trinium", amount = 0 },
    { name = "Scrap Xanion", amount = 0 },
    { name = "Scrap Ogonite", amount = 0 },
    { name = "Scrap Avorion", amount = 0 }
}

--endregion

--region #PHASE CALLS

mission.globalPhase.getRewardedItems = function()
    local methodName = "Global Phase Get Rewarded Items"
    mission.Log(methodName, "Getting reward items...")
    
    local xrand = random()
    local items = {}
    local totalScrap = mission.data.custom.totalScrapDelivered

    local possibleRarities = {RarityType.Common, RarityType.Common, RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare}
    if mission.data.custom.inBarrier then
        possibleRarities = {RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare, RarityType.Rare, RarityType.Exceptional, RarityType.Exotic}
    end

    --25% chance of getting a random rarity cargo upgrade. Need to turn in at least 500 scrap.
    if xrand:test(0.25) and totalScrap >= 500 then
        mission.Log(methodName, "Getting cargo upgrade")

        local _SeedInt = xrand:getInt(1, 20000)
        local upgradeRarity = getRandomEntry(possibleRarities)
        table.insert(items, SystemUpgradeTemplate("data/scripts/systems/cargoextension.lua", Rarity(upgradeRarity), Seed(_SeedInt)))
    end

    --12.5% chance of getting a r-salvaging turret. Need to turn in at least 1000 scrap.
    if xrand:test(0.125) and totalScrap >= 1000 then
        mission.Log(methodName, "Getting salvaging turret")

        local x, y = mission.data.location.x, mission.data.location.y
        local generator = SectorTurretGenerator()

        local turretRarity = getRandomEntry(possibleRarities)
        table.insert(items, InventoryTurret(generator:generate(x, y, 0, Rarity(turretRarity), WeaponType.RawSalvagingLaser, nil)))
    end

    return table.unpack(items)
end

mission.phases[1] = {}
mission.phases[1].onBegin = function()
    local methodName = "Phase 1 On Begin"

    local _sector = Sector()
    local giver = Entity(mission.data.giver.id)
    local x, y = mission.data.location.x, mission.data.location.y

    mission.data.accomplishMessage = mission.data.custom.failMessage
    mission.data.custom.droppedScrap = false
    mission.data.custom.stationId = mission.data.giver.id.string
    mission.data.custom.totalScrapDelivered = 0

    mission.Log(methodName, "Sector name is " .. tostring(_sector.name) .. " Giver title is " .. tostring(giver.translatedTitle))

    mission.data.description[1].arguments = { sectorName = _sector.name, giverTitle = giver.translatedTitle }
    mission.data.description[2].text = formatDescription(giver)
    mission.data.description[3].arguments = { _X = x, _Y = y }

    local descidx = 4
    for _, scrapType in pairs(mission.data.custom.scrapTypes) do
        mission.data.description[descidx].arguments = { _SCRAPAMT = scrapType.amount, _SCRAPTYPE = scrapType.name }
        descidx = descidx + 1
    end
end

mission.phases[1].onBeginServer = function()
    local x, y = mission.data.location.x, mission.data.location.y

    mission.data.custom.inBarrier = MissionUT.checkSectorInsideBarrier(x, y)

    mission.internals.fulfilled = true --This mission will accomplish at the end, and not fail. The only question is how much money the player gets.
end

mission.phases[1].onStartDialog = function(entityId)
    local methodName = "On Start Dialog"

    if not atTargetLocation() then
        return
    end

    mission.Log(methodName, "Checking to see if " .. tostring(entityId) .. " matches " .. tostring(mission.data.custom.stationId))

    if entityId == Uuid(mission.data.custom.stationId) then
        local scriptUI = ScriptUI(entityId)
        if not scriptUI then
            return
        end

        scriptUI:addDialogOption("Deliver scrap metal", "onDeliverScrap")
    end
end

mission.phases[1].onAccomplish = function()
    local methodName = "Phase 1 On Accomplish"

    if mission.data.custom.droppedScrap then
        mission.Log(methodName, "Player accomplished mission - rewarding.")

        local x, y = mission.data.location.x, mission.data.location.y
        local thousands = 0

        --Calculate reward
        for matlidx, scrapData in pairs(mission.data.custom.scrapTypes) do
            local matl = Material(matlidx - 1)
            local matlCredits = (matl.costFactor * scrapData.amount * 10)

            mission.Log(methodName, "Material name is " .. tostring(matl.name) .. " turned in " .. tostring(scrapData.amount) .. " for " .. tostring(math.ceil(matlCredits)) .. " credits.")

            mission.data.reward.credits = mission.data.reward.credits + math.ceil(matlCredits)
            thousands = math.floor(scrapData.amount / 1000)
        end

        mission.data.reward.paymentMessage = "Earned %1% credits for dropping off " .. tostring(mission.data.custom.totalScrapDelivered) .. " units of scrap."
        --Can't use the normal reward factor progression here - selling resources is already fairly profitable and I don't want to make things TOO easy for the player :P
        --Especially since you can stash and deliver, or do wrecking havoc to bring a bunch of wreckages in and salvage those @ the scrapyard - essentially getting paid 3 times.
        mission.data.reward.credits = mission.data.reward.credits * (Balancing.GetSectorRewardFactor(x, y) * 0.125)
        mission.data.reward.relations = thousands * 100

        reward()
    else
        punish()
    end
end

--endregion

--region #SERVER CALLS

function incrementScrapDelivery()
    local methodName = "Increment Scrap Count"
    if onClient() then
        mission.Log(methodName, "Calling on Client => Invoking on server")
        invokeServerFunction("incrementScrapDelivery")
        return
    end
    mission.Log(methodName, "Called on server.")

    mission.data.accomplishMessage = mission.data.custom.accomplishMessage

    local _player = Player()
    local ship = _player.craft

    local descidx = 4
    for _, scrapType in pairs(mission.data.custom.scrapTypes) do
        --Get amount in ship's hold
        local holdAmount = ship:getCargoAmount(scrapType.name)

        --Add that to scrapType.amount
        scrapType.amount = scrapType.amount + holdAmount
        mission.data.custom.totalScrapDelivered = mission.data.custom.totalScrapDelivered + holdAmount

        --Remove from hold
        ship:removeCargo(scrapType.name, holdAmount)

        --Update description & increment index
        mission.data.description[descidx].arguments = { _SCRAPAMT = scrapType.amount, _SCRAPTYPE = scrapType.name }
        descidx = descidx + 1
    end

    mission.data.custom.droppedScrap = true
    
    --sync w/ client.
    sync()
end
callable(nil, "incrementScrapDelivery")

--endregion

--region #CLIENT CALLS

function onDeliverScrap(entityId)
    local methodName = "On Deliver Scrap"
    mission.Log(methodName, "Beginning. Entity ID is " .. tostring(entityId))

    local conditionFunc = function()
        --Check to make sure player has any scrap to deliver.
        --print("Entering condition func")
        local _player = Player()
        local ship = _player.craft

        if not _player or not ship then
            return false
        end

        local conditionOK = false

        for _, scrapType in pairs(mission.data.custom.scrapTypes) do
            local holdAmount = ship:getCargoAmount(scrapType.name)
            if holdAmount > 0 then
                conditionOK = true
                break
            end
        end

        return conditionOK
    end
    
    local dockedFunc = function()
        local dockedDialog = {}
        dockedDialog.text = "Thank you for the scrap delivery! We'll add this to your account."
        dockedDialog.onEnd = "incrementScrapDelivery"

        return dockedDialog
    end

    local undockedFunc = function()
        local undockedDialog = {}
        undockedDialog.text = "Please dock to the station to drop off the scrap!"

        return undockedDialog
    end

    local failedFunc = function()
        local failedDialog = {}
        failedDialog.text = "You do not have any scrap in your hold! Please ensure you have some to deliver."

        return failedDialog
    end

    mission.Log(methodName, "Getting docked dialog selector.")
    MissionUT.dockedDialogSelector(entityId, conditionFunc(), failedFunc, undockedFunc, dockedFunc)
end

--endregion

--region #MAKEBULLETIN CALLS

function formatDescription(_Station)
    local _Faction = Faction(_Station.factionIndex)
    local _Aggressive = _Faction:getTrait("aggressive")

    local descriptionType = 1 --Neutral
    if _Aggressive > 0.5 then
        descriptionType = 2 --Aggressive.
    elseif _Aggressive <= -0.5 then
        descriptionType = 3 --Peaceful.
    end

    local descriptionTable = {
        "To any enterprising captains out there, we're running short on resources, and have decided to do some scrapping. Collect anything you can harvest and deliver it to us. We'll pay you.", --Neutral
        "Our military's ability to obliterate ships outstrips our ability to harvest them. That's where you come in. Harvest some pirates and bring the remains to us. You will be compensated.", --Aggressive
        "Peace be with you. We need additional resources, but our military isn't strong enough to take on local pirates. Destroy some for us and harvest their ships. We'll pay you for the scrap." --Peaceful
    }

    return descriptionTable[descriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local target = {}
    target.x, target.y = Sector():getCoordinates()

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end
    
    local _Description = formatDescription(_Station)

    reward = 0

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = "Variable", --Depends on how you get the scrap.
        reward = "Variable",
        script = "missions/scrapscramble.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you for your patronage! We'll pay you based on how much scrap you turn over.",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/scrapscramble.lua") or player:hasScript("missions/scrapdelivery.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional scrap delivery contracts! Abandon your current one or complete it.")
                return 0
            end
            return 1
        ]],
        onAccept = [[
            local self, player = ...
            player:sendChatMessage(Entity(self.arguments[1].giver), 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]],

        -- data that's important for our own mission
        arguments = {{
            giver = _Station.index,
            location = target,
            reward = {credits = reward, relations = 0},
            punishment = { relations = 1000 }, --Nothing too bad. Just a little sting.
            initialDesc = _Description
        }},
    }

    return bulletin
end

--endregion