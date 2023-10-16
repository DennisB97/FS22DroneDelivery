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

---@class DroneActionPhase.
-- used on server only.
-- Class for handling one phase of moving drone in a hub, pickup or delivery point.
DroneActionPhase = {}
DroneActionPhase_mt = Class(DroneActionPhase)
InitObjectClass(DroneActionPhase, "DroneActionPhase")

--- new creates a new DroneActionPhase.
--@param drone is the drone that will be moved or rotated in the phase.
--@param targetPosition is the final position of this phase the drone should be moved to, can be nil.
--@param targetDirection is the look at direction drone should have at end of phase.
--@param speed is the speed that drone should have when being moved given in meters/s.
--@param rotationSpeed is the rotational degrees per second that drone should have to reach Y targetRotation, given in degrees/s.
--@param phaseStartCallback is optional callback to first get called when starting the phase.
--@param phaseEndCallback is optional callback to when phase ends.
--@param additionalTaskCallback is an optional callback to run each run to do something other too before finishing,
-- callback will receive booleans indicating if position is done and rotation is done and then the dt time and time elapsed since phase start, callback should return constantly true when finished if called.
--@param nextPhase is optional next phase which this links to.
function DroneActionPhase.new(drone,targetPosition,targetDirection,speed,rotationSpeed,phaseStartCallback,phaseEndCallback,additionalTaskCallback,nextPhase)
    local self = setmetatable({}, DroneActionPhase_mt)
    self.targetPosition = targetPosition
    self.targetDirection = targetDirection
    self.speed = speed or 1
    self.rotationSpeed = rotationSpeed or 10
    self.phaseStartCallback = phaseStartCallback
    self.phaseEndCallback = phaseEndCallback
    self.additionalTaskCallback = additionalTaskCallback
    self.firstRun = true
    self.drone = drone
    self.next = nextPhase
    self.currentTime = 0
    self.quaternionAlpha = 0
    self.toTargetDegrees = 0
    return self
end

--- setDrone is called to give this phase a drone, if wasn't given initially when phase was created.
-- will also give drone to the all the next phases linked to this phase.
--@param drone is the drone to give to the phase.
function DroneActionPhase:setDrone(drone)
    self.drone = drone

    if self.next ~= nil then
        self.next:setDrone(drone)
    end
end

--- reset called to reset this phase.
--@param bRecursive optionally will reset all the next phases too, to make sure if reusing root phase that all phases are reset.
function DroneActionPhase:reset(bRecursive)
    self.currentDistance = 0
    self.quaternionAlpha = 0
    self.toTargetDegrees = 0
    self.currentTime = 0
    self.firstRun = true

    if bRecursive and self.next ~= nil then
        self.next:reset(bRecursive)
    end
end

--- run forwarded from DroneActionManager which runs every update to actually execute this phase.
--@param dt is deltatime in ms.
--@return true if phase is completed.
function DroneActionPhase:run(dt)

    if self.drone == nil then
        return false
    end

    local sDt = dt / 1000
    local x,y,z = getWorldTranslation(self.drone.rootNode)
    local quatX,quatY,quatZ,quatW = getWorldQuaternion(self.drone.rootNode)

    -- if first run then sets initial target position and rotation if exists.
    if self.firstRun then
        self.firstRun = false

        if self.targetPosition ~= nil then
            self.startPosition = {}
            self.startPosition.x, self.startPosition.y, self.startPosition.z = x,y,z
            self.currentDistance = 0
            self.targetDistance = MathUtil.vector3Length(self.targetPosition.x - x,self.targetPosition.y - y, self.targetPosition.z - z)
        end

        if self.targetDirection ~= nil then

            if self.targetDirection.x ~= 0 and self.targetDirection.y ~= 0 or self.targetDirection.z ~= 0 then

                self.startQuat = {}
                self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w = quatX,quatY,quatZ,quatW

                self.targetQuat = PickupDeliveryHelper.createTargetQuaternion(self.drone.rootNode,self.targetDirection)
                self.toTargetDegrees = math.deg(math.acos(self.startQuat.x * self.targetQuat.x + self.startQuat.y * self.targetQuat.y + self.startQuat.z * self.targetQuat.z + self.startQuat.w * self.targetQuat.w))

                if math.abs(self.targetQuat.x-self.startQuat.x)< 0.005 and math.abs(self.targetQuat.y-self.startQuat.y) < 0.005 and math.abs(self.targetQuat.z-self.startQuat.z) < 0.005 and math.abs(self.targetQuat.w-self.startQuat.w) < 0.005 then
                    self.targetQuat = nil
                end
            end
        end

        if self.phaseStartCallback ~= nil then
            self.phaseStartCallback(self.drone)
        end
    end

    local bFinalPosition = true
    local bFinalRotation = true

    -- interpolates a target position if has one
    if self.targetPosition ~= nil then

        self.currentDistance = self.currentDistance + (sDt * self.speed)

        local alpha = MathUtil.clamp(CatmullRomSpline.normalize01(self.currentDistance,0,self.targetDistance),0,1)

        x, y, z = MathUtil.vector3Lerp(self.startPosition.x,self.startPosition.y,self.startPosition.z,self.targetPosition.x,self.targetPosition.y,self.targetPosition.z,alpha)

        if alpha ~= 1 then
            bFinalPosition = false
        end

    end

    -- interpolates a target quaternion if has one
    if self.targetQuat ~= nil then

        self.quaternionAlpha = MathUtil.clamp(self.quaternionAlpha + ((self.rotationSpeed * sDt) / self.toTargetDegrees),0,1)

        quatX,quatY,quatZ,quatW = MathUtil.slerpQuaternion(self.startQuat.x, self.startQuat.y, self.startQuat.z, self.startQuat.w,self.targetQuat.x, self.targetQuat.y, self.targetQuat.z, self.targetQuat.w,self.quaternionAlpha)

        -- slerpQuaternion might give NaN values need to filter out
        if tostring(quatX) == "nan" or tostring(quatY) == "nan" or tostring(quatZ) == "nan" or tostring(quatW) == "nan" then
            quatX,quatY,quatZ,quatW = getWorldQuaternion(self.owner.rootNode)
        end

        if self.quaternionAlpha < 1 then
            bFinalRotation = false
        end

    end

    self.currentTime = self.currentTime + sDt

    self.drone:setWorldPositionQuaternion(x,y,z, quatX,quatY,quatZ,quatW, 1, false)

    local additionalTaskDone = true

    if self.additionalTaskCallback ~= nil then
        additionalTaskDone = self.additionalTaskCallback(bFinalPosition,bFinalRotation,sDt,self.currentTime)
    end

    -- if all returns true then done with this phase
    if bFinalPosition and bFinalRotation and additionalTaskDone then

        self:reset()
        if self.phaseEndCallback ~= nil then
            self.phaseEndCallback(self.drone)
        end

        return true
    end


    return false
end



