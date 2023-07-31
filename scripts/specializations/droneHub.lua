--[[
This file is part of Bird feeder mod (https://github.com/DennisB97/FS22DroneDelivery)

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



--- Drone Hub specialization for placeables.
---@class DroneHub.
DroneHub = {}

--- prerequisitesPresent checks if all prerequisite specializations are loaded, none needed in this case.
--@param table specializations specializations.
--@return boolean hasPrerequisite true if all prerequisite specializations are loaded.
function DroneHub.prerequisitesPresent(specializations)
    return true;
end


--- registerEventListeners registers all needed FS events.
function DroneHub.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", DroneHub)
    SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", DroneHub)
end

--- run is part of activatableObjectsSystem call which gets called when this hub tries to be activated.
function DroneHub:run()
    if g_droneHubScreen == nil then
        Logging.warning("g_droneHubScreen was nil when trying to open the GUI!")
        return
    end

    if not self.spec_droneHub.bInUse then
        self:setInUse(true)
        DroneHubAccessedEvent.sendEvent(self,true)
        g_droneHubScreen:setController(self)
        g_gui:showGui("DroneHubScreen")
    end

end

--- registerFunctions registers new functions.
function DroneHub.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onMenuTriggerCallback", DroneHub.onMenuTriggerCallback)
    SpecializationUtil.registerFunction(placeableType, "run", DroneHub.run)
    SpecializationUtil.registerFunction(placeableType, "linkDrone", DroneHub.linkDrone)
    SpecializationUtil.registerFunction(placeableType, "unLinkDrone", DroneHub.unLinkDrone)
    SpecializationUtil.registerFunction(placeableType, "addOnSlotStateChangedListeners", DroneHub.addOnSlotStateChangedListeners)
    SpecializationUtil.registerFunction(placeableType, "removeOnSlotStateChangedListeners", DroneHub.removeOnSlotStateChangedListeners)
    SpecializationUtil.registerFunction(placeableType, "onSlotStateChange", DroneHub.onSlotStateChange)
    SpecializationUtil.registerFunction(placeableType, "renameDroneRoute", DroneHub.renameDroneRoute)
    SpecializationUtil.registerFunction(placeableType, "onGridMapGenerated", DroneHub.onGridMapGenerated)
    SpecializationUtil.registerFunction(placeableType, "initializeHub", DroneHub.initializeHub)
    SpecializationUtil.registerFunction(placeableType, "applyConfigSettings", DroneHub.applyConfigSettings)
    SpecializationUtil.registerFunction(placeableType, "setInUse", DroneHub.setInUse)
    SpecializationUtil.registerFunction(placeableType, "onExitingMenu", DroneHub.onExitingMenu)
end

--- registerEvents registers new events.
function DroneHub.registerEvents(placeableType)
--     SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederFillLevelChanged")

end

--- registerOverwrittenFunctions register overwritten functions.
function DroneHub.registerOverwrittenFunctions(placeableType)
--     SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", DroneHub.collectPickObjectsOW)

end

--- onLoad loading creates the
--@param savegame loaded savegame.
function DroneHub:onLoad(savegame)
	--- Register the spec
	self.spec_droneHub = self["spec_FS22_DroneDelivery.droneHub"]
    local xmlFile = self.xmlFile
    local spec = self.spec_droneHub
    self.activateText = g_i18n:getText("droneHub_hubActivateText")
    spec.droneSlots = {}
    spec.slotStateChangedListeners = {}

    if self.isServer then
        spec.bSearchedDrones = false


    end

    local i = 0
    while true do
        local droneKey = string.format("placeable.droneHub.drones.drone(%d)", i)

        if not xmlFile:hasProperty(droneKey) then
            break
        else

            local slotNode = xmlFile:getValue(droneKey .. "#attachNode",nil,self.components,self.i3dMappings)
            local position = {}
            position.x,position.y,position.z = getWorldTranslation(slotNode)
            local rotation = {}
            rotation.x, rotation.y,rotation.z = getWorldRotation(slotNode)
            local droneSlot = DroneHubDroneSlot.new(self,i+1,position,rotation)
            table.insert(spec.droneSlots,droneSlot)
            i = i + 1
        end
    end

    spec.menuTrigger = xmlFile:getValue("placeable.droneHub#menuTrigger",nil,self.components,self.i3dMappings)
    if spec.menuTrigger ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.menuTrigger, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "DroneHub:onLoad: menu trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end

end

--- onDelete when drone hub deleted, clean up the unloading station and storage and birds and others.
function DroneHub:onDelete()
    local spec = self.spec_droneHub

    if self.isServer then
        g_messageCenter:unsubscribe(MessageType.GRIDMAP3D_GRID_GENERATED,self)
    end

    if spec.menuTrigger ~= nil then
        removeTrigger(spec.menuTrigger)
        spec.menuTrigger = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
function DroneHub:onUpdate(dt)
    local spec = self.spec_droneHub

    -- initial update, search through the world to find all drones in the world and check if any belong linked to this hub
    if self.isServer and not spec.bSearchedDrones then

        for _, slot in ipairs(spec.droneSlots) do
            slot:searchDrone()
        end

        spec.bSearchedDrones = true

    end



end

--- debugRender if debug is on for mod then debug renders some feeder variables.
--@param dt is deltatime received from update function.
function DroneHub:debugRender(dt)
    if not self.isServer then
        return
    end

    local spec = self.spec_droneHub
    self:raiseActive()


end

--- Event on finalizing the placement of this bird feeder.
-- used to create the birds and feeder states and other variables initialized.
function DroneHub:onFinalizePlacement()
    local spec = self.spec_droneHub
    local xmlFile = self.xmlFile

    if self.isServer then
        --@TODO: TEMP
        self:initializeHub()

        if FlyPathfinding and FlyPathfinding.bPathfindingEnabled then

            if g_currentMission.gridMap3D:isAvailable() then
                self:initializeHub()
            else
                g_messageCenter:subscribe(MessageType.GRIDMAP3D_GRID_GENERATED, self.onGridMapGenerated, self)
            end
        else

            for _, slot in ipairs(spec.droneSlots) do
                slot:changeState(slot.EDroneWorkStatus.INCOMPATIBLE)
            end

        end
    end


    if spec.menuTrigger ~= nil then
        addTrigger(spec.menuTrigger,"onMenuTriggerCallback",self)
    end

end

function DroneHub:onGridMapGenerated()
--     self:initializeHub()
end

function DroneHub:initializeHub()
    local spec = self.spec_droneHub
    local dirtyFlags = 0
    for _, slot in ipairs(spec.droneSlots) do
        dirtyFlags = dirtyFlags + slot:initialize()
    end

    self:raiseDirtyFlags(dirtyFlags)
end

--- Registering
function DroneHub.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DroneHub")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".droneHub#menuTrigger", "trigger used to be able to enter the menu of dronehub")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".droneHub.drones.drone(?)#attachNode", "drone attach node on hub")
    DroneHubDroneSlot.registerXMLPaths(schema, basePath .. ".droneHub.drones.drone(?)")
--
    schema:setXMLSpecializationType()
end

--- Registering
function DroneHub.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DroneHub")

    DroneHubDroneSlot.registerSavegameXMLPaths(schema, basePath .. "drones.drone(?)")
    schema:setXMLSpecializationType()
end

--- On saving,
function DroneHub:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_droneHub

    for i, slot in ipairs(spec.droneSlots) do
        local slotKey = string.format(key .. "drones.drone(%d)",i)
        slot:saveToXMLFile(xmlFile,slotKey, usedModNames)
    end

end

--- On loading,
function DroneHub:loadFromXMLFile(xmlFile, key)
    local spec = self.spec_droneHub

    for i, slot in ipairs(spec.droneSlots) do
        local slotKey = string.format(key .. "drones.drone(%d)",i)
        slot:loadFromXMLFile(xmlFile, slotKey)
    end

    return true
end

--- onReadStream initial receive at start from server these variables.
function DroneHub:onReadStream(streamId, connection)

    if connection:getIsServer() then
        local spec = self.spec_droneHub

        for _, slot in ipairs(spec.droneSlots) do
            slot:readStream(streamId,connection)
        end


    end
end

--- onWriteStream initial sync at start from server to client these variables.
function DroneHub:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
        local spec = self.spec_droneHub


        for _, slot in ipairs(spec.droneSlots) do
            slot:writeStream(streamId,connection)
        end


    end
end

--- onReadUpdateStream receives from server these variables when dirty raised on server.
function DroneHub:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_droneHub

        for _, slot in ipairs(spec.droneSlots) do
            slot:readUpdateStream(streamId,timestamp,connection)
        end

    end

end

--- onWriteUpdateStream syncs from server to client these variabels when dirty raised.
function DroneHub:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_droneHub
        print("write update stream")
        for _, slot in ipairs(spec.droneSlots) do
            slot:writeUpdateStream(streamId,connection,dirtyMask)
        end



    end

end

-- --- collectPickObjectsOW overriden function for collecting pickable objects, avoiding error for trigger node getting added twice.
-- --@param superFunc original function.
-- --@param trigger node
-- function DroneHub:collectPickObjectsOW(superFunc,node)
--     local spec = self.spec_droneHub
--     local bExists = false
--
--     if spec == nil then
--         superFunc(self,node)
--         return
--     end
--
--     if getRigidBodyType(node) ~= RigidBodyType.NONE then
--        for _, loadTrigger in ipairs(spec.unloadingStation.unloadTriggers) do
--             if node == loadTrigger.exactFillRootNode then
--                 bExists = true
--                 break
--             end
--         end
--     end
--
--     if not bExists then
--         superFunc(self,node)
--     end
-- end

--- onMenuTriggerCallback is called when player enters larger trigger around the hub.
--@param triggerId is the trigger's id.
--@param otherId is the id of the one triggering the trigger.
--@param onEnter is bool indicating if entered.
--@param onLeave is indicating if left the trigger.
--@param onStay indicates if staying on the trigger.
function DroneHub:onMenuTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if g_currentMission == nil then
        return
    end

    local spec = self.spec_droneHub
    local player = g_currentMission.players[otherId]

    if player ~= nil and player.farmId == self:getOwnerFarmId() then

        local playerFarm = g_farmManager:getFarmByUserId(player.userId)

        -- require manageProduction permissions from player to adjust drone settings in the hub.
        if playerFarm ~= nil and playerFarm.userIdToPlayer[player.userId] ~= nil and playerFarm.userIdToPlayer[player.userId].permissions.manageProductions then

            if onEnter then
                g_currentMission.activatableObjectsSystem:addActivatable(self)
            else
                g_currentMission.activatableObjectsSystem:removeActivatable(self)
            end

        else
            if onEnter then
                g_currentMission.hud.sideNotifications:addNotification(g_i18n:getText("droneHub_rightsMissing"),{0,0,0,1},5000)
            end
        end
    end

end

function DroneHub:linkDrone(drone,id,slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeLinking(drone,id)
end

function DroneHub:unLinkDrone(slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeUnlinking()
end

function DroneHub:applyConfigSettings(slotIndex,pickUpPointCopy,deliveryPointCopy)

    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeSettingsApply(pickUpPointCopy,deliveryPointCopy)
end

function DroneHub:renameDroneRoute(slotIndex,name)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeRenaming(name)
end

function DroneHub:setInUse(inUse)
    local spec = self.spec_droneHub

    spec.bInUse = inUse
end

function DroneHub:onExitingMenu()
    self:setInUse(false)
    DroneHubAccessedEvent.sendEvent(self,false)

end

function DroneHub:addOnSlotStateChangedListeners(callback)
    table.addElement(self.spec_droneHub.slotStateChangedListeners,callback)
end

function DroneHub:removeOnSlotStateChangedListeners(callback)
    table.removeElement(self.spec_droneHub.slotStateChangedListeners, callback)
end

function DroneHub:onSlotStateChange(slotIndex)
    for _, callback in ipairs(self.spec_droneHub.slotStateChangedListeners) do
        callback(slotIndex)
    end
end

-- --- onGridMapGenerated bound function to the broadcast when gridmap has been generated.
-- -- server only.
-- function PlaceableFeeder:onGridMapGenerated()
--     self:initializeFeeder()
-- end













