local RescueSlaves_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Rescue Slaves", _Tooltip = "rescueslaves" })

    return RescueSlaves_getBulletinMissionModules(modTable)
end