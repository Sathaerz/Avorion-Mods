local DestroyPrototype_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Destroy Prototype Battleship", _Tooltip = "destroyprototype2" })

    return DestroyPrototype_getBulletinMissionModules(modTable)
end