
package.path = package.path .. ";data/scripts/lib/?.lua"

ShipGenerator = include ("shipgenerator")
LLTEUtil = include("llteutil")
MissionUT = include("missionutility")

include ("randomext")
include ("stringutility")
local SectorSpecifics = include("sectorspecifics")

local _Debug = 0

if onServer() then

function initialize()
    local faction = Galaxy():findFaction("The Family")

    --The Family can't be eradicated, so there's no need to check for that.
    --Get local players. There must be one of at least rank 2 here for the merchant to spawn.
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()
    local _Players = {_Sector:getPlayers()}
    local _Terminate = true
    local _PaladinPresent = false
    for _, _P in pairs(_Players) do
        local _RankLevel = _P:getValue("_bau_family_ranklevel")
        if _RankLevel and _RankLevel >= 2 then
            _Terminate = false
        end
        if _RankLevel == 5 then
            _PaladinPresent = true
        end
    end

    --Then if this is inside the barrier and the family for any players haven't reached the barrier yet, we terminate this.
    --We can't do this in the previous loop because it's possible that it would get set to false again.
    if MissionUT.checkSectorInsideBarrier(_X, _Y) then
        for _, _P in pairs(_Players) do
            if not _P:getValue("_bau_family_inbarrier") then
                if _Debug == 1 then
                    print("Player " .. tostring(_P.name) .. " has not gotten the family past the barrier. Terminating.")
                end
                _Terminate = true
            end
        end
    end

    if _Debug == 1 then
        print("_Terminate value is " .. tostring(_Terminate))
    end

    if _Terminate then
        terminate()
        return
    end

    -- create the merchant
    local pos = random():getDirection() * 1500
    local matrix = MatrixLookUpPosition(normalize(-pos), vec3(0, 1, 0), pos)
    local ship = ShipGenerator.createFreighterShip(faction, matrix)

    ship:invokeFunction("icon.lua", "set", nil)
    ship:removeScript("icon.lua")

    if _PaladinPresent then
        ship:setValue("_llte_UnderbossInventory", true)
    end

    ship.title = "Mobile Family Merchant"
    --ship:addScript("data/scripts/entity/merchants/cavaliersutilitymerchant.lua")
    --ship:addScript("data/scripts/entity/merchants/cavaliersturretmerchant.lua")
    --ship:addScript("data/scripts/entity/merchants/travellingmerchant.lua")
    --ship:addScript("ai/withdrawatlowhealth.lua", 0.1, 1, 1, 0.02)

    Sector():broadcastChatMessage(ship, 0, "%1% %2% here. I'll be offering my services to anyone from The Family for the next 15 minutes!"%_T, ship.title, ship.name)

    terminate()
end

end
