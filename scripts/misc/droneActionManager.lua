

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


function DroneActionManager:delete()

    if self.isDeleted then
        return
    end

    self.isDeleted = true


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

function DroneActionManager:addDrone(phase)
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