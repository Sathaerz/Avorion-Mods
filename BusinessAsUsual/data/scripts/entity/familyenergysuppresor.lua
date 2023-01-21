
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include ("stringutility")
include ("sync")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FamEnergySuppressor
FamEnergySuppressor = {}
local self = FamEnergySuppressor
self.data = {time = 24 * 60 * 60} --Runs for more than twice as long.

defineSyncFunction("data", self)

function FamEnergySuppressor.getUpdateInterval()
    return 60
end

function FamEnergySuppressor.interactionPossible()
    return true
end

function FamEnergySuppressor.initialize()
    if onServer() then
        local entity = Entity()
        if entity.title == "" then
            entity.title = "Energy Signature Suppressor Mk. III"%_T
        end

        entity:setValue("no_attack_events", true)
    else
        self.sync()
    end

end

function FamEnergySuppressor.initUI()
    ScriptUI():registerInteraction("Close"%_t, "")
end

function FamEnergySuppressor.updateServer(timeStep)
    self.data.time = self.data.time - timeStep

    if self.data.time <= 0 then
        local x, y = Sector():getCoordinates()
        getParentFaction():sendChatMessage("Energy Signature Suppressor"%_T, ChatMessageType.Normal, [[Your energy signature suppressor in sector \s(%1%:%2%) has burnt out!]]%_T, x, y)
        getParentFaction():sendChatMessage("Energy Signature Suppressor"%_T, ChatMessageType.Warning, [[Your energy signature suppressor in sector \s(%1%:%2%) has burnt out!]]%_T, x, y)
        Entity():clearValues()
        terminate()
    end
end

function FamEnergySuppressor.updateClient(timeStep)
    self.data.time = self.data.time - timeStep

    self.sync()
end


function FamEnergySuppressor.secure()
    return self.data
end

function FamEnergySuppressor.restore(data)
    self.data = data
end

function FamEnergySuppressor.onSync()
    local data = {}
    data.hours = math.floor(self.data.time / 3600)
    data.minutes = math.floor((self.data.time - data.hours * 3600) / 60)

    local text = ""
    if data.hours > 0 then
        text = "Runtime: ${hours} hours ${minutes} minutes before burning out."%_t % data
    else
        text = "Runtime: ${minutes} minutes before burning out."%_t % data
    end

    InteractionText().text = text
end
