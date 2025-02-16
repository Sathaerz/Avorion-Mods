package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")
The4 = include("story/the4")

function interactionPossible(player)
--    if not interacted then return 1 end
    return true
end

function getUpdateInterval()
    return 0.5
end

function initialize()

end

function initUI()
    ScriptUI():registerInteraction("[Hail]", "startInteraction")
end

function startAttacking()
    local ships = {Sector():getEntitiesByFaction(Entity().factionIndex)}

    if onClient() then
        for _, ship in pairs(ships) do
            if ship:hasComponent(ComponentType.Plan) then
                Music():fadeOut(1.5)
                registerBoss(ship.index, nil, nil, "data/music/special/despair.ogg", "The Brotherhood")
                if ship.title:match("Tankem") then setBossHealthColor(ship.index, ColorRGB(1.0, 0.5, 0.3)) end
                if ship.title:match("Reconstructo") then setBossHealthColor(ship.index, ColorRGB(0.2, 0.7, 0.2)) end
            end
        end
        invokeServerFunction("startAttacking")
        return
    end

    local players = {Sector():getPlayers()}

    for _, player in pairs(players) do
        for _, ship in pairs(ships) do
            if ship:hasComponent(ComponentType.ShipAI) then
                local ai = ShipAI(ship.index)
                ai:setAggressive()
                ai:registerEnemyFaction(player.index)
                if player.allianceIndex then
                    ai:registerEnemyFaction(player.allianceIndex)
                end
            end
        end
    end

end
callable(nil, "startAttacking")

function startInteraction()
    local dialog = {}
    local noChoice = {}

    local _Threats = {
        "Well, we said we'd be back for the artifact.",
        "We'll tear the artifact from your smoking wreckage.",
        "Time to claim what's rightfully ours.",
        "You got lucky last time, but luck won't save you again.",
        "Thanks for holding on to the artifact for us. We'll be taking it now."
    }
    
    dialog.text = "Ah, it's you. " .. randomEntry(_Threats)
    dialog.followUp = noChoice

    local _Quips = {
        "Perish.",
        "I suspect you know what that means.",
        "Let's get on with it.",
        "Go down, you wretch.",
        "Don't think you've bested us yet."
    }

    noChoice.text = randomEntry(_Quips)
    noChoice.onEnd = "startAttacking"

    ScriptUI():showDialog(dialog, false)
end

function updateClient()
    if not interacted and Entity().title == "Tankem" then
        Player():startInteracting(Entity(), "story/the4revenge.lua", 0)
        interacted = true
    end
end

function updateServer()
    if Sector().numPlayers == 0 then
        Sector():deleteEntity(Entity())
    end
end





