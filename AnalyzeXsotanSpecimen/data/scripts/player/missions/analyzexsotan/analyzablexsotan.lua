package.path = package.path .. ";data/scripts/lib/?.lua"

include("defaultscripts")
include("stringutility")
include("callable")

local _Debug = 0

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex)
    local player = Player(playerIndex)

    local craft = player.craft
    if craft == nil then return false end

    local dist = craft:getNearestDistance(Entity())
    local targetDist = 300 * getDistanceBonus(craft)

    if dist < targetDist then
        return true
    end

    return false, "You're not close enough to analyze this Xsotan."
end

function initUI()
    ScriptUI():registerInteraction("Begin Analysis", "onAnalyze")
end

function onAnalyze()
    ScriptUI():showDialog(makeDialog())
end

function makeDialog()
    local d0 = {}

    local craft = Player().craft
    local targetDist = 10

    if craft then
        targetDist = targetDist * getDistanceBonus(craft)
    end
    targetDist = math.floor(targetDist)

    local myAI = ShipAI()
    if myAI:isEnemyPresent(true) then
        if Entity():getValue("analyzexsotan_analysis_in_progress") then
            d0.text = "You're already analyzing this Xsotan. Remain within ${_DISTANCE} km to gather telemetry. Additionally, you must be in a ship." % { _DISTANCE = targetDist }
        else
            d0.text = "Starting Analysis - stay within ${_DISTANCE} km of the Xsotan while the analysis completes. Additionally, you must be in a ship." % { _DISTANCE = targetDist }
            d0.answers = { 
                { answer = "OK", onSelect = "xsostartanalysis" }
            }
        end

    else
        d0.text = "Only active Xsotan can be analyzed! Fire your weapons to alert it."
    end

    return d0
end

function xsostartanalysis()
    if onClient() then
        if _Debug == 1 then
            print("Called on Client => Invoking on server")
        end

        invokeServerFunction("xsostartanalysis")
        return
    end

    if _Debug == 1 then
        print("Called on Server => Sending callback")
    end

    Player(callingPlayer):sendCallback("onMissionXsotanAnalysisStart", Entity().id.string)
    --Do not terminate this - we might need to re-call it.
end
callable(nil, "xsostartanalysis")

function getDistanceBonus(craft)
    local scannerBonus = 1

    --if the player has more than one scanner system, idk what happens. why would you have more than one scanner booster
    if craft:hasScript("scannerbooster.lua") or craft:hasScript("superscoutsystem.lua") then
        local scannerRarity = 0
        
        if craft:hasScript("scannerbooster.lua") then
            local ok, ret = craft:invokeFunction("scannerbooster.lua", "getRarity")
            if ok == 0 then
                scannerRarity = ret.value --Get the rarity tier value rather than the name.
            end
            scannerBonus = scannerBonus + ((5 + scannerRarity) * 0.1) --should give a 40% bonus @ petty, up to a 100% bonus @ legendary
        else
            local ok, ret = craft:invokeFunction("superscoutsystem.lua", "getRarity")
            if ok == 0 then
                scannerRarity = ret.value --Get the rarity tier value rather than the name.
            end
            scannerBonus = scannerBonus + (((5 + scannerRarity) * 0.1) * 0.8) --ITR upgrades are generally worth ~80% a normal upgrade.
        end

        if _Debug == 1 then
            print("Craft has scanner booster - rarity is: " .. tostring(scannerRarity) .. " final bonus is: " .. tostring(scannerBonus))
        end
    end

    return scannerBonus
end