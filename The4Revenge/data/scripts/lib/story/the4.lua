function The4.createChaingunTurret()
    local generator = SectorTurretGenerator(Seed(152))
    generator.coaxialAllowed = false

    local turret = generator:generate(150, 0, 0, Rarity(RarityType.Common), WeaponType.ChainGun)
    local weapons = {turret:getWeapons()}
    turret:clearWeapons()
    for _, weapon in pairs(weapons) do
        weapon.reach = 1000
        weapon.reach = 1000
        weapon.pmaximumTime = weapon.reach / weapon.pvelocity
        weapon.hullDamageMultiplier = 0.25
        turret:addWeapon(weapon)
    end

    turret.turningSpeed = 2.0
    turret.crew = Crew()

    return turret
end

function The4.spawnFlare(_X, _Y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 10

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local _Boss = The4.createShip(faction, position, volume, "Style 2")
    local _Turret = The4.createLaserTurret()
    ShipUtility.addTurretsToCraft(_Boss, _Turret, 15, 15)
    ShipUtility.addBossAntiTorpedoEquipment(_Boss)

    _Boss.title = "Flare"
    Boarding(_Boss).boardable = false
    _Boss:addScript("story/the4revenge")

    _Boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    --Add offensive script
    local _LaserDamage = 77000
    _Boss:addScriptOnce("lasersniper.lua", {_DamagePerFrame = _LaserDamage, _UseEntityDamageMult = true})

    if _Factor >= 10 then
        _Boss:addScriptOnce("overdrive.lua")
    end

    Loot(_Boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(_X, _Y, -16, Rarity(RarityType.Exotic), WeaponType.Laser)))
    _Boss:setDropsAttachedTurrets(false)

    return _Boss
end

function The4.spawnWastelayer(_X, _Y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 10

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local _Boss = The4.createShip(faction, position, volume, "Style 2")
    local _Turret = The4.createChaingunTurret()
    ShipUtility.addTurretsToCraft(_Boss, _Turret, 15, 15)

    _Boss.title = "Wastelayer"
    Boarding(_Boss).boardable = false
    _Boss:addScript("story/the4revenge")

    _Boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")

    --Add offensive script
    local _TorpSlammerValues = {}
    _TorpSlammerValues._TimeToActive = 12
    _TorpSlammerValues._ROF = 4
    _TorpSlammerValues._UpAdjust = false
    _TorpSlammerValues._DamageFactor = 16
    _TorpSlammerValues._DurabilityFactor = 4
    _TorpSlammerValues._ForwardAdjustFactor = 1
    _TorpSlammerValues._UseEntityDamageMult = true

    _Boss:addScriptOnce("torpedoslammer.lua", _TorpSlammerValues)

    if _Factor >= 10 then
        _Boss:addScriptOnce("overdrive.lua")
    end

    Loot(_Boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(_X, _Y, -16, Rarity(RarityType.Exotic), WeaponType.ChainGun)))
    _Boss:setDropsAttachedTurrets(false)

    return _Boss
end

function The4.spawnRevengeTank(x, y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 20

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local boss = The4.createShip(faction, position, volume, "Style 3")
    local turret = The4.createLaserTurret()
    ShipUtility.addTurretsToCraft(boss, turret, 20, 20)
    ShipUtility.addBossAntiTorpedoEquipment(boss)
    boss.title = "Tankem"
    boss:addScript("story/the4revenge")
    Boarding(boss).boardable = false

    -- adds legendary turret drop
    boss:addScriptOnce("internal/common/entity/background/legendaryloot.lua")
    boss:addScriptOnce("utility/buildingknowledgeloot.lua")

    --add defensive scripts
    boss:addScriptOnce("adaptivedefense.lua")
    if _Factor < 10 then
        boss:addScriptOnce("ironcurtain.lua")
    else
        boss:addScriptOnce("tankemspecial.lua", 145, 0.35, _Factor)
        boss:addScriptOnce("terminalblocker.lua")
    end
    if _Factor >= 5 then
        boss.damageMultiplier = (boss.damageMultiplier or 1) * 1.5
    end

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, -16, Rarity(RarityType.Exotic), WeaponType.Laser)))
    boss:setDropsAttachedTurrets(false)

    return boss
end

function The4.spawnRevengeHealer(x, y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 8

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local boss = The4.createShip(faction, position, volume, "Style 1")
    local turret = The4.createHealingTurret()
    ShipUtility.addTurretsToCraft(boss, turret, 15, 15)
    ShipUtility.addBossAntiTorpedoEquipment(boss)
    boss.title = "Reconstructo"
    boss:addScript("story/healer")
    boss:addScript("story/the4revenge")
    Boarding(boss).boardable = false

    --add defensive scripts
    local _FactorBoostCycle = 60
    if _Factor >= 10 then
        _FactorBoostCycle = 30 --Pass 'em out twice as fast and heal twice as much.
    end
    boss:addScriptOnce("allybooster.lua", {_HealWhenBoosting = true, _HealPctWhenBoosting = 33, _BoostCycle = _FactorBoostCycle})
    if _Factor >= 5 then
        boss:addScriptOnce("eternal.lua")
    end

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, -16, Rarity(RarityType.Exotic), WeaponType.RepairBeam)))
    boss:setDropsAttachedTurrets(false)

    return boss
end

function The4.spawnRevengeShieldbreaker(x, y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 10

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local boss = The4.createShip(faction, position, volume, "Style 2")
    local turret = The4.createPlasmaTurret()
    ShipUtility.addTurretsToCraft(boss, turret, 15, 15)
    ShipUtility.addBossAntiTorpedoEquipment(boss)
    boss.title = "Shieldbreaker"
    boss:addScript("story/the4revenge")
    Boarding(boss).boardable = false

    --add offensive scripts
    boss:addScriptOnce("overdrive.lua")
    if _Factor >= 5 then
        boss.damageMultiplier = (boss.damageMultiplier or 1) * 1.25
    end

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, -16, Rarity(RarityType.Exotic), WeaponType.PlasmaGun)))
    boss:setDropsAttachedTurrets(false)

    return boss
end

function The4.spawnRevengeHullbreaker(x, y, _Factor)
    local faction = The4.getFaction()
    local volume = Balancing_GetSectorShipVolume(faction:getHomeSectorCoordinates()) * 10

    local translation = random():getDirection() * 500
    local position = MatrixLookUpPosition(-translation, vec3(0, 1, 0), translation)

    local boss = The4.createShip(faction, position, volume, "Style 2")
    local turret = The4.createRailgunTurret()
    ShipUtility.addTurretsToCraft(boss, turret, 15, 15)
    ShipUtility.addBossAntiTorpedoEquipment(boss)
    boss.title = "Hullbreaker"
    boss:addScript("story/the4revenge")
    Boarding(boss).boardable = false

    --add offensive scripts
    boss:addScriptOnce("overdrive.lua")
    if _Factor >= 5 then
        boss.damageMultiplier = (boss.damageMultiplier or 1) * 1.25
    end

    Loot(boss.index):insert(InventoryTurret(SectorTurretGenerator():generate(x, y, -16, Rarity(RarityType.Exotic), WeaponType.RailGun)))
    boss:setDropsAttachedTurrets(false)

    return boss
end

local The4RevengeCheckForEnd = The4.checkForEnd
function The4.checkForEnd()
    local ended = The4RevengeCheckForEnd()

    if ended then
        local players = {Sector():getPlayers()}

        for _, player in pairs(players) do        
            local killCT = player:getValue("the4_total_kills") or 0
            killCT = killCT + 1
            player:setValue("the4_total_kills", killCT)
        end
    end

    return ended
end

local The4RevengeSpawn = The4.spawn
function The4.spawn(x, y)
    local _Players = {Sector():getPlayers()}
    local _SpawnRevenge = true
    local _Factor = 0

    for _, _Player in pairs(_Players) do
        --All players must have killed the4 to get the nasty version.
        if not _Player:getValue("last_killed_the4") then
            _SpawnRevenge = false
        end
        --Use the highest # of kills in the group.
        local _KillCT = _Player:getValue("the4_total_kills")
        if _KillCT and _KillCT > _Factor then
            _Factor = _KillCT
        end
    end

    --Drop the factor by so it doesn't start coming into play until after the 2nd kill.
    _Factor = math.max(_Factor - 1, 0)
    _Factor = math.min(_Factor, 20) --In a first for me, we'll cap it at 20.

    if _SpawnRevenge then
        local ships = {Sector():getEntitiesByFaction(The4.getFaction().index)}

        for _, ship in pairs(ships) do
            if ship:hasComponent(ComponentType.Title) then
                if ship.title == "Tankem"
                    or ship.title == "Shieldbreaker"
                    or ship.title == "Hullbreaker"
                    or ship.title == "Reconstructo" 
                    or ship.title == "Wastelayer"
                    or ship.title == "Flare" then
    
                    return
                end
            end
        end
    
        print ("spawning the The 4's revenge!")
    
        -- set the last_spawned value for all players in the sector
        local players = {Sector():getPlayers()}
        local runtime = Server().unpausedRuntime
        for _, player in pairs(players) do
            player:setValue("last_spawned_the4", runtime)
        end

        local _Healer = The4.spawnRevengeHealer(x, y, _Factor)
        local _DD1 = The4.spawnRevengeShieldbreaker(x, y, _Factor)
        local _DD2 = The4.spawnRevengeHullbreaker(x, y, _Factor)
        local _DD3 = The4.spawnFlare(x, y, _Factor)
        local _DD4 = The4.spawnWastelayer(x, y, _Factor)
        local _Tank = The4.spawnRevengeTank(x, y, _Factor)

        enemies = {}
        table.insert(enemies, _Healer)
        table.insert(enemies, _DD1)
        table.insert(enemies, _DD2)
        table.insert(enemies, _DD3)
        table.insert(enemies, _DD4)
        table.insert(enemies, _Tank)

        local players = {Sector():getPlayers()}

        for _, boss in pairs(enemies) do
            ShipAI(boss.index):setAggressive()
            boss:addScriptOnce("avenger.lua") --All of them are avengers
            boss:addScriptOnce("megablocker.lua") --All are megablockers

            local _DuraFactor = 2 + (_Factor / 2)
            local _ShieldDuraFactor = 2 + (_Factor / 2)
            local _DamageFactor = 4 + (_Factor / 2)
            --Tankem has bad stats so they get a better multiplier on stuff.
            if boss.title == "Tankem" then
                _DamageFactor = 6 + (_Factor / 2)
                _DuraFactor = 3 + (_Factor / 2)
            end
            if boss.title == "Reconstructo" and _Factor >= 5 then
                _DuraFactor = 3 + (_Factor / 2)
            end

            boss.damageMultiplier = (boss.damageMultiplier or 1) * _DamageFactor

            local _Shield = Shield(boss)
            if _Shield then 
                _Shield.maxDurabilityFactor = (_Shield.maxDurabilityFactor or 0) + _ShieldDuraFactor
            else
                _DuraFactor = _DuraFactor * 2
            end

            local _Dura = Durability(boss)
            if _Dura then 
                _Dura.maxDurabilityFactor = (_Dura.maxDurabilityFactor or 0) + _DuraFactor
            end

            -- like all players
            for _, player in pairs(players) do
                ShipAI(boss.index):registerFriendFaction(player.index)
            end
        end

        print("The 4's revenge spawned!")

        -- send sector callback on finished spawning
        Sector():sendCallback("onThe4Spawned", _Healer.id, _DD1.id, _DD2.id, _Tank.id, Sector():getCoordinates(), _DD3.id, _DD4.id)
    
        return _Healer, _DD1, _DD2, _Tank, _DD3, _DD4
    else
        The4RevengeSpawn(x, y)
    end
end