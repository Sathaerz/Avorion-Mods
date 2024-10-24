--Extensions to StructuredMission.

--region #SERVER FUNCTIONS

function getOnLocation(inSector)
    local _Sector = inSector or Sector()
    local _X, _Y = _Sector:getCoordinates()
    if _X == mission.data.location.x and _Y == mission.data.location.y then
        return true
    else
        return false
    end
end

function runFullSectorCleanup(cleanAll)
    local _Sector = Sector()
    local _OnLocation = getOnLocation(_Sector)
    if cleanAll == nil then --if it's not set, then set it to true. Can't do cleanAll = cleanAll or true b/c that will remove (correct) false values.
        cleanAll = true
    end

    if _OnLocation then
        --Just in case the mission doesn't include ESCCUtil. Deletes everything that clearMissionAssets would when not deleting everything (true/false)
        local _ESCCUtil = include("esccutil")
        local _EntityTypes = _ESCCUtil.majorEntityTypes()
        if cleanAll then
           _EntityTypes = _ESCCUtil.allEntityTypes() 
        end
        _Sector:addScript("sector/deleteentitiesonplayersleft.lua", _EntityTypes)
        _Sector:removeScript("sector/background/campaignsectormonitor.lua")
    else
        local cleanupFunc = function(lCleanAll)
            local _MX, _MY = mission.data.location.x, mission.data.location.y
            Galaxy():loadSector(_MX, _MY)
            invokeSectorFunction(_MX, _MY, true, "campaignsectormonitor.lua", "clearMissionAssets", true, lCleanAll)
        end
        
        --There are certain circumstances where we abandon the mission but the sector hasn't gotten the sectormonitor - don't cause an error in that case, but do log.
        local status, result = pcall(cleanupFunc, cleanAll)
        if not status then 
            mission.Log("Cleanup", "Sector does not have campaignsectormonitor attached.", nil)
        end
    end
end

--endregion

--region #CLIENT FUNCTIONS

function startBossCameraAnimation(bossId)
    bossId = Uuid(bossId)
    local camera = Player().cameraPosition
    local startPosition = camera.translation

    local boss = Entity(bossId)
    local direction = normalize(boss.translationf - startPosition)
    local endPosition = boss.translationf - direction * boss.radius

    local path = endPosition - startPosition

    local bossUp = boss.up
    if dot(camera.up, bossUp) < 0 then
        bossUp = -bossUp -- limit the angle of rotation for the camera
    end

    local keyframes = {}
    table.insert(keyframes, CameraKeyFrame(startPosition, startPosition + camera.look * 1000, camera.up, 0))
    table.insert(keyframes, CameraKeyFrame(startPosition, bossId, camera.up, 1))
    table.insert(keyframes, CameraKeyFrame(startPosition + path * 0.8, bossId, bossUp, 1.8))
    table.insert(keyframes, CameraKeyFrame(startPosition + path, bossId, bossUp, 4))

    Player():setCameraKeyFrames(unpack(keyframes))
end

--endregion

--region #CLIENT / SERVER functions

function mission.Log(_MethodName, _Msg, _OverrideDebug)
    local localDebug = mission._Debug
    if _OverrideDebug then
        localDebug = _OverrideDebug
    end
    if localDebug and localDebug == 1 then
        local _Name = mission._Name or mission.title or "Mission"
        print("[" .. _Name .. "] - [" .. _MethodName .. "] - " .. _Msg)
    end
end

--endregion