package.path = package.path .. ";data/scripts/lib/?.lua"

local MissionUT = include("missionutility")
local AsyncShipGen = include("asyncshipgenerator")
local SectorTurretGenerator = include("sectorturretgenerator")

ESCCUtil = include("esccutil")
BAUUtil = include("bauutil")

include ("faction")

--Don't remove this or else the script might break.
--namespace BusinessFrameworkMission
BusinessFrameworkMission = {}
local self = BusinessFrameworkMission

self.Family = nil
self._ContactTime = 30 --Default is 30 minutes. Set to 0 for debug.

self._Debug = 0

--region #INIT

function BusinessFrameworkMission.initialize()
    local _MethodName = "initialize"
    self.Log(_MethodName, "Beginning...")

    if Player():registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed") == 1 then
        self.Log(_MethodName, "Failed To Register Callback: onSectorArrivalConfirmed")
    end
end

--endregion

function BusinessFrameworkMission.getUpdateInterval()
    return 30
end

function BusinessFrameworkMission.Faction()
    --Try to get the faction if we don't have it loaded.
    if not self.Family then self.Family = Galaxy():findFaction("The Family") end
    if not self.Family then return false end
    return true
end

--region #SERVER CALLS

function BusinessFrameworkMission.updateServer(_TimeStep)
    local _MethodName = "On Update Server"
    self.Log(_MethodName, "Beginning...")

    --True/False faction check. Also tries to load the factin. Don't do anything until we find The Family.
    if not self.Faction() then
        self.Log(_MethodName, "Unable to find The Family. They remain undiscovered.")
        return
    end
    local player = Player()
    local _Server = Server()

    local currentTime = _Server.unpausedRuntime
    --First, we need to make sure the player hasn't done equilibrium. We do this by loading the new value of Family 5.
    local fam5accomplished = player:getValue("family_5_accomplished")
    local fam5accomplished_old = player:getValue("family_5_accomplished_old")

    if fam5accomplished then
        player:setValue("encyclopedia_bau_fam5_done", true)

        self.initializePlayerValues(player)

        if not fam5accomplished_old or not player:getValue("_bau_family_startstory") then
            --Wait about 10 minutes
            player:setValue("_bau_family_startstory", currentTime + (10 * 60))
        end

        if currentTime > player:getValue("_bau_family_startstory") then
            local _RankLevel = player:getValue("_bau_family_ranklevel") or 0
            local _RepLevel = player:getValue("_bau_family_rep") or 0
            local _VanillaStoryAdvancement = player:getValue("story_advance") or 0
            local _HaveAvo = player:getValue("_bau_family_have_avorion")
            local _GuardianRespawn = _Server:getValue("guardian_respawn_time")
            local _SwarmRespawn = _Server:getValue("xsotan_swarm_time")
            local _SwarmDuration = _Server:getValue("xsotan_swarm_duration")
            self.checkPlayerRank(_RankLevel, _RepLevel)

            local _GuardianCanSpawn = true
            if _GuardianRespawn or _SwarmRespawn or _SwarmDuration then
                _GuardianCanSpawn = false
            end

            local _Story1 = player:getValue("_bau_story_1_accomplished")
            local _Story2 = player:getValue("_bau_story_2_accomplished")
            local _Story3 = player:getValue("_bau_story_3_accomplished")
            local _Story4 = player:getValue("_bau_story_4_accomplished")
            local _Story5 = player:getValue("_bau_story_5_accomplished")

            self.Log(_MethodName, "Story 1 is " .. tostring(_Story1) .. " checking for script and attaching.")
            if not _Story1 and not player:hasScript("missions/family/story/baustorymission1.lua") then
                player:addScript("missions/family/story/baustorymission1.lua")
            end

            if _Story1 and not _Story2 and not player:hasScript("missions/family/story/baustorymission2.lua") then
                player:addScript("missions/family/story/baustorymission2.lua")
            end

            if _Story2 and not _Story3 and not player:hasScript("missions/family/story/baustorymission3.lua") then
                player:addScript("missions/family/story/baustorymission3.lua")
            end

            if _Story3 and not _Story4 and not player:hasScript("missions/family/story/baustorymission4.lua") and _RankLevel >= 4 and _HaveAvo then
                player:addScript("missions/family/story/baustorymission4.lua")
            end

            if _Story4 and not _Story5 and not player:hasScript("missions/family/story/baustorymission5.lua") and _RankLevel >= 4 and _VanillaStoryAdvancement >= 6 and _GuardianCanSpawn then
                player:addScript("missions/family/story/baustorymission5.lua")
            end
        end
    else
        local _RankLevel = player:getValue("_bau_family_ranklevel")
        local _Rank = player:getValue("_bau_family_rank")
        if _RankLevel and _Rank and fam5accomplished_old and _RankLevel > 1 then
            --Send nastygram to player.
            local _Mail = Mail()
            _Mail.text = Format("u betrayed da family. hek u")
            _Mail.header = ":("
            _Mail.sender = "Moretti"
            _Mail.id = "bau_equilibrium_mail"
            player:addMail(_Mail)
        end
        --Clear all values.
        self.resetPlayerValues(player)
    end

    player:setValue("family_5_accomplished_old", fam5accomplished)
end

function BusinessFrameworkMission.onSectorArrivalConfirmed(playerIndex, _X,  _Y)
    local _MethodName = "On Sector Arrival Confirmed"
    self.Log(_MethodName, "Beginning...")

    -- True/False Faction Check. Also trys to load the faction.
    -- Don't Do anything till we find The Family
    if not self.Faction() then
        self.Log(_MethodName, "Unable to find The Family. They remain undiscovered.")
        return
    end
    local _Player = Player()

    local _fam5accomplished = _Player:getValue("family_5_accomplished")
    local _famRank = _Player:getValue("_bau_family_rank")
    local _famStartStory = _Player:getValue("_bau_family_startstory")

    --If the sector is not safe, return.
    local _SectorSafe = self.getSectorSafe(_Player, _X, _Y)
    if not _SectorSafe then return end

    if _fam5accomplished and _famRank and _SectorSafe then
        --Start with the scouts after start of story + 10 mins
        local nextfamContact = _Player:getValue("_bau_family_nextcontact") or (_famStartStory + (10 * 60))

        local currentTime = Server().unpausedRuntime
        if currentTime >= nextfamContact and currentTime >= _famStartStory then
            if self.Family then
                --Contact the player every 30 minutes afterwards. This can be adjusted if needed by modifying self._ContactTime
                self.Log(_MethodName, "Attempting to spawn Family Scout")
                local futurefamContact = currentTime + (self._ContactTime * 60)
                _Player:setValue("_bau_family_nextcontact", futurefamContact)
                
                local esccShipGen = AsyncShipGen(BusinessFrameworkMission, BusinessFrameworkMission.onCreateFamScout)
                esccShipGen:startBatch()

                esccShipGen:createScout(self.Family, BusinessFrameworkMission.getPosition())

                esccShipGen:endBatch()
            end
        else
            self.Log(_MethodName, "The server has run for : " .. tostring(currentTime) .. " seconds - the scout will next spawn at : " .. tostring(nextfamContact) .. " seconds.")
        end
    else
        self.Log(_MethodName, "Fam 5 accomplished is : " .. tostring(_fam5accomplished) .. " - famRank is : " .. tostring(_famRank) .. " - SectorSafe is : " .. tostring(_SectorSafe) .. " - one of these values is not set correctly and the scout will not spawn.")
    end
end

function BusinessFrameworkMission.getPosition()
    local _MethodName = "Get Position"
    self.Log(_MethodName, "Beginning...")

    local _Rgen = ESCCUtil.getRand()
    local _Pos = _Rgen:getVector(-100,100)

    return MatrixLookUpPosition(-_Pos, vec3(0, 1, 0), _Pos)
end

function BusinessFrameworkMission.getSectorSafe(_Player, _X, _Y)
    local _MethodName = "Is Sector Safe"
    self.Log(_MethodName, "Calculating if sector is safe.")
    local _SectorSafe = true

    --If this is the location of another mission, don't contact the player.
    local otherMissionLocations = MissionUT.getMissionLocations()
    if otherMissionLocations:contains(_X, _Y) then
        self.Log(_MethodName, "Sector not safe - another mission is located here.")
        _SectorSafe = false
    end

    --If this is the location of pirates, don't contact the player.
    if ESCCUtil.countEntitiesByValue("is_pirate") > 0 then
        self.Log(_MethodName, "Sector not safe - pirates are present.")
        _SectorSafe = false
    end

    if ESCCUtil.countEntitiesByValue("is_xsotan") > 0 then
        self.Log(_MethodName, "Sector not safe - xsotan are present.")
        _SectorSafe = false
    end

    --If this is the location of a faction that hates the player, contact the player.
    local controllingFaction = Galaxy():getControllingFaction(_X, _Y)
    if controllingFaction then
        local relation = _Player:getRelations(controllingFaction.index)
        if relation < -80000 then
            self.Log(_MethodName, "Sector not safe - controlling faction hates player.")
            _SectorSafe = false
        end
    end

    --Finally, if the player is inside the barrier and the family has not yet reached the inside of the barrier, contact the player.
    if MissionUT.checkSectorInsideBarrier(_X, _Y) then
        if not _Player:getValue("_bau_family_inbarrier") then
            self.Log(_MethodName, "Sector not safe - Family is not inside barrier yet.")
            _SectorSafe = false
        end
    end

    self.Log(_MethodName, "Final sector safe value : " .. tostring(_SectorSafe))

    return _SectorSafe
end

function BusinessFrameworkMission.onCreateFamScout(generated)
    local _MethodName = "On Create Family Scout"
    self.Log(_MethodName, "Beginning...")

    for _, ship in pairs(generated) do
        --patrol and then hail the player.
        ship.title = "Family " .. ship.title
        ship:setValue("_bau_playercontact_idx", Player().index)

        ship:addScript("ai/patrolpeacefully.lua")    
        ship:addScript("entity/familycontact.lua")
        MissionUT.deleteOnPlayersLeft(ship)
    end
end

function BusinessFrameworkMission.checkPlayerRank(_CurrentRank, _CurrentRep)
    local _MethodName = "Checking Player Rank"
    self.Log(_MethodName, "Starting...")
    --[[
        RANK
            1 - Associate
            2 - Soldier
            3 - Capo
            4 - Consigliere
            5 - Underboss

            controlled by _bau_family_rep - a little hidden reputation stat.
            STORY 1/2/3 = +3, STORY 4/5 = +8
            SIDE -
                - Side1 = +1 
                - Side2 = +1 
                - Side4 = +2 
                - Side5 = +4 
                - Side6 = +4 
            --All side missions give +1 rep @ danger 10.
            +5 pts to get to 2
            +10 (15 total) pts to get to 3
            +15 (30 total) pts to get to 4
            +20 (50 total) pts to get to 5
    ]]

    local _Player = Player()
    local _CurrentRankName = _Player:getValue("_bau_family_rank")
    local _Story5Accomplished = _Player:getValue("_bau_story_5_accomplished")
    local _SendMail = false
    local _MailText = nil
    local _AttachUnderbossItems = false
    local _New_Rank_Number = 1
    local _New_Rank_Name = ""

    self.Log(_MethodName, "Current rank is " .. tostring(_CurrentRank) .. " (" .. tostring(_CurrentRankName) .. ") and current rep is " .. tostring(_CurrentRep) .. " story 5 accomplished is " .. tostring(_Story5Accomplished))

    --Start rank check here.
    if _CurrentRank == 1 and _CurrentRep >= 5 then
        --send mail and promote
        _SendMail = true

        _New_Rank_Number = 2
        _New_Rank_Name = "Soldier"

        _MailText = Format("Placeholder for rank 1. Good job %1% %2%", _CurrentRankName, _Player.name)
    elseif _CurrentRank == 2 and _CurrentRep >= 15 then
        _SendMail = true

        _New_Rank_Number = 3
        _New_Rank_Name = "Capo"

        _MailText = Format("Placeholder for rank 2. Good job on making %3%, former %1% %2%", _CurrentRankName, _Player.name, _New_Rank_Name)
    elseif _CurrentRank == 3 and _CurrentRep >= 30 then
        _SendMail = true

        _New_Rank_Number = 4
        _New_Rank_Name = "Consigliere"

        _MailText = Format("Placeholder for rank 2. Good job on making %3%, former %1% %2%", _CurrentRankName, _Player.name, _New_Rank_Name)
    elseif _CurrentRank == 4 and _CurrentRep >= 50 and _Story5Accomplished then
        _SendMail = true
        _AttachUnderbossItems = true

        _New_Rank_Number = 5
        _New_Rank_Name = "Underboss"

        _MailText = Format("Placeholder for rank 2. Good job on making %3%, former %1% %2%", _CurrentRankName, _Player.name, _New_Rank_Name)
    end

    _Player:setValue("_bau_family_ranklevel", _New_Rank_Number)
    _Player:setValue("_bau_family_rank", _New_Rank_Name)

    if _SendMail then
        local _Mail = Mail()
        _Mail.text = _MailText
        _Mail.header = Format("Promotion to %1%",  _New_Rank_Name)
        _Mail.sender = "Moretti"
        _Mail.id = "_bau_promotion_mail"

        if _AttachUnderbossItems then 
            --Get a legendary cargo & trading upgrade.
            --Get two sniper cannons.
        end

        _Player:addMail(_Mail)
    end
end

function BusinessFrameworkMission.resetPlayerValues(_Player)
    _Player:setValue("_bau_family_ranklevel", nil)
    _Player:setValue("_bau_family_rank", nil)
    _Player:setValue("_bau_family_rep", nil)
    _Player:setValue("_bau_family_nextcontact", nil)
    _Player:setValue("_bau_family_startstory", nil)
    _Player:setValue("_bau_story_1_accomplished", nil)
    _Player:setValue("_bau_story_2_accomplished", nil)
    _Player:setValue("_bau_story_3_accomplished", nil)
    _Player:setValue("_bau_story_4_accomplished", nil)
    _Player:setValue("_bau_story_5_accomplished", nil)
    _Player:setValue("_bau_family_have_avorion", nil)
    _Player:setValue("_bau_family_strength", nil)
    _Player:setValue("_bau_family_inbarrier", nil)
    --Remove all scripts, and I mean ALL scripts.
    local _Scripts = {
        "missions/family/story/baustorymission1.lua",
        "missions/family/story/baustorymission2.lua",
        "missions/family/story/baustorymission3.lua",
        "missions/family/story/baustorymission4.lua",
        "missions/family/story/baustorymission5.lua",
        "missions/family/side/bausidemission1.lua",
        "missions/family/side/bausidemission2.lua",
        "missions/family/side/bausidemission3.lua",
        "missions/family/side/bausidemission4.lua",
        "missions/family/side/bausidemission5.lua",
        "missions/family/side/bausidemission6.lua"
    }

    for _, _Script in pairs(_Scripts) do
        if _Player:hasScript(_Script) then
            self.Log(_MethodName, "Invoking fail method of " .. _Script, 1)
            _Player:invokeFunction(_Script, "fail")
        end
    end
    --After this has set, we regenerate the arsenal, since the value that triggers that can be set during the massive if/elseif above.
    self.regenerateFactionArsenal()
end

function BusinessFrameworkMission.initializePlayerValues(_Player)
    --If the player JUST finished family 5 and started the story, we need to set some values.
    if not _Player:getValue("_bau_family_rank") then
        _Player:setValue("_bau_family_rank", "Associate")
    end
    if not _Player:getValue("_bau_family_ranklevel") then
        _Player:setValue("_bau_family_rank", 1)
    end
    if not _Player:getValue("_bau_family_rep") then
        _Player:setValue("_bau_family_rep", 0)
    end
    if not _Player:getValue("_bau_family_strength") then
        _Player:setValue("_bau_family_strength", 1)
    end
end

function BusinessFrameworkMission.regenerateFactionArsenal()
    local _MethodName = "Regenerate Faction Arsenal"
    --Determine if the inventory should be regenerated.
    local _Regenerated = self.Family:getValue("_bau_family_regeneratedArsenal")

    if _Regenerated then
        self.Log(_MethodName, "The Family do not need to have their weaponry regenerated - returning and exiting.")
        return
    end

    --Clear out the inventory of the family.
    self.Family:getInventory():clear()

    --Next, get tech level by strength
    local _TechLevel = 24

    local _X, _Y = Balancing_GetSectorByTechLevel(_TechLevel)
    local _Seed = Server().seed + self.Family.index

    local turretGenerator = SectorTurretGenerator(_Seed)
    --Don't add PDC types to this list. We don't want to have Family ships having PD Slapfights
    self.Log(_MethodName, "Generating more powerful Turrets")
    local _TurretTypes = {
        WeaponType.ChainGun, 
        WeaponType.MiningLaser, 
        WeaponType.SalvagingLaser, 
        WeaponType.Bolter, 
        WeaponType.Laser,
        WeaponType.TeslaGun,
        WeaponType.PulseCannon,
        WeaponType.Cannon,
        WeaponType.PlasmaGun,
        WeaponType.RocketLauncher,
        WeaponType.RailGun,
        WeaponType.LightningGun
    }

    for _, _WType in pairs(_TurretTypes) do
        local _FamTurret = turretGenerator:generate(_X, _Y, 0, nil, _WType)
        _FamTurret.coaxial = false
        if _WType == WeaponType.Laser or _WType == WeaponType.RocketLauncher then
            --Lasers are no longer shit, but we buff them anyways!
            local _TWeapons = {_FamTurret:getWeapons()}
            _FamTurret:clearWeapons()
            for _, _W in pairs(_TWeapons) do
                if _WType == WeaponType.Laser then
                    _W.damage = _W.damage * 2
                    _W.reach = _W.reach * 1.5
                elseif _WType == WeaponType.RocketLauncher then
                    _W.damage = _W.damage * 1.5
                    _W.seeker = true
                end

                _FamTurret:addWeapon(_W)
            end
        end

        self.Family:getInventory():add(_FamTurret, false)
    end

    self.Family:setValue("_bau_family_regeneratedArsenal", true)
end

--endregion

--region CLIENT / SERVER CALLS

function BusinessFrameworkMission.Log(_MethodName, _Msg, _OverrideDebug)
    local _TempDebug = self._Debug
    if _OverrideDebug then self._Debug = _OverrideDebug end
    if self._Debug and self._Debug == 1 then
        print("[BAU Framework Mission] - [" .. _MethodName .. "] - " .. _Msg)
    end
    if _OverrideDebug then self._Debug = _TempDebug end
end

--endregion

--All of the following player values are added / changed by this mod:
--[[
_bau_family_inbarrier
_bau_family_ranklevel
_bau_family_rank
_bau_family_rep
_bau_family_nextcontact
_bau_family_startstory
_bau_story_1_accomplished
_bau_story_2_accomplished
_bau_story_3_accomplished
_bau_story_4_accomplished
_bau_story_5_accomplished
_bau_family_have_avorion
_bau_family_strength
_bau_family_inbarrier
]]

--All of the following family faction values are added / changed by this mod:
--[[
_bau_family_regeneratedArsenal
]]