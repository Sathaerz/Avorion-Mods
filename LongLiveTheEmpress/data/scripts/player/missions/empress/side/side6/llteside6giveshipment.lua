package.path = package.path .. ";data/scripts/lib/?.lua"

Dialog = include ("dialogutility")
include ("stringutility")
include ("callable")

function initUI()
    ScriptUI():registerInteraction("I have the shipment.", "startInteraction")
end

function interactionPossible(_PlayerIndex, _Option)
    local _Player = Player(_PlayerIndex)
    local craft = _Player.craft
    if craft == nil then return false end

    return true
end

function startInteraction()
    local d0 = {}
    local d1 = {}

    d0.text = "Excellent! Transferring shipment now."
    d0.onEnd = "handOverShipment"

    d1.text = "Our scanners can't find the shipment on your ship. Come back with the shipment and we'll take it."

    if not hasGoods() then
        d0.followUp = d1
    else
        d0.followUp = Dialog.empty()
    end

    ScriptUI():showDialog(d0, false)
end

function hasGoods()
    local _Ship
    if onClient() then
        _Ship = Player().craft
    else
        local _Player = Player(callingPlayer)
        _Ship = Entity(_Player.craftIndex)
    end

    for good, amount in pairs(_Ship:findCargos("Avorion Shipment")) do
        if amount > 0 then
            return true
        end
    end

    return false
end

function handOverShipment()
    if onClient() then
        if hasGoods() then
            invokeServerFunction("handOverShipment")
        end
    else
        local _Player = Player(callingPlayer)

        if hasGoods() then
            local _Ship = Entity(_Player.craftIndex)

            for good, amount in pairs(_Ship:findCargos("Avorion Shipment")) do
                if amount > 0 then
                    _Ship:removeCargo(good, 1)
                    break
                end
            end

            invokeClientFunction(_Player, "transactionDone")
        else
            invokeClientFunction(_Player, "noShipment")
        end
    end
end
callable(nil, "handOverShipment")

function noShipment()
    local d0 = {}

    d0.text = "Our scanners can't find the shipment on your ship. Come back with the shipment and we'll take it."

    ScriptUI():showDialog(d0, false)
end

function transactionDone()
    local d0 = {}

    d0.text = "Looks like everything is in order. Thank you very much! We'll be on our way."
    d0.onEnd = "onEnd"

    ScriptUI():showDialog(d0, false)
end

function onEnd()
    Player():invokeFunction("player/missions/empress/side/lltesidemission6.lua", "finishMission")
end