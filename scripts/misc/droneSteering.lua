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
    self.targetSpline = nil
    self.pathDirection = 1
    self.currentSegmentIndex = 1
    self.radius = 0.5
    self.maxFutureDistance = 10
    self.minFutureDistance = 2
    self.futureDistance = 5
    self.targetDistance = 3
    self.slowRadius = 10
    self.startPointCallback = nil
    self.actionManager = DroneActionManager.new(self,true,false)
    self.actionManager:register(true)
    self.velocity = {x=0,y=0,z=0}
    self.acceleration = 0.5
    self.bHasArrived = false
    return self
end


function DroneSteering:interrupt()

    self.bHasArrived = false
    self.targetSpline = nil
    if self.actionManager ~= nil then
        self.actionManager:interrupt(self.owner)
    end


end

function DroneSteering:delete()

    if self.actionManager ~= nil then
        self.actionManager:delete()
        self.actionManager = nil
    end

end

function DroneSteering:setTargetSpline(spline)
    self.targetSpline = spline
end

function DroneSteering:setPathDirection(direction)
    self.pathDirection = direction
end

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
            end

--         local rotateToSplineMoveDirection = DroneActionPhase.new(self.owner,nil,splineDirection,nil,10,nil,actionsDoneCallback,nil,nil)

        local moveToSpline = DroneActionPhase.new(self.owner,splinePosition,nil,1,nil,nil,actionsDoneCallback,nil,nil)

        splineDirection.y = 0

        local rotateToSpline = DroneActionPhase.new(self.owner,nil,direction,nil,10,nil,nil,nil,moveToSpline)

        local toSplineAction = DroneActionPhase.new(self.owner,{x=x,y=splinePosition.y,z=z},nil,1,nil,nil,nil,nil,rotateToSpline)

        if self.actionManager ~= nil then
            self.actionManager:addDrone(toSplineAction)
        end

    end
end

function DroneSteering:run(dt)
    if self.targetSpline == nil or self.bHasArrived then
        return
    end

    local sDt = dt / 1000

    local currentPosition = {x=0,y=0,z=0}
    currentPosition.x, currentPosition.y, currentPosition.z = getWorldTranslation(self.owner.rootNode)

    if self:checkIfArrived(currentPosition) then
        return true
    end

    local directionX, directionY, directionZ = MathUtil.vector3Normalize(self.velocity.x, self.velocity.y, self.velocity.z)

    self.velocity.x = self.velocity.x + (directionX * (self.acceleration * sDt))
    self.velocity.y = self.velocity.y + (directionY * (self.acceleration * sDt))
    self.velocity.z = self.velocity.z + (directionZ * (self.acceleration * sDt))
    self:limitVelocity(directionX,directionY,directionZ,false)

    local currentMagnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)

    local futureX = currentPosition.x + (directionX * self.futureDistance)
    local futureY = currentPosition.y + (directionY * self.futureDistance)
    local futureZ = currentPosition.z + (directionZ * self.futureDistance)

    DebugUtil.drawOverlapBox(futureX, futureY, futureZ, 0, 0, 0, 0.25, 0.25, 0.25, 0, 0, 1)

    local splinePosition, splineDistance,directionToSpline, distanceToTarget = self.targetSpline:getClosePositionOnCurve({x=futureX,y=futureY,z=futureZ},0.10,self.targetSpline.segments[self.currentSegmentIndex])

    local bCloseToEnd = self:isWithinSlowRadius(splineDistance)


    DebugUtil.drawOverlapBox(splinePosition.x, splinePosition.y, splinePosition.z, 0, 0, 0, 0.25, 0.25, 0.25, 0, 1, 0)
    self:adjustCurrentSegment(splinePosition)
    local target = self:getTarget(splinePosition,splineDistance)

    -- adjust min height from ground as long as not nearing the end which might be near ground
    if not bCloseToEnd then
        self:limitTargetHeight(target)
    end


    DebugUtil.drawOverlapBox(target.x, target.y, target.z, 0, 0, 0, 0.25, 0.25, 0.25, 1, 0, 0)

    local directionToTarget = {x=0,y=0,z=0}
    directionToTarget.x, directionToTarget.y, directionToTarget.z = MathUtil.vector3Normalize(target.x - currentPosition.x, target.y - currentPosition.y, target.z - currentPosition.z)

    if distanceToTarget > self.radius then
        self.velocity.x = self.velocity.x + ((directionToTarget.x * currentMagnitude) - self.velocity.x)
        self.velocity.y = self.velocity.y + ((directionToTarget.y * currentMagnitude) - self.velocity.y)
        self.velocity.z = self.velocity.z + ((directionToTarget.z * currentMagnitude) - self.velocity.z)

        directionX, directionY, directionZ = MathUtil.vector3Normalize(self.velocity.x, self.velocity.y, self.velocity.z)
        self:limitVelocity(directionX,directionY,directionZ,bCloseToEnd)
    end

    currentMagnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)
    self:scaleFutureDistance(currentMagnitude)

    local newPosition = {x= currentPosition.x + (self.velocity.x * sDt),y = currentPosition.y + (self.velocity.y * sDt), z = currentPosition.z + (self.velocity.z * sDt)}

    local quatX, quatY, quatZ, quatW = getWorldQuaternion(self.owner.rootNode)

    self.owner:setWorldPositionQuaternion(newPosition.x, newPosition.y, newPosition.z, quatX,quatY, quatZ, quatW, 1, true)

    return false
end

function DroneSteering:isWithinSlowRadius(splineDistance)

    if self.pathDirection == 1 and splineDistance >= self.targetSpline:getSplineLength() - self.slowRadius then
        return true
    elseif splineDistance <= self.slowRadius then
        return true
    else
        return false
    end

end

function DroneSteering:limitTargetHeight(target)
    target.y = MathUtil.clamp(target.y,self.groundOffset,999999)
end

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

function DroneSteering:getTarget(splinePosition,currentDistance)

    if self.targetSpline == nil then
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



function DroneSteering:checkIfArrived(position)

    local goalPosition = nil
    if self.pathDirection == 1 then
        goalPosition = self.targetSpline:getSegmentByTime(1).p2
    else
        goalPosition = self.targetSpline:getSegmentByTime(0).p1
    end

    if CatmullRomSpline.isNearlySamePosition(position,goalPosition,0.1) then
        local quatX, quatY, quatZ, quatW = getWorldQuaternion(self.owner.rootNode)
        self.owner:setWorldPositionQuaternion(goalPosition.x,goalPosition.y,goalPosition.z,quatX,quatY,quatZ,quatW,1,true)
        self:arrived()
        return true
    end

    return false
end

function DroneSteering:arrived()
    self.bHasArrived = true
    self.targetSpline = nil
    self.owner:onDroneArrived()
end



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

function DroneSteering:scaleFutureDistance(magnitude)

    magnitude = MathUtil.vector3Length(self.velocity.x,self.velocity.y,self.velocity.z)
    alpha = CatmullRomSpline.normalize01(magnitude,self.verticalSpeed,self.horizontalSpeed)

    self.futureDistance = MathUtil.lerp(self.minFutureDistance,self.maxFutureDistance,alpha)

end

