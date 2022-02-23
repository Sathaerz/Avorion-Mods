--[[
    Secret Mission
    Destroy Superweapon
    NOTES:
        - Deliberately made to be extremely difficult.
        - I want this to be a superboss that is nearly impossible to defeat.
        - Super tired of players flexing about how 1337 their ships are with 500 bajillion hp / shield / omicron and how easy missions are.
        - The Super Weapon should have either a siege gun that does 233 to 300 million damage per shot, or an instant-kill laser a-la the laser boss.
        - ^ The siege gun should kill a 700 million HP ship in roughly 3 shots. Obviously the instant-kill laser kills things instantly. << >>
        - The secondary weapons on the Super Weapon should be incredibly powerful. Use either long-range lasers or seeker missiles.
        - Siege gun type bosses get a significant damage bonus to secondary weapon banks.
        - Add anti-torpedo equipment, ofc.
    ADDITIONAL REQUIREMENTS TO DO THIS MISSION:
        - Find the chip in Attack Research Base.
    ROUGH OUTLINE
        - Go to the sector.
        - Fight the Super Weapon.
        - Kill it, if you can.
    DANGER LEVEL
        N/A - This mission's difficulty is always the same.
]]
package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")
include("structuredmission")

ESCCUtil = include("esccutil")
PariahUtility = include("pariahutility")

local SectorSpecifics = include("sectorspecifics")
local Balancing = include("galaxy")

mission._Debug = 0
mission._Name = "Destroy Superweapon"

--region #INIT

--Standard mission data.
mission.data.brief = "Destroy Superweapon"
mission.data.title = "Destroy Superweapon"
mission.data.icon = "data/textures/icons/hazard-sign.png"
mission.data.priority = 8
mission.data.description = {
    "In the ruins of the research lab, you seem to have found schematics and location data for an extremely powerful superweapon.",
    { text = "Judging from the schematics, it will be nearly impossible to defeat. You will undoubtedly be regarded as a hero by ${_FACTION} if you manage to destroy it." },
    { text = "The Superweapon seems to be located in sector (${location.x}:${location.y})." },
    { text = "Destroy the Superweapon", bulletPoint = true, fulfilled = false }
}

local attackresearchbase_init = initialize
function initialize(_Data_in)
    local _MethodName = "initialize"
    mission.Log(_MethodName, "Beginning...")

    if onServer()then
        if not _restoring then
            mission.Log(_MethodName, "Calling on server.")

            local _Rgen = ESCCUtil.getRand()

            --[[=====================================================
                CUSTOM MISSION DATA:
                .friendlyFaction
                .mainType
                .secondaryWeapons
                .gordianKnotid
            =========================================================]]
            mission.data.custom.friendlyFaction = _Data_in.friendlyFaction
            mission.data.custom.mainType = _Data_in.superweaponMain
            mission.data.custom.secondaryWeapons = _Data_in.superweaponSecondary

            mission.data.description[2].arguments = { _FACTION = Faction(mission.data.custom.friendlyFaction).name}

            _Data_in.reward = { credits = 100000000000, paymentMessage = "Earned %1% credits for destroying the Superweapon." }

            --Run standard initialization
            attackresearchbase_init(_Data_in)
        else
            --Restoring
            attackresearchbase_init()
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

mission.phases[1] = {}
mission.phases[1].noBossEncountersTargetSector = true
mission.phases[1].noPlayerEventsTargetSector = true
mission.phases[1].noLocalPlayerEventsTargetSector = true
mission.phases[1].onTargetLocationEntered = function(_X, _Y) 
    local _MethodName = "Phase 1 on Target Location Entered"
    
    if not mission.data.custom.gordianKnotid then
        local _GordianKnot = PariahUtility.spawnSuperWeapon(mission.data.custom.mainType, mission.data.custom.secondaryWeapons)
        mission.data.custom.gordianKnotid = _GordianKnot.id
    end
end

mission.phases[1].onTargetLocationArrivalConfirmed = function(_X, _Y)
    local _MethodName = "Phase 1 on Target Location Arrival Confirmed"
    mission.Log(_MethodName, "Beginning...")

    local _Rgen = ESCCUtil.getRand()

    local _Taunts = {
        "Let's fight, Captain. We'll settle this in battle.",
        "Prepare yourself!",
        "You don't want me as your enemy.",
        "It's time.",
        "You're a long way from home, aren't you?",
        "Remember, you wanted this.",
        "Have you the strength?",
        "What have we here?",
        "We all make mistakes. Don't you think, Captain?"
    }

    local _GordianKnot = Entity(mission.data.custom.gordianKnotid)
    Sector():broadcastChatMessage(_GordianKnot, ChatMessageType.Chatter, _Taunts[_Rgen:getInt(1, #_Taunts)])
end

mission.phases[1].onEntityDestroyed = function(_ID, _LastDamageInflictor)
    local _MethodName = "Phase 1 On Entity Destroyed"
    mission.Log(_MethodName, "Beginning...")

    if _ID == mission.data.custom.gordianKnotid then
        finishAndReward()
    end
end

--endregion

--region #SERVER CALLS

function finishAndReward()
    local _MethodName = "Finish and Reward"
    mission.Log(_MethodName, "Running win condition.")

    --We have to manually set the reputation here because we can't carry over the giver from the previous mission to the chip to this mission.
    local _MissionDoer = Player().craftFaction or Player()
    local _Faction = Faction(mission.data.custom.friendlyFaction)
    local _Relation = _MissionDoer:getRelation(mission.data.custom.friendlyFaction)
    local _Galaxy = Galaxy()

    _Galaxy:setFactionRelations(_Faction, _MissionDoer, 100000)
    if _Relation.status ~= RelationStatus.Neutral and _Relation.status ~= RelationStatus.Allies then
        _Galaxy:setFactionRelationStatus(_Faction, _MissionDoer, RelationStatus.Neutral)
    end

    Player():sendChatMessage(_Faction.name, 0, "That... that was incredible! You are truly a hero. Please accept this reward.")
    reward()
    accomplish()
end

--endregion