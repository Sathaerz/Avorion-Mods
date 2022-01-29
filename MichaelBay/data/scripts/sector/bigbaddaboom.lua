package.path = package.path .. ";data/scripts/lib/?.lua"

include("randomext")

function initialize()
    local _Sector = Sector()

    if onClient() then
        _Sector:registerCallback("onDestroyed", "onDestroyed")
    end
end

if onClient() then

    function onDestroyed(_ID)
        local _Entity = Entity(_ID)
        local _Pos = _Entity.translationf
        local _Rad = _Entity:getBoundingSphere().radius

        if _Entity.type == EntityType.Ship or _Entity.type == EntityType.Station then
            local _MinOffset = -8
            local _MaxOffset = math.abs(_MinOffset) * 2

            local _MainRadScale = 2
            local _SecondRadMinScale = 0.4
            local _SecondRadMaxScale = 1.2
            local _ThirdRadMinScale = 0.8
            local _ThirdRadMaxScale = 1.4
            local _TertiaryMaxDelay = 1.2
            local _TertiaryMin = 1
            local _TertiaryMax = 5
            if _Entity.type == EntityType.Station then
                _MainRadScale = 0.8
                _SecondRadMinScale = 0.3
                _SecondRadMaxScale = 0.4
                _ThirdRadMinScale = 0.4
                _ThirdRadMaxScale = 0.6
                _TertiaryMaxDelay = 2.2
                _TertiaryMin = 3
                _TertiaryMax = 7
            end

            showExplosion(_Pos, _Rad * _MainRadScale)

            local _Secondary = random():getInt(2, 4)
            for _ = 1, _Secondary do
                local _XPosition = vec3(_Pos.x + (_MinOffset + random():getInt(0, _MaxOffset)), _Pos.y + (_MinOffset + random():getInt(0, _MaxOffset)), _Pos.z + (_MinOffset + random():getInt(0, _MaxOffset)))
                local _XScale = random():getFloat(_SecondRadMinScale, _SecondRadMaxScale)
                showExplosion(_XPosition, _Rad * _XScale)
            end
    
            local _Tertiary = random():getInt(_TertiaryMin, _TertiaryMax)
            for _ = 1, _Tertiary do
                local _Delay = random():getFloat(0.3, _TertiaryMaxDelay)
                local _XPosition = vec3(_Pos.x + (_MinOffset + random():getInt(0, _MaxOffset)), _Pos.y + (_MinOffset + random():getInt(0, _MaxOffset)), _Pos.z + (_MinOffset + random():getInt(0, _MaxOffset)))
                local _XScale = random():getFloat(_ThirdRadMinScale, _ThirdRadMaxScale)
                deferredCallback(_Delay, "showExplosion", _XPosition, _Rad * _XScale)
            end
        end
    end
    
    function showExplosion(_Pos, _Rad)
        if not _Pos  or not _Rad then return end

        Sector():createExplosion(_Pos, _Rad, false)
    end
end

