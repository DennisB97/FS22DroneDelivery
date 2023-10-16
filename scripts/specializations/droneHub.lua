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
    SpecializationUtil.registerFunction(placeableType, "addOnDataChangedListeners", DroneHub.addOnDataChangedListeners)
    SpecializationUtil.registerFunction(placeableType, "removeOnDataChangedListeners", DroneHub.removeOnDataChangedListeners)
    SpecializationUtil.registerFunction(placeableType, "onDataChange", DroneHub.onDataChange)
    SpecializationUtil.registerFunction(placeableType, "renameDroneRoute", DroneHub.renameDroneRoute)
    SpecializationUtil.registerFunction(placeableType, "onGridMapGenerated", DroneHub.onGridMapGenerated)
    SpecializationUtil.registerFunction(placeableType, "initializeHub", DroneHub.initializeHub)
    SpecializationUtil.registerFunction(placeableType, "receiveConfigSettings", DroneHub.receiveConfigSettings)
    SpecializationUtil.registerFunction(placeableType, "validatedSlotSettings", DroneHub.validatedSlotSettings)
    SpecializationUtil.registerFunction(placeableType, "setInUse", DroneHub.setInUse)
    SpecializationUtil.registerFunction(placeableType, "onExitingMenu", DroneHub.onExitingMenu)
    SpecializationUtil.registerFunction(placeableType, "getEntrancePosition", DroneHub.getEntrancePosition)
    SpecializationUtil.registerFunction(placeableType, "invalidPlacement", DroneHub.invalidPlacement)
    SpecializationUtil.registerFunction(placeableType, "checkAccess", DroneHub.checkAccess)
    SpecializationUtil.registerFunction(placeableType, "checkAccessInitCallback", DroneHub.checkAccessInitCallback)
    SpecializationUtil.registerFunction(placeableType, "hasAnyLinkedDrones", DroneHub.hasAnyLinkedDrones)
    SpecializationUtil.registerFunction(placeableType, "setChargeCoverAnimation", DroneHub.setChargeCoverAnimation)
    SpecializationUtil.registerFunction(placeableType, "getDroneHandler", DroneHub.getDroneHandler)
    SpecializationUtil.registerFunction(placeableType, "setSlotDirty", DroneHub.setSlotDirty)
    SpecializationUtil.registerFunction(placeableType, "clearConfigSettings", DroneHub.clearConfigSettings)
end

--- registerOverwrittenFunctions register overwritten functions.
function DroneHub.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "canBeSold", DroneHub.canBeSold)
end

--- onLoad loading creates all the required variables and creates the slots for the drones.
--@param savegame loaded savegame.
function DroneHub:onLoad(savegame)
	--- Register the spec
	self.spec_droneHub = self["spec_FS22_DroneDelivery.droneHub"]
    local xmlFile = self.xmlFile
    local spec = self.spec_droneHub
    self.activateText = g_i18n:getText("droneHub_hubActivateText")
    spec.bInvalid = false
    spec.droneSlots = {}
    spec.dataChangedListeners = {}
    spec.uiSlotDataDirtyFlag = self:getNextDirtyFlag()
    spec.uiSlotDirtyIndex = -1

    if self.isServer then
        spec.entrancePosition = {}
        local entrance = xmlFile:getValue("placeable.droneHub#entrance",nil,self.components,self.i3dMappings)
        if entrance == nil then
            Logging.xmlWarning(self.xmlFile, "DroneHub:onLoad: entrance node missing from xml!")
            spec.bInvalid = true
        end

        spec.entrancePosition.x, spec.entrancePosition.y, spec.entrancePosition.z = getWorldTranslation(entrance)
    end

    local i = 0
    while true do
        local droneKey = string.format("placeable.droneHub.drones.drone(%d)", i)

        if not xmlFile:hasProperty(droneKey) then
            break
        else

            local slotNode = xmlFile:getValue(droneKey .. "#attachNode",nil,self.components,self.i3dMappings)
            if not slotNode then
                Logging.xmlWarning(self.xmlFile, "DroneHub:onLoad: attach node not found from: %s",droneKey)
                return
            end

            local position = {}
            position.x,position.y,position.z = getWorldTranslation(slotNode)
            local rotation = {}
            rotation.x, rotation.y,rotation.z = getWorldRotation(slotNode)
            local droneSlot = DroneHubDroneSlot.new(self,i+1,position,rotation,self.isServer,self.isClient)
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

--- canBeSold the hub can only be sold if doesn't have any drones linked.
--@return true,nil if can be sold else false, and message.
function DroneHub:canBeSold()

    if self:hasAnyLinkedDrones() then
        return false, g_i18n:getText("droneHub_unlinkBeforeSell")
    end

    return true, nil
end

--- onDelete when drone hub deleted, cleans up the slots and dronehandler and menutrigger.
function DroneHub:onDelete()
    local spec = self.spec_droneHub

    if self.isServer then
        g_messageCenter:unsubscribe(MessageType.GRIDMAP3D_GRID_GENERATED,self)
    end

    for _, slot in ipairs(spec.droneSlots) do
        slot:onDelete()
    end

    if self.droneHandler ~= nil then
        self.droneHandler:delete()
        self.droneHandler = nil
    end

    if spec.menuTrigger ~= nil then
        removeTrigger(spec.menuTrigger)
        spec.menuTrigger = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
--@param dt is deltatime in ms.
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

--- setChargeCoverAnimation sets the animation for the slot cover for specific slot.
--@param slotIndex indicates which slot cover animation needs to be changed.
--@param bOpen bool indicating should the slot cover be open or closed.
function DroneHub:setChargeCoverAnimation(slotIndex,bOpen)
    if self.spec_animatedObjects == nil or self.spec_animatedObjects.animatedObjects[slotIndex] == nil then
        return
    end

    local slotAnimatedObject = self.spec_animatedObjects.animatedObjects[slotIndex]
    if slotAnimatedObject ~= nil then
        if bOpen and slotAnimatedObject.animation.time < 1 then
            slotAnimatedObject.activatable:onAnimationInputToggle()
        elseif not bOpen and slotAnimatedObject.animation.time >= 1 then
            slotAnimatedObject.activatable:onAnimationInputToggle()
        end

    end
end

--- Event on finalizing the placement of this drone hub.
-- used to create the dronehandler and accesstester, and either subscribes to the grid done message or proceeds to initialize the hub immediately.
function DroneHub:onFinalizePlacement()
    local spec = self.spec_droneHub

    if self.isServer and not spec.bInvalid then
        spec.droneHandler = DroneActionManager.new(self,self.isServer,self.isClient,false)
        spec.droneHandler:register(true)

        -- set a limit how complex location the hub can be by adjusting how many closed nodes A* pathfinding can close before should stop search for a path to hub.
        spec.maxAccessClosedNodes = 2000
        -- adjust how fast it should A* pathfind to see if hub can be accessed
        spec.accessSearchLoops = 10
        spec.bSearchedDrones = false

        if FlyPathfinding.bPathfindingEnabled then

            -- create pathfinding class that will be used to check if the location of this hub is good after gridmap becomes available
            spec.accessTester = AStar.new(self.isServer,self.isClient)
            spec.accessTester:register(true)

            if g_currentMission.gridMap3D:isAvailable() then
                self:initializeHub()
            else
                g_messageCenter:subscribe(MessageType.GRIDMAP3D_GRID_GENERATED, self.onGridMapGenerated, self)
            end
        else
            spec.bInvalid = true
            for _, slot in ipairs(spec.droneSlots) do
                slot:changeState(slot.ESlotState.NOFLYPATHFINDING)
            end
        end
    end

    if spec.menuTrigger ~= nil then
        addTrigger(spec.menuTrigger,"onMenuTriggerCallback",self)
    end

end

--- onGridMapGenerated callback to the grid being generated complete message.
-- proceeds to initialize the hub when grid has been generated.
function DroneHub:onGridMapGenerated()
    self:initializeHub()
end

--- intializeHub called to check first the access to the entrance of hub by pathfind test.
function DroneHub:initializeHub()
    local callback = function(aStarSearch) self:checkAccessInitCallback(aStarSearch) end
    self:checkAccess(callback)
end

--- setSlotDirty marks a specific slot as dirty and in need of sync.
--@param slotIndex the index of the slot which is dirty.
function DroneHub:setSlotDirty(slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots[slotIndex] ~= nil then
        self:raiseDirtyFlags(spec.droneSlots[slotIndex]:getDirtyFlag())
    end
end

--- setAllSlotsDirty will mark all the slots of the dronehub as dirty and raise the flags.
function DroneHub:setAllSlotsDirty()
    local spec = self.spec_droneHub
    for _, slot in ipairs(spec.droneSlots) do
        dirtyFlags = dirtyFlags +  slot:getDirtyFlag()
    end

    self:raiseDirtyFlags(dirtyFlags)
end

--- hasAnyLinkedDrones called to check if hub has any drone linked up on any of the slots the hub has.
--@return false if did not have any linked drones.
function DroneHub:hasAnyLinkedDrones()
    local spec = self.spec_droneHub

    for _, slot in ipairs(spec.droneSlots) do
        if slot:isLinked() then
            return true
        end
    end

    return false
end

--- Registering xmlpaths for the entrance, menutrigger and drone attachnode.
function DroneHub.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DroneHub")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".droneHub#menuTrigger", "trigger used to be able to enter the menu of dronehub")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".droneHub#entrance", "Entrance node used for docking drones or leaving drones")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".droneHub.drones.drone(?)#attachNode", "drone attach node on hub")
    schema:setXMLSpecializationType()
end

--- Registering save xml paths for hub, hub itself does not save any but hubslot has so forwards call.
function DroneHub.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DroneHub")
    DroneHubDroneSlot.registerSavegameXMLPaths(schema, basePath .. "drones.drone(?)")
    schema:setXMLSpecializationType()
end

--- On saving forwards saving call to each slot that hub has.
function DroneHub:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_droneHub

    for i, slot in ipairs(spec.droneSlots) do
        local slotKey = string.format(key .. "drones.drone(%d)",i)
        slot:saveToXMLFile(xmlFile,slotKey, usedModNames)
    end

end

--- On loading forwards loading call to each slot that hub has.
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

        for _, slot in ipairs(spec.droneSlots) do
            slot:writeUpdateStream(streamId,connection,dirtyMask)
        end
    end
end

--- getEntrancePosition returns the entrance position of dronehub, given as {x=,y=,z=}.
function DroneHub:getEntrancePosition()
    local spec = self.spec_droneHub
    if spec.entrancePosition == nil then
        return nil
    end

    return {x=spec.entrancePosition.x, y=spec.entrancePosition.y,z=spec.entrancePosition.z}
end

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

    if player ~= nil and player.farmId == self:getOwnerFarmId() and g_currentMission.player == player then

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

--- getDroneHandler called to return the drone handler of hub.
function DroneHub:getDroneHandler()
    return self.spec_droneHub.droneHandler
end

--- linkDrone called from event to forward call of linking to hub slot.
--@param drone which is being linked up.
--@param id new linking id between the slot and the drone.
--@param slotIndex indicating which slot is being linked up.
function DroneHub:linkDrone(drone,id,slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeLinking(drone,id)
end

--- unLinkDrone called from event to forward call of unlinking drone from hub slot.
--@param slotIndex indicating which slot is being unlinked.
function DroneHub:unLinkDrone(slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeUnlinking()
end

--- receiveConfigSettings called from event to forward call to slot about a config change.
--@param slotIndex indicating which slot is receiving new config.
--@param newPickupConfig is the new pickup settings
--@param newDeliveryConfig is the new delivery settings.
function DroneHub:receiveConfigSettings(slotIndex,newPickupConfig,newDeliveryConfig)

    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:verifySettings(newPickupConfig,newDeliveryConfig)
end

--- clearConfigSettings is called from event to forward call to slot about settings being cleared.
--@param slotIndex indicating which slot is clearing config.
function DroneHub:clearConfigSettings(slotIndex)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeSettingsClear()
end

--- validatedSlotSettings is called from event to forward call to slot about new settings been validated.
--@param slotIndex indicating which slot has settings validated.
--@param bValid indicates if the settings were valid or not.
--@param bLoadedConfig indicates if the settings were loaded from xml file.
function DroneHub:validatedSlotSettings(slotIndex,bValid,bLoadedConfig)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:onValidatedSettings(bValid,bLoadedConfig)
end

--- renameDroneRoute is called from event to forward call to slot about new name for the slot route.
--@param slotIndex indicating which slot has its route renamed.
--@parma name is the new name to be given.
function DroneHub:renameDroneRoute(slotIndex,name)
    local spec = self.spec_droneHub
    if spec.droneSlots == nil or spec.droneSlots[slotIndex] == nil then
        return
    end

    spec.droneSlots[slotIndex]:finalizeRenaming(name)
end

--- setInUse marks the dronehub as being in use.
function DroneHub:setInUse(inUse)
    local spec = self.spec_droneHub
    spec.bInUse = inUse
end

--- onExitingMenu called when the dronehub menu is exited, will mark as not in use and also send event to let each client know.
function DroneHub:onExitingMenu()
    self:setInUse(false)
    DroneHubAccessedEvent.sendEvent(self,false)
end

--- addOnDataChangedListeners called to add any callback to the data changed.
--@param callback is the function to call when data has changed on dronehub.
function DroneHub:addOnDataChangedListeners(callback)
    table.addElement(self.spec_droneHub.dataChangedListeners,callback)
end

--- removeOnDataChangedListeners called to remove any callback from the data changed listeners.
--@param callback is the function that was suppose to be called when data has changed on dronehub.
function DroneHub:removeOnDataChangedListeners(callback)
    table.removeElement(self.spec_droneHub.dataChangedListeners, callback)
end

--- onDataChange called when data has changed on the hub slot.
--@param slotIndex is on which slot data has changed.
function DroneHub:onDataChange(slotIndex)
    for _, callback in ipairs(self.spec_droneHub.dataChangedListeners) do
        callback(slotIndex)
    end
end

--- checkAccess uses AStar pathfinder to check that the hub is placed in a suitable space.
-- server only.
--@param callback is the callback to call when AStar is done pathfinding with result.
--@return true if could check hub access which would mean it is not invalid placed already.
function DroneHub:checkAccess(callback)
    local spec = self.spec_droneHub
    if callback == nil or spec.bInvalid then
        return false
    end

    if FlyPathfinding.bPathfindingEnabled and spec.accessTester ~= nil and spec.accessTester:isPathfinding() == false then
        -- pathfind down from the sky to the hub.
        if spec.accessTester:find({x=0,y=2000,z=0},spec.entrancePosition,false,true,false,callback,nil,spec.accessSearchLoops,spec.maxAccessClosedNodes) == false then
            callback({nil,false})
        end
    end
    return true
end

--- checkAccessInitCallback is callback used for checking hub access when initializing hub after grid is available.
-- server only.
--@param aSearchResult is the result received from AStar class as type {path array of (x=,y=,z=},bWasGoal}.
function DroneHub:checkAccessInitCallback(aSearchResult)
    local spec = self.spec_droneHub

    -- second value is bool indicating if goal(hub) was reached or not
    if not aSearchResult[2] then
        self:invalidPlacement()
        return
    end


    local dirtyFlags = 0
    for _, slot in ipairs(spec.droneSlots) do
        slot:initialize()
        dirtyFlags = dirtyFlags + slot:getDirtyFlag()
    end

    self:raiseDirtyFlags(dirtyFlags)
end

--- invalidPlacement called when dronehub access has been blocked to the entrance position.
-- marks all the slots as invalid placement, and notifies player.
function DroneHub:invalidPlacement()

    local spec = self.spec_droneHub

    DroneHubInvalidPlacementEvent.sendEvent(self)

    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId == self:getOwnerFarmId() then
        g_currentMission.hud.sideNotifications:addNotification(g_i18n:getText("droneHub_noAccess"),{1,0,0,1},30000)
    end

    spec.bInvalid = true

    if self.isServer then
        local dirtyFlags = 0
        for _, slot in ipairs(spec.droneSlots) do
            slot:changeState(slot.ESlotState.INCOMPATIBLEPLACEMENT)
            dirtyFlags = dirtyFlags + slot:getDirtyFlag()
        end

        self:raiseDirtyFlags(dirtyFlags)
    end
end














