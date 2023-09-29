

---@class DronePathCreator.
-- Handles creating path between hub -> pickup -> delivery -> hub.
DronePathCreator = {}
DronePathCreator_mt = Class(DronePathCreator)
InitObjectClass(DronePathCreator, "DronePathCreator")

--- new creates a new PickupDeliveryManager object.
--@param entrancePosition is table of hub's entrance position where drones will leave and enter, given as {x=,y=,z=}.
function DronePathCreator.new(entrancePosition)
    local self = setmetatable({}, DronePathCreator_mt)

    self.trianglePath = {}
    self.entrancePosition = entrancePosition
    self.pickUpPlaceable = nil
    self.deliveryPlaceable = nil
    self.pathGenerator = AStar.new(true,false)
    self.pathGenerator:register(true)
    self.splineGenerator = CatmullRomSplineCreator.new(true,false)
    self.splineGenerator:register(true)
    -- a distance value in m, when closer than this will have lower pathfind between points. Else will go higher up in the sky between points.
    self.nearbyDistanceLimit = 650
    -- if longer distance than above limit then, this indicates how high up the path should be made between points.
    self.longDistanceSkyFlyHeight = 50
    -- else lower height
    self.skyFlyHeight = 5

    self.callback = nil
    -- these bools indicate which paths need to be made
    self.bRequiresToPickup = false
    self.bRequiresToDelivery = false
    self.bRequiresToHub = false
    self.EConnections = {TOPICKUP = 1, TODELIVERY = 2, TOHUB = 3}
    self.EConnectionStep = {VERTICALUP = 1, HORIZONTAL = 2, VERTICALDOWN = 3, DONE = 4}
    self.currentStep = self.EConnectionStep.VERTICALUP
    self.currentConnection = nil
    return self
end


function DronePathCreator:delete()

    if self.splineGenerator ~= nil then
        self.splineGenerator:delete()
        self.splineGenerator = nil
    end

    if self.pathGenerator ~= nil then
        self.pathGenerator:delete()
        self.pathGenerator = nil
    end

    self.trianglePath = nil
    self.previousTriangle = nil
    self.callback = nil

end

function DronePathCreator:generateNew(pickUpPlaceable,deliveryPlaceable,callback)
    if pickUpPlaceable == nil and deliveryPlaceable == nil then
        return
    end

    self.previousTriangle = self.trianglePath
    self.trianglePath = {}
    self.callback = callback
    self.bRequiresToPickup = false
    self.bRequiresToDelivery = false
    self.bRequiresToHub = false
    self.previousPickUpPlaceable = self.pickUpPlaceable
    self.previousDeliveryPlaceable = self.deliveryPlaceable

    -- the path between pickup and delivery is always new as either delivery of bot delivery and pickup is new
    self.bRequiresToDelivery = true

    if pickUpPlaceable ~= nil and self.pickUpPlaceable ~= pickUpPlaceable then
        -- if pickup placeable is new then requires to pickup
        self.bRequiresToPickup = true
        self.pickUpPlaceable = pickUpPlaceable
    else
        -- else puts back the previous generated spline as the toPickup path
        self.trianglePath.toPickup = self.previousTriangle.toPickup
    end

    if deliveryPlaceable ~= nil and self.deliveryPlaceable ~= deliveryPlaceable then
        -- if delivery placeable is new then requires new spline to hub
        self.bRequiresToHub = true
        self.deliveryPlaceable = deliveryPlaceable
    else
        -- else uses the previous toHub spline
        self.trianglePath.toHub = self.previousTriangle.toHub
    end

    self:newConnection()
end

function DronePathCreator:newConnection()
    self.currentSpline = nil
    self.currentStep = self.EConnectionStep.VERTICALUP

    local startPosition = {x=0,y=0,z=0}
    startPosition.x, startPosition.y, startPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
    local endPosition = nil

    if self.bRequiresToPickup then
        self.bRequiresToPickup = false
        self.currentConnection = self.EConnections.TOPICKUP
        endPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
    elseif self.bRequiresToDelivery then
        self.bRequiresToDelivery = false
        self.currentConnection = self.EConnections.TODELIVERY
        startPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
        endPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
    elseif self.bRequiresToHub then
        self.bRequiresToHub = false
        self.currentConnection = self.EConnections.TOHUB
        startPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
        endPosition = {}
        endPosition.x,endPosition.y,endPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
    end

    if endPosition ~= nil then
        self.bIsLowerHeight = false
        if self:isLowerHeightConnection(startPosition,endPosition) then
            self.bIsLowerHeight = true
        end

        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    else -- if no end position means the whole "triangle" path is ready
        self.callback(self.trianglePath)
    end

end

function DronePathCreator:isLowerHeightConnection(startPosition,endPosition)
    local distance = MathUtil.vector3Length(startPosition.x - endPosition.x, startPosition.y - endPosition.y, startPosition.z - endPosition.z)
    return distance <= self.nearbyDistanceLimit
end


function DronePathCreator:createNewPath(startPosition,endPosition)

    local callback = function(aStarResult) self:onPathCreated(aStarResult) end
    -- To delivery will use the postProcessDronePath function instead of the one in the AStar class.
    local bDefaultSmoothPath = self.currentConnection ~= self.EConnections.TODELIVERY

    if not self.pathGenerator:find(startPosition,endPosition,false,true,true,callback,bDefaultSmoothPath,5,10000) then
        self:creationFailed()
        return
    end

end

function DronePathCreator:onPathCreated(aStarResult)

    if not aStarResult[2] then
        self:creationFailed()
        return
    end

    -- To delivery will use the postProcessDronePath function instead of the one in the AStar class.
    if self.currentConnection == self.EConnections.TODELIVERY then
        self:postProcessDronePath(aStarResult[1])
    end

    local customP0 = nil
    local lastDirection = nil

    if self.currentSpline ~= nil then
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        customP0 = {}
        customP0.x,customP0.y,customP0.z = lastSegment.p1.x, lastSegment.p1.y, lastSegment.p1.z
        lastDirection = {}
        lastDirection.x, lastDirection.y, lastDirection.z = MathUtil.vector3Normalize(lastSegment.p2.x - lastSegment.p1.x,lastSegment.p2.y - lastSegment.p1.y, lastSegment.p2.z - lastSegment.p1.z)
    end

    local callback = function(spline) self:onSplineCreated(spline) end
    self.splineGenerator:createSpline(aStarResult[1],callback,customP0,nil,lastDirection)
end


function DronePathCreator:onSplineCreated(spline)

    if self.bIsDirect then
        self:finalizeSpline(spline)
        return
    end

    if self.currentSpline == nil then
        self.currentSpline = spline
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    else

        local callback = function(newSpline) self:onSplineCombined(newSpline) end
        self.splineGenerator:combineSplinesAtDistance(self.currentSpline,spline,self.currentSpline:getSplineLength(),callback)

    end


end

function DronePathCreator:onSplineCombined(spline)

    if self.currentStep == self.EConnectionStep.DONE then
        self:finalizeSpline(spline)
    else
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    end

end

--- getNextEndPosition
function DronePathCreator:getNextEndPosition(startPosition)

    self.flyHeight = self.skyFlyHeight

    if not self.bIsLowerHeight then
        self.flyHeight = self.longDistanceSkyFlyHeight
    end

    if self.currentStep == self.EConnectionStep.VERTICALUP then
        raycastAll(startPosition.x,startPosition.y,startPosition.z,0,1,0,"heightCheckCallback",self.flyHeight,self,CollisionFlag.STATIC_WORLD,false,false)
        startPosition.y = startPosition.y + self.flyHeight
        self.currentStep = self.EConnectionStep.HORIZONTAL
        return startPosition
    end

    -- get the end position which is the way when step is HORIZONTAL or VERTICALDOWN
    local finalPosition = nil
    if self.currentConnection == self.EConnections.TOPICKUP then
        finalPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        finalPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
    elseif self.currentConnection == self.EConnections.TOHUB then
        finalPosition = {x=self.entrancePosition.x,y=self.entrancePosition.y,z=self.entrancePosition.z}
    end

    if self.currentStep == self.EConnectionStep.HORIZONTAL then
        raycastAll(finalPosition.x,finalPosition.y,finalPosition.z,0,1,0,"heightCheckCallback",self.flyHeight,self,CollisionFlag.STATIC_WORLD,false,false)
        finalPosition.y = finalPosition.y + self.flyHeight
        self.currentStep = self.EConnectionStep.VERTICALDOWN
    elseif self.currentStep == self.EConnectionStep.VERTICALDOWN then
        self.currentStep = self.EConnectionStep.DONE
    end

    return finalPosition
end

function DronePathCreator:heightCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    if object:isa(Placeable) then
        self.flyHeight = distance - g_currentMission.gridMap3D.maxVoxelResolution
        return false
    end

    return true
end

function DronePathCreator:finalizeSpline(spline)

    if self.currentConnection == self.EConnections.TOPICKUP then
        self.trianglePath.toPickup = spline
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        self.trianglePath.toDelivery = spline
    elseif self.currentConnection == self.EConnections.TOHUB then
        self.trianglePath.toHub = spline
    end

    self:newConnection()
end

--- postProcessDronePath called to remove some zigzag found in the path with a trace check for making sure not cutting corners.
function DronePathCreator:postProcessDronePath(path)
    if path == nil or #path < 3 then
        return
    end

    local pathPositionsToRemove = {}

    local firstNode = path[1]
    local secondNode = path[2]
    local thirdNode = path[3]
    local goalNode = path[#path]
    local currentIndex = 3

    while thirdNode ~= nil do

        if secondNode == goalNode then
            break
        end

        local bIsLast = thirdNode == goalNode

        local fiveTraceStartPositions = {firstNode}
        local fiveTraceEndPositions = {thirdNode}


        local directionX,directionY,directionZ = MathUtil.vector3Normalize(thirdNode.x - firstNode.x,thirdNode.y - firstNode.y,thirdNode.z - firstNode.z)
        local crossVectorX, crossVectorY, crossVectorZ = 0,1,0

        local dotResult = MathUtil.dotProduct(directionX,directionY,directionZ,crossVectorX,crossVectorY,crossVectorZ)
        if dotResult == 1 or dotResult == -1 then
            crossVectorX,crossVectorY,crossVectorZ = 1,0,0
        end

        local perpX,perpY,perpZ = MathUtil.vector3Normalize(MathUtil.crossProduct(directionX,directionY,directionZ,crossVectorX,crossVectorY,crossVectorZ))


        local squareOffsetDistance = 0.4
        table.insert(fiveTraceStartPositions,{x= firstNode.x + (perpX * squareOffsetDistance), y= firstNode.y + (perpY * squareOffsetDistance),z= firstNode.z + (perpZ * squareOffsetDistance) })
        table.insert(fiveTraceEndPositions,{x= thirdNode.x + (perpX * squareOffsetDistance), y= thirdNode.y + (perpY * squareOffsetDistance),z= thirdNode.z + (perpZ * squareOffsetDistance) })

        table.insert(fiveTraceStartPositions,{x= firstNode.x - (perpX * squareOffsetDistance), y= firstNode.y - (perpY * squareOffsetDistance),z= firstNode.z - (perpZ * squareOffsetDistance) })
        table.insert(fiveTraceEndPositions,{x= thirdNode.x - (perpX * squareOffsetDistance), y= thirdNode.y - (perpY * squareOffsetDistance),z= thirdNode.z - (perpZ * squareOffsetDistance) })

        perpX,perpY,perpZ = MathUtil.crossProduct(directionX,directionY,directionZ,perpX,perpY,perpZ)

        table.insert(fiveTraceStartPositions,{x= firstNode.x + (perpX * squareOffsetDistance), y= firstNode.y + (perpY * squareOffsetDistance),z= firstNode.z + (perpZ * squareOffsetDistance) })
        table.insert(fiveTraceEndPositions,{x= thirdNode.x + (perpX * squareOffsetDistance), y= thirdNode.y + (perpY * squareOffsetDistance),z= thirdNode.z + (perpZ * squareOffsetDistance) })

        table.insert(fiveTraceStartPositions,{x= firstNode.x - (perpX * squareOffsetDistance), y= firstNode.y - (perpY * squareOffsetDistance),z= firstNode.z - (perpZ * squareOffsetDistance) })
        table.insert(fiveTraceEndPositions,{x= thirdNode.x - (perpX * squareOffsetDistance), y= thirdNode.y - (perpY * squareOffsetDistance),z= thirdNode.z - (perpZ * squareOffsetDistance) })

        self.bTraceBlocked = false
        for i = 1, #fiveTraceStartPositions do

            self:checkShortCut(fiveTraceStartPositions[i],fiveTraceEndPositions[i])

            if self.bTraceBlocked then
                -- in case the second node was blocked then next raycast will be made from that node
                firstNode = secondNode
                break
            end

        end

        if not self.bTraceBlocked then
            table.insert(pathPositionsToRemove,currentIndex-1) -- minus one as index points to the third, but middle is the one to be removed
        end


        secondNode = thirdNode
        thirdNode = path[currentIndex+1]
        currentIndex = currentIndex + 1

        if bIsLast then
            break
        end
    end

    for i = #pathPositionsToRemove, 1, -1 do
        table.remove(path,pathPositionsToRemove[i])
    end

end

function DronePathCreator:checkShortCut(startPosition,endPosition)

    -- do a raycasts to check if middle node can be left out of path
    local directionX,directionY,directionZ = MathUtil.vector3Normalize(endPosition.x - startPosition.x,endPosition.y - startPosition.y,endPosition.z - startPosition.z)
    local distance = MathUtil.vector3Length(endPosition.x - startPosition.x,endPosition.y - startPosition.y,endPosition.z - startPosition.z)
    raycastClosest(startPosition.x,startPosition.y,startPosition.z,directionX,directionY,directionZ,"pathTraceCallback",distance,self,CollisionFlag.STATIC_WORLD)
end


function DronePathCreator:pathTraceCallback(objectId)
    if objectId < 1 or g_currentMission.terrainRootNode == objectId then
        return true
    else
        -- set that trace was blocked so can't remove middle path position from between
        self.bTraceBlocked = true
        return false
    end

end

function DronePathCreator:creationFailed()
    self.pickUpPlaceable = self.previousPickUpPlaceable
    self.deliveryPlaceable = self.previousDeliveryPlaceable
    self.trianglePath = self.previousTriangle

    if self.callback ~= nil then
        self.callback(nil)
    end

end


