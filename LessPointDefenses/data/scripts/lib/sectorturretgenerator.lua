local xmods = Mods()

local hasHET = false
for _, p in pairs(xmods) do
    if p.id == "1821043731" then
        hasHET = true
        break
    end
end

if not hasHET then

    local _Version = GameVersion()

    if _Version.major <= 1 then

        local generate_LessPointDefenses = generate
        function SectorTurretGenerator:generate(x, y, offset_in, rarity_in, type_in, material_in)
            --print("running updated generate method")
            local offset = offset_in or 0
            local dps = 0
    
            local rarities = self.rarities or self:getSectorRarityDistribution(x, y)
            local rarity = rarity_in or Rarity(getValueFromDistribution(rarities, self.random))
            local seed, qx, qy = self:getTurretSeed(x, y, weaponType, rarity)
    
            local sector = math.max(0, math.floor(length(vec2(qx, qy))) + offset)
    
            local weaponDPS, weaponTech = Balancing_GetSectorWeaponDPS(sector, 0)
            local miningDPS, miningTech = Balancing_GetSectorMiningDPS(sector, 0)
            local materialProbabilities = Balancing_GetTechnologyMaterialProbability(sector, 0)
            local material = material_in or Material(getValueFromDistribution(materialProbabilities, self.random))
    
            local types = Balancing_GetWeaponProbability(sector, 0)
    
            --print("rarity value: " .. rarity.value .. "  rarity type: " .. rarity.type)
    
            if rarity.value == RarityType.Legendary then
                --print("legendary weapon! blocking point defenses.")
                types[WeaponType.AntiFighter] = nil
                types[WeaponType.PointDefenseChainGun] = nil
                types[WeaponType.PointDefenseLaser] = nil
            end
    
            local weaponType = type_in or getValueFromDistribution(types, self.random)
            --print("weaponType value: " .. weaponType)
    
            local tech = 0
            if weaponType == WeaponType.MiningLaser then
                dps = miningDPS
                tech = miningTech
            elseif weaponType == WeaponType.RawMiningLaser then
                dps = miningDPS * 2
                tech = miningTech
            elseif weaponType == WeaponType.ForceGun then
                dps = 1200
                tech = weaponTech
            else
                dps = weaponDPS
                tech = weaponTech
            end
    
            return TurretGenerator.generateSeeded(seed, weaponType, dps, tech, rarity, material)
        end

    else

        local generate_LessPointDefenses = generate
        function SectorTurretGenerator:generate(x, y, offset_in, rarity_in, type_in, material_in)

            local offset = offset_in or 0
            local dps = 0
        
            local rarities = self.rarities or self:getSectorRarityDistribution(x, y)
            local rarity = rarity_in or Rarity(getValueFromDistribution(rarities, self.random))
            if self.minRarity then
                if rarity < self.minRarity then rarity = self.minRarity end
            end
            if self.maxRarity then
                if rarity > self.maxRarity then rarity = self.maxRarity end
            end
        
            local seed, qx, qy = self:getTurretSeed(x, y, weaponType, rarity)
        
            local sector = math.max(0, math.floor(length(vec2(qx, qy))) + offset)
        
            local weaponDPS, weaponTech = Balancing_GetSectorWeaponDPS(sector, 0)
            local miningDPS, miningTech = Balancing_GetSectorMiningDPS(sector, 0)
            local materialProbabilities = Balancing_GetTechnologyMaterialProbability(sector, 0)
            local material = material_in or Material(getValueFromDistribution(materialProbabilities, self.random))

            local types = Balancing_GetWeaponProbability(sector, 0)
    
            --print("rarity value: " .. rarity.value .. "  rarity type: " .. rarity.type)
    
            if rarity.value == RarityType.Legendary then
                --print("legendary weapon! blocking point defenses.")
                types[WeaponType.AntiFighter] = nil
                types[WeaponType.PointDefenseChainGun] = nil
                types[WeaponType.PointDefenseLaser] = nil
            end

            local weaponType = type_in or getValueFromDistribution(types, self.random)
        
            local tech = 0
            if weaponType == WeaponType.MiningLaser then
                dps = miningDPS
                tech = miningTech
            elseif weaponType == WeaponType.RawMiningLaser then
                dps = miningDPS * 1.6
                tech = miningTech
            elseif weaponType == WeaponType.ForceGun then
                dps = 1200
                tech = weaponTech
            else
                dps = weaponDPS
                tech = weaponTech
            end
        
            return TurretGenerator.generateSeeded(seed, weaponType, dps, tech, rarity, material)
        end

    end

    local generateArmed_LessPointDefenses = generateArmed
    function SectorTurretGenerator:generateArmed(x, y, offset_in, rarity_in, material_in)

        local offset = offset_in or 0
        local sector = math.floor(length(vec2(x, y))) + offset
        local types = Balancing_GetWeaponProbability(sector, 0)

        types[WeaponType.RepairBeam] = nil
        types[WeaponType.MiningLaser] = nil
        types[WeaponType.SalvagingLaser] = nil
        types[WeaponType.RawSalvagingLaser] = nil
        types[WeaponType.RawMiningLaser] = nil
        types[WeaponType.ForceGun] = nil

        if rarity_in.value == RarityType.Legendary then
            types[WeaponType.AntiFighter] = nil
            types[WeaponType.PointDefenseChainGun] = nil
            types[WeaponType.PointDefenseLaser] = nil
        end

        local weaponType = getValueFromDistribution(types, self.random)

        return self:generate(x, y, offset_in, rarity_in, weaponType, material_in)
    end

end