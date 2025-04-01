package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("structuredmission")
include("player") --needed to use MissionUT.dockedDialogSelector

local Balancing = include ("galaxy")

mission._Debug = 0
mission._Name = "Scrap Delivery"

--region #INIT

--Standard mission data.
mission.data.brief = mission._Name
mission.data.title = mission._Name
mission.data.autoTrackMission = true
mission.data.description = {
    { text = "You recieved the following request from the ${sectorName} ${giverTitle}:" }, --Placeholder
    { text = "" }, --Placeholder
    { text = "Deliver ${_SCRAPAMT} ${_SCRAPTYPE} to the Scrapyard in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false },
    { text = "${_SCRAPDELIVERED} / ${_SCRAPAMT} delivered", bulletPoint = true, fulfilled = false }
}
mission.data.accomplishMessage = "Thank you for the scrap! We transferred the reward to your account."

mission.data.custom.scrapTypes = {
    { matlIdx = 0, name = "Scrap Iron" },
    { matlIdx = 1, name = "Scrap Titanium" },
    { matlIdx = 2, name = "Scrap Naonite" },
    { matlIdx = 3, name = "Scrap Trinium" },
    { matlIdx = 4, name = "Scrap Xanion" },
    { matlIdx = 5, name = "Scrap Ogonite" },
    { matlIdx = 6, name = "Scrap Avorion" }
}

local ScrapDelivery_init = initialize
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
        mission.data.custom.scrapNeeded = _Data_in.scrapNeeded
        mission.data.custom.scrapTypeNeeded = _Data_in.scrapTypeNeeded

        local scrapTypeNeededName = mission.data.custom.scrapTypes[mission.data.custom.scrapTypeNeeded].name

        mission.data.custom.scrapTypeNeededName = scrapTypeNeededName --Shortcut for text formatting. Could technically do it like line 47 each time but that would be agony.
        mission.data.custom.scrapDelivered = 0 --Allows for partial deliveries.

        --[[=====================================================
            MISSION DESCRIPTION SETUP:
        =========================================================]]
        mission.data.description[1].arguments = { sectorName = _sector.name, giverTitle = giver.translatedTitle }
        mission.data.description[2].text = _Data_in.initialDesc
        mission.data.description[2].arguments = { _SCRAPAMT = mission.data.custom.scrapNeeded, _SCRAPTYPE = scrapTypeNeededName }
        mission.data.description[3].arguments = { _X = _X, _Y = _Y, _SCRAPAMT = mission.data.custom.scrapNeeded, _SCRAPTYPE = scrapTypeNeededName }
        mission.data.description[4].arguments = { _SCRAPDELIVERED = mission.data.custom.scrapDelivered,  _SCRAPAMT = mission.data.custom.scrapNeeded }
    end

    --Run vanilla init. Managers _restoring on its own.
    ScrapDelivery_init(_Data_in, bulletin)
end

--endregion

--region #PHASE CALLS

mission.phases[1] = {}
mission.phases[1].onBegin = function()
    --Can't set this up until the init call on line 70
    mission.data.custom.stationId = mission.data.giver.id.string
end

mission.phases[1].updateServer = function(timeStep)
    --We shouldn't be able to deliver more scrap than needed, but just in case.
    if mission.data.custom.scrapDelivered >= mission.data.custom.scrapNeeded then
        finishAndReward()
    end
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

    local _player = Player()
    local ship = _player.craft

    local scrapAmountNeeded = mission.data.custom.scrapNeeded - mission.data.custom.scrapDelivered

    local holdAmount = ship:getCargoAmount(mission.data.custom.scrapTypeNeededName)

    local scrapToDeliver = holdAmount
    if scrapAmountNeeded < holdAmount then
        scrapToDeliver = scrapAmountNeeded
    end

    mission.Log(methodName, "Needed: " .. tostring(scrapAmountNeeded) .. " " .. mission.data.custom.scrapTypeNeededName .. " In hold: " .. tostring(holdAmount) .. " Delivering: " .. tostring(scrapToDeliver))

    --Remove from hold
    ship:removeCargo(mission.data.custom.scrapTypeNeededName, scrapToDeliver)

    --Increment delivered amount
    mission.data.custom.scrapDelivered = mission.data.custom.scrapDelivered + scrapToDeliver

    mission.data.description[4].arguments = { _SCRAPDELIVERED = mission.data.custom.scrapDelivered,  _SCRAPAMT = mission.data.custom.scrapNeeded }
    
    --sync w/ client.
    sync()
end
callable(nil, "incrementScrapDelivery")

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

function onDeliverScrap(entityId)
    local methodName = "On Deliver Scrap"
    mission.Log(methodName, "Beginning. Entity ID is " .. tostring(entityId))

    local conditionFunc = function()
        --print("Entering condition func")
        local _player = Player()
        local ship = _player.craft

        if not _player or not ship then
            return false
        end

        local holdAmount = ship:getCargoAmount(mission.data.custom.scrapTypeNeededName)
        if holdAmount > 0 then
            return true
        end

        return false
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
        failedDialog.text = "You do not have any ${_SCRAPTYPE}! Please ensure you have some to deliver." % {_SCRAPTYPE = mission.data.custom.scrapTypeNeededName }
        
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
        "To any enterprising captains out there, we're running short on resources. ${_SCRAPAMT} ${_SCRAPTYPE} should cover the shortfall. Please deliver it to us - we'll pay you for your time and effort. We don't care how you get the scrap - only that you get it to us.", --Neutral
        "Our military's ability to obliterate ships outstrips our ability to harvest them. That's where you come in. Harvest some pirates or Xsotan and bring the remains to us. We need ${_SCRAPAMT} ${_SCRAPTYPE}. You will be compensated, of course. Let it never be said we don't appreciate our minions.", --Aggressive
        "Peace be with you. We need additional resources, but our military isn't strong enough to take on local pirates and Xsotan. Perhaps if we can acquire ${_SCRAPAMT} additional ${_SCRAPTYPE}, we'll be able to fend them off. Please deliver this scrap to us. We'll pay you for your efforts." --Peaceful
    }

    return descriptionTable[descriptionType]
end

mission.makeBulletin = function(_Station)
    local _MethodName = "Make Bulletin"
    mission.Log(_MethodName, "Making Bulletin.")
    --This mission happens in the same sector you accept it in.
    local x, y = Sector():getCoordinates()
    local insideBarrier = MissionUT.checkSectorInsideBarrier(x, y)    
    local target = { x = x, y = y }

    if not target.x or not target.y then
        mission.Log(_MethodName, "Target.x or Target.y not set - returning nil.")
        return 
    end
    
    local _Description = formatDescription(_Station)

    --pick a random payout value
    local payout = random():getInt(1, 10) * 10000 * Balancing.GetSectorRewardFactor(x, y)
    if insideBarrier then
        payout = payout * 2
    end

    --pick a random scrap type
    --First, we need to get the material probabilities in the area so the player isn't asked to turn avorion in outside the barrier.
    local matlProbabilities = Balancing_GetMaterialProbability(x, y)
    local availableMatlIndexes = {}
    for matlIdx, probability in pairs(matlProbabilities) do
        if probability > 0 then
            --This gets a bit spammy so uncomment with caution.
            --mission.Log(_MethodName, "Index " .. tostring(matlIdx) .. " is avaialble. Adding " .. tostring(matlIdx + 1) .. " to table.")
            table.insert(availableMatlIndexes, matlIdx + 1) --Iron is matl index 0, and LUA tables start at 1 :vomit:.
        end
    end
    local matlIndexNeeded = getRandomEntry(availableMatlIndexes)
    --mission.Log(_MethodName, "Chose matlIndex " .. tostring(matlIndexNeeded))
    local scrapData = mission.data.custom.scrapTypes[matlIndexNeeded]

    --calculate amount of scrap to turn in based on payout and some other values.
    local matl = Material(scrapData.matlIdx)
    local valuePerMatl = (matl.costFactor * 10)
    local matlAmountNeeded = math.floor((payout / valuePerMatl) / 3) --More efficient than Scrap Scramble, but max payout is capped rather than being "as much as you can bring in" - also, no reward items.
    local matlAmountUpperLimit = math.floor((payout / valuePerMatl) / 2) --Set a minimum efficiency.
    matlAmountNeeded = matlAmountNeeded + random():getInt(-5000, 5000) --Variety is the spice of life.
    matlAmountNeeded = math.min(matlAmountNeeded, matlAmountUpperLimit) 
    matlAmountNeeded = math.max(matlAmountNeeded, 1000) --1000 is the absolute lowest limit.

    reward = payout

    local bulletin =
    {
        -- data for the bulletin board
        brief = mission.data.brief,
        title = mission.data.title,
        description = _Description,
        difficulty = "Variable", --Depends on how you get the scrap.
        reward = "¢${reward}",
        script = "missions/scrapdelivery.lua",
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward), _SCRAPAMT = matlAmountNeeded, _SCRAPTYPE = scrapData.name },
        msg = "Thank you! We'll pay you once you deliver the scrap.",
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
            reward = {credits = reward, relations = 1000, paymentMessage = "Earned %1% credits for delivering scrap." },
            initialDesc = _Description,
            scrapNeeded = matlAmountNeeded,
            scrapTypeNeeded = matlIndexNeeded
        }},
    }

    return bulletin
end

--endregion