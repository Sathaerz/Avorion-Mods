local DefendPrototype_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Defend Prototype Battleship", _Tooltip = "defendprototype" })

    return DefendPrototype_getBulletinMissionModules(modTable)
end