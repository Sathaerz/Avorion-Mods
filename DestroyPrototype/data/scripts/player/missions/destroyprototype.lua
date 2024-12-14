package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

local Balancing = include ("galaxy")
local PirateGen = include("pirategenerator")
local AsyncPirateGen = include ("asyncpirategenerator")
local PrototypeGenerator = include("destroyprotogenerator")
local SpawnUtility = include ("spawnutility")
local ShipUtility = include ("shiputility")
MissionUT = include("missionutility")
include("relations")
include("mission")
include("utility")
include("stringutility")
include("callable")

missionData.brief = "Destroy Prototype Battleship"%_t --missionData.brief shows on the left-hand side in the list.
missionData.title = "Destroy Prototype Battleship"%_t --missionData.title shows whenever the mission is accepted / accomplished / abandoned.

function getUpdateInterval()
    return 2
end

function initialize(giverId, x, y, reward, punishment, dangerValue)

    initMissionCallbacks()

    if onClient() then
        sync()
	else
		Player():registerCallback("onSectorEntered", "onSectorEntered")
		Player():registerCallback("onSectorLeft", "onSectorLeft")
		Player():registerCallback("onSectorArrivalConfirmed", "onSectorArrivalConfirmed")
    end
	
	if onServer() and not _restoring then
		local station = Entity(giverId)
		local offeringFaction = Faction(station.factionIndex)
		local dAggroValue = offeringFaction:getTrait("aggressive")	

		missionData.giver = station.id
		missionData.factionIndex = station.factionIndex
		missionData.location = {x = x, y = y}
		missionData.dangerValue = dangerValue
		missionData.stationName  = station.name
		missionData.stationTitle = station.translatedTitle
		missionData.reward = reward
		missionData.punishment = punishment
		--Get the description / accomplish + fail messages -- these are initialized here instead of being static values at the start of the script (unlike most other misisons)
		--this is because they depend on the aggressive trait value of the faction (and the random danger value), which is impossible to determine before the script has run.
		local bulletinDescription = fmtMissionDescription(dAggroValue, missionData.dangerValue)
		missionData.description = {}
		missionData.description[1] = "You recieved the following request from the " .. Sector().name .. " " .. station.translatedTitle .. ":"
		missionData.description[2] = bulletinDescription % missionData.location
		missionData.description[3] = "- Investigate (${x}:${y})" % missionData.location
		missionData.accomplishMessage = fmtWinMessage(dAggroValue)
		missionData.failMessage = fmtFailMessage(dAggroValue)
		--Variables used to keep various events from happening twice.
		missionData.spawnedEnemies = false
		missionData.spawnedSecondWave = false
		missionData.bshipTauntSent = false
	end
end

--mimics structuredmission.reward, becasue Mission doesn't have a similar function call. Pretty boilerplate but eh, what can you do.
function giveReward()
	if onClient() then return end

	local receiver = Player().craftFaction or Player()
	local r = missionData.reward
	
	if r.credits
		or r.iron
		or r.titanium
		or r.naonite
		or r.trinium
		or r.xanion
		or r.ogonite
		or r.avorion then
		
		receiver:receive(r.paymentMessage or "", r.credits or 0, r.iron or 0, r.titanium or 0, r.naonite or 0, r.trinium or 0, r.xanion or 0, r.ogonite or 0, r.avorion or 0)
	end
	
    if r.relations and missionData.factionIndex then
        local faction = Faction(missionData.factionIndex)
        if faction and faction.isAIFaction then
            changeRelations(receiver, faction, r.relations, r.relationChangeType, true, false)
        end
    end
end

function givePunishment()
	if onClient() then return end

    local punishee = Player().craftFaction or Player()
    local p = missionData.punishment

    if p.credits
        or p.iron
        or p.titanium
        or p.naonite
        or p.trinium
        or p.xanion
        or p.ogonite
        or p.avorion then

        punishee:pay(p.paymentMessage or "", 
					math.abs(p.credits or 0),
					math.abs(p.iron or 0),
					math.abs(p.titanium or 0),
					math.abs(p.naonite or 0),
					math.abs(p.trinium or 0),
					math.abs(p.xanion or 0),
					math.abs(p.ogonite or 0),
					math.abs(p.avorion or 0))
    end

	if p.relations and missionData.factionIndex then
        local faction = Faction(missionData.factionIndex)
        if faction and faction.isAIFaction then
            changeRelations(punishee, faction, -math.abs(p.relations), nil)
        end
    end
end

--Functional calls
function onSectorLeft(player, x, y)
	if missionData.location and missionData.location.x and missionData.location.y then
		if x == missionData.location.x and y == missionData.location.y then
			if onTargetLocationLeft then
				onTargetLocationLeft(x, y)
			end
		end
	end
end

function onSectorArrivalConfirmed(player, x, y)
	if missionData.location and missionData.location.x and missionData.location.y then
		if x == missionData.location.x and y == missionData.location.y then
			if onTargetLocationConfirmed then
				onTargetLocationConfirmed(x, y)
			end
		end
	end
end

function onTargetLocationEntered(x, y)
	if not missionData.spawnedEnemies then
		--Spawn enemies
		spawnEnemies(missionData.dangerValue)
		missionData.spawnedEnemies = true
	end
end

function onTargetLocationLeft(x, y)
	local sender = missionData.stationTitle
    Player():sendChatMessage(sender, 0, missionData.failMessage)
	fail()
	givePunishment()
end

function onTargetLocationConfirmed(x, y)
	if missionData.spawnedEnemies and not missionData.bshipTauntSent then
		--print("sending taunt")
		local bshiptaunts = {
			"You'll never see this coming!"%_t,
			"It seems we've been found out! Take them down now!"%_t,
			"I guess this is it. At least we'll be taking you with us."%_t,
			"Witness us!"%_t,
			"Never thought we'd die running from a do-gooder."%_t,
			"To infinity! And beyond!"%_t
			}
		local bshiptaunt = bshiptaunts[random():getInt(1, #bshiptaunts)]
		Sector():broadcastChatMessage(bship, ChatMessageType.Chatter, bshiptaunt)
		missionData.bshipTauntSent = true
	end
end

function onRestore()
	--Re-register callback for battleship just in case the player quit / restarted the game mid-mission.
	--if missionData.bshipID then
	--	print("Attempting to reattach callbacks to main ship")
	--else
	--	print("No battleship ID saved")
	--end
	bship = Entity(missionData.bshipID)
	bship:registerCallback("onDestroyed", "DestroyPrototype_onTargetDestroyed")
	if missionData.dangerValue == 10 then
		bship:registerCallback("onDamaged", "DestroyPrototype_onTargetDamaged")
	end
		for _, ship in pairs({Sector():getEntitiesByFaction(PirateGen:getPirateFaction().index)}) do
		if ship.isShip then
			ship:addScript("deleteonplayersleft.lua")
		end
    end
end

function updateServer(timeStep)
    updateMission(timeStep)

    if missionData.dangerValue == 10 and not missionData.spawnedSecondWave then
		--Check # of ships left.
		local counter = 0
		for _, ship in pairs({Sector():getEntitiesByFaction(PirateGen:getPirateFaction().index)}) do
			if ship.isShip then
				counter = counter + 1
			end
		end
		
		if counter == 1 then
			--only 1 ship left -- almost certainly the prototype. Spawn the 2nd wave.
			spawnSecondWave()
		end
	end
end

--Custom callbacks.
function DestroyPrototype_onTargetDestroyed()
	--When the prototype is destroyed, that's it. The mission is won.
	--Have all remaining pirates warp out + one of them send a curse to the player.
	local sentTaunt = false
	for _, ship in pairs({Sector():getEntitiesByFaction(PirateGen:getPirateFaction().index)}) do
		if ship.isShip and not sentTaunt then
			--It doesn't make sense for the main enemy ship to send the taunt after it was destroyed.
			if ship.id.string ~= missionData.bshipID.string then
				local defeatedtaunts = {
					"No!!! NO!!!"%_t,
					"Damn you! We'll remember this!"%_t,
					"We'll get you next time!"%_t,
					"We'll be watching, and we'll be waiting. When you least expect it... that's when we'll strike."%_t,
					"We'll see you sucking vacuum for this!"%_t,
					"The day is yours, but revenge will be ours!"%_t
					}
				local defeatedtaunt = defeatedtaunts[random():getInt(1, #defeatedtaunts)]
				Sector():broadcastChatMessage(ship, ChatMessageType.Chatter, defeatedtaunt)
				sentTaunt = true
			end
		end
        ship:addScriptOnce("entity/utility/delayeddelete.lua", random():getFloat(4, 7))
    end
	
	local sender = missionData.stationTitle
    Player():sendChatMessage(sender, 0, missionData.accomplishMessage)
	finish()
	giveReward()
end

function DestroyPrototype_onTargetDamaged()
	local bshiphull = bship.durability
	local bshiphullThreshold = bship.maxDurability / 2
	if bshiphull < bshiphullThreshold and not missionData.spawnedSecondWave then
		spawnSecondWave()
	end
end

function onSecondWaveSpawned(generated)
	SpawnUtility.addEnemyBuffs(generated)
	local sentTaunt = false
	local bshipName = Entity(missionData.bshipID).name
	for _, ship in pairs(generated) do
        if not sentTaunt then
			local reinforcementtaunts = {
				"Reinforcements on station! Stay strong, " .. bshipName .. "!"%_t,
				"We'll tear you to pieces!"%_t,
				"If the " .. bshipName .. " is destroyed, this is all for nothing! Protect it with your lives!"%_t,
				"All ships, weapons to full! Engage! Engage! Engage!"%_t,
				"Hang tight " .. bshipName .. ", the cavalry is here!"%_t,
				"Mind if we cut in?"%_t
				}
			local reinforcementtaunt = reinforcementtaunts[random():getInt(1, #reinforcementtaunts)]
			Sector():broadcastChatMessage(ship, ChatMessageType.Chatter, reinforcementtaunt)
			sentTaunt = true
		end
		ship:addScript("deleteonplayersleft.lua")
    end
end

--Custom (but still 'functional') calls.
function spawnEnemies(dangerValue)
	--print("attempting to spawn enemies")
	--Get nearest pirate faction.
	--Spawn one large + powerful ship -- this is the battleship in question.
	PirateGen.pirateLevel = Balancing_GetPirateLevel(missionData.location.x, missionData.location.y) --This prevents PirateGen / AsyncPirateGen from creating pirates from different factions.
	bship = PrototypeGenerator.create(DestroyPrototype_getEnemyPosition(), Faction(missionData.factionIndex), PirateGen:getPirateFaction(), dangerValue)
	bship:registerCallback("onDestroyed", "DestroyPrototype_onTargetDestroyed")
	bship:addScript("deleteonplayersleft.lua")
	
	missionData.bshipID = bship.id
	print("mission battleship id is: " .. missionData.bshipID.string)
	
	--If dangerValue is high enough, spawn additonal enemies.
	local firstWaveMin = 2
	local firstWaveMax = 4
	if dangerValue >= 8 then
		firstWaveMax = firstWaveMax + 1
	end
	if dangerValue == 10 then
		firstWaveMin = firstWaveMin + 1
		firstWaveMax = firstWaveMax + 1
	end

	--Spawn the first wave. Appears on danger value 6+
	if dangerValue > 5 then
		local firstWaveCount = random():getInt(firstWaveMin, firstWaveMax)

		for idx=1,firstWaveCount,1 do
			bandit = PirateGen.createBandit(DestroyPrototype_getEnemyPosition())
			bandit:addScript("deleteonplayersleft.lua")
		end
	end
	--If dangerValue is max (10) -- spawn another wave of enemies after the battleship hits 50%.
	if dangerValue == 10 then
		bship:registerCallback("onDamaged", "DestroyPrototype_onTargetDamaged")
	end
end

function spawnSecondWave()
	missionData.spawnedSecondWave = true --Don't spawn it again.
	--We'll rip this from wave generator.
	--Make 1-3 bandits, 1-2 pirates, 0-1 marauder, 0-1 raider
	local banditCount = random():getInt(1, 3)
	local pirateCount = random():getInt(1, 2)
	local marauderCount = random():getInt(0, 1)
	local raiderCount = random():getInt(0, 1)
	
	--Get values for matrix.
	local dir = normalize(vec3(getFloat(-1, 1), getFloat(-1, 1), getFloat(-1, 1)))
    local up = vec3(0, 1, 0)
    local right = normalize(cross(dir, up))
    local pos = dir * 1000
    local distance = 150
	
	local sWaveGen = AsyncPirateGen(nil, onSecondWaveSpawned)
    sWaveGen:startBatch()

    local counter = 0
	
	for idx=1,banditCount,1 do
		sWaveGen:createScaledBandit(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
		counter = counter + 1
	end
	for idx=1,pirateCount,1 do
		sWaveGen:createScaledPirate(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
		counter = counter + 1
	end
	if marauderCount > 0 then
		sWaveGen:createScaledMarauder(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
		counter = counter + 1
	end
	if raiderCount > 0 then
		sWaveGen:createScaledRaider(MatrixLookUpPosition(-dir, up, pos + right * distance * counter))
		counter = counter + 1
	end
	
	sWaveGen:endBatch()
end

function DestroyPrototype_getEnemyPosition()
	local pos = random():getVector(-1000,1000)
	return MatrixLookUpPosition(-pos, vec3(0, 1, 0), pos)
end

--getBulletin and getBulletin related values / calls, including messages, etc.
--No real need to allow these to be acessible outside this mod -- they are just mission descriptions that vary by the aggressive value of the faction and the danger value of the mission.
--Peaceful description
local psDesc1 = [[We were developing a prototype self-defense system when it was captured by a gang of pirates! We regret that things have come to this, but the system must be destroyed before they have a chance to reverse-engineer the technology and enhance their ships. Or worse, sell it to our enemies. Unfortunately, our forces are insufficient for the task.]]
local psDesc2 = [[Signals from the battleship's radar module show that it is being escorted. Use caution on approach.]]
local psDesc3 = [[The tracker on the stolen ship shows that it is located at (${x}:${y}). Please do what needs to be done.]]

--Aggressive description
local asDesc1 = [[Some scumbag pirates stole one of our new battleships! It was going to be the pride of our new fleet, but now it's as good as scrap metal! An example must be made. The loss of the materiel is regrettable, but those who would steal from us must be made to realize the consequences of their actions.]]
local asDesc2 = [[Intel says that some of the bandits ran off with their prize. It doesn't matter. They'll pay with the rest of them.]]
local asDesc3 = [[We tracked it to (${x}:${y}). Destroy the ship, and kill all parties involved.]]

--Moderate description
local msDesc1 = [[We need your help. Our new battleship was hijacked by pirates and we can't afford to leave it in enemy hands, or else they'll be able to reverse-engineer it and use the experimental technology to enhance their own ships. We need you to destroy it. Don't worry - we'll reward you for doing so. We think the compensation is sufficient for the task.]]
local msDesc2 = [[We believe that is being escorted by additional pirate ships. Use caution on approach.]]
local msDesc3 = [[It seems that they didn't disable the ship's tracking beacon. It shows that the ship is currently in (${x}:${y}).]]

--Accomplish messages.
local winMsg = {
	[[Thanks. Here's your reward, as promised.]], --Moderate
	[[Thank you for taking care of that scum. We transferred the reward to your account.]], --Aggressive
	[[Thank you for your trouble. We transferred the reward to your account.]] --Peaceful
}

--Failure messages.
local failMsg = {
	[[You weren't able to destroy it? That's too bad. We'll find someone else to take care of it.]], --Moderate
	[[We see that you weren't up for the task. Unfortunate, but unsurprising. We should have taken care of it ourselves.]], --Aggressive
	[[You weren't able to destroy it? This is bad... we were low on options to begin with...]] --Peaceful
}

function fmtMissionDescription(aggroVal, dangerValue)
	local descriptionType = 1 --Moderate
	if aggroVal >= 0.5 then
		descriptionType = 2 --Aggressive
	elseif aggroVal <= -0.5 then
		descriptionType = 3 --Peaceful
	end
	
	local description = ""
	if descriptionType == 1 then
		description = msDesc1
		if dangerValue >= 6 then
			description = description .. "\n\n" .. msDesc2
		end
		description = description .. "\n\n" .. msDesc3
	elseif descriptionType == 2 then
		description = asDesc1
		if dangerValue >= 6 then
			description = description .. "\n\n" .. asDesc2
		end
		description = description .. "\n\n" .. asDesc3
	elseif descriptionType == 3 then
		description = psDesc1
		if dangerValue >= 6 then
			description = description .. "\n\n" .. psDesc2
		end
		description = description .. "\n\n" .. psDesc3
	end

	return description
end

function fmtFailMessage(aggroVal)
	local msgType = 1 --Moderate
	if aggroVal >= 0.5 then
		msgType = 2 --Aggressive
	elseif aggroVal <= -0.5 then
		msgType = 3 --Peaceful
	end

	return failMsg[msgType]
end

function fmtWinMessage(aggroVal)
	local msgType = 1 --Moderate
	if aggroVal >= 0.5 then
		msgType = 2 --Aggressive
	elseif aggroVal <= -0.5 then
		msgType = 3 --Peaceful
	end
	
	return winMsg[msgType]
end

--Add this mission to bulletin boards of stations.
function getBulletin(station)
	--This is not offered from player / alliance stations. There's too much stuff that either breaks or doesn't make sense. How would a player not realize one of their own ships got hijacked?
	local offeringFaction = Faction(station.factionIndex)
	if offeringFaction and (offeringFaction.isPlayer or offeringFaction.isAlliance) then return end
	--[[Script: Player jumps into sector and kills the prototype battleship -- a very large and powerful enemy. Very simple and straightforward -- not much of a twist to this one.	
	]]
	--print("running getBulletin")
	--Get coordinates first.
	local target = {}
	local x, y = Sector():getCoordinates()
	local giverInsideBarrier = MissionUT.checkSectorInsideBarrier(x, y)
	target.x, target.y = MissionUT.getSector(x, y, 7, 20, false, false, false, false)
	
	if not target.x or not target.y or giverInsideBarrier ~= MissionUT.checkSectorInsideBarrier(target.x, target.y) then return end

	local fFaction = Faction(station.factionIndex)
	local dAggroValue = fFaction:getTrait("aggressive")	
	--I don't like how formulaic most Avorion missions are, so we'll throw in a hidden "danger value" to spice things up a bit.
	--[[Danger value effects:
		Please note that these effects are cumulative -- i.e. the mission listed difficulty / description will change at danger level 6-7, but also at 8+ as well.
		- Danger Value 1 - 5
			Prototype Scale = 40
			Prototype Turret Factor = 3
			Prototype Damage Factor = 3
			Prototype Loot = 3 Turrets guaranteed
		- Danger Value 6 - 7
			Initial group of 2-4 bandits spawns with Prototype
			Prototype Scale = +10 (50 total)
			Prototype Turret Factor = +1 (4 total)
			Mission listed difficulty / description changed slightly to hint that this one is harder.
		- Danger Value 8 - 9
			Initial group of 2-5 (+1 max) bandits spawns with Prototype
			Prototype Scale = +10 (60 total)
			Prototype Turret Factor = +1 (5 total)
		- Danger Value 10
			Initial group of 3-6 (+1 min, +1 max) bandits spawns with Prototype
			Prototype Scale = +10 (70 total)
			Prototype Turret Factor = +1 (6 total)
			Prototype Damage Factor = +1 (4 total)
			Prototype Loot = +1 (total 4) Turrets guaranteed
			When either of the following conditions are met, an additional wave of 1-3 Bandits, 1-2 Pirates, 0-1 Marauders, and 0-1 Raiders spawn
				- Prototype drops to 50% health or lower
				- All ships other than the Prototype are destroyed
		- Danger Value [Any]
			Prototype always gets a random bonus to its damage factor ranging from (1 to [Danger Level]) / 50 -- this means it gets anywhere from a 2 to 20% bonus.
	]]
	local dangerValue = random():getInt(1, 10)
	
	local description = fmtMissionDescription(dAggroValue, dangerValue)
	local sDifficulty = "Difficult /*difficulty*/"%_t
	if dangerValue >= 6 then
		sDifficulty = "Extreme /*difficulty*/"%_t
	end

	local _BaseReward = 100000
	if dangerValue >= 5 then
		_BaseReward = _BaseReward + 10000
	end
	if dangerValue == 10 then
		_BaseReward = _BaseReward + 15000
	end
	_BaseReward = _BaseReward * Balancing.GetSectorRewardFactor(Sector():getCoordinates())
	if giverInsideBarrier then
		_BaseReward = _BaseReward * 2
	end
	local _Version = GameVersion()
    if _Version.major > 1 then
        _BaseReward = _BaseReward * 1.33
    end

    reward = {credits = _BaseReward, relations = 8000, paymentMessage = "Earned %1% for destroying the prototype."}
	punishment = {relations = reward.relations}

    local bulletin =
    {
        brief = "Destroy Prototype Battleship"%_t,
        description = description,
        difficulty = sDifficulty,
        reward = "$${reward}",
        script = "missions/destroyprototype.lua",
        arguments = {station.index, target.x, target.y, reward, punishment, dangerValue},
        formatArguments = {x = target.x, y = target.y, reward = createMonetaryString(reward.credits)},
        msg = "Thank you. We have tracked the battleship to \\s(%i:%i). Please destroy it.",
        entityTitle = station.title,
        entityTitleArgs = station:getTitleArguments(),
        onAccept = [[
            local self, player = ...
            local title = self.entityTitle % self.entityTitleArgs
            player:sendChatMessage(title, 0, self.msg, self.formatArguments.x, self.formatArguments.y)
        ]]
    }

    return bulletin
end