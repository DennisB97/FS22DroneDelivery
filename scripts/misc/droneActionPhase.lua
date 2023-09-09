
---@class DroneActionPhase.
-- used on server only.
-- Class for handling one phase of moving drone in a hub, pickup or delivery point.
DroneActionPhase = {}
DroneActionPhase_mt = Class(DroneActionPhase)
InitObjectClass(DroneActionPhase, "DroneActionPhase")

--- new creates a new PlaceablesPointManager object.
--@param drone is the drone that will be moved or rotated in the phase.
--@param targetPosition is the final position of this phase the drone should be moved to, can be nil.
--@param targetDirection is the look at direction drone should have at end of phase.
--@param speed is the speed that drone should have when being moved given in meters/s.
--@param rotationTime is the rotational time that drone should have to reach Y targetRotation, given in s.
--@param phaseStartCallback is optional callback to first get called when starting the phase.
--@param phaseEndCallback is optional callback to when phase ends.
--@param additionalTaskCallback is an optional callback to run each run to do something other too before finishing,
-- callback will receive booleans indicating if position is done and rotation is done and then the dt time, callback should return constantly true when finished if called.
--@param nextPhase is optional next phase which this links to.
function DroneActionPhase.new(drone,targetPosition,targetDirection,speed,rotationTime,phaseStartCallback,phaseEndCallback,additionalTaskCallback,nextPhase)
    local self = setmetatable({}, DroneActionPhase_mt)
    self.targetPosition = targetPosition
    self.targetDirection = targetDirection
    self.speed = speed or 1
    self.rotationTime = rotationTime or 1
    self.phaseStartCallback = phaseStartCallback
    self.phaseEndCallback = phaseEndCallback
    self.additionalTaskCallback = additionalTaskCallback
    self.firstRun = true
    self.drone = drone
    self.next = nextPhase
    self.currentTime = 0
    return self
end

function DroneActionPhase:setDrone(drone)
    self.drone = drone

    if self.next ~= nil then
        self.next:setDrone(drone)
    end
end

function DroneActionPhase:reset()
    self.currentDistance = 0
end

function DroneActionPhase:run(dt)

    if self.drone == nil then
        return false
    end

    local x,y,z = getWorldTranslation(self.drone.rootNode)
    local quatX,quatY,quatZ,quatW = getWorldQuaternion(self.drone.rootNode)

    if self.firstRun then
        self.firstRun = false

        if self.targetPosition ~= nil then
            self.startPosition = {}
            self.startPosition.x, self.startPosition.y, self.startPosition.z = x,y,z
            self.currentDistance = 0
            self.targetDistance = MathUtil.vector3Length(self.targetPosition.x - x,self.targetPosition.y - y, self.targetPosition.z - z)
        end

        if self.targetDirection ~= nil then

            self.startQuat = {}
            self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w = quatX,quatY,quatZ,quatW

            self.targetQuat = PickupDeliveryHelper.createTargetQuaternion(self.drone.rootNode,self.targetDirection)
        end

        if self.phaseStartCallback ~= nil then
            self.phaseStartCallback()
        end
    end

    local bFinalPosition = true
    local bFinalRotation = true

    if self.targetPosition ~= nil then

        self.currentDistance = self.currentDistance + ((dt/1000) * self.speed)

        local alpha = MathUtil.clamp(CatmullRomSpline.normalize01(self.currentDistance,0,self.targetDistance),0,1)

        x, y, z = MathUtil.vector3Lerp(self.startPosition.x,self.startPosition.y,self.startPosition.z,self.targetPosition.x,self.targetPosition.y,self.targetPosition.z,alpha)

        if alpha ~= 1 then
            bFinalPosition = false
        end

    end


    if self.targetQuat ~= nil then

        local alpha = MathUtil.clamp(CatmullRomSpline.normalize01(self.currentTime,0,self.rotationTime),0,1)

        quatX,quatY,quatZ,quatW = MathUtil.slerpQuaternion(self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w,self.targetQuat.x, self.targetQuat.y, self.targetQuat.z, self.targetQuat.w,alpha)

        if alpha ~= 1 then
            bFinalRotation = false
        end

    end

    self.currentTime = self.currentTime + (dt/1000)

    self.drone:setWorldPositionQuaternion(x,y,z, quatX,quatY,quatZ,quatW, 1, true)

    local additionalTaskDone = true

    if self.additionalTaskCallback ~= nil then
        additionalTaskDone = self.additionalTaskCallback(bFinalPosition,bFinalRotation,dt)
    end

    if bFinalPosition and bFinalRotation and additionalTaskDone then

        self:reset()
        if self.phaseEndCallback ~= nil then
            self.phaseEndCallback()
        end

        return true
    end


    return false
end



