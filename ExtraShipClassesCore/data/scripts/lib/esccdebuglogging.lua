-- This is a direct copy of SDK's logging tool! Big thanks to him for sharing it with me!
-- This is a simple Logging tool to allow easy logic tracing and Logging fucntions to be inserted into your scripts.
package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("randomext")

local ESCCDebugLogging = {}
local self = ESCCDebugLogging

ESCCDebugLogging.ModName = ""
ESCCDebugLogging.Debugging = 0
ESCCDebugLogging.Warnings = 1
ESCCDebugLogging.Errors = 1
ESCCDebugLogging.Infos = 1

--[[
    Simple Name Constrution fucntion used in the formatting of the lines below.
    m = (Method Name) The name of the calling method.
    returns a formatted string:
    -- "[Shield Check]: " if no ModName was set
    -- "[Shield Booster - Shield Check]: " if ModName was set
]]
function ESCCDebugLogging.GetName(m)
    if not self.ModName then self.ModName = "" end                                  -- Prevent it from being nil.
    local _Name = "" if self.Modname ~= "" then _Name = self.ModName .. " - " end   -- Format Name if its not "".
    return "[" .. _Name .. tostring(m) .."]: "                                      -- Return Built Name
end

--[[
    Simple Print() Wrapping Fucntion that allows more control.
    m = (Method Name) The name of the calling method.
    t = (Text) The text being printed.
    l = (Log) 0 = no, 1 = Yes. Allowes Toggeling DebugLogging and Overriding 
        Settings for warnings and error logging.
]]
function ESCCDebugLogging.Line(m, t, l)
    l = l or 0 m = m or ""
    if m ~= "" then m = ESCCDebugLogging.GetName(m) end -- Not passing the "m" var (nil) will just remove it so just the text shows.
    if l == 1 then print(m .. t) end
end

--[[
    Simple Warning Log formatting function to make it easier to log issues.
    m = (Method Name) The name of the calling method.
    t = (Text) The text being printed.    
]]
function ESCCDebugLogging.Warning(m, t)
    ESCCDebugLogging.Line(m, "[Warning] " .. t, self.Warnings)    
end

--[[
    Simple Info Log formatting function
    m = (Method Name) The name of the calling method.
    t = (Text) The text being printed.    
    l = (Log) 0 = no, 1 = Yes. Allowes Toggeling DebugLogging and Overriding 
        Settings for logging in this function.
]]
function ESCCDebugLogging.Info(m, t, l)
    ESCCDebugLogging.Line(m, "[Info] " .. t, self.Infos)    
end

--[[
    Simple Warning Log formatting function to make it easier to log issues.
    m = (Method Name) The name of the calling method.
    t = (Text) The text being printed.    
]]
function ESCCDebugLogging.Error(m, t)
    ESCCDebugLogging.Line(m, "[Error] " .. t, self.Errors)
end

--[[
    Simple Warning Log formatting function to make it easier to log issues.
    m = (Method Name) The name of the calling method.
    t = (Text) The text being printed.    
    l = (Log) 0 = no, 1 = Yes. Allowes Toggeling DebugLogging and Overriding 
]]
function ESCCDebugLogging.Debug(m, t, l)
    l = l or self.Debugging -- For Compatibility With Old Function Calls
    ESCCDebugLogging.Line(m, "[Debug] " .. t, l)
end

return ESCCDebugLogging