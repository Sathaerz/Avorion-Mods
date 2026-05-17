package.path = package.path .. ";data/scripts/lib/?.lua"

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace VengeanceStory5ArmsFortress
VengeanceStory5ArmsFortress = {}
local self = VengeanceStory5ArmsFortress

function VengeanceStory5ArmsFortress.initialize()
    if onClient() then
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/vengeance/mw2armorveil.ogg")
    end
end

function VengeanceStory5ArmsFortress.setPhaseTwoTrack()
    if onClient() then
        --print("invoking switch tracks")
        unregisterBoss(Entity().index)
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/vengeance/ffxivpenitus.ogg")
    end
end

function VengeanceStory5ArmsFortress.setFailureTrack()
    if onClient() then
        --print("invoking switch tracks")
        unregisterBoss(Entity().index)
        Music():fadeOut(1.5)
        registerBoss(Entity().index, nil, nil, "data/music/vengeance/fs2bpviolence.ogg")
    end
end