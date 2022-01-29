local Original_ArmedObjectPrice = ArmedObjectPrice
function ArmedObjectPrice(object)
    return Original_ArmedObjectPrice(object) / 75
end