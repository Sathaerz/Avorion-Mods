local EscortCivilians_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Escort Civilian Transports", _Tooltip = "escortcivilians" })

    return EscortCivilians_getBulletinMissionModules(modTable)
end