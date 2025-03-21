package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include("player") --needed to use MissionUT.dockedDialogSelector

local Balancing = include ("galaxy")
local SectorTurretGenerator = include ("sectorturretgenerator")

mission._Debug = 0
mission._Name = "Mineral Madness"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "" }, --Placeholder
    { text = "Drop ore off in sector (${_X}:${_Y}) - Delivered so far:", bulletPoint = true, fulfilled = false },
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false }, --placeholder
    { text = "${_OREAMT} ${_ORETYPE}", bulletPoint = true, fulfilled = false } --placeholder
}
mission.data.timeLimit = 30 * 60 --Player has 30 minutes.
mission.data.timeLimitInDescription = true --Show the player how much time is left.
--Can't set mission.data.reward.paymentMessage here since we are using a funky setup for doing the rewards.
mission.data.custom.accomplishMessage = "Thank you for the ores! We transferred the reward to your account."
mission.data.custom.failMessage = "We see that you weren't able to drop off any ore. That's a shame. Better luck next time!"
mission.data.custom.oreTypes = {
    { name = "Iron Ore", amount = 0 },
    { name = "Titanium Ore", amount = 0 },
    { name = "Naonite Ore", amount = 0 },
    { name = "Trinium Ore", amount = 0 },
    { name = "Xanion Ore", amount = 0 },
    { name = "Ogonite Ore", amount = 0 },
    { name = "Avorion Ore", amount = 0 }
}

local MineralMadness_init = initialize
function initialize(_Data_in, bulletin)
    local methodName = "initialize"
    mission.Log(methodName, "Beginning...")

    if onServer() and not _restoring then
        local _X, _Y = _Data_in.location.x, _Data_in.location.y

        local _sector = Sector()
        local giver = Entity(_Data_in.giver)

        mission.Log(methodName, "Sector name is " .. tostring(_sector.name) .. " Giver title is " .. tostring(giver.translatedTitle))

        --[[=====================================================
            CUSTOM MISSION DATA SETUP:
        =========================================================]]
        mission.data.accomplishMessage = mission.data.custom.failMessage
        mission.data.custom.droppedOre = false
        mission.data.custom.inBarrier = MissionUT.checkSectorInsideBarrier(_X, _Y)
        mission.data.custom.totalOreDelivered = 0

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _sector.name, giverTitle = giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[3].arguments = { _X = _X, _Y = _Y }
    end

    --Run vanilla init. Managers _restoring on its own.
    MineralMadness_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS

mission.globalPhase.getRewardedItems = function()
    local methodName = "Global Phase Get Rewarded Items"
    mission.Log(methodName, "Getting reward items...")
    
    local xrand = random()
    local items = {}
    local totalOre = mission.data.custom.totalOreDelivered

    local possibleRarities = {RarityType.Common, RarityType.Common, RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare}
    if mission.data.custom.inBarrier then
        possibleRarities = {RarityType.Uncommon, RarityType.Uncommon, RarityType.Rare, RarityType.Rare, RarityType.Exceptional, RarityType.Exotic}
    end

    --25% chance of getting a random rarity cargo upgrade.
    if xrand:test(0.25) and totalOre >= 500 then
        mission.Log(methodName, "Getting cargo upgrade")

        local _SeedInt = xrand:getInt(1, 20000)
        local upgradeRarity = getRandomEntry(possibleRarities)
        table.insert(items, SystemUpgradeTemplate("data/scripts/systems/cargoextension.lua", Rarity(upgradeRarity), Seed(_SeedInt)))
    end

    --12.5% chance of getting a r-mining turret. Need to have delivered at least 1000 ore.
    if xrand:test(0.125) and totalOre >= 1000 then
        mission.Log(methodName, "Getting mining turret")

        local x, y = mission.data.location.x, mission.data.location.y
        local generator = SectorTurretGenerator()

        local turretRarity = getRandomEntry(possibleRarities)
        table.insert(items, InventoryTurret(generator:generate(x, y, 0, Rarity(turretRarity), WeaponType.RawMiningLaser, nil)))
    end

    return table.unpack(items)
end

mission.phases[1] = {}
mission.phases[1].onBegin = function()
    local methodName = "Phase 1 On Begin"
    mission.Log(methodName, "Setting arguments for ores.")

    --Can't set this up until the init call on line 72
    mission.data.custom.stationId = mission.data.giver.id.string

    local descidx = 4
    for _, oreType in pairs(mission.data.custom.oreTypes) do
        mission.data.description[descidx].arguments = { _OREAMT = oreType.amount, _ORETYPE = oreType.name }
        descidx = descidx + 1
    end
end

mission.phases[1].onBeginServer = function()
    mission.internals.fulfilled = true --This mission will succeed at the end, and not fail. The only question is how much money the player gets.
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

        scriptUI:addDialogOption("Deliver ores", "onDeliverOre")
    end
end

mission.phases[1].onAccomplish = function()
    local methodName = "Phase 1 On Accomplish"

    if mission.data.custom.droppedOre then
        mission.Log(methodName, "Player accomplished mission - rewarding.")

        local x, y = mission.data.location.x, mission.data.location.y
        local thousands = 0

        --Calculate reward
        for matlIdx, oreData in pairs(mission.data.custom.oreTypes) do
            local matl = Material(matlIdx - 1)
            local matlCredits = (matl.costFactor * oreData.amount * 10)

            mission.Log(methodName, "Material name is " .. tostring(matl.name) .. " turned in " .. tostring(oreData.amount) .. " for " .. tostring(math.ceil(matlCredits)) .. " credits.")

            mission.data.reward.credits = mission.data.reward.credits + math.ceil(matlCredits)
            thousands = math.floor(oreData.amount / 1000)
        end

        mission.data.reward.paymentMessage = "Earned %1% credits for dropping off " .. tostring(mission.data.custom.totalOreDelivered) .. " units of ore."
        --Can't use the normal reward factor progression here - selling resources is already fairly profitable and I don't want to make things TOO easy for the player :P
        --The payout is shockingly high for doing The Dig and just letting your ship fly around and gather resources. You can get 40 million off of this easily.
        mission.data.reward.credits = mission.data.reward.credits * (Balancing.GetSectorRewardFactor(x, y) * 0.25)
        mission.data.reward.relations = thousands * 100

        reward()
    else
        punish()
    end
end

--endregion

--region #SERVER CALLS

function incrementOreDelivery()
    local methodName = "Increment Ore Delivery"
    if onClient() then
        mission.Log(methodName, "Calling on Client => Invoking on server")
        invokeServerFunction("incrementOreDelivery")
        return
    end
    mission.Log(methodName, "Called on server.")

    mission.data.accomplishMessage = mission.data.custom.accomplishMessage

    local _player = Player()
    local ship = _player.craft

    local oreDepotId = Uuid(mission.data.custom.stationId)
    local oreDepot = Entity(oreDepotId)

    local descidx = 4
    for matlIdx, oreType in pairs(mission.data.custom.oreTypes) do
        --Get amount in ship's hold
        local holdAmount = ship:getCargoAmount(oreType.name)

        --Add that to oreType.amount
        oreType.amount = oreType.amount + holdAmount
        mission.data.custom.totalOreDelivered = mission.data.custom.totalOreDelivered + holdAmount

        --Remove from hold
        ship:removeCargo(oreType.name, holdAmount)

        --Give to resource depot
        mission.Log(methodName, "Invoking addResource on oreDepot")
        oreDepot:invokeFunction("resourcetrader.lua", "addResource", matlIdx, holdAmount)

        --Update description & increment index
        mission.data.description[descidx].arguments = { _OREAMT = oreType.amount, _ORETYPE = oreType.name }
        descidx = descidx + 1
    end

    mission.data.custom.droppedOre = true
    
    --sync w/ client.
    sync()
end
callable(nil, "incrementOreDelivery")

--endregion

--region #CLIENT CALLS

function onDeliverOre(entityId)
    local methodName = "On Deliver Ore"
    mission.Log(methodName, "Beginning. Entity ID is " .. tostring(entityId))

    local conditionFunc = function()
        --print("Entering condition func")
        local _player = Player()
        local ship = _player.craft

        if not _player or not ship then
            return false
        end
        
        --Check to make sure player has any scrap to deliver.
        local conditionOK = false

        for _, oreType in pairs(mission.data.custom.oreTypes) do
            local holdAmount = ship:getCargoAmount(oreType.name)
            if holdAmount > 0 then
                conditionOK = true
                break
            end
        end

        return conditionOK
    end
    
    local dockedFunc = function()
        local dockedDialog = {}
        dockedDialog.text = "Thank you for the ore delivery! We'll add this to your account."
        dockedDialog.onEnd = "incrementOreDelivery"

        return dockedDialog
    end

    local undockedFunc = function()
        local undockedDialog = {}
        undockedDialog.text = "Please dock to the station to drop off the ore!"

        return undockedDialog
    end

    local failedFunc = function()
        local failedDialog = {}
        failedDialog.text = "You do not have any ores in your hold! Please ensure you have some to deliver."

        return failedDialog
    end

    mission.Log(methodName, "Getting docked dialog selector.")
    MissionUT.dockedDialogSelector(entityId, conditionFunc(), failedFunc, undockedFunc, dockedFunc)
end

--endregion

--region #MAKEBULLETIN CALLS

function formatDescription()
    local descriptionTable = {
        "Hey there! Some of our miners are down for the count but the need for resources never ends! There's always something to build or repair. We'd appreciate it if you could mine some while we fix up our ships. Bring as much raw ore as you can! We'll pay you for it.",
        "We've been working as hard as we can to mine resources but it's not enough! We need some help. If you could go and strip some mineral fields we'd appreciate the help! Go ahead and drop off any raw ores you collect, we'll pay you an increased rate per unit!",
        "Oh god. I just finished a mining expedition and one of my engineers dumped half the contents of my cargo bay! I've reamed him out, but I'll get fired if the boss catches on! Help! If you can drop off some raw ores, maybe he won't find out... I'll pay you! Lots!!!"
    }

    if random():test(0.05) then
        descriptionTable = {
            "Hello friend! If you are able, could you please acquire some interesting ores for my collection? The minerals of this galaxy are absolutely fascinating! Bring some to this depot, and I will make sure you are compensated for your time! ouo7"
        }
    end

    return getRandomEntry(descriptionTable)
end

mission.makeBulletin = function(_Station)
    local methodName = "Make Bulletin"
    mission.Log(methodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local target = {}
    target.x, target.y = Sector():getCoordinates()

    if not target.x or not target.y then
        mission.Log(methodName, "Target.x or Target.y not set - returning nil.")
        return 
    end
    
    local _Description = formatDescription()

    reward = 0

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = "Variable", --Depends on how you get the ore.
        reward = "Variable",
        script = "missions/mineralmadness.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward)},
        msg = "Thank you for your patronage! We'll pay you based on how much ore you deliver to us!",
        giverTitle = _Station.title,
        giverTitleArgs = _Station:getTitleArguments(),
        checkAccept = [[
            local self, player = ...
            if player:hasScript("missions/mineralmadness.lua") then
                player:sendChatMessage(Entity(self.arguments[1].giver), 1, "You cannot accept additional ore delivery contracts! Abandon your current one or complete it.")
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