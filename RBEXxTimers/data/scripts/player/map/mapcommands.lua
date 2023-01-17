
--[[
These are the definitions for tracked bosses:
 - The display name,
 - The icon,
 - The data key for the last kill timestamp,
 - And a collection of lines for alerts when they become available.
 - Wait timer - this is mostly 30 * 60 but it is significantly longer for a core encounter boss.
 - Check func - this is mostly just "return true" but Swenks and Core Encounters have special conditions to spawn.
]]
local bcds_Bosses = {}

local _list = {
    { "Swoks"%_t, "anchor", "last_killed_swoks",
    {   
        "Outer rim traders are in a panic over a new pirate boss in uncharted space."%_t,
        "The latest scion of a prestigious pirate family has ascended to leadership."%_t,
        "Titanium belt ruffians have rallied around a new pirate leader."%_t,
    }, 30 * 60,
    function()
        return true
    end},
    { "The AI"%_t, "triple-plier", "last_killed_ai",
    {
        "Encrypted signal: XSOTAN_SIGNAL_SCAN: ACTIVE // COUNTERMEASURES: STANDBY"%_t,
        "Contacts in Naonite space have reported seeing a strange machine."%_t,
    }, 30 * 60,
    function()
        return true
    end},
    { "Bottan"%_t, "cargo-scrambler", "last_killed_bottan",
    {
        "You've received an anonymous notice about 'easy money' delivering unspecified goods."%_t,
        "A suspicious advertisement for a courier job was broadcast from a nearby market."%_t,
    }, 30 * 60, 
    function()
        return true
    end},
    { "Energy Lab"%_t, "power-lightning", "last_killed_scientist",
    {
        "You've received reports of new satellites broadcasting strange research notes."%_t,
        "High-power satellite signals have reappeared near the barrier."%_t,
        "A news bulletin claims that M.A.D. Science has resumed operations."%_t,
    }, 30 * 60,
    function()
        return true
    end},
    { "The 4"%_t, "hangar", "last_killed_the4",
    {
        "Whispers of fantastic riches in exchange for Xsotan artifacts are again circulating."%_t,
        "A famous quartet of researchers is searching for Xsotan artifacts once more."%_t,
    }, 30 * 60,
    function()
        return true
    end},
}

local _ActiveMods = Mods()
for _, _mod in pairs(_ActiveMods) do
    if _mod.id == "2733586433" then --Swenks
		table.insert(_list, 0, {"Swenks", "bolter-gun", "last_killed_swenks",
        {
            "The traders of the iron wastes are in a panic over a new pirate boss in uncharted space.",
            "It seems that the Lord of the Wastes has once again come to reclaim his position.",
        }, 30 * 60,
        function(_player)
            if _player:getValue("_lotw_story_5_accomplished") then
                return true
            else
                return false
            end
        end})
    end

	if _mod.id == "2724867356" then --Core Encounter.
		table.insert(_list, {"Core Encounter", "hazard-sign", "last_killed_coreencounter",
        {
            "Whispers of an extremely powerful ship in the core of the galxy are circulating.",
            "Rumors have it that the pirates in the core of the galaxy have constructed a fantastically powerful weapon.",
            "Something incredibly dangerous is prowling through the core.",
        }, 180 * 60,
        function(_player)
            if _player:getValue("story_completed") or _player:getValue("wormhole_guardian_destroyed") then
                return true
            else
                return false
            end
        end})
	end
end

for _, boss in pairs(_list) do
    table.insert(bcds_Bosses, {
        name = boss[1],
        icon = "data/textures/icons/${iconName}.png" % { iconName = boss[2] },
        getCooldown = function() return bcds_cdFromKey(boss[3], boss[5]) end,
        alertLines = boss[4],
        checkFunc = boss[6]
    })
end

if onClient() then

local bcds_resolution = getResolution()
local bcdsWindow
local bcdsSavedWindowPos
local bcdsBox

local bcds_MapCommands_initialize_original = MapCommands.initialize
function MapCommands.initialize()
    bcds_MapCommands_initialize_original()

    local player = Player()
    player:registerCallback("onShowGalaxyMap", "bcds_onShowGalaxyMap")
    player:registerCallback("onHideGalaxyMap", "bcds_onHideGalaxyMap")
    player:registerCallback("onGalaxyMapUpdate", "bcds_onGalaxyMapUpdate")
end

function bcds_cdFromKey(key, waitPeriod)
    waitPeriod = waitPeriod or 30 * 60
    local now = Client().unpausedRuntime
    local earlier = Player():getValue(key) or 0
    return math.max(0, waitPeriod + earlier - now)
end

function MapCommands.bcds_onShowGalaxyMap()
    MapCommands.bcds_createList()
end

function MapCommands.bcds_createList()
    -- Tear down any existing window: if a non-default/non-"docked" position exists for the window,
    -- preserve it; otherwise we'll automatically position and resize it.
    if bcdsWindow then
        bcdsSavedWindowPos = (not MapCommands.bcds_windowIsAutoPositioned() and bcdsWindow.position) or nil
        bcdsBox:clear()
        bcdsBox = nil
        bcdsWindow:clear()
        bcdsWindow:hide()
        bcdsWindow = nil
    end

    -- If there are no bosses, there's no window right now
    local bosses = 0
    local _player = Player()
    for _, boss in pairs(bcds_Bosses) do
        if boss.getCooldown() > 0 and boss.checkFunc(_player) then bosses = bosses + 1 end
    end
    if bosses == 0 then return end

    local width = 300
    local height = 18 * bosses
    local size = vec2(width, height)

    -- If there's no preserved window position, just put it all the way off screen so that it's auto-
    -- positioned next update/frame
    local pos = bcdsSavedWindowPos or bcds_resolution

    bcdsWindow = GalaxyMap():createWindow(Rect(pos, pos + size))
    bcdsWindow.caption = "Boss Cooldowns"%_t
    bcdsWindow.moveable = true
    bcdsWindow.showCloseButton = true

    bcdsBox = bcdsWindow:createListBoxEx(Rect(vec2(), size))
    bcdsBox.columns = 3
    bcdsBox.rowHeight = 25
    bcdsBox.entriesSelectable = false
    bcdsBox.fontSize = 18
    bcdsBox:setColumnWidth(0, 25)
    bcdsBox:setColumnWidth(1, 150)
    bcdsBox:setColumnWidth(2, 125)
    for _, boss in pairs(bcds_Bosses) do
        if boss.getCooldown() == 0 or boss.checkFunc(_player) == false then goto nextBoss end
        bcdsBox:addRow()
        local row = bcdsBox.rows - 1
        bcdsBox:setEntry(0, row, boss.icon, false, false, ColorRGB(1, 1, 1))
        bcdsBox:setEntryType(0, row, ListBoxEntryType.Icon)
        bcdsBox:setEntry(1, row, boss.name, false, false, ColorRGB(1, 1, 1))
        bcdsWindow.height = bcdsWindow.height + 15
        bcdsBox.height = bcdsBox.height + 15
        :: nextBoss ::
    end

    bcdsWindow:hide()
    bcdsWindow:show()
end

function MapCommands.bcds_onHideGalaxyMap()
end

local bcds_nextAlertCheckAtSeconds
local bcds_alertCheckInterval = 5

local bcds_MapCommands_update_original = MapCommands.update
function MapCommands.update(timestep)
    if bcds_MapCommands_update_original then bcds_MapCommands_update_original(timestep) end
    -- We update here to pop alert messages for ended cooldowns even when the galaxy map isn't up.
    -- To be mindful of performance, we only do these out-of-map checks every 5 seconds.
    local now = appTime()
    local _player = Player()
    if bcds_nextAlertCheckAtSeconds and now < bcds_nextAlertCheckAtSeconds then return end
    bcds_nextAlertCheckAtSeconds = now + bcds_alertCheckInterval

    for _, boss in pairs(bcds_Bosses) do
        local previousCooldown = boss.lastUpdateCheckCooldown
        local newCooldown = boss.getCooldown()
        if previousCooldown and previousCooldown > 0 and newCooldown == 0 and boss.checkFunc(_player) then
            MapCommands.onBossCooldownEnded(boss)
        end
        if newCooldown > 0 and not bcdsWindow then
            MapCommands.bcds_createList()
        end
        boss.lastUpdateCheckCooldown = newCooldown
    end
end

local bcds_updateWhileInMapAfter
function MapCommands.bcds_onGalaxyMapUpdate(timeStep)
    -- Check window repositioning continually for fluid snapping
    MapCommands.bcds_doAutoPosition()
    -- Otherwise, only update in the galaxy map on 1s intervals
    local now = appTime()
    if bcds_updateWhileInMapAfter and now < bcds_updateWhileInMapAfter then return end
    bcds_updateWhileInMapAfter = now + 1
    MapCommands.bcds_updateList()
end

function MapCommands.bcds_updateList()
    if not bcdsWindow or not bcdsBox then return end

    -- Helper: get the matching row number in the listBoxEx for a given name. Saves
    -- extra nesting/indentation to break it out this way.
    function getRowNumForName(name)
        for i = 1, bcdsBox.rows or 0, 1 do
            if bcdsBox:getEntry(1, i - 1) == name then return i end
        end
        return nil
    end

    local Color = {}
    Color.gray = ColorRGB(0.6, 0.6, 0.6)

    -- Check every boss for additions, removals, and updates
    local _player = Player()
    for _, boss in pairs(bcds_Bosses) do
        local cd = boss.getCooldown()
        local rowNum = getRowNumForName(boss.name)
        if (not rowNum and cd > 0) or (rowNum and cd == 0) or (rowNum and boss.checkFunc(_player) == false) then
            -- Something needs to be added or removed. Regenerate the list and signal for immediate
            -- alert consideration in case it's time for one of those.
            MapCommands.bcds_createList()
            MapCommands.bcds_updateList()
            bcds_nextAlertCheckAtSeconds = 0
            return
        elseif rowNum then
            -- Otherwise, update the time for an existing entry
            local cdString = createReadableShortTimeString(cd)
            bcdsBox:setEntry(2, (rowNum - 1), cdString, false, false, Color.gray)
        else
            -- Not added, not removed, and not updated: this boss isn't changing right now
            -- and doesn't need anything done in this list.
        end
    end
end

-- This "autoposition" behavior facilitates a bottom-right snapping behavior; dragging so that the
-- window goes partially off-screen in the lower right will pop it back and qualify it for automatic
-- resizing in a quasi-"docked" mode
function MapCommands.bcds_doAutoPosition()
    if not bcdsWindow or not MapCommands.bcds_windowIsAutoPositioned() then return end
    bcdsWindow.position = bcds_resolution - bcdsWindow.size
end

function MapCommands.bcds_windowIsAutoPositioned()
    if not bcdsWindow then return false end
    local lowerRight = bcdsWindow.position + bcdsWindow.size
    return lowerRight.x >= bcds_resolution.x and lowerRight.y >= bcds_resolution.y
end

end -- if onClient

function MapCommands.onBossCooldownEnded(boss)
    if onClient() then
        invokeServerFunction("onBossCooldownEnded", boss)
        return
    end
    if not boss.lastAlertTime or boss.lastAlertTime + 5 < appTime() then
        boss.lastAlertTime = appTime() 
        Player():sendChatMessage("", 3, randomEntry(boss.alertLines))
    end
end
callable(MapCommands, "onBossCooldownEnded")
