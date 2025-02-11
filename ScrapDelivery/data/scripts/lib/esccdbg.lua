local ScrapDelivery_getBulletinMissionModules = getBulletinMissionModules
function getBulletinMissionModules(modTable)
    table.insert(modTable, { _Caption = "Scrap Delivery", _Tooltip = "scrapdelivery" })

    return ScrapDelivery_getBulletinMissionModules(modTable)
end