package.path = package.path .. ";data/scripts/lib/?.lua"

--Run the rest of the includes.
include ("galaxy")
include ("stringutility")
include ("callable")
include ("relations")
Dialog = include("dialogutility")
ESCCUtil = include("esccutil")

--Don't remove this or else the script might break.
--namespace FamilyContact
FamilyContact = {}
local self = FamilyContact

self.hailedPlayer = nil
self.contactPlayer = nil
self._GiveAllMissions = false --FOR TESTING PURPOSES ONLY - SET TO FALSE FOR LIVE VERSION

self._Debug = 0

--region #INIT

function FamilyContact.initialize()
    local _MethodName = "inizialize"
    self.Log(_MethodName, "Initialize Family Contact Script - Player should be hailed immediately")
    --Start hailing the player immediately.
    local playerIndex = Entity():getValue("_bau_playercontact_idx")
    self.contactPlayer = Player(playerIndex)
end

--endregion

function FamilyContact.getUpdateInterval()
    return 1.0
end

--region #SERVER CALLS

function FamilyContact.onUpdateServer(timeStep)
    if not self.hailedPlayer then
        deferredCallback(30, "onServerHailTimeout")
        invokeClientFunction(self.contactPlayer, "startHailing")
        self.hailedPlayer = true
    end
end

function FamilyContact.onServerHailTimeout()
    local _MethodName = "On Server Hail Timeout"
    self.Log(_MethodName, "Starting server hail timeout - player resonded is " .. tostring(self.playerResponded))
    if self.playerResponded then return end

    invokeClientFunction(self.contactPlayer, "onClientHailTimeout")
end

--endregion

--region #CLIENT CALLS

function FamilyContact.startHailing()
    ScriptUI():startHailing("startTalk", "warpOut")
end

function FamilyContact.onClientHailTimeout()
    ScriptUI():stopHailing()
    self.warpOut()
end

function CavaliersContact.startTalk()
    local _MethodName = "Start Talk"
    self.Log(_MethodName, "Initiating conversation with the player")

    self.playerHasBeenContacted()
    local rgen = ESCCUtil.getRand()
    local _Rank = self.contactPlayer:getValue("_bau_family_rank")
    local _RankLevel = self.contactPlayer:getValue("_bau_family_ranklevel")
    local _Story3Done = self.contactPlayer:getValue("_bau_story_3_accomplished")
    local _HaveAvo = self.contactPlayer:getValue("_bau_family_have_avorion")

    local greetings = {"Hello", "Greetings", "Hail"}
    local d0mid = {"We're glad to see you here", "Moretti sends his regards."}
    local missionconfirms = {"We'll contact you with the details.", "Here's the mission.", "Here are the details.", "Uploading mission data."}
    local goodbyes = {"Goodbye.", "Farewell.", "Arrivederci.", "Until then.", "Be careful out there..."}

    local dialog0 = {}
    local dialog1 = {}
    local dialog2 = {}

    --Determine the side mission options based on the player's rank. Always add at least one. 50% chance to add a 2nd. 25% chance to add a 3rd.
    local missionTable = { "EscortShipment", "DestroyRaiders" }
    local availableMissionTable = {}
    if _RankLevel >= 2 then
        table.insert(missionTable, "DestroyXsotan")
    end
    if _RankLevel >= 3 then
        table.insert(missionTable, "DestroyOutpost")
    end
    if _Story3Done and _HaveAvo then
        table.insert(missionTable, "DeliverMaterials")
    end
    if self._GiveAllMissions then
        for _, _Mission in pairs(missionTable) do
            table.insert(availableMissionTable, _Mission)
        end
    else
        self.Log(_MethodName, "Adding first mission...")
        local firstMission = missionTable[rgen:getInt(1, #missionTable)]
        table.remove(missionTable, ESCCUtil.getIndex(missionTable, firstMission))
        table.insert(availableMissionTable, firstMission)
        if rgen:getInt(1, 2) == 1 and #missionTable >= 1 then
            self.Log(_MethodName, "Adding second mission...")
            local secondMission = missionTable[rgen:getInt(1, #missionTable)]
            table.remove(missionTable, ESCCUtil.getIndex(missionTable, secondMission))
            table.insert(availableMissionTable, secondMission)
        end
        if #availableMissionTable >= 1 and rgen:getInt(1, 4) == 1 and #missionTable >= 1 then
            self.Log(_MethodName, "Adding third mission...")
            local thirdMission = missionTable[rgen:getInt(1, #missionTable)]
            table.remove(missionTable, ESCCUtil.getIndex(missionTable, thirdMission))
            table.insert(availableMissionTable, thirdMission)
        end
    end
    if _Story3Done and not _HaveAvo then
        --always add Deliver Materials if we've done story 3 and haven't done it once already.
        table.insert(availableMissionTable, "DeliverMaterials")
    end
    if _RankLevel >= 3 and _Story2Done and not _Story3Done then
        --always add Order from Chaos if it is available - add this at the start of the table.
        table.insert(availableMissionTable, 1, "OrderfromChaos")
    end

    local noThanksText = "No problem. We'll catch you next time. " .. goodbyes[rgen:getInt(1, #goodbyes)]

    dialog0.text = greetings[rgen:getInt(1, #greetings)] .. ", " .. _Rank .. " " .. self.contactPlayer.name .. "! " .. d0mid[rgen:getInt(1, #d0mid)] .. ". Are you currently busy?"
    dialog0.answers = {
        {answer = "I'm available.", followUp = dialog1 },
        {answer = "I'm busy.", onSelect = "warpOut", text = noThanksText}
    }
    dialog1.text = "Great! We could use your asssistance."
    dialog1.answers = {
        {answer = "What would you have me do?", followUp = dialog2 }
    }
    dialog2.text = "There are a few different tasks that you could help us with. Here's what's available."
    dialog2.answers = {}
    for _, mission in pairs(availableMissionTable) do
        local missionAcceptText = "Thank you for your assistance. " .. missionconfirms[rgen:getInt(1, #missionconfirms)]
        if mission == "EscortShipment" then
            table.insert(dialog2.answers, {answer = "Escort Shipment", onSelect = "escortShipment", text = missionAcceptText})
        elseif mission == "DestroyRaiders" then
            table.insert(dialog2.answers, {answer = "Ambush Raiders", onSelect = "destroyRaiders", text = missionAcceptText})
        elseif mission == "FutileResistance" then
            table.insert(dialog2.answers, {answer = "Defeat Resistance", onSelect = "destroyResistance", text = missionAcceptText})
        elseif mission == "DestroyXsotan" then
            table.insert(dialog2.answers, {answer = "Destroy Xsotan", onSelect = "destroyXsotan", text = missionAcceptText})
        elseif mission == "DestroyOutpost" then
            table.insert(dialog2.answers, {answer = "Destroy Outpost", onSelect = "destroyOutpost", text = missionAcceptText})
        elseif mission == "OrderfromChaos" then
            table.insert(dialog2.answers, {answer = "Order from Chaos", onSelect = "orderfromChaos", text = "The empress will be in touch."})
        elseif mission == "DeliverMaterials" then
            table.insert(dialog2.answers, {answer = "Deliver Materials", onSelect = "deliverMaterials", text = missionAcceptText})
        end
    end
    table.insert(dialog2.answers, {answer = "On second thought, I'd rather not do any of those.", onSelect = "warpOut", text = noThanksText})

    ScriptUI():interactShowDialog(dialog0, false)
end

--endregion