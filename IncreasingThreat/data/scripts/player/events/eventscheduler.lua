local _Debug = 0
local _TargetIndex = nil

for _Idx, _Event in pairs(events) do
    --Figure out if this is the pirate attack and reduce the time on it.
    if _Event.arguments and _Event.arguments[1] == "pirateattack.lua" then
        _Event.schedule = random():getInt(30, 50) * 60
    end
    --Figure out where to yeet fake distress signal.
    if _Event.script and _Event.script == "events/fakedistresssignal" then
        if _Debug == 1 then
            print("Found fake distress signal event at index " .. tostring(_Idx))
        end
        _TargetIndex = _Idx
    end
end
if _TargetIndex then
    table.remove(events, _TargetIndex)
    if _Debug == 1 then
        print("Removed standard fake distress signal event.")
    end
end

table.insert(events, {schedule = random():getInt(60, 80) * 60, localEvent = true,  script = "events/sectoreventstarter", arguments = {"decapstrike.lua"}, to = 560})
table.insert(events, {schedule = random():getInt(45, 60) * 60, localEvent = false, script = "events/deepfakedistress", arguments = {true}, to = 560})
table.insert(events, {schedule = random():getInt(60, 80) * 60, localEvent = false, script = "events/itfakedistresssignal", arguments = {true}, to = 560})
--Add a second / third event farther into the galaxy to balance out the massive # of Xsotan attacks going.
table.insert(events, {schedule = random():getInt(50, 70) * 60, localEvent = true,  script = "events/sectoreventstarter", arguments = {"pirateattack.lua"}, to = 350})
table.insert(events, {schedule = random():getInt(50, 70) * 60, localEvent = true,  script = "events/sectoreventstarter", arguments = {"pirateattack.lua"}, to = 250})

function EventScheduler.unPause()
    if _Debug == 1 then
        local _Player = Player()
        print("Unpausing events for " .. tostring(_Player.name))
    end
    self.pauseTime = 0
end