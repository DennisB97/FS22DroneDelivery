---@class DroneSteering.
-- Handles steering a drone along spline path.
DroneSteering = {}
DroneSteering_mt = Class(DroneSteering)
InitObjectClass(DroneSteering, "DroneSteering")

--- new creates a new DroneSteering object.
function DroneSteering.new()
    local self = setmetatable({}, DroneSteering_mt)
    self.currentPath = nil
    self.currentDistance = 0
    self.maxVelocity = 15

    return self
end


function DroneSteering:steer(dt)

    if self.currentPath ~= nil then
        self.currentDistance = self.currentDistance + ((dt/1000) * self.maxVelocity)
        local splineLength = self.currentPath:getSplineLength()
        local difference = math.abs(splineLength - self.currentDistance)
        local endPosition,endDirection,_,_ = self.currentPath:getSplineInformationAtDistance(splineLength)
        if self.currentDistance >= self.currentPath:getSplineLength() then
            self.currentPath = self.bufferPath
            self.bufferPath = nil
            self.currentDistance = difference
        end

        if self.currentPath ~= nil then
            local position,forwardDirection,_ = self.currentPath:getSplineInformationAtDistance(self.currentDistance)
            self:alignBirdWithSpline(position,forwardDirection)

        else
            self.currentDistance = 0
            self:alignBirdWithSpline(endPosition,endDirection)

            if self.currentState == self.EBirdStates.LEAVEFLY then
                if self.spawnPosition.x == endPosition.x and self.spawnPosition.y == endPosition.y and self.spawnPosition.z == endPosition.z then
                    self:changeState(self.EBirdStates.HIDDEN)
                end
            elseif self.currentState == self.EBirdStates.FEEDERLAND then
                self:changeState(self.EBirdStates.EAT)
            end
        end
    end
end



function DroneSteering:alignDroneWithSpline(position,direction)
    if position == nil or direction == nil then
        return
    end

    local newYRot = MathUtil.getYRotationFromDirection(direction.x,direction.z)
    local rotX,_,rotZ = getRotation(self.rootNode)



    self:setPositionAndRotation(position,{x=rotX,y=newYRot,z=rotZ},false)
end