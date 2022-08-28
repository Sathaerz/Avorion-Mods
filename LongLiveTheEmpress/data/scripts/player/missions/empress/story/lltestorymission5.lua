--[[
    Story Mission 5.
    Long Live The Empress
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Story Mission 4 Done
        - Cavaliers Rank 4
        - Cavaliers Strength 2 (Have completed 2 upgrade arsenal missions)
        - All other prerequisites for fighting The Guardian have been established.
    ROUGH OUTLINE
        - Player reads mail from Adriana
        - Go to the location in the mail
        - Dialog with Adriana - end with yes / no option.
        - If the player says yes, XWG jumps in after dialog. Make it a weaker version of the XWG that can't harness the power of the black hole.
        - Do XWG things. It jumps out after 75% HP
        - If the player says no, then nothing happens. - Adriana just says "Okay, I trust you. Just let me know if you change your mind."
            - She will wait in the sector until after the mission.
        - If the player fights the XWG after it jumps out, start it at 75% HP.
        - Regardless, the player wins when they beat the guardian.
    DANGER LEVEL
        5+ - The mission starts at Danger Level 5. It is a fixed value since this is a non-repeatable* story mission.
            - No alteration to the standard story stuff other than what is outlined above.

        * - Technically. The player can always abandon and restart.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

--Run the rest of the includes.
include("callable")
include("randomext")
include("structuredmission")

ESCCUtil = include("esccutil")
LLTEUtil = include("llteutil")

local PirateGenerator = include("pirategenerator")
local AsyncPirateGenerator = include ("asyncpirategenerator")
local AsyncShipGenerator = include ("asyncshipgenerator")
local SectorSpecifics = include ("sectorspecifics")
local Balancing = include ("galaxy")
local SpawnUtility = include ("spawnutility")
local Xsotan = include("story/xsotan")
local Placer = include("placer")

mission._Debug = 0
mission._Name = "Long Live The Empress"

--region #INIT

local llte_storymission_init = initialize
function initialize()
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Long Live The Empress Begin...")

    if onServer()then
        if not _restoring then
            --Standard mission data.
            mission.data.brief = "Long Live the Empress!"
            mission.data.title = "Long Live the Empress!"
			mission.data.icon = "data/textures/icons/cavaliers.png"
			mission.data.priority = 9
            mission.data.description = { 
                "When you decide to face The Guardian, The Cavaliers are ready to stand with you.",
                { text = "Read Adriana's mail", bulletPoint = true, fulfilled = false },
                --If any of these have an X / Y coordinate, they will be updated with the correct location when starting the appropriate phase.
                { text = "Meet Adriana in sector (${_X}:${_Y})", bulletPoint = true, fulfilled = false, visible = false },
                { text = "Kill the Guardian", bulletPoint = true, fulfilled = false, visible = false }
            }

            --[[=====================================================
                CUSTOM MISSION DATA:
                .dangerLevel
                .sector1
                .defeatedGuardian
                .reducedGuardian
                .empressBladeid
                .capitalsSpawned
            =========================================================]]
			mission.data.custom.dangerLevel = 10 --This is a story mission, so we keep things predictable.

            local missionReward = 1500000

            missionData_in = {location = nil, reward = {credits = missionReward}}
    
            llte_storymission_init(missionData_in)
        else
            --Restoring
            llte_storymission_init()
        end
    end
    
    if onClient() then
        if not _restoring then
            initialSync()
        else
            sync()
        end
    end
end

--endregion

--region #PHASE CALLS

mission.globalPhase = {}
mission.globalPhase.triggers = {}
mission.globalPhase.triggers[1] = {
    condition = function()
        local _Sector = Sector()
        local _X, _Y = _Sector:getCoordinates()

        if _X == 0 and _Y == 0 and mission.data.custom.defeatedGuardian then
            local _Guardian = {_Sector:getEntitiesByScript("data/scripts/entity/story/wormholeguardian.lua")}
            if #_Guardian > 0 then
                return true
            end
        else
            return false
        end
    end,
    callback = function()
        local _Sector = Sector()
        local _Guardian = {_Sector:getEntitiesByScript("data/scripts/entity/story/wormholeguardian.lua")}

        local _HPRatio = _Guardian[1].durability / _Guardian[1].maxDurability
        if _HPRatio > 0.75 then
            _Guardian[1].durability = _Guardian[1].maxDurability * 0.75
        end
    end,
    repeating = false
}
mission.globalPhase.onEntityDestroyed = function(_Index)
    local _MethodName = "On Entity Destroyed"
    mission.Log(_MethodName, "Destroyed an entitiy.")
    if onServer() then
        local entity = Entity(_Index)
        if entity:hasScript("data/scripts/entity/story/wormholeguardian.lua") then
            finishAndReward()
        end
    end
end

mission.globalPhase.onAccomplish = function()
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Mail = Mail()
    if mission.data.custom.defeatedGuardian then
        _Mail.text = Format("%1% %2%!\n\nWhen we managed to break the pirate group, I thought we had accomplished something momentous. However, that pales in comparison to what we've accomplished today.\n\nThe Galaxy's wounds won't close immediately, but with the defeat of the Xsotan and our continued efforts to suppress piracy, we have a chance to bring about a solid, lasting peace.\n\nThank you for everything, %2%. It has been a privilege and an honor to fight alongside you. May you find success in your future adventures, %1%!\n\nEmpress Adriana Stahl", _Rank, _Player.name)
    else
        _Mail.text = Format("%1% %2%!\n\nWhen we managed to break the pirate group, I thought we had accomplished something momentous. However, that pales in comparison to what you've accomplished today.\n\nThe Galaxy's wounds won't close immediately, but between your defeat of the Xsotan and our continued efforts to suppress piracy, we have a chance to bring about a solid, lasting peace.\n\nThank you for everything, %2%. May you find success in your future adventures, %1%!\n\nEmpress Adriana Stahl", _Rank, _Player.name)
    end
	_Mail.header = "Peace at last"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
    _Mail.id = "_llte_story5_mailwin"

    local _LMTCS = SystemUpgradeTemplate("data/scripts/systems/militarytcs.lua", Rarity(RarityType.Legendary), Seed(1))
    _Mail:addItem(_LMTCS)

	_Player:addMail(_Mail)
end

mission.phases[1] = {}
mission.phases[1].showUpdateOnEnd = true
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].onBeginServer = function()
    local _MethodName = "Phase 1 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.custom.sector1 = getNextLocation(1)
    local _X, _Y = mission.data.custom.sector1.x, mission.data.custom.sector1.y
    
    local _Player = Player()
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
    local _Mail = Mail()
	_Mail.text = Format("%1% %2%,\n\nI'm sure that you already knew this, but there's a resistance force that has been fighting the Xsotan here for the last 200 years! We encountered them ourselves while dealing with some pirates attacking a local faction. They told us that the Xsotan are guarding something in the center of the galaxy, and that they cannot get close due to the number of Xsotan present. Every attempt they've made has failed!\n\nIf we could just find out what they are guarding... this could be it! This could be our chance to defeat the Xsotan and bring true peace to the galaxy.\nI've been thinking about the artifact that we recovered when we traveled to the center of the galaxy, and I have a plan in mind! If you want our help fighting the Xsotan, we're ready! Come meet us in (%3%:%4%).\n\nEmpress Adriana Stahl", _Rank, _Player.name, _X, _Y)
	_Mail.header = "Defeating the Xsotan"
	_Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	_Mail.id = "_llte_story5_mail1"
	_Player:addMail(_Mail)
end

mission.phases[1].playerCallbacks = 
{
	{
		name = "onMailRead",
        func = function(_PlayerIndex, _MailIndex)
            local _MethodName = "Phase 1 on Mail Read"
			if onServer() then
				local _Player = Player()
				local _Mail = _Player:getMail(_MailIndex)
                if _Mail.id == "_llte_story5_mail1" then
                    mission.Log(_MethodName, "Player read " .. tostring(_Mail.id))
                    Player():setValue("encyclopedia_llte_xsotan_artifact_contd_found", true)
					nextPhase()
				end
			end
		end
	}
}

mission.phases[2] = {}
mission.phases[2].timers = {}
mission.phases[2].triggers = {}
mission.phases[2].triggers[1] = {
    condition = function()
		if onServer() then
			return true
        else
            if mission.data.custom.empressBladeid and Entity(mission.data.custom.empressBladeid) then
                local _ScriptUI = ScriptUI(mission.data.custom.empressBladeid)
                return _ScriptUI ~= nil
            else
                return false
            end
		end
	end,
	callback = function()
		if onClient() then
			onPhase2Dialog(mission.data.custom.empressBladeid)
		end
	end,
	repeating = false
}
mission.phases[2].triggers[2] = {
    condition = function()
        if onClient() then
            return true
        else
            local _Guardian = {Sector():getEntitiesByScript("player/missions/empress/story/story5/weakwormholeguardian.lua")}

            if #_Guardian > 0 then
                local _HPRatio = _Guardian[1].durability / _Guardian[1].maxDurability
                if _HPRatio <= 0.75 then
                    return true
                end
            end
    
            return false
        end
    end,
    callback = function()
        if onServer() then
            local _Sector = Sector()
            local _Guardian = {_Sector:getEntitiesByScript("player/missions/empress/story/story5/weakwormholeguardian.lua")}
    
            ESCCUtil.allXsotanDepart()
            _Sector:deleteEntityJumped(_Guardian[1])
            mission.data.custom.defeatedGuardian = true
            nextPhase()
        end
    end,
    repeating = false
}
mission.phases[2].showUpdateOnEnd = true
mission.phases[2].noBossEncountersTargetSector = true
mission.phases[2].onBeginServer = function()
    local _MethodName = "Phase 2 On Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = mission.data.custom.sector1
    mission.data.description[2].fulfilled = true
    mission.data.description[3].arguments = { _X = mission.data.location.x, _Y = mission.data.location.y }
    mission.data.description[3].visible = true
    mission.data.description[4].visible = true
end

mission.phases[2].onTargetLocationEntered = function(_X, _Y)
	local _MethodName = "Phase 2 on Target Location Entered"
	mission.Log(_MethodName, "Beginning...")

	if not mission.data.custom.capitalsSpawned then
		local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress(false)
        mission.data.custom.empressBladeid = _EmpressBlade.id
        mission.data.custom.capitalsSpawned = true
	end
end

mission.phases[2].onAbandon = function()
    if mission.data.location then
        runFullSectorCleanup()
    end
end

mission.phases[3] = {}
mission.phases[3].timers = {}
mission.phases[3].onBeginServer = function()
    local _MethodName = "Phase 3 on Begin Server"
    mission.Log(_MethodName, "Beginning...")
    mission.data.location = { x = 0, y = 0 }
    mission.data.description[3].fulfilled = true
    if not Entity(mission.data.custom.empressBladeid) then
        --In the (rare) event that the Blade of the Empress was pushed out of the sector due to damage, send a mail telling the player to head to 0:0
        local _Player = Player()
        local _Rank = _Player:getValue("_llte_cavaliers_rank")
        local _Mail = Mail()
	    _Mail.text = Format("%1% %2%!\n\nWhat was that? Was that what the Xsotan are guarding at the center of the galaxy?\nIt vanished from our scanners, so it looks like you managed to drive it out of the sector! If it's on the run, can finish it off! Head to the center of the galaxy! I'm gathering the rest of the fleet.\n\nEmpress Adriana Stahl", _Rank, _Player.name)
	    _Mail.header = "Head to the center!"
	    _Mail.sender = "Empress Adriana Stahl @TheCavaliers"
	    _Mail.id = "_llte_story5_mail2"
	    _Player:addMail(_Mail)
    end
end

mission.phases[3].onBeginClient = function()
    local _MethodName = "Phase 3 on Begin Client"
    if Entity(mission.data.custom.empressBladeid) then
        onPhase3Dialog(mission.data.custom.empressBladeid)
    end
end

mission.phases[3].onTargetLocationEntered = function(_X, _Y)
	local _MethodName = "Phase 3 on Target Location Entered"
	mission.Log(_MethodName, "Beginning...")

	mission.phases[3].timers[1] = {
        time = 20,
        callback = function()
            --respawn the blade of the empress.
            local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress(false)
            MissionUT.deleteOnPlayersLeft(_EmpressBlade)
            mission.data.custom.empressBladeid = _EmpressBlade.id
            local _AI = ShipAI(_EmpressBlade)
            _AI:setAggressive()

            --spawn 3x normal and 3x heavy defenders.
            spawnCavalierShips(3, 3)

            --set up another timer to respawn the cavaliers ships as needed.
            mission.phases[3].timers[2] = {
                time = 120,
                callback = function()
                    local _Sector = Sector()
                    local _X, _Y = _Sector:getCoordinates()
                    if _X ~= 0 or _Y ~= 0 then
                        return
                    end

                    local _EmpressBlade = ESCCUtil.countEntitiesByValue("_llte_empressblade")
                    if _EmpressBlade == 0 then
                        local _EmpressBlade = LLTEUtil.spawnBladeOfEmpress(false)
                        MissionUT.deleteOnPlayersLeft( _EmpressBlade)
                        mission.data.custom.empressBladeid = _EmpressBlade.id
                        local _AI = ShipAI(_EmpressBlade)
                        _AI:setAggressive()
                    end

                    local _Defenders = 0
                    local _HeavyDefenders = 0
                    local _CavShips = {Sector():getEntitiesByScriptValue("is_cavaliers")}
                    for _, _Cav in pairs(_CavShips) do
                        if _Cav:getValue("is_defender") then
                            if _Cav:getValue("is_heavy_defender") then
                                _HeavyDefenders = _HeavyDefenders + 1
                            else
                                _Defenders = _Defenders + 1
                            end
                        end
                    end
                    local _D2S = math.max(3 - _Defenders, 0)
                    local _HD2S = math.max(3 - _HeavyDefenders, 0)
                    mission.Log(_MethodName, "Spawning " .. tostring(_D2S) .. " defenders and " .. tostring(_HD2S) .. " heavy defenders.")
                    spawnCavalierShips(_D2S, _HD2S)
                end,
                repeating = true
            }

            --broadcast a message from the blade of the empress.
            local _Player = Player()
            local _PlayerName = _Player.name

            broadcastEmpressBladeMsg("We stand with you, " .. _PlayerName .. "! All ships, attack the Xsotan!")
        end,
        repeating = false
    }
end

--endregion

--region #SERVER CALLS

function getNextLocation(_Location)
    local _MethodName = "Get Next Location"
    
    mission.Log(_MethodName, "Getting a location.")
    local x, y = Sector():getCoordinates()
	local target = {}
	
	local _NxTable = {
		{ _RingPos = 20, _InBarrier = true }
	}

	local _Nx, _Ny = ESCCUtil.getPosOnRing(x, y, _NxTable[_Location]._RingPos)
	target.x, target.y = MissionUT.getSector(math.floor(_Nx), math.floor(_Ny), 1, 4, false, false, false, false, _NxTable[_Location]._InBarrier)

	if target == nil or target.x == nil or target.y == nil then
		print("Could not get a location - enacting failsafe")
		target.x, target.y = MissionUT.getSector(x, y, 1, 20, false, false, false, false, _NxTable[_Location]._InBarrier)
	end	

    return target
end

function spawnCavalierShips(_Defenders, _HeavyDefenders)
    local _Faction =  Galaxy():findFaction("The Cavaliers")
    local _Generator = AsyncShipGenerator(nil, onCavaliersFinished)
    _Generator:startBatch()

	if _Defenders > 0 then
		for _ = 1, _Defenders do
			_Generator:createDefender(_Faction, PirateGenerator.getGenericPosition())
		end
	end

	if _HeavyDefenders > 0 then
		for _ = 1, _HeavyDefenders do
			_Generator:createHeavyDefender(_Faction, PirateGenerator.getGenericPosition())
		end
	end

    _Generator:endBatch()
end

function onCavaliersFinished(_Generated)
    local _MethodName = "On Cavaliers Finished"
    for _, _S in pairs(_Generated) do
        _S.title = "Cavaliers " .. _S.title
        _S:setValue("npc_chatter", nil)
        _S:setValue("is_cavaliers", true)
        _S:addScript("ai/withdrawatlowhealth.lua", 0.15)
        _S:removeScript("antismuggle.lua")
        LLTEUtil.rebuildShipWeapons(_S, Player():getValue("_llte_cavaliers_strength"))
        
        _S:addScript("entity/story/wormholeguardianally.lua")
        MissionUT.deleteOnPlayersLeft(_S)
        local _AI = ShipAI(_S)
        _AI:setAggressive()
    end
end

function broadcastEmpressBladeMsg(_Msg, ...)
	local _Sector = Sector()
	local _EmpressBlade = {_Sector:getEntitiesByScriptValue("_llte_empressblade")}
	_Sector:broadcastChatMessage(_EmpressBlade[1], ChatMessageType.Normal, _Msg, ...)
end

function runFullSectorCleanup()
    local _X, _Y = Sector():getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        local _EntityTypes = ESCCUtil.allEntityTypes()
        Sector():addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
    else
        local _MX, _MY = mission.data.location.x, mission.data.location.y
        Galaxy():loadSector(_MX, _MY)
        invokeSectorFunction(_MX, _MY, true, "lltesectormonitor.lua", "clearMissionAssets", _MX, _MY, true, true)
    end
end

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    local _Player = Player()
    local _Name = _Player.name
    local _Rank = _Player:getValue("_llte_cavaliers_rank")
	local _Rgen = ESCCUtil.getRand()

    local _WinMsgTable = {
        "This is it, " .. _Name .. "! We did it! We defeated the Xsotan!"
	}
	
	_Player:setValue("_llte_story_5_accomplished", true)

    --Increase reputation by 8
    _Player:setValue("_llte_cavaliers_rep", _Player:getValue("_llte_cavaliers_rep") + 8)
    _Player:sendChatMessage("Adriana Stahl", 0, _WinMsgTable[_Rgen:getInt(1, #_WinMsgTable)])
    reward()
    accomplish()
end

--endregion

--region #CLIENT CALLS

--This worked really well in the last mission! Let's do it again.
function onPhase2Dialog(_ID)
    --At the start of the mission.
    local _MethodName = "On Phase 2 Dialog"
    mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

    local d0 = {}
    local d1 = {}
    local d2 = {}
    local d3 = {}
    local d4 = {}
    local d5 = {}
    local d6 = {}
    local d7 = {}
    local d8 = {}
    local d9 = {}
    local d10 = {}
    local d11 = {}

    local _Talker = "Adriana Stahl"
    local _TalkerColor = MissionUT.getDialogTalkerColor1()
    local _TextColor = MissionUT.getDialogTextColor1()

    local _Talker2 = "Research"
    local _TalkerColor2 = ESCCUtil.getSaneColor(60, 100, 60)
    local _TextColor2 = ESCCUtil.getSaneColor(60, 100, 60)
    
    local _Player = Player()
    local _PlayerRank = _Player:getValue("_llte_cavaliers_rank")
    local _PlayerName = _Player.name

    --d0
    d0.text = _PlayerRank .. " " .. _PlayerName .. "! It's good to see you again!"
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor
    d0.followUp = d1
    
    d1.text = "When you're ready to make the push to the center, The Cavaliers are ready to fight with you! Just say the word, and we'll be there."
    d1.talker = _Talker
    d1.textColor = _TextColor
    d1.talkerColor = _TalkerColor
    d1.answers = {
        { answer = "Let's do this. You said you had a plan?", followUp = d3 },
        { answer = "Thank you, but I'll face this myself.", followUp = d2 }
    }
    
    d2.text = "Okay! I'll be here in case you change your mind. Make us proud, " .. _PlayerRank .. "!"
    d2.talker = _Talker
    d2.textColor = _TextColor
    d2.talkerColor = _TalkerColor
    d2.onEnd = "onPhase2DialogEndNo"
    
    d3.text = "Yes! I was talking about the artifact with our research team. We think we can set it up to draw some Xsotan-"
    d3.talker = _Talker
    d3.textColor = _TextColor
    d3.talkerColor = _TalkerColor
    d3.followUp = d4
    
    d4.text = "Research deck? This is the bridge. We've got power fluctuations in your area and the hangar bay. Are you running any tests?"
    d4.talker = _Talker
    d4.textColor = _TextColor
    d4.talkerColor = _TalkerColor
    d4.followUp = d5
    
    d5.text = "Not that I know of, bridge. Let me che-"
    d5.talker = _Talker2
    d5.textColor = _TextColor2
    d5.talkerColor = _TalkerColor2
    d5.followUp = d6
    
    d6.text = "What's going on down there? Fluctuations are spreading all across the ship!"
    d6.talker = _Talker
    d6.textColor = _TextColor
    d6.talkerColor = _TalkerColor
    d6.followUp = d7
    
    d7.text = "Uhh... I don't know... give me a second. We were examining the artifact, and had just started scans and..."
    d7.talker = _Talker2
    d7.textColor = _TextColor2
    d7.talkerColor = _TalkerColor2
    d7.followUp = d8
    
    d8.text = "Subspace readings are off the charts! What have you done?!"
    d8.talker = _Talker
    d8.textColor = _TextColor
    d8.talkerColor = _TalkerColor
    d8.followUp = d9
    
    d9.text = "The artifact turned itself on! We don't know what it's doing! You have to cut power to the research decks!"
    d9.talker = _Talker2
    d9.textColor = _TextColor2
    d9.talkerColor = _TalkerColor2
    d9.followUp = d10
    
    d10.text = "... Bridge to all stations! Emergency shutdown procedures engaged!"
    d10.talker = _Talker
    d10.textColor = _TextColor
    d10.talkerColor = _TalkerColor
    d10.followUp = d11
    
    d11.text = "CUT IT OFF!"
    d11.talker = _Talker2
    d11.textColor = _TextColor2
    d11.talkerColor = _TalkerColor2
    d11.onEnd = "onPhase2DialogEndYes"

    ScriptUI(_ID):interactShowDialog(d0, false)
end

function onPhase3Dialog(_ID)
    local _MethodName = "On Phase 3 Dialog"
    mission.Log(_MethodName, "Beginning... ID is: " .. tostring(_ID))

    local d0 = {}
    local d1 = {}

    local _Talker = "Adriana Stahl"
    local _TalkerColor = MissionUT.getDialogTalkerColor1()
    local _TextColor = MissionUT.getDialogTextColor1()

    d0.text = "What... what was that?! Was that what the Xsotan are guarding at the center of the galaxy?!"
    d0.talker = _Talker
    d0.textColor = _TextColor
    d0.talkerColor = _TalkerColor
    d0.followUp = d1

    d1.text = "We've got it on the run! If we press the attack we can finish it off! Head to the center! I'll gather the rest of the fleet!"
    d1.talker = _Talker
    d1.textColor = _TextColor
    d1.talkerColor = _TalkerColor
    d1.onEnd = "onPhase3DialogEnd"

    ScriptUI(_ID):interactShowDialog(d0, false)
end

--endregion

--region #CLIENT / SERVER CALLS

function onPhase2DialogEndYes()
	local _MethodName = "On Phase 2 Dialog End [YES]"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase2DialogEndYes")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

        mission.phases[2].timers[1] = {
            time = 2,
            callback = function()
                broadcastEmpressBladeMsg("It's too late! Massive subspace signature inbound! Get ready to engage!")
            end,
            repeating = false
        }
        mission.phases[2].timers[2] = {
            time = 8,
            callback = function()
                Xsotan.createGuardian()
                local _Guardian = {Sector():getEntitiesByScript("data/scripts/entity/story/wormholeguardian.lua")}
                _Guardian[1]:removeScript("wormholeguardian.lua")
                _Guardian[1]:removeScript("legendaryloot.lua") --Just in case?
                _Guardian[1]:addScriptOnce("player/missions/empress/story/story5/weakwormholeguardian.lua")

                local _XWGDura = Durability(_Guardian[1])
                _XWGDura.invincibility = 0.74

                local _EmpressAI = ShipAI(mission.data.custom.empressBladeid)
                _EmpressAI:setAggressive()
            end,
            repeating = false
        }

        --No need to sync.
	end
end
callable(nil, "onPhase2DialogEndYes")

function onPhase2DialogEndNo()
	local _MethodName = "On Phase 2 Dialog End [NO]"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase2DialogEndNo")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

        local _EmpressBlade = Entity(mission.data.custom.empressBladeid)
        _EmpressBlade:addScriptOnce("player/missions/empress/story/story5/lltestory5empressblade.lua")

		--No need to sync.
	end
end
callable(nil, "onPhase2DialogEndNo")

function onPhase3DialogEnd()
	local _MethodName = "On Phase 3 Dialog End"

	if onClient() then
		mission.Log(_MethodName, "Calling on Client - invoking on Server")

		invokeServerFunction("onPhase3DialogEnd")
		return
	else
		mission.Log(_MethodName, "Calling on Server")

        local _Rgen = ESCCUtil.getRand()

        local _EmpressBlade = Entity(mission.data.custom.empressBladeid)
        _EmpressBlade:addScriptOnce("entity/utility/delayeddelete.lua", _Rgen:getFloat(4, 8))
	end
end
callable(nil, "onPhase3DialogEnd")

--endregion