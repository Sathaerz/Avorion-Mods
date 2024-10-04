local BAU_WarZoneCheck_OnDestroyed = WarZoneCheck.onDestroyed
function WarZoneCheck.onDestroyed(destroyedId, destroyerId)

    local victim = Entity(destroyedId)
    if not victim then return end

    --Family ships should not cause a warzone. We don't care about Commune / Cavaliers ships here.
    if victim:getValue("is_family") then return end

    BAU_WarZoneCheck_OnDestroyed(destroyedId, destroyerId)
end