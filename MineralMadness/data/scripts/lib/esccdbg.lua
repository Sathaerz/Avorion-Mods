local MineralMadness_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Mineral Madness", _Tooltip = "mineralmadness" })

    return MineralMadness_getBulletinMissionModules(modTable)
end