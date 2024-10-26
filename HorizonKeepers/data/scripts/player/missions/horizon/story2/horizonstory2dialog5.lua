package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

HorizonUtil = include("horizonutil")

--namespace HorizonStory2Dialog5
HorizonStory2Dialog5 = {}
local self = HorizonStory2Dialog5

self._Debug = 0

--region #INIT

--Holy fuck am I finally done with these??? Really wish there was some better documentation on addDialogInteraction.
--Or that it allowed for setting of priority.
function HorizonStory2Dialog5.initialize()
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HorizonStory2Dialog5.interactionPossible(playerIndex)
    local _MethodName = "Interaction Possible"
    self.Log(_MethodName, "Determining interactability with " .. tostring(playerIndex))
    local _Player = Player(playerIndex)
    local _Entity = Entity()

    local craft = _Player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(_Entity)

    local targetplayerid = _Entity:getValue("horizon_story_player")

    if dist < 1000 and playerIndex == targetplayerid then
        return true
    end

    return false
end

function HorizonStory2Dialog5.initUI()
    ScriptUI():registerInteraction("Contact Mace", "onContact", 99)
end

function HorizonStory2Dialog5.onContact(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end

    _UI:showDialog(self.getDialog())
end

function HorizonStory2Dialog5.getDialog()
    local _MethodName = "Get Dialogue"
    self.Log(_MethodName, "Beginning...")

    local _PlayerHasChip = false
    local items = Player():getInventory():getItemsByType(InventoryItemType.VanillaItem)
    for _, slot in pairs(items) do
        local item = slot.item

        --Not stackable but the player should only have one.
        if item:getValue("subtype") == "HorizonStoryDataChip" then
            _PlayerHasChip = true
            break
        end
    end

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4_chip = {}
    local d4_nochip = {}

    d0.text = "... Yes?"
    d0.answers = {
        { answer = "Those pirates tried to kill me.", followUp = d1 }
    }

    d1.text = "THEY WHAT????"
    d1.followUp = d2

    d2.text = "Oh no. Oh god. I had a feeling they were going to do that. I. Holy shit. There's no way I could have stood up to them in my tiny ship. I'm sorry for getting you into this, but you saved my life. Thank you."
    d2.followUp = d3

    d3.text = "I owe you. Okay. Where's that chip?"
    if _PlayerHasChip then
        d3.answers = {
            { answer = "Here it is.", followUp = d4_chip, onSelect = "removeChip" }
        }
    else
        d3.answers = {
            { answer = "... I lost it.", followUp = d4_nochip }
        }
    end

    d4_chip.text = "Great. I'll have it broken in no time. Just make sure to store this information somewhere safe. Once I'm done, I'm deleting every trace of this from my systems!"
    d4_chip.onEnd = "onEnd"

    d4_nochip.text = "Really. All of that and you lost the chip? Good thing I found another one while cleaning out some pirates the other day."
    d4_nochip.talker = "Varlance"
    d4_nochip.textColor = HorizonUtil.getDialogVarlanceTextColor()
    d4_nochip.talkerColor = HorizonUtil.getDialogVarlanceTalkerColor()
    d4_nochip.followUp = d4_chip

    for _, _d in pairs({ d0, d1, d2, d3, d4_chip }) do
        _d.talker = "Mace"
        _d.textColor = HorizonUtil.getDialogMaceTextColor()
        _d.talkerColor = HorizonUtil.getDialogMaceTalkerColor()
    end

    return d0
end

function HorizonStory2Dialog5.onEnd()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    Player():invokeFunction("player/missions/horizon/horizonstory2.lua", "contactedHacker4")
end

--endregion

--region #SERVER CALLS

--Starts as a client call and apparently it works??? You can actually remove something from a player's inventory clientside. Shit is wack as hell.
--It comes back when the server is reloaded and the player's inventory is refreshed, though, so it does nothing.
--I can't believe that it doesn't error out in the first place, lmaoooooo.
function HorizonStory2Dialog5.removeChip()
    local methodName = "Remove Chip"

    if onClient() then
        self.Log(methodName, "Calling on client => invoking on server.")
        --have to invoke this on server.
        invokeServerFunction("removeChip")
        return
    end

    self.Log(methodName, "Invoked on server.")

    local _Player = Player(callingPlayer)
    local _Inventory = _Player:getInventory()
    local items = _Inventory:getItemsByType(InventoryItemType.VanillaItem)
    for idx, slot in pairs(items) do
        local item = slot.item

        --Not stackable but the player should only have one.
        if item:getValue("subtype") == "HorizonStoryDataChip" then
            self.Log(methodName, "Found chip - removing it.")
            _Inventory:removeAll(idx)
            break
        end
    end
end
callable(HorizonStory2Dialog5, "removeChip")

--endregion

--region #SECURE / RESTORE / LOG

function HorizonStory2Dialog5.secure()
    return self._Data
end

function HorizonStory2Dialog5.restore(_Values)
    self._Data = _Values
end

function HorizonStory2Dialog5.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 2 Dialog 5] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion