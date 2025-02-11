local TransferSatellite_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Transfer Satellite", _Tooltip = "transfersatellite" })

    return TransferSatellite_getBulletinMissionModules(modTable)
end