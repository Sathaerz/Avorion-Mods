package.path = package.path .. ";data/scripts/lib/?.lua"

Dialog = include ("dialogutility")
include ("stringutility")
include ("callable")

local interacted
local flyAway
local startedFight
local paymentSuccessful

function getUpdateInterval()
    return 0.5
end

function initialize()
    local sector = Sector()
    sector:registerCallback("onStartFiring", "onSetToAggressive")
    Entity():registerCallback("onCollision", "onSetToAggressive")
end

function onSetToAggressive()
    if onServer() then
        broadcastInvokeClientFunction("startFight")

        local players = {Sector():getPlayers()}
        for _, player in pairs(players) do
            local allianceIndex = player.allianceIndex
            for _, pirate in pairs(getPirates()) do
                local ai = ShipAI(pirate.index)
                ai:registerEnemyFaction(player.index)
                if allianceIndex then
                    ai:registerEnemyFaction(allianceIndex)
                end
            end
        end
    end
end

function startFight()
    if onClient() and not startedFight then
        ScriptUI():stopInteraction()
        displayChatMessage(string.format("%s is attacking!"%_t, Entity().translatedTitle), "", 2)
        invokeServerFunction("startFight")
        registerBoss(Entity().index, nil, nil, "data/music/special/bladesedge.ogg")
        startedFight = true
        return
    end

    local player = Player(callingPlayer)
    local allianceIndex = player.allianceIndex
    for _, pirate in pairs(getPirates()) do
        local ai = ShipAI(pirate.index)
        ai:registerEnemyFaction(callingPlayer)
        if allianceIndex then
            ai:registerEnemyFaction(allianceIndex)
        end
    end
end
callable(nil, "startFight")

function normalDialog()
    local entity = Entity()

    local d0 = {} 
    local d1 = {} 
    local d2 = {} 
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}

    local _Talker = "Boss Swenks"

    --d0
    d0.text = "So you're the one who's been causing me so many problems."
    d0.talker = _Talker
    d0.answers = {
        { answer = "Who are you?", followUp = d1 }
    }

    d1.text = "You haven't heard of me yet? I am Swenks. Lord of the Iron Wastes. You'll get to know me soon enough."
    d1.talker = _Talker
    d1.answers = {
        {answer = "You don't scare me.", followUp = d3 },
        {answer = "What do you want from me?", followUp = d2},
        {answer = "It's time someone put an end to you.", followUp = d4}
    }

    if Entity():getValue("swoks_beaten") then
        table.insert(d1.answers, {answer = "Swenks? Is that like an off-brand Swoks?", followUp = d5 })
    end
    table.insert(d1.answers, {answer = "I'll be leaving now.", followUp = d6 })

    d2.text = "You have two choices. You can die quietly, or you can die screaming. Up to you."
    d2.talker = _Talker
    d2.answers = {
        {answer = "Or maybe you'll die first.", followUp = d4},
        {answer = "Wait. Can't I pay you?", followUp = d7}
    }

    d3.text = "You're certainly a brave one! Perhaps I'll kill you quickly."
    d3.talker = _Talker
    d3.followUp = d2

    d4.text = "Heh. Look at you! Do you really think you have a chance?"
    d4.talker = _Talker
    d4.onEnd = "startFight"

    d5.text = "I'm nothing like Swoks!! How dare you?!"
    d5.talker = _Talker
    d5.onEnd = "startFight"

    d6.text = "Not so fast."
    d6.talker = _Talker
    d6.followUp = d2

    d7.text = "We used to take payments, but too many people whined about clicking through the dialogue without paying attention and paying by accident. Really, it's much easier to kill do-gooders like you."
    d7.talker = _Talker
    d7.followUp = d8

    d8.text = "So, time to die."
    d8.talker = _Talker
    d8.onEnd = "startFight"

    return d0
end

function updateClient()
    if not interacted and not startedFight then

        ScriptUI():interactShowDialog(normalDialog(), false)

        interacted = true
    end
end

function getPirates()
    local self = Entity()
    local pirates = {}

    for _, other in pairs({Sector():getEntitiesByComponent(ComponentType.ShipAI)}) do
        if other.factionIndex == self.factionIndex then
            table.insert(pirates, other)
        end
    end

    return pirates
end
