local AmbushRaiders_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Ambush Pirate Raiders", _Tooltip = "ambushraiders" })

    return AmbushRaiders_getBulletinMissionModules(modTable)
end