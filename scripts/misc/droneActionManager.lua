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

---@class DroneActionManager.
-- Handles moving drone to accurate location when delivering or picking up and moving in or out drones of hub while possibly executing actions.
DroneActionManager = {}
DroneActionManager_mt = Class(DroneActionManager,Object)
InitObjectClass(DroneActionManager, "DroneActionManager")

--- new creates a new DroneActionManager object.
--@param owner of this action manager.
--@param isServer if owner is server.
--@param isClient if owner is client.
function DroneActionManager.new(owner,isServer,isClient)
    local self = Object.new(isServer,isClient, DroneActionManager_mt)
    self.owner = owner
    self.phaseQueue = {}
    self.currentPhase = nil
    self.isDeleted = false
    return self
end

--- delete when deleted cleans up and interrupts any ongoing action.
function DroneActionManager:delete()

    if self.isDeleted then
        return
    end

    self.isDeleted = true
    self:interruptAll()

    DroneActionManager:superClass().delete(self)
end

--- update function called every frame when there is some drones to move around in phases.
--@param dt is deltatime in ms.
function DroneActionManager:update(dt)

    if self.currentPhase ~= nil then

        if self.currentPhase:run(dt) then -- returns true when phase was completed

            if self.currentPhase ~= nil and self.currentPhase.next ~= nil then -- linked list so will point to next if has any other phases.
                self.currentPhase = self.currentPhase.next
            elseif next(self.phaseQueue) ~= nil then -- if no new phase then checks queue if has any new drone in queue.
                self.currentPhase = self.phaseQueue[1]
                table.remove(self.phaseQueue,1)
            else -- else returns so that raiseActive is not called as no need to run the update when doesn't move anything.
                self.currentPhase = nil
                return
            end
        end

        self:raiseActive()
    end

end

--- addAction used to add an action phase to the manager.
-- phase is of type DroneActionPhase, which contains the movement/rotation and some action information to do.
function DroneActionManager:addAction(phase)
    if phase == nil then
        return
    end

    if self.currentPhase == nil then
        self.currentPhase = phase
        self:raiseActive()
        return
    end

    table.insert(self.phaseQueue,phase)
end

--- interrupt is called to interrupt the current action phase, if there is more in queue will set next as current.
--@param drone is the owner of an action phase to find the correct phase and interrupt and remove.
function DroneActionManager:interrupt(drone)
    if drone == nil then
        return
    end

    if self.currentPhase ~= nil and self.currentPhase.drone == drone then
        self.currentPhase:reset(true)
        self.currentPhase = nil
        if next(self.phaseQueue) ~= nil then
            self.currentPhase = self.phaseQueue[1]
            table.remove(self.phaseQueue,1)
        end

    else

        for i,phase in ipairs(self.phaseQueue) do
            if phase.drone == drone then
                table.remove(self.phaseQueue,i)
                break
            end
        end

    end
end

--- interruptAll is used to remove and interrupt all queued and current action phases.
function DroneActionManager:interruptAll()

    if self.currentPhase ~= nil then
        self:interrupt(self.currentPhase.drone)
    end

    for _, phase in ipairs(self.phaseQueue) do
        self:interrupt(phase.drone)
    end

    self.currentPhase = nil
    self.phaseQueue = {}
end