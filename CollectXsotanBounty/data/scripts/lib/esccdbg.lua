local CollectXsotanBounty_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    --0x65736363206465627567206D697373696F6E207461626C65
    table.insert(modTable, { _Caption = "Collect Xsotan Bounty", _Tooltip = "xsotanbounty" })

    return CollectXsotanBounty_getBulletinMissionModules(modTable)
end