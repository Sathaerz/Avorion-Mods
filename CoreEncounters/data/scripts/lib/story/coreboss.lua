package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

ESCCBoss = include("esccbossutil")

local PirateGenerator = include ("pirategenerator")

local CoreBoss = {}

function CoreBoss.spawn(_Player, _X, _Y)
    local pirates = {}
    local _PirateSpawns = {}

    local _PirateFaction = PirateGenerator.getPirateFaction()
    local _Random = random()

    --Two heavy ships
    if _Random:test(0.5) then
        if _Random:test(0.25) then
            table.insert(_PirateSpawns, "Devastator")
        else
            table.insert(_PirateSpawns, "Pillager")
        end
    else
        table.insert(_PirateSpawns, "Raider")
    end
    if _Random:test(0.5) then
        if _Random:test(0.25) then
            table.insert(_PirateSpawns, "Devastator")
        else
            table.insert(_PirateSpawns, "Pillager")
        end
    else
        table.insert(_PirateSpawns, "Raider")
    end
    --Two disruptors
    if _Random:test(0.5) then
        if _Random:test(0.25) then
            table.insert(_PirateSpawns, "Scorcher")
        else
            table.insert(_PirateSpawns, "Disruptor")
        end
    else
        table.insert(_PirateSpawns, "Disruptor")
    end
    if _Random:test(0.5) then
        if _Random:test(0.25) then
            table.insert(_PirateSpawns, "Scorcher")
        else
            table.insert(_PirateSpawns, "Disruptor")
        end
    else
        table.insert(_PirateSpawns, "Disruptor")
    end
    --Four light ships.
    if _Random:test(0.5) then
        if _Random:test(0.5) then
            table.insert(_PirateSpawns, "Prowler")
        else
            table.insert(_PirateSpawns, "Marauder")
        end
    else
        table.insert(_PirateSpawns, "Bandit")
    end
    if _Random:test(0.5) then
        if _Random:test(0.5) then
            table.insert(_PirateSpawns, "Prowler")
        else
            table.insert(_PirateSpawns, "Marauder")
        end
    else
        table.insert(_PirateSpawns, "Bandit")
    end
    if _Random:test(0.5) then
        if _Random:test(0.5) then
            table.insert(_PirateSpawns, "Prowler")
        else
            table.insert(_PirateSpawns, "Marauder")
        end
    else
        table.insert(_PirateSpawns, "Bandit")
    end
    if _Random:test(0.5) then
        if _Random:test(0.5) then
            table.insert(_PirateSpawns, "Prowler")
        else
            table.insert(_PirateSpawns, "Marauder")
        end
    else
        table.insert(_PirateSpawns, "Bandit")
    end
    --Four very light ships
    table.insert(_PirateSpawns, "Marauder")
    table.insert(_PirateSpawns, "Marauder")
    table.insert(_PirateSpawns, "Pirate")
    table.insert(_PirateSpawns, "Pirate")

    --Spawn dem pirates
    for _, _Ship in pairs(_PirateSpawns) do
        table.insert(pirates, PirateGenerator.createPirateByName(_Ship, PirateGenerator.getGenericPosition()))
    end

    --Spawn boss
    --We don't need to add a lot of the standard scripts like legendary loot, etc. because the ESCC boss util handles that for us already :D
    local _Rgen = ESCCUtil.getRand()
    local _BossType = _Rgen:getInt(1, 6)
    local _CoreBoss = ESCCBoss.spawnESCCBoss(_PirateFaction, _BossType)

    _CoreBoss:registerCallback("onDestroyed", "onCoreBossDestroyed")

    for _, pirate in pairs(pirates) do
        pirate:addScript("deleteonplayersleft.lua")
    end

    _CoreBoss:addScript("deleteonplayersleft.lua")
end

return CoreBoss