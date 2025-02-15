local AttackResearchBase_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Attack Research Base", _Tooltip = "attackresearchbase" })

    return AttackResearchBase_getBulletinMissionModules(modTable)
end