local Annihilatorium_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Annihilatorium", _Tooltip = "annihilatorium" })

    return Annihilatorium_getBulletinMissionModules(modTable)
end