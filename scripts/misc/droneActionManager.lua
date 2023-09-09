

---@class DroneActionManager.
-- Handles moving drone to accurate location when delivering or picking up and moving in or out drones of hub while possibly executing actions.
DroneActionManager = {}
DroneActionManager_mt = Class(DroneActionManager,Object)
InitObjectClass(DroneActionManager, "DroneActionManager")

--- new creates a new DroneActionManager object.
--@param owner of this action manager.
--@param isServer if owner is server.
--@param isClient if owner is client.
--@param bSaveCurrent if the current drone id should be saved so in case of a queue the .
function DroneActionManager.new(owner,isServer,isClient,bSaveCurrent)
    local self = Object.new(isServer,isClient, DroneActionManager_mt)
    self.owner = owner
    self.phaseQueue = {}
    self.currentPhase = nil
    self.bSaveCurrent = bSaveCurrent
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


--- On saving
function DroneActionManager:saveToXMLFile(xmlFile, key, usedModNames)
    local id = ""
    if self.currentPhase ~= nil then
        id = self.currentPhase.drone:getID()
    end

    if self.bSaveCurrent then
        xmlFile:setValue(key..".droneActionManager#current", id)
    end



end

--- On loading
function DroneActionManager:loadFromXMLFile(xmlFile, key)

    local id = Utils.getNoNil(xmlFile:getValue(key..".droneActionManager#current"),"")
    if id ~= nil then
        self.loadedID = id
    end

    return true
end

--- Registering
function DroneActionManager.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING,        basePath .. ".droneActionManager#current", "Current drone id that was being moved")

end

--- update function called every frame when there is some drones to move around in phases.
--@param dt is deltatime in ms.
function DroneActionManager:update(dt)

    if self.currentPhase ~= nil then

        if self.currentPhase:run(dt) then -- returns true when phase was completed

            if self.currentPhase.next ~= nil then -- linked list so will point to next if has any other phases.
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

    if (self.currentPhase == nil and self.loadedID == nil) or (self.currentPhase == nil and self.loadedID == phase.drone:getID()) then
        self.loadedID = nil
        self.currentPhase = phase
        self:raiseActive()
        return
    end

    table.insert(self.phaseQueue,phase)
end