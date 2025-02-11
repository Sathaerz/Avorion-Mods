local ScrapScramble_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Scrap Scramble", _Tooltip = "scrapscramble" })

    return ScrapScramble_getBulletinMissionModules(modTable)
end