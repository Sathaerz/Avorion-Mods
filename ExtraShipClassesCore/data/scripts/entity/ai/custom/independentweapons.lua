--Custom AI script.
package.path = package.path .. ";data/scripts/lib/?.lua"

include("weapontype")
include("weapontypeutility")

--namespace IndependentWeaponsAIScript
IndependentWeaponsAIScript = {}

function IndependentWeaponsAIScript.initialize()
    if onServer() then
        Entity():addMultiplyableBias(StatsBonuses.AutomaticTurrets, 10000)

        IndependentWeaponsAIScript.groupWeapons()
        IndependentWeaponsAIScript.setWeaponBehaviors()
    end
end

function IndependentWeaponsAIScript.groupWeapons()

    local entityTurrets = { Entity():getTurrets() }

    for _, turret in pairs(entityTurrets) do
        local entityTurret = Turret(turret.id)
        
        entityTurret.automatic = true
        entityTurret.group = 1
    end
end

function IndependentWeaponsAIScript.setWeaponBehaviors()
    local turretController = TurretController()

    turretController:setGroupFireMode(1, 2) --2 is Always(?)

    local groupOrders = turretController:getGroupOrders(1)
    print("Group orders after is " .. tostring(groupOrders))
end