local DestroyXsotanDreadnought_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Destroy Xsotan Dreadnought", _Tooltip = "destroyxsodread" })

    return DestroyXsotanDreadnought_getBulletinMissionModules(modTable)
end