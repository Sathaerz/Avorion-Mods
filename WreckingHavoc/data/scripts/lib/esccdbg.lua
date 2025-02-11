local WreckingHavoc_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Wrecking Havoc", _Tooltip = "wreckinghavoc" })

    return WreckingHavoc_getBulletinMissionModules(modTable)
end