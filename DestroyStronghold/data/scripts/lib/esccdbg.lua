local DestroyStronghold_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Destroy Pirate Stronghold", _Tooltip = "destroystronghold" })

    return DestroyStronghold_getBulletinMissionModules(modTable)
end