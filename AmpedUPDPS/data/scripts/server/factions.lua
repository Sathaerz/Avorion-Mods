--Overrides the intiializeAIFaction method so that they cannot spawn with point defense lasers or point defense turrets as their weapons.
local AmpedUP_initializeAIFaction = initializeAIFaction
function initializeAIFaction(faction)
    AmpedUP_initializeAIFaction(faction)
    faction:getInventory():clear()

    local seed = Server().seed + faction.index
    local random = Random(seed)

    local turretGenerator = SectorTurretGenerator(seed)

    local x, y = faction:getHomeSectorCoordinates()

    local sector = math.floor(length(vec2(x, y)))
    local types = Balancing_GetWeaponProbability(sector, 0)
    types[WeaponType.RepairBeam] = nil
    types[WeaponType.MiningLaser] = nil
    types[WeaponType.SalvagingLaser] = nil
    types[WeaponType.RawSalvagingLaser] = nil
    types[WeaponType.RawMiningLaser] = nil
    types[WeaponType.ForceGun] = nil
    --No point defenses!!!
    types[WeaponType.PointDefenseLaser] = nil
    types[WeaponType.PointDefenseChainGun] = nil
    types[WeaponType.AntiFighter] = nil

    local armed1type = getValueFromDistribution(types, random)
    local armed1 = turretGenerator:generate(x, y, 0, Rarity(RarityType.Common), armed1type, nil)
    armed1.coaxial = false

    local armed2type = getValueFromDistribution(types, random)
    local armed2 = turretGenerator:generate(x, y, 0, Rarity(RarityType.Common), armed2type, nil)
    armed2.coaxial = false

    local unarmed1 = turretGenerator:generate(x, y, 0, Rarity(RarityType.Common), WeaponType.MiningLaser)
    unarmed1.coaxial = false

    for _, turret in pairs({armed1, armed2}) do

        local weapons = {turret:getWeapons()}
        turret:clearWeapons()

        for _, weapon in pairs(weapons) do

            if weapon.isProjectile and (weapon.fireRate or 0) > 2 then
                local old = weapon.fireRate
                weapon.fireRate = math.random(1.0, 2.0)
                weapon.damage = weapon.damage * old / weapon.fireRate;
            end

            turret:addWeapon(weapon)
        end
    end

    faction:getInventory():add(armed1, false)
    faction:getInventory():add(armed2, false)
    faction:getInventory():add(unarmed1, false)
end