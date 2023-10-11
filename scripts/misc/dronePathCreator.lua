--[[
This file is part of Drone delivery mod (https://github.com/DennisB97/FS22DroneDelivery)

Copyright (c) 2023 Dennis B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this mod and associated files, to copy, modify ,subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This mod is for personal use only and is not affiliated with GIANTS Software.
Sharing or distributing FS22_DroneDelivery mod in any form is prohibited except for the official ModHub (https://www.farming-simulator.com/mods).
Selling or distributing FS22_DroneDelivery mod for a fee or any other form of consideration is prohibited by the game developer's terms of use and policies,
Please refer to the game developer's website for more information.
]]

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
    self.nearbyDistanceLimit = 600
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

--- delete cleans up the spline and astar generators.
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

--- generateNew called to start a new generation with new pickup and delivery placeable or delivery placeable new.
--@param pickUpPlaceable is a possible new pickup place.
--@param deliveryPlaceable is always given, new delivery place.
--@param callback function to call after all paths generated and made into splines.
function DronePathCreator:generateNew(pickUpPlaceable,deliveryPlaceable,callback)
    if pickUpPlaceable == nil and deliveryPlaceable == nil then
        return
    end

    -- store previous paths so can be used if a placeable hasn't changed
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

--- newConnection called to proceed create each path in order, and each path has different steps for the generation starting from verticalup.
function DronePathCreator:newConnection()
    self.currentSpline = nil
    self.currentStep = self.EConnectionStep.VERTICALUP

    local startPosition = {x=0,y=0,z=0}
    startPosition.x, startPosition.y, startPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
    local endPosition = nil

    if not self:checkPlacablesExists() then
        self:creationFailed()
        return
    end


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
        endPosition = {x=0,y=0,z=0}
        endPosition.x,endPosition.y,endPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
    end

    if endPosition ~= nil then
        self.bIsLowerHeight = false
        -- checking straight distance between start and end, if within limit will fly closer to ground
        if self:isLowerHeightConnection(startPosition,endPosition) then
            self.bIsLowerHeight = true
        end

        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    else -- if no end position means the whole "triangle" path is ready
        --last check to check that no placeable was deleted/sold while was generating
        if not self:checkPlacablesExists() then
            self:creationFailed()
        else
            self.callback(self.trianglePath)
        end
    end

end

--- checkPlaceablesExists used to check if the pickup and delivery placeable is still valid and not sold/deleted.
--@return true if they exists.
function DronePathCreator:checkPlacablesExists()
    if self.pickUpPlaceable == nil or self.pickUpPlaceable.isDeleted or self.deliveryPlaceable == nil or self.deliveryPlaceable.isDeleted then
        return false
    else
        return true
    end
end

--- isLowerHeightConnection check distance between given points if under nearby distance limit.
--@param startPosition , given as {x=,y=,z=}.
--@param endPosition, given as {x=,y=,z=}.
--@return true if distance was within the self.nearbyDistanceLimit.
function DronePathCreator:isLowerHeightConnection(startPosition,endPosition)
    local distance = MathUtil.vector3Length(startPosition.x - endPosition.x, startPosition.y - endPosition.y, startPosition.z - endPosition.z)
    return distance <= self.nearbyDistanceLimit
end

--- createNewPath called to have AStar class create a path between given points.
--@param startPosition , given as {x=,y=,z=}.
--@param endPosition, given as {x=,y=,z=}.
function DronePathCreator:createNewPath(startPosition,endPosition)

    local callback = function(aStarResult) self:onPathCreated(aStarResult) end
    -- To delivery will use the postProcessDronePath function instead of the one in the AStar class.
    -- to take a bit in consideration the bigger size of drone.
    local bDefaultSmoothPath = self.currentConnection ~= self.EConnections.TODELIVERY

    if not self.pathGenerator:find(startPosition,endPosition,false,true,true,callback,bDefaultSmoothPath,5,10000) then
        self:creationFailed()
        return
    end
end

--- onPathCreated is callback for the pathGenerator done.
--@aStarResult is the result of pathfinding, given as {pathArray,bReachedGoal}.
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

--- onSplineCreated is callback for the splineGenerator done.
--@param spline is the created CatmullRomSpline.
function DronePathCreator:onSplineCreated(spline)

    -- if currently no spline set, then this will be first spline base
    if self.currentSpline == nil then
        self.currentSpline = spline
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    else -- else combines the newly created into the previous
        local callback = function(newSpline) self:onSplineCombined(newSpline) end
        self.splineGenerator:combineSplinesAtDistance(self.currentSpline,spline,self.currentSpline:getSplineLength(),callback)
    end

end

--- onSplineCombined is callback when splineGenerator combined the given splines.
--@param spline is the newly combined spline.
function DronePathCreator:onSplineCombined(spline)

    if self.currentStep == self.EConnectionStep.DONE then
        self:finalizeSpline(spline)
    else
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    end

end

--- getNextEndPosition finds the correct end position to pathfind to, and progresses the EConnectionStep forward after each time function is called.
--@param startPosition is from where the pathfind starts, given as {x=,y=,z=}.
--@return new endPosition to pathfind to, given as {x=,y=,z=}.
function DronePathCreator:getNextEndPosition(startPosition)

    self.flyHeight = self:getCorrectFlyHeight()

    if self.currentStep == self.EConnectionStep.VERTICALUP then
        raycastAll(startPosition.x,startPosition.y,startPosition.z,0,1,0,"heightCheckCallback",self.flyHeight,self,CollisionFlag.STATIC_WORLD,false,false)
        local newHeight = startPosition.y + self.flyHeight
        self.currentStep = self.EConnectionStep.HORIZONTAL
        -- only if actually higher position was possible then proceed, otherwise will skip vertical up step
        if newHeight > startPosition.y then
            startPosition.y = newHeight
            return startPosition
        end
        self.flyHeight = self:getCorrectFlyHeight() -- reset after raycast callback changed it
    end

    -- have to make sure the placeables exists as below the PickupDeliveryHelper will require the placeable ids to be valid
    if not self:checkPlacablesExists() then
        self:creationFailed()
        return
    end

    -- get the end position which is the way when step is HORIZONTAL or VERTICALDOWN
    local finalPosition = nil
    if self.currentConnection == self.EConnections.TOPICKUP then
        finalPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        finalPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
    elseif self.currentConnection == self.EConnections.TOHUB then
        finalPosition = {x=self.entrancePosition.x,y=self.entrancePosition.y,z=self.entrancePosition.z}
    else
        return nil
    end

    if self.currentStep == self.EConnectionStep.HORIZONTAL then
        raycastAll(finalPosition.x,finalPosition.y,finalPosition.z,0,1,0,"heightCheckCallback",self.flyHeight,self,CollisionFlag.STATIC_WORLD,false,false)
        local newHeight = finalPosition.y + self.flyHeight
        -- if end position horizontal is lower than the actual final position then skips the vertical down step and makes direct path
        if newHeight <= finalPosition.y then
            self.currentStep = self.EConnectionStep.DONE
        else
            finalPosition.y = newHeight
            self.currentStep = self.EConnectionStep.VERTICALDOWN
        end


    elseif self.currentStep == self.EConnectionStep.VERTICALDOWN then
        self.currentStep = self.EConnectionStep.DONE
    end

    return finalPosition
end

--- getCorrectFlyHeight helper function to get correct height value based on bool.
--@return fly height in the y axis to use.
function DronePathCreator:getCorrectFlyHeight()
    if not self.bIsLowerHeight then
        return self.longDistanceSkyFlyHeight
    end
    return self.skyFlyHeight
end

--- heightCheckCallback is used as callback for rayCastAll.
-- checks if collides with any placeable, and if it does gets the safe distance that is not inside collision.
--@param objectId collided objectId.
--@param x coordinate of hit.
--@param y coordinate of hit.
--@param z coordinate of hit.
--@param distance how long the trace was for hit.
--@return true to continue search and false if trace should stop.
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

--- finalizeSpline called to complete and add generated spline to the trianglePath.
--@param spline is the finalized ready spline of one path out of the three.
function DronePathCreator:finalizeSpline(spline)

    if self.currentConnection == self.EConnections.TOPICKUP then
        self.trianglePath.toPickup = spline
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        self.trianglePath.toDelivery = spline
    elseif self.currentConnection == self.EConnections.TOHUB then
        self.trianglePath.toHub = spline
    end

    -- after done tries to go for new connections.
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

--- checkShortCut calls to make a rayCastClosest to check if any hit is blocking possible shortcutting in the path.
--@param startPosition , given as {x=,y=,z=}.
--@param endPosition, given as {x=,y=,z=}.
function DronePathCreator:checkShortCut(startPosition,endPosition)

    -- do a raycasts to check if middle node can be left out of path, one time out of multiple calls made to make sure a drone size object can pass
    local directionX,directionY,directionZ = MathUtil.vector3Normalize(endPosition.x - startPosition.x,endPosition.y - startPosition.y,endPosition.z - startPosition.z)
    local distance = MathUtil.vector3Length(endPosition.x - startPosition.x,endPosition.y - startPosition.y,endPosition.z - startPosition.z)
    raycastClosest(startPosition.x,startPosition.y,startPosition.z,directionX,directionY,directionZ,"pathTraceCallback",distance,self,CollisionFlag.STATIC_WORLD)
end

--- pathTraceCallback callback to the raycastClosest, if hits any solid placeable will mark as traceBlocked and stop trace.
--@param objectId is hit id of object.
--@param return true to continue the trace, false stops when has hit any solid placeable.
function DronePathCreator:pathTraceCallback(objectId)
    if objectId < 1 or g_currentMission.terrainRootNode == objectId then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    if not object:isa(Placeable) then
        return true
    end

    -- set that trace was blocked so can't remove middle path position from between
    self.bTraceBlocked = true
    return false

end

--- creationFailed called to mark as creating the paths with given placeables failed.
function DronePathCreator:creationFailed()
    self.pickUpPlaceable = self.previousPickUpPlaceable
    self.deliveryPlaceable = self.previousDeliveryPlaceable
    self.trianglePath = self.previousTriangle

    if self.pathGenerator ~= nil then
        self.pathGenerator:interrupt()
    end

    if self.splineGenerator ~= nil then
        self.splineGenerator:interrupt()
    end

    if self.callback ~= nil then
        self.callback(nil)
        self.callback = nil
    end

end


