local AnalyzeXsotanSpecimen_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Analyze Xsotan Specimen", _Tooltip = "xsotanspecimen" })

    return AnalyzeXsotanSpecimen_getBulletinMissionModules(modTable)
end