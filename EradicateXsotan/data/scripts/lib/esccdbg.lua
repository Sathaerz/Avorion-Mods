local EradicateXsotan_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Eradicate Xsotan Infestation", _Tooltip = "eradicatexsotan" })

    return EradicateXsotan_getBulletinMissionModules(modTable)
end