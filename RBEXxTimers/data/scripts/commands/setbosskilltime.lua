package.path = package.path .. ";data/scripts/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"

include ("galaxy")
include ("stringutility")
include ("randomext")
include ("callable")
include ("relations")

local SpawnRandomBosses = include("player/story/spawnrandombosses")

local bcds_bossKillKeyMap = {}
bcds_bossKillKeyMap["swoks"] = "last_killed_swoks"
bcds_bossKillKeyMap["theai"] = "last_killed_ai"
bcds_bossKillKeyMap["bottan"] = "last_killed_bottan"
bcds_bossKillKeyMap["scientist"] = "last_killed_scientist"
bcds_bossKillKeyMap["the4"] = "last_killed_the4"

local _ActiveMods = Mods()
for _, _mod in pairs(_ActiveMods) do
    if _mod.id == "2733586433" then
        bcds_bossKillKeyMap["swenks"] = "last_killed_swenks"
    end

	if _mod.id == "2724867356" then
		bcds_bossKillKeyMap["coreencounter"] = "last_killed_coreencounter"
	end
end

function execute(sender, commandName, name, time)

    return 1, "", "This command isn't currently enabled."
    --[[
    if not name then return 1, "", getHelp() end
    local keyFromName = bcds_bossKillKeyMap[string.lower(name)]
    if not keyFromName then return 1, "", "Unknown boss" end
    time = time or 30 * 60
    local lastKillTime = Server().unpausedRuntime - time

    Player(callingPlayer):setValue(keyFromName, lastKillTime)

    return 0, "", ""
    ]]
end

function getDescription()
    return "No description provided."
end

function getHelp()
    local msg = "Sets the seconds since the last kill for a boss encounter. Valid bosses:"
    for name, _ in pairs(bcds_bossKillKeyMap) do
        msg = msg .. "\n" .. name
    end
    return msg
end
