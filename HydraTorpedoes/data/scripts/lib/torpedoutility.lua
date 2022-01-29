TorpedoUtility.WarheadType["NuclearHydra"] = #TorpedoUtility.Warheads+1 --Should be 11 under most circumstances
table.insert(TorpedoUtility.Warheads, {type = WarheadType.NuclearHydra,     name = "Nuclear Hydra",        hull = 1,     shield = 1,       size = 1.0, color = ColorRGB(0.8, 0.8, 0.8)})

TorpedoUtility.WarheadType["NeutronHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.NeutronHydra,     name = "Neutron Hydra",        hull = 3,     shield = 1,       size = 1.0, color = ColorRGB(0.8, 0.8, 0.3)})

TorpedoUtility.WarheadType["FusionHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.FusionHydra,      name = "Fusion Hydra",         hull = 1,     shield = 3,       size = 1.0, color = ColorRGB(1.0, 0.4, 0.1)})

TorpedoUtility.WarheadType["TandemHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.TandemHydra,      name = "Tandem Hydra",         hull = 1.5,   shield = 2,       size = 1.5, color = ColorRGB(0.8, 0.2, 0.2), shieldAndHullDamage = true})

TorpedoUtility.WarheadType["KineticHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.KineticHydra,     name = "Kinetic Hydra",        hull = 2.5,   shield = 0.25,    size = 1.5, color = ColorRGB(0.7, 0.3, 0.7), damageVelocityFactor = true})

TorpedoUtility.WarheadType["IonHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.IonHydra,         name = "Ion Hydra",            hull = 0.25,  shield = 3,       size = 2.0, color = ColorRGB(0.2, 0.7, 1.0), energyDrain = true})

TorpedoUtility.WarheadType["PlasmaHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.PlasmaHydra,      name = "Plasma Hydra",         hull = 1,     shield = 5,       size = 2.0, color = ColorRGB(0.2, 0.8, 0.2)})

TorpedoUtility.WarheadType["SabotHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.SabotHydra,       name = "Sabot Hydra",          hull = 2,     shield = 0,       size = 3.0, color = ColorRGB(1.0, 0.1, 0.5), penetrateShields = true})

TorpedoUtility.WarheadType["EMPHydra"] = #TorpedoUtility.Warheads+1
table.insert(TorpedoUtility.Warheads, {type = WarheadType.EMPHydra,         name = "EMP Hydra",            hull = 0,     shield = 0.025,   size = 3.0, color = ColorRGB(0.3, 0.3, 0.9), deactivateShields = true})

TorpedoUtility.WarheadType["AntiMatterHydra"] = #TorpedoUtility.Warheads+1 --Should be 20 under most circumstances.
table.insert(TorpedoUtility.Warheads, {type = WarheadType.AntiMatterHydra,  name = "Anti-Matter Hydra",    hull = 8,     shield = 6,       size = 5.0, color = ColorRGB(0.2, 0.2, 0.2), storageEnergyDrain = 75000000})

table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.NuclearHydra, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.NeutronHydra, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.FusionHydra, damageType = DamageType.Energy})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.TandemHydra, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.KineticHydra, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.IonHydra, damageType = DamageType.Energy})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.PlasmaHydra, damageType = DamageType.Plasma})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.SabotHydra, damageType = DamageType.Physical})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.EMPHydra, damageType = DamageType.Electric})
table.insert(TorpedoUtility.DamageTypes, {type = WarheadType.AntiMatterHydra, damageType = DamageType.AntiMatter})

function TorpedoUtility.getWarheadNameByType(_Type)
    for _, _Warhead in pairs(TorpedoUtility.Warheads) do
        if _Warhead.type == _Type then
            return _Warhead.name
        end
    end

    return "Unknown"
end

function TorpedoUtility.isHydra(_Type)
    local _Warhead = TorpedoUtility.Warheads[_Type]

    if string.match(_Warhead.name, "Hydra") then
        return true
    else
        return false
    end
end

function TorpedoUtility.getStandardWarhead(_HydraWarhead)
    local _Warhead = TorpedoUtility.Warheads[_HydraWarhead]

    local _Pattern = string.gsub(_Warhead.name, "Hydra", "")
    _Pattern = string.gsub(_Pattern, " ", "") --Trim spaces.

    return TorpedoUtility.WarheadType[_Pattern]
end