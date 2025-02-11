local CollectPirateBounty_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Collect Pirate Bounty", _Tooltip = "piratebounty" })

    return CollectPirateBounty_getBulletinMissionModules(modTable)
end