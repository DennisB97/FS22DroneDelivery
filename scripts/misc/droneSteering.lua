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

---@class DroneSteering.
-- Handles steering a drone along spline path.
DroneSteering = {}
DroneSteering_mt = Class(DroneSteering)
InitObjectClass(DroneSteering, "DroneSteering")

--- new creates a new DroneSteering object.
--@param owner is the drone that will be steered.
--@param groundOffset given drone how much from ground should travel at least.
--@param carrySpeed how fast m/s drone can go when carrying objects.
--@param horizontalSpeed how fast m/s drone can go directly horizontal.
--@param verticalSpeed how fast m/s drone can go either direct up or down.
function DroneSteering.new(owner,groundOffset,carrySpeed,horizontalSpeed,verticalSpeed)
    local self = setmetatable({}, DroneSteering_mt)
    self.owner = owner
    self.groundOffset = groundOffset
    self.carrySpeed = carrySpeed
    self.horizontalSpeed = horizontalSpeed
    self.verticalSpeed = verticalSpeed
    self.targetQuat = {x=0,y=0,z=0,w=0}
    self.startQuat = {x=0,y=0,z=0,w=0}
    self.targetSpline = nil
    self.pathDirection = 1
    self.currentSegmentIndex = 1
    self.radius = 0.5
    self.maxFutureDistance = 10
    self.minFutureDistance = 2
    self.futureDistance = 5
    self.targetDistance = 1
    self.slowRadius = 10
    self.startPointCallback = nil
    self.actionManager = DroneActionManager.new(self,true,false)
    self.actionManager:register(true)
    self.velocity = {x=0,y=0,z=0}
    self.acceleration = 0.5
    self.bHasArrived = false
    self.minDegreeDifference = 5
    self.rotationSpeed = 20
    return self
end

--- delete cleans up the actionManager.
function DroneSteering:delete()

    if self.actionManager ~= nil then
        self.actionManager:delete()
        self.actionManager = nil
    end

end

--- interrupt will stop the any steering or any going to spline action, and reset variables.
function DroneSteering:interrupt()

    self.bHasArrived = false
    self.previousSpline = self.targetSpline
    self.targetSpline = nil
    if self.actionManager ~= nil then
        self.actionManager:interrupt(self.owner)
    end

end

--- setTargetSpline used to set the spline which will be used to move drone to and then steer along.
--@param spline is of type CatmullRomSpline.
function DroneSteering:setTargetSpline(spline)
    self.targetSpline = spline
end

--- setPathDirection used to set direction 1 or -1, to indicate which direction along the spline should steer.
--@param direction either -1 which indicates moving backwards on the spline, 1 indicates forwards which is default.
function DroneSteering:setPathDirection(direction)
    self.pathDirection = direction
end

--- getToStartPoint is called before steering, to make drone move to the nearest position on spline.
--@param callback is used to signal after the moving to spline is complete.
function DroneSteering:getToStartPoint(callback)
    if self.owner == nil or self.targetSpline == nil then
        Logging.warning("No target spline set for drone steering before getting to start point?!")
        return
    end

    self.bHasArrived = false
    self.startPointCallback = callback
    self.futureDistance = 5

    if self.targetSpline ~= nil then

        local x,y,z = getWorldTranslation(self.owner.rootNode)

        local splinePosition, splineDistance, direction, _, segmentIndex = self.targetSpline:getClosePositionOnSpline({x=x,y=y,z=z})
        self.currentSegmentIndex = segmentIndex

        local _,splineDirection, _,_ = self.targetSpline:getSplineInformationAtDistance(splineDistance)

        if self.pathDirection == -1 then
            splineDirection.x = splineDirection.x * -1
            splineDirection.y = splineDirection.y * -1
            splineDirection.z = splineDirection.z * -1
        end

        self.velocity.x,self.velocity.y,self.velocity.z = splineDirection.x, splineDirection.y, splineDirection.z

        local actionsDoneCallback = function()
                if self.startPointCallback ~= nil then
                    self.startPointCallback()
                end
                if self.owner ~= nil then
                    local quatX, quatY, quatZ, quatW = getWorldQuaternion(self.owner.rootNode)
                    self:setNewTargetRotation({x=quatX,y=quatY,z=quatZ,w=quatW})
                end

            end

        local moveToSpline = DroneActionPhase.new(self.owner,splinePosition,nil,1,nil,nil,actionsDoneCallback,nil,nil)

        splineDirection.y = 0

        local rotateToSpline = DroneActionPhase.new(self.owner,nil,direction,nil,self.rotationSpeed,nil,nil,nil,moveToSpline)

        local toSplineAction = DroneActionPhase.new(self.owner,{x=x,y=splinePosition.y,z=z},nil,1,nil,nil,nil,nil,rotateToSpline)

        if self.actionManager ~= nil then
            self.actionManager:addAction(toSplineAction)
        end

    else
        Logging.warning("No target spline was set for drone before trying to get to start point!")
    end

end

--- run gets forwarded from owner update function, runs every tick to steer along targetSpline if valid.
--@param dt is deltatime in ms.
function DroneSteering:run(dt)
    if self.targetSpline == nil or self.bHasArrived then
        return
    end

    local sDt = dt / 1000

    local currentPosition = {x=0,y=0,z=0}
    currentPosition.x, currentPosition.y, currentPosition.z = getWorldTranslation(self.owner.rootNode)

    -- check before anything if current position has arrived at the end of spline
    if self:checkIfArrived(currentPosition) then
        return true
    end

    -- getting current direction from velocity and accelerating it and limiting it to maximum possible.
    local directionX, directionY, directionZ = MathUtil.vector3Normalize(self.velocity.x, self.velocity.y, self.velocity.z)
    self.velocity.x = self.velocity.x + (directionX * (self.acceleration * sDt))
    self.velocity.y = self.velocity.y + (directionY * (self.acceleration * sDt))
    self.velocity.z = self.velocity.z + (directionZ * (self.acceleration * sDt))
    self:limitVelocity(directionX,directionY,directionZ,false)

    -- predicting the future position not necessarily on the spline
    local futureX = currentPosition.x + (directionX * self.futureDistance)
    local futureY = currentPosition.y + (directionY * self.futureDistance)
    local futureZ = currentPosition.z + (directionZ * self.futureDistance)

    -- getting the close position on spline from the future position and distance along the spline, and distance to the target
    local splinePosition, splineDistance,_directionToSpline, distanceToTarget = self.targetSpline:getClosePositionOnCurve({x=futureX,y=futureY,z=futureZ},0.10,self.targetSpline.segments[self.currentSegmentIndex])
    -- getting also the tangent the forward direction of the position on spline
    local _,splineDirection, _,_ = self.targetSpline:getSplineInformationAtDistance(splineDistance)
    if self.pathDirection == -1 then
        splineDirection.x = splineDirection.x * -1
        splineDirection.y = splineDirection.y * -1
        splineDirection.z = splineDirection.z * -1
    end

    -- checking the distance on the spline if near the end point of spline then marking as close to end
    local bCloseToEnd = self:isWithinSlowRadius(splineDistance)

--     if not g_currentMission.connectedToDedicatedServer then
--         DebugUtil.drawOverlapBox(futureX, futureY, futureZ, 0, 0, 0, 0.25, 0.25, 0.25, 0, 0, 1)
--         DebugUtil.drawOverlapBox(splinePosition.x, splinePosition.y, splinePosition.z, 0, 0, 0, 0.25, 0.25, 0.25, 0, 1, 0)
--     end

    -- adjusts the current spline segment which position is on, if spline still continues and is close to end of an segment might set it to next segment
    self:adjustCurrentSegment(splinePosition)

    -- getting target on the spline to steer towards if future is outside self.radius
    local target = self:getTarget(splineDistance)

    -- adjust min height from ground as long as not nearing the end which might be near ground
    if not bCloseToEnd then
        self:limitTargetHeight(target)
        distanceToTarget = MathUtil.vector3Length(splinePosition.x - target.x, splinePosition.y - target.y, splinePosition.z - target.z)
    end

--     if not g_currentMission.connectedToDedicatedServer then
--         DebugUtil.drawOverlapBox(target.x, target.y, target.z, 0, 0, 0, 0.25, 0.25, 0.25, 1, 0, 0)
--     end


    local directionToTarget = {x=0,y=0,z=0}
    directionToTarget.x, directionToTarget.y, directionToTarget.z = MathUtil.vector3Normalize(target.x - currentPosition.x, target.y - currentPosition.y, target.z - currentPosition.z)
    -- getting current speed from velocity for later use
    local currentMagnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)

    -- if distance is greater then will steer towards target and caps the velocity
    if distanceToTarget > self.radius then
        self.velocity.x = self.velocity.x + ((directionToTarget.x * currentMagnitude) - self.velocity.x)
        self.velocity.y = self.velocity.y + ((directionToTarget.y * currentMagnitude) - self.velocity.y)
        self.velocity.z = self.velocity.z + ((directionToTarget.z * currentMagnitude) - self.velocity.z)

        directionX, directionY, directionZ = MathUtil.vector3Normalize(self.velocity.x, self.velocity.y, self.velocity.z)
        self:limitVelocity(directionX,directionY,directionZ,bCloseToEnd)
        currentMagnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)
    end

    -- adjusts the future distance based on speed that drone has, the faster the longer future distance used
    self:scaleFutureDistance(currentMagnitude)

    -- get final new position, and also interpolated rotation
    local newPosition = {x= currentPosition.x + (self.velocity.x * sDt),y = currentPosition.y + (self.velocity.y * sDt), z = currentPosition.z + (self.velocity.z * sDt)}
    local quatX, quatY, quatZ , quatW = self:getDroneRotation(sDt,splineDirection.x,splineDirection.y,splineDirection.z)

    self.owner:setWorldPositionQuaternion(newPosition.x, newPosition.y, newPosition.z, quatX,quatY, quatZ, quatW, 1, false)
    return false
end

--- isWithinSlowRadius called to check if drone on spline would be close enough to end of spline.
--@param splineDistance is the distance to check on spline if close to end.
--@return true if given distance is near the end depending on pathDirection.
function DroneSteering:isWithinSlowRadius(splineDistance)

    if self.pathDirection == 1 and splineDistance >= self.targetSpline:getSplineLength() - self.slowRadius then
        return true
    elseif splineDistance <= self.slowRadius then
        return true
    else
        return false
    end

end

--- limitTargetHeight used to limit the y height in place to be minimum terrainHeight + self.groundOffset.
--@param target is the target position which needs .y limited, given as {x=,y=,z=}.
function DroneSteering:limitTargetHeight(target)
    local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,target.x,target.y,target.z)
    target.y = MathUtil.clamp(target.y,terrainHeight + self.groundOffset,999999)
end

--- adjustCurrentSegment called to check if requires to change the tracked currentSegment value, in case the spline continues and near the end of a segment.
--@param currentPosition is position on the spline to check if near P1 or P2 control point depending on self.pathDirection.
function DroneSteering:adjustCurrentSegment(currentPosition)
    if self.targetSpline == nil then
        return
    end

    local currentSegment = self.targetSpline.segments[self.currentSegmentIndex]

    if self.pathDirection == -1 and self.targetSpline.segments[self.currentSegmentIndex - 1] ~= nil then
        if CatmullRomSpline.isNearlySamePosition(currentPosition,currentSegment.p1,0.5) then
            self.currentSegmentIndex = self.currentSegmentIndex - 1
        end
    elseif self.pathDirection == 1 and self.targetSpline.segments[self.currentSegmentIndex + 1] ~= nil then
        if CatmullRomSpline.isNearlySamePosition(currentPosition,currentSegment.p2,0.5) then
            self.currentSegmentIndex = self.currentSegmentIndex + 1
        end
    end

end

--- getTarget called to get forward position on the spline to target steer.
--@param currentDistance distance on the spline which was closest to drone future position.
--@return a new target to steer towards, given as {x=,y=,z=}.
function DroneSteering:getTarget(currentDistance)
    if self.targetSpline == nil or currentDistance == nil then
        return
    end

    local currentSegment = self.targetSpline.segments[self.currentSegmentIndex]

    local target = nil

    if self.pathDirection == 1 then
        target = CatmullRomSpline.getPosition(currentSegment,self.targetSpline:getEstimatedT(currentSegment,currentDistance + self.targetDistance))
    else
        target = CatmullRomSpline.getPosition(currentSegment,self.targetSpline:getEstimatedT(currentSegment,currentDistance - self.targetDistance))
    end

    return target
end

--- checkIfArrived used to check if steering has reached final position on spline.
--@param position is the position drone is at to check, given as {x=,y=,z=}.
--@return true if was at end.
function DroneSteering:checkIfArrived(position)

    local goalPosition = nil
    if self.pathDirection == 1 then
        goalPosition = self.targetSpline:getSegmentByTime(1).p2
    else
        goalPosition = self.targetSpline:getSegmentByTime(0).p1
    end

    if CatmullRomSpline.isNearlySamePosition(position,goalPosition,0.1) then
        local quatX, quatY, quatZ, quatW = getWorldQuaternion(self.owner.rootNode)
        self.owner:setWorldPositionQuaternion(goalPosition.x,goalPosition.y,goalPosition.z,quatX,quatY,quatZ,quatW,1,false)
        self:arrived()
        return true
    end

    return false
end

--- arrived used when drone has arrived at end, will save last used spline as previous spline, and call the drone arrived listeners.
function DroneSteering:arrived()
    self.bHasArrived = true
    self.previousSpline = self.targetSpline
    self.targetSpline = nil
    self.owner:onDroneArrived()
end

--- limitVelocity limits the drone velocity based on y direction, if close to arriving, and general maximum speed.
--@param directionX, drone's x direction.
--@param directionY, drone's y direction.
--@param directionZ, drone's z direction.
--@param bArriving, if close to arriving at the end of spline.
function DroneSteering:limitVelocity(directionX,directionY,directionZ,bArriving)

    local magnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)

    local alpha = math.abs(directionY)

    if bArriving then
        self.velocity.x, self.velocity.y, self.velocity.z = directionX * 1, directionY * 1, directionZ * 1
    end

    local maxVelocity = MathUtil.lerp(self.horizontalSpeed,self.verticalSpeed,alpha)

    if magnitude > maxVelocity then
        self.velocity.x, self.velocity.y, self.velocity.z = directionX * maxVelocity, directionY * maxVelocity, directionZ * maxVelocity
    end
end

--- scaleFutureDistance scales the future distance variable based on given speed.
--@param magnitude is the speed of drone that scales the future distance.
function DroneSteering:scaleFutureDistance(magnitude)

    magnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)
    alpha = CatmullRomSpline.normalize01(magnitude,self.verticalSpeed,self.horizontalSpeed)

    self.futureDistance = MathUtil.lerp(self.minFutureDistance,self.maxFutureDistance,alpha)
end

--- getDroneRotation interpolates drone rotation based on velocity direction and self.rotationSpeed.
--@param sDt is deltatime in seconds.
--@param directionX, drone's direction in X.
--@param directionY, drone's direction in Y.
--@param directionZ, drone's direction in Z.
--@return interpolated quaternion of new rotation.
function DroneSteering:getDroneRotation(sDt,directionX,directionY,directionZ)

    -- limit any new interpolation target to only when drone is mostly moving horizontally.
    if math.abs(directionY) < 0.8 then

        local velocityQuat = PickupDeliveryHelper.createTargetQuaternion(self.owner.rootNode,{x=directionX,y=directionY,z=directionZ})

        local newTargetDegree = math.deg(math.acos(self.targetQuat.x * velocityQuat.x + self.targetQuat.y * velocityQuat.y + self.targetQuat.z * velocityQuat.z + self.targetQuat.w * velocityQuat.w))

        if newTargetDegree > self.minDegreeDifference then
            self:setNewTargetRotation(velocityQuat)
        end

    end

    self.quaternionAlpha = MathUtil.clamp(self.quaternionAlpha + ((self.rotationSpeed * sDt) / self.toTargetDegrees),0,1)

    local quatX,quatY,quatZ,quatW = MathUtil.slerpQuaternion(self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w,self.targetQuat.x, self.targetQuat.y, self.targetQuat.z, self.targetQuat.w,self.quaternionAlpha)

    -- slerpQuaternion might give NaN values need to filter out
    if tostring(quatX) == "nan" or tostring(quatY) == "nan" or tostring(quatZ) == "nan" or tostring(quatW) == "nan" then
        quatX,quatY,quatZ,quatW = getWorldQuaternion(self.owner.rootNode)
    end

    return quatX,quatY,quatZ,quatW
end

--- setNewTargetRotation changes the interpolation target for rotation.
--@param targetQuat is the new given quaternion to interpolate towards, given as {x=,y=,z=,w=}.
function DroneSteering:setNewTargetRotation(targetQuat)

    local quatX, quatY, quatZ, quatW = getWorldQuaternion(self.owner.rootNode)
    self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w = quatX,quatY,quatZ,quatW
    self.quaternionAlpha = 0
    self.quaternionAlpha = 0
    self.toTargetDegrees = 0

    self.targetQuat = targetQuat
    self.toTargetDegrees = math.deg(math.acos(self.startQuat.x * self.targetQuat.x + self.startQuat.y * self.targetQuat.y + self.startQuat.z * self.targetQuat.z + self.startQuat.w * self.targetQuat.w))
end
