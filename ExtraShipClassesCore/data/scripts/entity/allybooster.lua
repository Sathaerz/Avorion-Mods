package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/?.lua"

include("randomext")

--Don't remove the namespace comment!!! The script could break.
--namespace AllyBooster
AllyBooster = {}
local self = AllyBooster

self._Debug = 0

self._Data = {}

function AllyBooster.initialize(_Values)
    local _MethodName = "Initialize"
    self.Log(_MethodName, "Initializing Ally Booster v19 script on entity.")

    self._Data = _Values or {}

    self._Data._HealWhenBoosting = self._Data._HealWhenBoosting or false
    self._Data._HealPctWhenBoosting = self._Data._HealPctWhenBoosting or 0
    self._Data._BoostCycle = self._Data._BoostCycle or 60
    self._Data._MaxBoostCharges = self._Data._MaxBoostCharges or 3
    self._Data._ChargesMultiplier = self._Data._ChargesMultiplier or 1

    self._Data._BoostTime = 0
    self._Data._BoostCharges = 0

    self.Log(_MethodName, "Heal when boosting : " .. tostring(self._Data._HealWhenBoosting) .. " -- Healing % when boosting : " .. tostring(self._Data._HealPctWhenBoosting))
end

function AllyBooster.getUpdateInterval()
    return 5
end

--region #SERVER CALLS

function AllyBooster.updateServer(_TimeStep)
    local _MethodName = "Update Server"

    local entity = Entity()
    if entity.playerOwned or entity.allianceOwned then
        terminate()
        return
    end

    self._Data._BoostTime = self._Data._BoostTime + _TimeStep

    if self._Data._BoostTime >= self._Data._BoostCycle then
        self._Data._BoostCharges = self._Data._BoostCharges + (1 * self._Data._ChargesMultiplier)
        self._Data._BoostTime = 0
    end

    self.Log(_MethodName, "Boost charges : " .. tostring(self._Data._BoostCharges))
    if self._Data._BoostCharges > 0 then
        self.boost()
    end
end

function AllyBooster.boost()
    local _MethodName = "Boost"
    local _Scripts = {
        "eternal.lua",
        "phasemode.lua",
        "ironcurtain.lua",
        "adaptivedefense.lua",
        "overdrive.lua",
        "afterburn.lua",
        "avenger.lua",
        "frenzy.lua"
    }   

    local _Entity = Entity()
    local _FactionEntities = {Sector():getEntitiesByFaction(_Entity.factionIndex)}
    local _Allies = {}

    for _, _FEn in pairs(_FactionEntities) do
        if _FEn.id ~= _Entity.id and _FEn.type == EntityType.Ship then
            table.insert(_Allies, _FEn)
        end
    end

    if #_Allies > 0 then
        --Get ally to boost / script to boost with
        local _TargetAlly = getRandomEntry(_Allies)

         --Make this a bit smarter and don't try to double add a script to an ally.
        local possibleScripts = {}
        for _, script in pairs(_Scripts) do
            if not _TargetAlly:hasScript(script) then
                table.insert(possibleScripts, script)
            end
        end

        local _AllyScript = getRandomEntry(possibleScripts)

        --Get positions for laser
        local _AllyPosition = _TargetAlly.translationf
        local _MyPosition = _Entity.translationf
    
        self.Log(_MethodName, "Adding script " .. tostring(_AllyScript) .. " to ally.")
    
        _TargetAlly:addScriptOnce(_AllyScript)
        Boarding(_TargetAlly).boardable = false --Boarding boosted ships can cause bugs.

        --Heal the boosted target if applicable.
        if self._Data._HealWhenBoosting then
            self.Log(_MethodName, "Healing!")
            if not _TargetAlly.invincible then
                self.Log(_MethodName, "Target ally not invincible!")
                if _TargetAlly.durability < _TargetAlly.maxDurability then
                    local _HealPct = self._Data._HealPctWhenBoosting / 100
                    local _AllyMaxHull = _TargetAlly.maxDurability
    
                    self.Log(_MethodName, "Healing " .. tostring(_HealPct) .. "%!")
    
                    local _HealAmount = _AllyMaxHull * _HealPct
    
                    self.Log(_MethodName, "Healing " .. tostring(_HealAmount) .. "hp %!")

                    --Don't overcap healing.
                    if _TargetAlly.durability + _HealAmount > _AllyMaxHull then
                        _HealAmount = _AllyMaxHull - _TargetAlly.durability
                    end
    
                    _TargetAlly.durability = _TargetAlly.durability + _HealAmount
                end
            end
        end

        --Update ally title - only allow for this once or we can get weird crap like 'boosted boosted savage devastator'
        if not _TargetAlly:getValue("_increasingthreat_enhanced_title") and not _TargetAlly:getValue("_escc_enhanced_title") then
            _TargetAlly:setValue("_escc_enhanced_title", true)

            local _TitleArgs = _TargetAlly:getTitleArguments()
            _TitleArgs.script = "Boosted "
            local _AppendDirectlyToTitle = _TargetAlly:getValue("_escc_booster_append_title_direct")
            self.Log(_MethodName, "Title args are " .. tostring(_TitleArgs))
            if _AppendDirectlyToTitle then 
                _TargetAlly.title = "Boosted " .. _TargetAlly.title
            else
                local newTitle = "${script}" .. _TargetAlly.title

                self.Log(_MethodName, "Title is : " .. tostring(_TargetAlly.title) .. " new title is: " .. tostring(newTitle))

                _TargetAlly:setTitle(newTitle, _TitleArgs)
            end
        end

        --Finally, consume the boost charge and make the laser.
        self.Log(_MethodName, "Consuming boost charge.")
        self._Data._BoostCharges = self._Data._BoostCharges - 1
        self.createLaser(_MyPosition, _AllyPosition)
    end

    --Regardless of what happens, if we're over the maximum number of charges, make sure to cull.
    self.Log(_MethodName, "At " .. tostring(self._Data._BoostCharges) .. " out of " .. tostring(self._Data._MaxBoostCharges) .. " maximum charges.")
    if self._Data._BoostCharges > self._Data._MaxBoostCharges then
        self._Data._BoostCharges = self._Data._MaxBoostCharges
    end
end

--endregion

--region #CLIENT / SERVER functions

function AllyBooster.createLaser(_From, _To)
    if onServer() then
        broadcastInvokeClientFunction("createLaser", _From, _To)
        return
    end

    local _Color = color or ColorRGB(0, 0.8, 0.5)

    local _Sector = Sector()
    local _Laser = _Sector:createLaser(_From, _To, _Color, 16)

    _Laser.maxAliveTime = 1.5
    _Laser.collision = false
end

function AllyBooster.Log(_MethodName, _Msg)
    if self._Debug == 1 then
        print("[AllyBooster] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SECURE / RESTORE

function AllyBooster.secure()
    local _MethodName = "Secure"
    self.Log(_MethodName, "Securing self._Data")
    return self._Data
end

function AllyBooster.restore(_Values)
    local _MethodName = "Restore"
    self.Log(_MethodName, "Restoring self._Data")
    self._Data = _Values
end

--endregion