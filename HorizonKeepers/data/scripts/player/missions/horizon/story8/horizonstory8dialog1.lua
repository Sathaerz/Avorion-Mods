package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

HorizonUtil = include("horizonutil")
ESCCUtil = include("esccutil")

--namespace HorizonStory8Dialog1
HorizonStory8Dialog1 = {}
local self = HorizonStory8Dialog1

self._Debug = 0

local ingredients = {
    { name = "Energy Cell", amount = 5 },
    { name = "Computation Mainframe", amount = 1 },
    { name = "Coolant", amount = 1 },
    { name = "Satellite", amount = 1 },
    { name = "Food Bar", amount = 3 }
}

--region #INIT

function HorizonStory8Dialog1.initialize()
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Running...")
end

--endregion

--region #CLIENT CALLS

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function HorizonStory8Dialog1.interactionPossible(playerIndex)
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

function HorizonStory8Dialog1.initUI()
    ScriptUI():registerInteraction("Deliver Items", "onDeliver", 99)
end

function HorizonStory8Dialog1.onDeliver(_EntityIndex)
    local _UI = ScriptUI(_EntityIndex)
    if not _UI then return end
    if not callingPlayer then
        print("ERROR: Could not find callingPlayer")
        return 
    end

    local d0 = {}

    local _player = Player(callingPlayer)
    local craft = _player.craft
    if craft then
        local needs = self.findMissingGoods(craft)

        if #needs > 0 then
            local missing = enumerate(needs, function(g) return g.amount .. " " .. g.name end)
    
            d0.text = string.format("Ah, I don't think that will work. We still need %s.", missing)
        else
            d0.text = "... Great! That's everything I needed. I'll have it running in no time!"
            d0.onEnd = "onEnd"
        end
    else
        d0.text = "Ah, I don't think that will work. Come back with a ship and I'll take a look through the hold."
    end

    ESCCUtil.setTalkerTextColors({ d0 }, "Sophie", HorizonUtil.getDialogSophieTalkerColor(), HorizonUtil.getDialogSophieTextColor())

    _UI:showDialog(d0)
end

function HorizonStory8Dialog1.findMissingGoods(ship)
    local needs = {}
    for _, g in pairs(ingredients) do
        local has = ship:getCargoAmount(g.name)

        if has < g.amount then
            local good = goods[g.name]
            good = good:good()
            table.insert(needs, {name = good:displayName(g.amount - has), amount = g.amount - has})
        end
    end

    return needs
end

function HorizonStory8Dialog1.onEnd()
    local _MethodName = "On End"
    self.Log(_MethodName, "Beginning.")

    --remove the goods from the player, then invoke func to go on to next phase.
    self.onRemoveGoods()

    Player():invokeFunction("player/missions/horizon/horizonstory8.lua", "kothStory8_onDeliveredIngredients")
end

function HorizonStory8Dialog1.onRemoveGoods()
    if onClient() then
        invokeServerFunction("onRemoveGoods")
        return
    end

    local _player = Player(callingPlayer)
    local craft = _player.craft

    for _, g in pairs(ingredients) do
        -- remove goods
        craft:removeCargo(g.name, g.amount)
    end
end
callable(HorizonStory8Dialog1, "onRemoveGoods")

--endregion

--region #CLIENT / SERVER CALLS

function HorizonStory8Dialog1.Log(_MethodName, _Msg)
    if self._Debug and self._Debug == 1 then
        print("[Horizon Story 8 Dialog 1] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion