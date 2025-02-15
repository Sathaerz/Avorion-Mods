local ScanXsotanGroup_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Scan Xsotan Group", _Tooltip = "scanxsotangroup" })

    return ScanXsotanGroup_getBulletinMissionModules(modTable)
end