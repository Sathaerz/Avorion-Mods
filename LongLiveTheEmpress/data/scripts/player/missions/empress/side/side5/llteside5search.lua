package.path = package.path .. ";data/scripts/lib/?.lua"

include("stringutility")
include("callable")

--Add debug info last.
local WRELog = include("esccdebuglogging")
WRELog.Debugging = 0
WRELog.ModName = "LLTE Side Mission 5 - Search Wreckage"

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex)

    local player = Player(playerIndex)
    local _Entity = Entity()

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(_Entity)

    if dist < 200 then
        return true
    end

    return false, "You're not close enough to search the object."%_t
end

function initUI()
    ScriptUI():registerInteraction("Search"%_t, "onSearch")
end

function onSearch(entityIndex)
    local ui = ScriptUI(entityIndex)
    if not ui then return end

    local _HasCodes = Entity():getValue("_llte_optionalwreck_hascode")

    if _HasCodes then
        ui:showDialog(foundSomethingDialog())
    else
        ui:showDialog(foundNothingDialog())
    end
end

function foundNothingDialog()
    local d0_NothingFoundHer = {}

    d0_NothingFoundHer.text = "You don't find anything of note."%_t
    d0_NothingFoundHer.answers = {
        {answer = "OK"%_t, onSelect = "finishScript"}
    }

    return d0_NothingFoundHer
end

function foundSomethingDialog()
    -- make dialog
    local d0_YouFoundSomeInf = {}

    d0_YouFoundSomeInf.text = "In the ruins of the ship, you find a black box. It seems to contain some sort of communication codes."%_t
    d0_YouFoundSomeInf.answers = {
        {answer = "OK"%_t, onSelect = "onFoundEnd"}
    }

    return d0_YouFoundSomeInf
end

function finishScript()
    terminate()
    return
end

function onFoundEnd()
    Player():invokeFunction("player/missions/empress/side/lltesidemission5.lua", "foundCodes")

    terminate()
    return
end