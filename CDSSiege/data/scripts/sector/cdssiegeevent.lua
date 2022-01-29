include ("galaxy")
include ("randomext")
include ("stringutility")
include ("player")
include ("relations")

ESCCUtil = include("esccutil")

local Placer = include ("placer")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local SpawnUtility = include ("spawnutility")
local EventUT = include ("eventutility")

--namespace SiegeAttack
SiegeAttack = {}

if onServer() then

function SiegeAttack.initialize()
    local _Sector = Sector()
    local _X, _Y = _Sector:getCoordinates()

    local _Generator = AsyncPirateGenerator(SiegeAttack, SiegeAttack.onPiratesGenerated)

    local _Faction = _Generator:getPirateFaction()
    local _Controller = Galaxy():getControllingFaction(_X, _Y)

    if _Controller and _Controller.index == _Faction.index then
        terminate()
        return
    end

    local _BomberCount = getInt(3,5)
    local _BomberPositions = _Generator:getStandardPositions(_BomberCount, 200)

    _Generator:startBatch()

    for _, _Position in pairs(_BomberPositions) do
        _Generator:createScaledBomber(_Position)
    end

    _Generator:endBatch()

    _Sector:broadcastChatMessage("Server"%_t, 2, "Pirates are laying siege to the sector!")
    AlertAbsentPlayers(2, "Pirates are laying siege to sector \\s(%1%:%2%)!", _Sector:getCoordinates())
end

function SiegeAttack.onPiratesGenerated(_Generated)

    SpawnUtility.addEnemyBuffs(_Generated)
    Placer.resolveIntersections(_Generated)

    --Kill script after this runs.
    terminate()
    return
end

end