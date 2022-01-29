package.path = package.path .. ";data/scripts/lib/?.lua"

local Log = include("esccdebuglogging")
Log.Debugging = 0 --Be careful about this! It will produce a MASSIVE number of messages.
Log.ModName = "ESCC Timed Delete Script"

--Get updates frequently. Shouldn't be an issue.
function getUpdateInterval()
    return 0.5
end

function updateServer(timeStep)
    local _MethodName = "On Update Server"

    local entity = Entity()
    local deletetime = entity:getValue("_escc_deletion_timestamp")
    local servertime = Server().unpausedRuntime

    if deletetime then
        Log.Debug(_MethodName, "Deletion time is: " .. tostring(deletetime) .. " server time is: " .. tostring(servertime))
        if servertime > deletetime then
            Log.Debug(_MethodName, "Entity deleting self.")
            Sector():deleteEntity(entity)
        end
    end
end