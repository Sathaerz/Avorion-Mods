local AmpedUP_Balancing_GetSectorWeaponDPS = Balancing_GetSectorWeaponDPS
function Balancing_GetSectorWeaponDPS(x, y)
  local dps, techLevel = AmpedUP_Balancing_GetSectorWeaponDPS(x, y)
  return dps * 75, techLevel
end