Scrapyard._Tag = "wreckinghavoc_invalidredemption"
Scrapyard._Debug = 0
Scrapyard._OriginalValue = nil

--Server
local originalValue = Scrapyard._OriginalValue

local _SellWrecksTab = nil
local _SellWrecksClampFrame = nil
local _CanBroadcast = true
local _SellWreckButtons = {}

--region #CLIENT FUNCTIONS

local SellWreckages_initialize = Scrapyard.initialize
function Scrapyard.initialize()
    SellWreckages_initialize()
    if onServer() then
        Sector():registerCallback("onEntityUndocked", "onEntityUndocked")
    end
end

local SellWreckages_initUI = Scrapyard.initUI
function Scrapyard.initUI()
    local _MethodName = "Init UI"
    SellWreckages_initUI()

    --Tab for selling wrecks.
    _SellWrecksTab = tabbedWindow:createTab("Sell Wrecks", "data/textures/icons/scrap-metal.png", "Sell docked wreckages to the scrapyard.")
    size = _SellWrecksTab.size

    local textField = _SellWrecksTab:createTextField(Rect(0, 0, size.x, 50), "Sell wreckages docked to your ship. You will only get a portion of the value of the wreckage. If the scrapyard is running low on wrecks, it may pay more.")
    textField.padding = 7

    _SellWrecksClampFrame = _SellWrecksTab:createScrollFrame(Rect(0, 55, size.x, size.y - 55))

    sellWrecksButton = _SellWrecksTab:createButton(Rect(0, size.y - 40, 160, size.y), "Sell All Wrecks"%_t, "onSellWrecksButtonPressed")
end

local SellWreckages_onShowWindow = Scrapyard.onShowWindow
function Scrapyard.onShowWindow()
    local _MethodName = "On Show Window"
    SellWreckages_onShowWindow()
    _SellWrecksClampFrame:clear()
    _SellWreckButtons = {}
    local _Size = _SellWrecksClampFrame.size

    local _FontSize = 16
    local _LabelHeight = 45
    local _UIOffset = 0

    local _TotalValue = 0

    local _CurrentShip = Entity(Player().craftIndex)
    local _Clamps = DockingClamps(_CurrentShip)
    local _DockedEntities = {_Clamps:getDockedEntities()}

    Scrapyard.Log(_MethodName, tostring(#_DockedEntities) .. " entities are docked.")

    if #_DockedEntities > 0 then
        for _, _DockedID in pairs(_DockedEntities) do
            local _DockedEntity = Entity(_DockedID)
            Scrapyard.Log(_MethodName, "Type of docked entity: " .. tostring(_DockedEntity.type))
            if _DockedEntity.type == EntityType.Wreckage then
                local _Index = tostring(_DockedID)

                if not _DockedEntity:getValue(Scrapyard._Tag) then
                    local _PlanValue = (Scrapyard.getFullShipEntityValue(_DockedEntity) / 2)
                    _TotalValue = _TotalValue + _PlanValue
    
                    Scrapyard.Log(_MethodName, "Untagged wreck.")
                    _SellWrecksClampFrame:createLabel(vec2(5, 12 + (_LabelHeight * _UIOffset)), "Wreck docked to clamp " .. tostring(_UIOffset + 1) .. ":  " .. createMonetaryString(_PlanValue), _FontSize)
                    _SellWreckButtons[_Index] = _SellWrecksClampFrame:createButton(Rect(_Size.x - 180, 5 + (_LabelHeight * _UIOffset), _Size.x - 30, _LabelHeight + (_LabelHeight * _UIOffset)), "Sell This Wreck", "onSellSpecificWreckButtonPressed")
                else
                    Scrapyard.Log(_MethodName, "Tagged wreck.")
                    _SellWrecksClampFrame:createLabel(vec2(5, 5 + (_LabelHeight * _UIOffset)), "Wreck docked to clamp " .. tostring(_UIOffset + 1) .. " is tagged and cannot be sold.", _FontSize)
                end
            end
    
            _UIOffset = _UIOffset + 1
        end
        _SellWrecksClampFrame:createLabel(vec2(5, 5 + (_LabelHeight * (_UIOffset + 0.5))), "Total value:  " .. createMonetaryString(_TotalValue), _FontSize)
    else
        _SellWrecksClampFrame:createLabel(vec2(5, 5), "You currently have no wrecks docked.", _FontSize)
    end
end

function Scrapyard.onSellWrecksButtonPressed()
    invokeServerFunction("sellWrecks")
end

function Scrapyard.onSellSpecificWreckButtonPressed(_Button)
    local _MethodName = "On Sell Specific Wreck Button Pressed"
    Scrapyard.Log(_MethodName, "Beginning - _Button is : " .. tostring(_Button))
    for _, _B in pairs(_SellWreckButtons) do
        if _B.index == _Button.index then
            Scrapyard.Log(_MethodName, "Found the button for this clamp.")
            invokeServerFunction("sellWreck", _)
        end
    end
end

function Scrapyard.onBroadcast()
    displayChatMessage("Thanks for doing business with us. Please, do come again.", Entity().title, 0)
end

--endregion

--region #CLIENT / SERVER FUNCTIONS

function Scrapyard.getAllWreckValues()
    local _TotalWreckValues = 0
    local _TaggedWrecks = { Sector():getEntitiesByScriptValue(Scrapyard._Tag) }
    for _, _Wreck in pairs(_TaggedWrecks) do
        if _Wreck:hasComponent(ComponentType.MoneyDropper) then
            _TotalWreckValues = _TotalWreckValues + Scrapyard.getFullShipEntityValue(_Wreck)
        end
    end

    return _TotalWreckValues
end

function Scrapyard.getFullShipValue(_Plan)
    local _PlanValue = _Plan:getMoneyValue()
    local _ResValue = {_Plan:getResourceValue()}

    for _MAT, _VAL in pairs(_ResValue) do
        _PlanValue = _PlanValue + (Material(_MAT - 1).costFactor * _VAL * 10)
    end

    --Return the full value. We'll use it or modify it accordingly elsewhere.
    return _PlanValue
end

function Scrapyard.getFullShipEntityValue(_Entity)
    local _PlanValue = _Entity:getPlanMoneyValue()
    local _ResValue = {_Entity:getPlanResourceValue()}

    for _MAT, _VAL in pairs(_ResValue) do
        _PlanValue = _PlanValue + (Material(_MAT - 1).costFactor * _VAL * 10)
    end

    return _PlanValue
end

function Scrapyard.onEntityUndocked(_DockerID, _DockeeID)
    local _MethodName = "On Entity Undocked"
    Scrapyard.Log(_MethodName, "Beginning...")
    local _DockerShip = Entity(_DockerID)
    local _DockerFaction = Faction(_DockerShip.factionIndex)

    if _DockerFaction.isPlayer or _DockerFaction.isAlliance then
        local _Player = Player(_DockerFaction.index)

        if _DockerFaction.isPlayer then
            if _Player:hasScript("wreckinghavoc.lua") then
                Scrapyard.Log(_MethodName, "Player has mission that pays on undock - player is already getting paid twice. Don't triple pay.")
                return
            end
        end
        local _DockedEntity = Entity(_DockeeID)

        if _DockedEntity.type == EntityType.Wreckage then
            if not _DockedEntity:getValue(Scrapyard._Tag) then
                local _Plan = _DockedEntity:getMovePlan()
                _DockedEntity:setPlan(BlockPlan())
                local _Payout = (Scrapyard.getFullShipValue(_Plan) / 2)

                local _Sector = Sector()

                local _Velocity = Velocity(_DockedEntity)
                local _Wreck = _Sector:createWreckage(_Plan, _DockedEntity.position)
                local _WreckVelocity = Velocity(_Wreck)

                _Wreck:setValue(Scrapyard._Tag, true)
                _WreckVelocity:addVelocity(_Velocity.velocityf)

                _Sector:deleteEntity(_DockedEntity)

                if _Payout > 0 then
                    _DockerFaction:receive(Format("Received %1% Credits for selling a wreckage to a scrapyard.", createMonetaryString(_Payout)), _Payout)
                    changeRelations(Faction(), _DockerFaction, 75, RelationChangeType.ResourceTrade)
                    if _CanBroadcast then
                        invokeClientFunction(_Player, "onBroadcast")
                        _CanBroadcast = false
                    end
                else
                    Scrapyard.Log(_MethodName, "Payout was 0. No relation change or reward.")
                end
            end
        end
    end
end

function Scrapyard.Log(_MethodName, _Msg)
    if Scrapyard._Debug == 1 then
        print("[Scrapyard] - [" .. tostring(_MethodName) .. "] - " .. tostring(_Msg))
    end
end

--endregion

--region #SERVER FUNCTIONS

--Most of this is duplicated between sellWreck, sellWrecks, and undocked entities but I have no idea how to consolidate it into a function. So fuck you, whoever said my code was linear and repetitive.
function Scrapyard.sellWreck(_ID)
    local _MethodName = "Sell Wreck"
    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then 
        return 
    end

    local _Buyer, _Ship, _Player = getInteractingFaction(callingPlayer, AlliancePrivilege.ModifyCrafts, AlliancePrivilege.SpendResources)
    if not _Buyer then 
        return 
    end

    --Get the docking clamps of the player ship.
    local _Clamps = DockingClamps(_Ship)
    local _DockedEntities = {_Clamps:getDockedEntities()}
    local _Payout = 0

    --We don't need to worry about the entity being tagged, since the button won't appear if it is not tagged. Same if it's not a wreckage.
    for _, _EnID in pairs(_DockedEntities) do
        if tostring(_EnID) == _ID then
            local _DockedEntity = Entity(_EnID)
            Scrapyard.Log(_MethodName, "Found entity. Adding payout and rebuilding wreckage.")
            local _Sector = Sector()

            --Now that the entity is undocked, we shift it to a wreck in the sector, tag it, and pay the player half the value.
            Scrapyard.Log(_MethodName, "Entity " .. tostring(_EnID) .. " is a wreckage and has not yet been redeemed.")
            local _Plan = _DockedEntity:getMovePlan()
            local _Velocity = Velocity(_DockedEntity)
            _Sector:deleteEntity(_DockedEntity)

            _Payout = (Scrapyard.getFullShipValue(_Plan) / 2)

            local _Wreck = _Sector:createWreckage(_Plan, _DockedEntity.position)
            local _WreckVelocity = Velocity(_Wreck)
            _Wreck:setValue(Scrapyard._Tag, true) --We obviously have to retag it here.
            _WreckVelocity:addVelocity(_Velocity.velocityf)
        end
    end

    if _Payout > 0 then
        changeRelations(Faction(), _Buyer, 75, RelationChangeType.ResourceTrade)
        _Buyer:receive(Format("Received %1% Credits for selling a wreckage to a scrapyard.", createMonetaryString(_Payout)), _Payout)
    end

    invokeClientFunction(_Player, "transactionComplete")
end
callable(Scrapyard, "sellWreck")

function Scrapyard.sellWrecks()
    local _MethodName = "Sell Wrecks"
    if not CheckFactionInteraction(callingPlayer, Scrapyard.interactionThreshold) then 
        return 
    end

    local _Buyer, _Ship, _Player = getInteractingFaction(callingPlayer, AlliancePrivilege.ModifyCrafts, AlliancePrivilege.SpendResources)
    if not _Buyer then 
        return 
    end

    --Get the docking clamps of the player ship.
    local _Clamps = DockingClamps(_Ship)
    local _DockedEntities = {_Clamps:getDockedEntities()}

    if #_DockedEntities == 0 then
        _Player:sendChatMessage(Entity(),  ChatMessageType.Error, "You don't have any docked wreckages!")
        return
    end

    local _TaggedEntities = false

    local _CurrentValueOfWrecks = Scrapyard.getAllWreckValues()
    local _ValueRatio = _CurrentValueOfWrecks / originalValue
    local _Bonus = false
    --50% chance of a priority sale
    Scrapyard.Log(_MethodName, "Current value of wreck ins in sector : " .. tostring(_CurrentValueOfWrecks) .. " - original value of wrecks : " .. tostring(originalValue) .. " ratio is : " .. tostring(_ValueRatio))
    if _ValueRatio <= 0.5 then
        if random():getInt(1, 2) == 1 then
            _Bonus = true
        end
    end

    local _TotalPayout = 0
    local _WrecksSold = 0
    for _, _EnID in pairs(_DockedEntities) do
        local _DockedEntity = Entity(_EnID)

        if _DockedEntity.type == EntityType.Wreckage then
            if not _DockedEntity:getValue(Scrapyard._Tag) then
                _DockedEntity:setValue(Scrapyard._Tag) --We set the tag here so the player can't double dip with Wrecking Havoc when it's undocked.
                Scrapyard.Log(_MethodName, "Entity " .. tostring(_EnID) .. " is a wreckage and has not yet been redeemed.")
                local _Sector = Sector()

                local _Plan = _DockedEntity:getMovePlan()
                local _Velocity = Velocity(_DockedEntity)
                _Sector:deleteEntity(_DockedEntity) --Clean up old entity.
    
                _TotalPayout = _TotalPayout + (Scrapyard.getFullShipValue(_Plan) / 2)
                _WrecksSold = _WrecksSold + 1

                local _Wreck = _Sector:createWreckage(_Plan, _DockedEntity.position)
                local _WreckVelocity = Velocity(_Wreck)
                _Wreck:setValue(Scrapyard._Tag, true) --We obviously have to retag it here.
                _WreckVelocity:addVelocity(_Velocity.velocityf)
            else
                _TaggedEntities = true
            end
        end
    end

    local _BonusPayout = 0
    if _Bonus then
        _BonusPayout = _TotalPayout * 0.2
        _TotalPayout = _TotalPayout + _BonusPayout
    end

    local _Msg = "Received %1% Credits for selling " .. tostring(_WrecksSold) .. " wreckages to a scrapyard."
    if _Bonus then
        _Msg = _Msg .. " Included a " .. tostring(createMonetaryString(_BonusPayout)) .. " bonus."
    end
    if _TaggedEntities then
        _Msg = _Msg .. " Some of the wreckages were tagged and could not be sold."
    end

    if _TotalPayout > 0 then
        changeRelations(Faction(), _Buyer, 75 * _WrecksSold, RelationChangeType.ResourceTrade)
        _Buyer:receive(Format(_Msg, createMonetaryString(_TotalPayout)), _TotalPayout)
    else
        if _TaggedEntities then
            _Player:sendChatMessage(Entity(), ChatMessageType.Error, "We cannot reimburse you for tagged wreckages. It seems that all of your docked wreckages have been tagged.")
        end
    end
    
    invokeClientFunction(_Player, "transactionComplete")
end
callable(Scrapyard, "sellWrecks")

--Tags all the wrecks. This is done to prevent wrecks from being sold twice. Obviously only on the server.
local SellWreckages_updateServer = Scrapyard.updateServer
function Scrapyard.updateServer(_TimeStep)
    SellWreckages_updateServer(_TimeStep)
    local _MethodName = "Update Server"
    local _Sector = Sector()

    local _Ships = {_Sector:getEntitiesByType(EntityType.Ship)}
    local _Wrecks = {_Sector:getEntitiesByType(EntityType.Wreckage)}

    local _DockedWreckIDs = {}
    for _, _Ship in pairs(_Ships) do
        --Get clamps of ships that don't belong to the scrapyard.
        if _Ship.factionIndex ~= Entity().factionIndex then
            local _Clamps = DockingClamps(_Ship)
            if _Clamps then
                --Get docked entities in clamps
                local _DockedEntities = {_Clamps:getDockedEntities()}
                --Don't bother checking if there are 0 docked entities.
                if #_DockedEntities > 0 then
                    for _, _DockedID in pairs(_DockedEntities) do
                        local _DockedEntity = Entity(_DockedID)
                        if _DockedEntity and valid(_DockedEntity) and _DockedEntity.type == EntityType.Wreckage then
                            _DockedWreckIDs[tostring(_DockedID)] = true
                        end
                    end
                end
            end
        end
    end

    for _, _Wreck in pairs(_Wrecks) do
        local _WreckIndex = tostring(_Wreck.id)
        local _Wreck = Entity(_Wreck.id)
        if not _DockedWreckIDs[_WreckIndex] or not _Wreck:hasComponent(ComponentType.MoneyDropper) then
            _Wreck:setValue(Scrapyard._Tag, true)
        end
    end

    --Get value of all tagged wreckages in sector if originalValue is not set.
    if not originalValue then
        originalValue = Scrapyard.getAllWreckValues()
        Scrapyard.Log(_MethodName, "Original value of wrecks in this scrapyard sector : " .. tostring(originalValue))
    end

    _CanBroadcast = true
end

--endregion

--region #SECURE / RESTORE

local SellWreckages_secure = Scrapyard.secure
function Scrapyard.secure()
    local _Data = SellWreckages_secure()

    _Data.originalValue = originalValue

    return _Data
end

local SellWreckages_restore = Scrapyard.restore
function Scrapyard.restore(_Data_in)
    SellWreckages_restore(_Data_in)

    originalValue = _Data_in.originalValue
end

--endregion