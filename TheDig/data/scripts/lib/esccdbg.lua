local TheDig_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "The Dig", _Tooltip = "thedig" })

    return TheDig_getBulletinMissionModules(modTable)
end