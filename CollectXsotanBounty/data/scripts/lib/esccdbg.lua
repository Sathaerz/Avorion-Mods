local CollectXsotanBounty_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Collect Xsotan Bounty", _Tooltip = "xsotanbounty" })

    return CollectXsotanBounty_getBulletinMissionModules(modTable)
end