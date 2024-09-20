package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--See pirategenerator.lua for a better description of exactly what these ships do.
--fairly standard table of spawns by danger level. Scorchers (very dangerous shield-killing ships) don't start showing up until danger level 6.
--Devastators (the ultimate bullet sponge) don't show up until danger level 10.
local dangerLevel_StandardSpawnTables = {
    {Level = 1, Table = {"Outlaw", "Outlaw", "Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate"}},
    {Level = 2, Table = {"Outlaw", "Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Pirate", "Pirate", "Marauder", "Marauder"}},
    {Level = 3, Table = {"Outlaw", "Outlaw", "Bandit", "Bandit", "Pirate", "Pirate", "Marauder", "Marauder", "Raider", "Raider"}},
    {Level = 4, Table = {"Bandit", "Bandit", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider"}},
    {Level = 5, Table = {"Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider", "Ravager", "Ravager"}},
    {Level = 6, Table = {"Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider", "Ravager", "Ravager", "Scorcher", "Scorcher"}},
    {Level = 7, Table = {"Disruptor", "Disruptor", "Raider", "Raider", "Ravager", "Ravager", "Scorcher", "Scorcher", "Prowler", "Prowler"}},
    {Level = 8, Table = {"Disruptor", "Disruptor", "Raider", "Ravager", "Scorcher", "Scorcher", "Prowler", "Prowler", "Pillager", "Pillager"}},
    {Level = 9, Table = {"Disruptor", "Disruptor", "Scorcher", "Scorcher", "Scorcher", "Prowler", "Prowler", "Prowler", "Pillager", "Pillager"}},
    {Level = 10, Table = {"Disruptor", "Scorcher", "Scorcher", "Scorcher", "Prowler", "Prowler", "Pillager", "Pillager", "Pillager", "Devastator"}}
}
--low threat standard table of spawns by danger level. Custom ships (which are much more dangerous than the standard pirates) aren't even represented until
--threat level 10, where we have a mere 10% chance to spawn a prowler (not that threatening compared to a scorcher, pillager or devastator)
local dangerLevel_LowThreatSpawnTables = {
    {Level = 1, Table = {"Outlaw", "Outlaw", "Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate"}},
    {Level = 2, Table = {"Outlaw", "Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Pirate"}},
    {Level = 3, Table = {"Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Pirate", "Marauder"}},
    {Level = 4, Table = {"Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Pirate", "Marauder", "Marauder"}},
    {Level = 5, Table = {"Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder"}},
    {Level = 6, Table = {"Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider"}},
    {Level = 7, Table = {"Bandit", "Bandit", "Pirate", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider"}},
    {Level = 8, Table = {"Bandit", "Pirate", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider"}},
    {Level = 9, Table = {"Pirate", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider", "Ravager"}},
    {Level = 10, Table = {"Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider", "Ravager", "Prowler"}}
}
--high threat standard table of spawns by danger level. Custom ships show up early and the table caps off with a 50/50 scorcher / devastator split.
local dangerLevel_HighThreatSpawnTables = {
    {Level = 1, Table = {"Outlaw", "Outlaw", "Outlaw", "Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate"}},
    {Level = 2, Table = {"Outlaw", "Outlaw", "Bandit", "Bandit", "Bandit", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder"}},
    {Level = 3, Table = {"Bandit", "Bandit", "Pirate", "Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider"}},
    {Level = 4, Table = {"Pirate", "Marauder", "Marauder", "Marauder", "Raider", "Raider", "Raider", "Ravager", "Ravager", "Ravager"}},
    {Level = 5, Table = {"Marauder", "Raider", "Raider", "Raider", "Ravager", "Ravager", "Ravager", "Scorcher", "Scorcher", "Scorcher"}},
    {Level = 6, Table = {"Raider", "Ravager", "Ravager", "Ravager", "Scorcher", "Scorcher", "Scorcher", "Prowler", "Prowler", "Prowler"}},
    {Level = 7, Table = {"Ravager", "Scorcher", "Scorcher", "Scorcher", "Prowler", "Prowler", "Prowler", "Pillager", "Pillager", "Pillager"}},
    {Level = 8, Table = {"Scorcher", "Scorcher", "Scorcher", "Prowler", "Pillager", "Pillager", "Pillager", "Devastator", "Devastator", "Devastator"}},
    {Level = 9, Table = {"Scorcher", "Scorcher", "Scorcher", "Scorcher", "Pillager", "Pillager", "Devastator", "Devastator", "Devastator", "Devastator"}},
    --50/50 split, so no need for more than this.
    {Level = 10, Table = {"Scorcher", "Devastator"}}
}
--standard table for a faction.
local dangerLevel_factionStandardSpawnTable = {
    {Level = 1, Table = {"L", "L", "L", "L", "L", "L", "L", "L", "L", "L"}},
    {Level = 2, Table = {"L", "L", "L", "L", "L", "L", "L", "L", "M", "M"}},
    {Level = 3, Table = {"L", "L", "L", "L", "L", "L", "M", "M", "M", "M"}},
    {Level = 4, Table = {"L", "L", "L", "L", "M", "M", "M", "M", "M", "M"}},
    {Level = 5, Table = {"L", "L", "M", "M", "M", "M", "M", "M", "M", "M"}},
    {Level = 6, Table = {"M", "M", "M", "M", "M", "M", "M", "M", "M", "M"}},
    {Level = 7, Table = {"M", "M", "M", "M", "M", "M", "M", "M", "H", "H"}},
    {Level = 8, Table = {"M", "M", "M", "M", "M", "M", "H", "H", "H", "H"}},
    {Level = 9, Table = {"M", "M", "M", "M", "H", "H", "H", "H", "H", "H"}},
    {Level = 10, Table = {"M", "M", "H", "H", "H", "H", "H", "H", "H", "H"}}
}

local ESCCUtil = {}
local self = ESCCUtil

self.RandomCalled = 0

self._Debug = 0

--If you want to just get the table to do something with it - such as adding a jammer
function ESCCUtil.getStandardTable(dangerLevel, threatLevel, _Faction)
    local _MethodName = "Get Standardized Spawn Table"
    --Get standard if not specified.
    threatLevel = threatLevel or "Standard"
    _Faction = _Faction or false --Most usages of this will be for pirates.

    ESCCUtil.Log(_MethodName, "Grabbing " .. tostring(threatLevel) .. " table for danger level " .. tostring(dangerLevel))
    --Set which spawn table set we're looking through
    local tbl = {}
    if _Faction then
        ESCCUtil.Log(_MethodName, "Getting faction table.")
        tbl = dangerLevel_factionStandardSpawnTable
    else
        ESCCUtil.Log(_MethodName, "Getting non-faction table.")
        if threatLevel == "Low" then
            tbl = dangerLevel_LowThreatSpawnTables
        elseif threatLevel == "High" then
            tbl = dangerLevel_HighThreatSpawnTables
        elseif threatLevel == "Standard" then
            tbl = dangerLevel_StandardSpawnTables
        end
    end

    if not tbl then
        ESCCUtil.Log(_MethodName, "Could not set tbl - function will likely error on return.", 1)
    end

    for _, lt in pairs(tbl) do
        if lt.Level == dangerLevel then
            ESCCUtil.Log(_MethodName, "Found requested table. Returning value.")
            return lt.Table
        end
    end
end

function ESCCUtil.getStandardWave(_DangerLevel, _WaveShips, _ThreatLevel, _Faction)
    local _MethodName = "Get Standard Pirate Wave"
    _ThreatLevel = _ThreatLevel or "Standard"
    _Faction = _Faction or false --This will be used for pirates most of the time.

    ESCCUtil.Log(_MethodName, "Getting wave table for " .. tostring(_WaveShips) .. " at danger level " .. tostring(_DangerLevel) .. " at threat level " .. tostring(_ThreatLevel) .. " _Faction is " .. tostring(_Faction))

    local _SpawnTable = self.getStandardTable(_DangerLevel, _ThreatLevel, _Faction)
    local _EnemyTable = {}
    local _Rgen = self.getRand()

    for _ = 1, _WaveShips do
        table.insert(_EnemyTable, _SpawnTable[_Rgen:getInt(1, #_SpawnTable)])
    end

    return _EnemyTable
end

function ESCCUtil.countEntitiesByValue(_Value)
    --We know this works, and the spam messages can be quite annoying. There's no need to add debugging to this.
    local _Entities = {Sector():getEntitiesByScriptValue(_Value)}
    if _Entities then
        return #_Entities
    else
        return 0
    end
end

function ESCCUtil.getStandardTemplateBlacklist()
    local _MethodName = "Get Standard Template Blacklist"
    ESCCUtil.Log(_MethodName, "Beginning...")

    local templateBlacklist = {
        "sectors/asteroidshieldboss",
        "sectors/ancientgates",
        "sectors/containerfield",
        "sectors/cultists",
        "sectors/pirateasteroidfield",
        "sectors/piratefight",
        "sectors/piratestation",
        "sectors/resistancecell",
        "sectors/researchsatellite",
        "sectors/smugglerhideout",
        "sectors/wreckagefield",
        "sectors/xsotanasteroids",
        "sectors/xsotanbreeders",
        "sectors/xsotantransformed"
    }

    return templateBlacklist
end

function ESCCUtil.getRand()
    local _MethodName = "Get Random Number Generator"
    ESCCUtil.Log(_MethodName, "Beginning...")

    self.RandomCalled = self.RandomCalled + random():getInt(1, 720)
    return Random(Seed(os.time() + self.RandomCalled))
end

function ESCCUtil.clampToNearest(_Value, _Clamp, _Round)
    _Round = _Round or "Down"
    local _ClampCoefficient = math.floor(_Value / _Clamp)
    if _Round == "Up" then
        _ClampCoefficient = math.ceil(_Value / _Clamp)
    end
    return _ClampCoefficient * _Clamp
end

function ESCCUtil.getIndex(_Table, _Element)
    local _MethodName = "Get Index of Table"
    if not _Table or not _Element then
        ESCCUtil.Log(_MethodName, "Cannot get random element - either the table or the element was not provided", 1)
        return
    end
    for _IDX, _VAL in pairs(_Table) do
        if _VAL == _Element then
            return _IDX
        end
    end
    --Standard C# practice.
    return -1 
end

function ESCCUtil.getSaneColor(_R, _G, _B)
    --For some reason OpenGL does colors by floats which is just wack.
    local _Rfactor = _R / 255
    local _Gfactor = _G / 255
    local _Bfactor = _B / 255

    return ColorRGB(_Rfactor, _Gfactor, _Bfactor)
end

function ESCCUtil.getDistanceToCenter(_X, _Y)
    local _MethodName = "Get Distance to Center"

    local _Dist = math.sqrt((_X * _X) + (_Y * _Y))

    ESCCUtil.Log(_MethodName, "Distance to center is: " .. _Dist)

    return _Dist
end

function ESCCUtil.getPosOnRing(x_in, y_in, dist)
    --local slope = y_in/x_in
    --local x = dist/math.sqrt(slope^2 + 1)
    --if x_in < 0 then x = -x end
    --local y = slope*x
    --return x, y

    local _Dist1 = math.sqrt((x_in * x_in) + (y_in * y_in))
    local _Pos = vec2(x_in, y_in) * (dist/_Dist1)

    return math.floor(_Pos.x), math.floor(_Pos.y)
end

function ESCCUtil.playerBeatStory(_Player)
    if _Player:getValue("story_completed") or _Player:getValue("wormhole_guardian_destroyed") then
        return true
    else
        return false
    end
end

function ESCCUtil.allPiratesDepart()
    local _Pirates = {Sector():getEntitiesByScriptValue("is_pirate")}
    local _Rgen = ESCCUtil.getRand()
    for _, _P in pairs(_Pirates) do
        _P:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(3, 6))
    end
end

function ESCCUtil.allXsotanDepart()
    local _Ships = {Sector():getEntitiesByScriptValue("is_xsotan")}
    local _Rgen = ESCCUtil.getRand()
    for _, _S in pairs(_Ships) do
        _S:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(2, 5))
    end
end

function ESCCUtil.majorEntityTypes()
    return {
        EntityType.Ship,
        EntityType.Station,
        EntityType.Asteroid,
        EntityType.Torpedo,
        EntityType.Fighter
    }
end

function ESCCUtil.allEntityTypes()
    return {
        EntityType.None,
        EntityType.Ship,
        EntityType.Drone,
        EntityType.Station,
        EntityType.Turret,
        EntityType.Asteroid,
        EntityType.Wreckage,
        EntityType.Anomaly,
        EntityType.Loot,
        EntityType.WormHole,
        EntityType.Torpedo,
        EntityType.Fighter,
        EntityType.Container,
        EntityType.Unknown,
        EntityType.Other
    }
end

function ESCCUtil.setBombardier(_Ship)
    local _TitleArgs = _Ship:getTitleArguments()

    local _ToughnessArg = _TitleArgs.toughness or ""
    local _TitleArg = _TitleArgs.title or ""
    local _ScriptNameArg = "Bombardier "

    _Ship:setTitle("${toughness}${scriptname}${title}", {toughness = _ToughnessArg, title = _TitleArg, scriptname = _ScriptNameArg})
    _Ship:removeScript("icon.lua")
    _Ship:addScript("icon.lua", "data/textures/icons/pixel/torpedoboatex.png")
end

function ESCCUtil.setDeadshot(_Ship)
    local _TitleArgs = _Ship:getTitleArguments()

    local _ToughnessArg = _TitleArgs.toughness or ""
    local _TitleArg = _TitleArgs.title or ""
    local _ScriptNameArg = "Deadshot "

    _Ship:setTitle("${toughness}${lasername}${title}", {toughness = _ToughnessArg, title = _TitleArg, lasername = _ScriptNameArg})
    _Ship:removeScript("icon.lua")
    _Ship:addScript("icon.lua", "data/textures/icons/pixel/laserboat.png")
end

--region #LOGGING

function ESCCUtil.Log(_MethodName, _Msg, _OverrideDebug)
    local _LocalDebug = ESCCUtil._Debug or 0
    if _OverrideDebug == 1 then
        _LocalDebug = 1
    end

    if _LocalDebug == 1 then
        print("[ESCC Utility] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion

return ESCCUtil