local AmbushRaiders_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    --0x65736363206465627567206D697373696F6E207461626C65
    table.insert(modTable, { _Caption = "Ambush Pirate Raiders", _Tooltip = "ambushraiders" })

    return AmbushRaiders_getBulletinMissionModules(modTable)
end