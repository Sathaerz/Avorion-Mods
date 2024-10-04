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

function FamilyContact.startTalk()
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
    local missionTable = { "RescueAssociate", "RumRun" }
    local availableMissionTable = {}
    if _RankLevel >= 2 then
        table.insert(missionTable, "GoingToTheMat")
    end
    if _RankLevel >= 3 then
        table.insert(missionTable, "AuctionKings")
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
        --Family just tells you to do it, but this is a safeguard in case the player abandons the mission.
        table.insert(availableMissionTable, "DeliverMaterials")
    end

    local noThanksText = "No problem. We'll catch you next time. " .. goodbyes[rgen:getInt(1, #goodbyes)]

    dialog0.text = greetings[rgen:getInt(1, #greetings)] .. ", " .. _Rank .. " " .. self.contactPlayer.name .. "! " .. d0mid[rgen:getInt(1, #d0mid)] .. ". Are you currently busy?"
    dialog0.answers = {
        {answer = "I'm available.", followUp = dialog1 },
        {answer = "I'm busy.", onSelect = "warpOut", text = noThanksText}
    }
    dialog1.text = "We could use your asssistance."
    dialog1.answers = {
        {answer = "What would you have me do?", followUp = dialog2 }
    }
    dialog2.text = "There are a few different tasks that you could help us with. Here's what's available."
    dialog2.answers = {}
    for _, mission in pairs(availableMissionTable) do
        local missionAcceptText = "Thank you for your assistance. " .. missionconfirms[rgen:getInt(1, #missionconfirms)]
        if mission == "RescueAssociate" then
            table.insert(dialog2.answers, {answer = "Rescue Associate", onSelect = "rescueAssoc", text = missionAcceptText})
        elseif mission == "RumRun" then
            table.insert(dialog2.answers, {answer = "Rum Run", onSelect = "rumRun", text = missionAcceptText})
        elseif mission == "GoingToTheMat" then
            table.insert(dialog2.answers, {answer = "Going To The Mat", onSelect = "gotoTheMat", text = missionAcceptText})
        elseif mission == "AuctionKings" then
            table.insert(dialog2.answers, {answer = "Auction Kings", onSelect = "auctionKings", text = missionAcceptText})
        elseif mission == "DeliverMaterials" then
            table.insert(dialog2.answers, {answer = "Deliver Materials", onSelect = "deliverMaterials", text = missionAcceptText})
        end
    end
    table.insert(dialog2.answers, {answer = "On second thought, I'd rather not do any of those.", onSelect = "warpOut", text = noThanksText})

    ScriptUI():interactShowDialog(dialog0, false)
end

--endregion

--region # CLIENT/SERVER CALLS

function FamilyContact.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[BAU Family Contact] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

function FamilyContact.warpOut()
    --No penalty for rejecting contact with them.
    if onClient() then
        invokeServerFunction("warpOut")
        return
    end

    local entity = Entity()
    local rgen = ESCCUtil.getRand()

    entity:addScriptOnce("utility/delayeddelete.lua", rgen:getFloat(3, 6))
end
callable(FamilyContact, "warpOut")

function FamilyContact.playerHasBeenContacted()
    local _MethodName = "Player has been contacted"
    self.Log(_MethodName, "Beginning...")
    if onClient() then
        invokeServerFunction("playerHasBeenContacted")
        return
    end

    self.playerResponded = true
end
callable(FamilyContact, "playerHasBeenContacted")

--endregion

--region #MISSION LIST

--RESCUE ASSOCIATE
function FamilyContact.rescueAssoc()
    local _MethodName = "Resuce Associate"
    if onClient() then
        self.Log(_MethodName, "Invoking on Server")
        invokeServerFunction("rescueAssoc")
        return
    end

    self.Log(_MethodName, "Adding mission script to player.")
    self.contactPlayer:addScript("data/scripts/player/missions/family/side/bauside1.lua")
    self.warpOut()
end
callable(FamilyContact, "rescueAssoc")

--RUM RUN
function FamilyContact.rumRun()
    local _MethodName = "Rum Run"
    if onClient() then
        self.Log(_MethodName, "Invoking on Server")
        invokeServerFunction("rumRun")
    end

    self.Log(_MethodName, "Adding mission script to player.")
    self.contactPlayer:addScript("data/scripts/player/missions/family/side/bauside2.lua")
    self.warpOut()
end
callable(FamilyContact, "rumRun")

--GOING TO THE MAT
function FamilyContact.gotoTheMat()
    local _MethodName = "Going To The Mat"
    if onClient() then
        self.Log(_MethodName, "Invoking on Server")
        invokeServerFunction("gotoTheMat")
    end

    self.Log(_MethodName, "Adding mission script to player.")
    self.contactPlayer:addScript("data/scripts/player/missions/family/side/bauside3.lua")
    self.warpOut()
end
callable(FamilyContact, "gotoTheMat")

--AUCTION KINGS
function FamilyContact.auctionKings()
    local _MethodName = "Auction Kings"
    if onClient() then
        self.Log(_MethodName, "Invoking on Server")
        invokeServerFunction("auctionKings")
    end

    self.Log(_MethodName, "Adding mission script to player.")
    self.contactPlayer:addScript("data/scripts/player/missions/family/side/bauside4.lua")
    self.warpOut()
end
callable(FamilyContact, "auctionKings")

--DELIVER MATERIALS
function FamilyContact.deliverMaterials()
    local _MethodName = "Deliver Materials"
    if onClient() then
        self.Log(_MethodName, "Invoking on Server")
        invokeServerFunction("deliverMaterials")
    end

    self.Log(_MethodName, "Adding mission script to player.")
    self.contactPlayer:addScript("data/scripts/player/missions/family/side/bauside5.lua")
    self.warpOut()
end
callable(FamilyContact, "deliverMaterials")

--endregion