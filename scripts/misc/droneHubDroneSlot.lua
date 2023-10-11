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

DroneHubDroneSlot = {}
DroneHubDroneSlot_mt = Class(DroneHubDroneSlot)
InitObjectClass(DroneHubDroneSlot, "DroneHubDroneSlot")

function DroneHubDroneSlot.new(hubOwner,inSlotIndex,inPosition,inRotation,isServer,isClient)
    if hubOwner == nil then
        Logging.warning("No hub owner given to a new DroneHubDroneSlot!")
        return
    end

    local self = setmetatable({}, DroneHubDroneSlot_mt)
    self.isServer = isServer
    self.isClient = isClient
    self.linkedDrone = nil
    self.linkedDroneID = ""
    self.hubOwner = hubOwner
    self.name = ""
    self.slotIndex = inSlotIndex
    self.ESlotState = {NOLINK = 0,LINKED = 1, LINKCHANGING = 2, BOOTING = 3, INCOMPATIBLEPLACEMENT = 4, NOFLYPATHFINDING = 5, APPLYINGSETTINGS = 6}
    self.currentState = self.ESlotState.BOOTING
    self.slot = {}
    self.slot.position = inPosition
    self.slot.rotation = inRotation
    self.slotConfig = DroneHubSlotConfig.new(self,self.hubOwner,self.isServer,self.isClient)
    self.interactionDisabledListeners = {}

    if self.isServer then
        self.droneArriveCallback = function(drone) self:onDroneArrived(drone) end
        self.stateDirtyFlag = self.hubOwner:getNextDirtyFlag()
        self.dockSpeed = 1
        self.dockTurnSpeed = 15
        self:createActionPhases()
        self.trianglePath = nil
        self.pathCreator = DronePathCreator.new(self.hubOwner:getEntrancePosition())
    end

    return self
end

function DroneHubDroneSlot:onDelete()

    if self.pathCreator ~= nil then
        self.pathCreator:delete()
        self.pathCreator = nil
    end

    if self.slotConfig ~= nil then
        self.slotConfig:delete()
        self.slotConfig = nil
    end

    if self.prepareSettingsTimer ~= nil then
        self.prepareSettingsTimer:delete()
    end

end

--- On saving
function DroneHubDroneSlot:saveToXMLFile(xmlFile, key, usedModNames)

    xmlFile:setValue(key.."#droneID", self.linkedDroneID)
    xmlFile:setValue(key.."#name", self.name)

    if self.slotConfig ~= nil then
        self.slotConfig:saveToXMLFile(xmlFile,key,usedModNames)
    end
end

--- On loading
function DroneHubDroneSlot:loadFromXMLFile(xmlFile, key)

    self.linkedDroneID = Utils.getNoNil(xmlFile:getValue(key.."#droneID"),"")
    self.name = Utils.getNoNil(xmlFile:getValue(key.."#name"),"")

    if self.slotConfig ~= nil then
        self.slotConfig:loadFromXMLFile(xmlFile,key)
    end

    return true
end


--- Registering
function DroneHubDroneSlot.registerXMLPaths(schema, basePath)

end

--- Registering
function DroneHubDroneSlot.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING,        basePath .. "#droneID", "Drone and slot unique ID")
    schema:register(XMLValueType.STRING,        basePath .. "#name", "Drone route name")
    schema:register(XMLValueType.BOOL,        basePath .. "#slotCoverOpen", "Bool indicating if slot cover is open state")
    DroneHubSlotConfig.registerSavegameXMLPaths(schema,basePath)
end

function DroneHubDroneSlot:readStream(streamId,connection)

    self.linkedDroneID = streamReadString(streamId)
    self.name = streamReadString(streamId)
    self.linkedDrone = NetworkUtil.readNodeObject(streamId)
    local state = streamReadInt8(streamId)
    self:changeState(state)

    if self.slotConfig ~= nil then
        self.slotConfig:readStream(streamId,connection)
    end

end

function DroneHubDroneSlot:writeStream(streamId,connection)

    streamWriteString(streamId,self.linkedDroneID)
    streamWriteString(streamId,self.name)
    NetworkUtil.writeNodeObject(streamId,self.linkedDrone)
    streamWriteInt8(streamId,self.currentState)

    if self.slotConfig ~= nil then
        self.slotConfig:writeStream(streamId,connection)
    end
end

--- readUpdateStream receives from server these variables when dirty raised on server.
function DroneHubDroneSlot:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then


        local state = streamReadInt8(streamId)
        self:changeState(state)


    end
end

--- writeUpdateStream syncs from server to client these variabels when dirty raised.
function DroneHubDroneSlot:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then


        streamWriteInt8(streamId,self.currentState)


    end
end

function DroneHubDroneSlot:getDirtyFlag()
    return self.stateDirtyFlag
end

function DroneHubDroneSlot:getOwnerFarmId()
    local farmId = -1
    if self.hubOwner ~= nil then
        farmId = self.hubOwner:getOwnerFarmId()
    end
    return farmId
end

function DroneHubDroneSlot:createActionPhases()

    self:createUnDockingAction()
    self:createDockingAction()
end

function DroneHubDroneSlot:createUnDockingAction()
    if self.hubOwner == nil then
        return
    end

    local hubEntrancePosition = self.hubOwner:getEntrancePosition()

    local hubForwardDirection = {}
    hubForwardDirection.x, hubForwardDirection.y, hubForwardDirection.z = localDirectionToWorld(self.hubOwner.rootNode,0,0,1)

    local slightlyUpPosition = {}
    slightlyUpPosition.x, slightlyUpPosition.y, slightlyUpPosition.z = self.slot.position.x, self.slot.position.y + 0.3, self.slot.position.z

    local slightlyForwardPositionStep2 = {}
    slightlyForwardPositionStep2.x, slightlyForwardPositionStep2.y, slightlyForwardPositionStep2.z = slightlyUpPosition.x, slightlyUpPosition.y, slightlyUpPosition.z
    slightlyForwardPositionStep2.x = slightlyForwardPositionStep2.x + (hubForwardDirection.x * 2.8)
    slightlyForwardPositionStep2.z = slightlyForwardPositionStep2.z + (hubForwardDirection.z * 2.8)

    local directionToEntrance = {}
    directionToEntrance.x, directionToEntrance.y, directionToEntrance.z = MathUtil.vector3Normalize(hubEntrancePosition.x - slightlyForwardPositionStep2.x,hubEntrancePosition.y - slightlyForwardPositionStep2.y,hubEntrancePosition.z - slightlyForwardPositionStep2.z)
    directionToEntrance.y = 0

    local finishedCallback = function()
            if self.linkedDrone ~= nil then
                self.linkedDrone:changeState(self.linkedDrone.spec_drone.EDroneStates.PICKING_UP)
            end
        end

    local moveToEntranceAction = DroneActionPhase.new(nil,hubEntrancePosition,nil,self.dockSpeed,nil,nil,finishedCallback,nil,nil)

    local rotateTowardsEntranceAction = DroneActionPhase.new(nil,nil,directionToEntrance,nil,self.dockTurnSpeed,nil,nil,nil,moveToEntranceAction)

    local slightlyForwardAction = DroneActionPhase.new(nil,slightlyForwardPositionStep2,nil,self.dockSpeed,nil,nil,nil,nil,rotateTowardsEntranceAction)


    -- root action step, will go just upward slightly from the hub. As start action will start rotors, as end action will put up drone legs.
    local rotorStartCallback = function()
            if self.linkedDrone ~= nil then
                self.linkedDrone:playDroneAnimation("rotorAnimation",true)
            end
        end

    local legsUpCallback = function()
            if self.linkedDrone ~= nil then
                self.linkedDrone:playDroneAnimation("legAnimation",true)
            end
            if self.hubOwner ~= nil then
                self.hubOwner:setChargeCoverAnimation(self.slotIndex,false)
            end
        end


    self.unDockingAction = DroneActionPhase.new(nil,slightlyUpPosition,nil,0.1,nil,rotorStartCallback,legsUpCallback,nil,slightlyForwardAction) -- slowly up first 10cm/s speed
end

function DroneHubDroneSlot:createDockingAction()
    if self.hubOwner == nil then
        return
    end

    local hubEntrancePosition = self.hubOwner:getEntrancePosition()

    local hubForwardDirection = {}
    hubForwardDirection.x, hubForwardDirection.y, hubForwardDirection.z = localDirectionToWorld(self.hubOwner.rootNode,0,0,1)


    local slightlyUpPosition = {}
    slightlyUpPosition.x, slightlyUpPosition.y, slightlyUpPosition.z = self.slot.position.x, self.slot.position.y + 0.3, self.slot.position.z

    local slightlyForwardPositionStep2 = {}
    slightlyForwardPositionStep2.x, slightlyForwardPositionStep2.y, slightlyForwardPositionStep2.z = slightlyUpPosition.x, slightlyUpPosition.y, slightlyUpPosition.z
    slightlyForwardPositionStep2.x = slightlyForwardPositionStep2.x + (hubForwardDirection.x * 2.8)
    slightlyForwardPositionStep2.z = slightlyForwardPositionStep2.z + (hubForwardDirection.z * 2.8)


    local directionToSlot = {}
    directionToSlot.x, directionToSlot.y, directionToSlot.z = MathUtil.vector3Normalize(slightlyForwardPositionStep2.x - hubEntrancePosition.x,slightlyForwardPositionStep2.y - hubEntrancePosition.y,slightlyForwardPositionStep2.z - hubEntrancePosition.z)
    directionToSlot.y = 0


    local finishedCallback = function()
            if self.linkedDrone ~= nil then
                self.linkedDrone:stopDroneAnimation("rotorAnimation")
                self.linkedDrone:setDroneIdleState()
            end
        end

    local legsDownCallback = function()
            if self.linkedDrone ~= nil then
                self.linkedDrone:playDroneAnimation("legAnimation",false)
            end
            if self.hubOwner ~= nil then
                self.hubOwner:setChargeCoverAnimation(self.slotIndex,true)
            end
        end


    local downToSlotAction = DroneActionPhase.new(nil,self.slot.position,nil,0.1,nil,nil,finishedCallback,nil,nil) -- last step go slowly 10cm/s down and not default dockSpeed

    local rotateOutwardsAction = DroneActionPhase.new(nil,nil,hubForwardDirection,nil,self.dockTurnSpeed,nil,legsDownCallback,nil,downToSlotAction)

    local slightlyForward2Action = DroneActionPhase.new(nil,slightlyUpPosition,nil,self.dockSpeed,nil,nil,nil,nil,rotateOutwardsAction)

    local rotateToSlotAction = DroneActionPhase.new(nil,nil,{x=hubForwardDirection.x * -1,y= hubForwardDirection.y * -1,z= hubForwardDirection.z * -1},nil,self.dockTurnSpeed,nil,nil,nil,slightlyForward2Action)

    local slightlyForwardAction = DroneActionPhase.new(nil,slightlyForwardPositionStep2,nil,self.dockSpeed,nil,nil,nil,nil,rotateToSlotAction)

    self.dockingAction = DroneActionPhase.new(nil,nil,directionToSlot,nil,self.dockTurnSpeed,nil,nil,nil,slightlyForwardAction)
end

function DroneHubDroneSlot:requestUndocking()
    if self.unDockingAction ~= nil and self.hubOwner ~= nil then
        self.hubOwner:getDroneHandler():addAction(self.unDockingAction)
    end
end

function DroneHubDroneSlot:requestDocking()
    if self.dockingAction ~= nil and self.hubOwner ~= nil then
        self.hubOwner:getDroneHandler():addAction(self.dockingAction)
    end
end

function DroneHubDroneSlot:requestDirectReturn()
    if self.linkedDrone == nil or self.hubOwner == nil then
        return
    end

    self.linkedDrone:setDirectPosition(self.slot.position,self.slot.rotation,true)
    self.linkedDrone:setAnimationsToDefault()
    self.hubOwner:setChargeCoverAnimation(self.slotIndex,true)

    self.linkedDrone:setDroneIdleState()
end

--- initialize gets called from hub when grid has been generated
function DroneHubDroneSlot:initialize()
    if self.linkedDrone == nil then
        self:changeState(self.ESlotState.NOLINK)
        return
    end

    if self.slotConfig ~= nil then
        -- if has no loaded pickup and delivery placeable then doesn't get initialized and returns false so need to change to linked state
        if not self.slotConfig:initializeConfig() then
            self:newPathInvalidated()
        end
    end
end

function DroneHubDroneSlot:changeState(newState)

    if self.currentState == newState or newState == nil or newState < 0 then
        return
    end

    local previousInteractionState = self:isInteractionDisabled()

    self.currentState = newState

    self.hubOwner:onDataChange(self.slotIndex)

    if self:isInteractionDisabled() ~= previousInteractionState then
        self:onInteractionStateChanged(self:isInteractionDisabled())
    end

    if self.isServer then
        self.hubOwner:setSlotDirty(self.slotIndex)
    end

    if newState == self.ESlotState.INCOMPATIBLEPLACEMENT or newState == self.ESlotState.NOFLYPATHFINDING then
        self:emergencyUnlink()
    end
end

function DroneHubDroneSlot:onInteractionStateChanged(isDisabled)
    for _, callback in ipairs(self.interactionDisabledListeners) do
        callback(isDisabled)
    end
end

function DroneHubDroneSlot:getStateText()
    local stateText = self:getCurrentStateName()

    if self.currentState ~= self.ESlotState.INCOMPATIBLEPLACEMENT and self.currentState ~= self.ESlotState.NOFLYPATHFINDING and
            self.currentState ~= self.ESlotState.APPLYINGSETTINGS and self.currentState ~= self.ESlotState.LINKCHANGING and self.currentState ~= self.ESlotState.BOOTING and self.linkedDrone ~= nil then

        stateText = self.linkedDrone:getCurrentStateName()
    end

    return stateText
end

function DroneHubDroneSlot:isInteractionDisabled()

    if self.currentState == self.ESlotState.INCOMPATIBLEPLACEMENT or self.currentState == self.ESlotState.NOFLYPATHFINDING or
            self.currentState == self.ESlotState.APPLYINGSETTINGS or self.currentState == self.ESlotState.LINKCHANGING or self.currentState == self.ESlotState.BOOTING then
        return true
    end

    return false
end

function DroneHubDroneSlot:addOnInteractionDisabledListeners(callback)
    table.addElement(self.interactionDisabledListeners,callback)
end

function DroneHubDroneSlot:removeOnInteractionDisabledListeners(callback)
    table.removeElement(self.interactionDisabledListeners, callback)
end


function DroneHubDroneSlot:searchDrone()

    if self.linkedDroneID == "" or self.slotConfig == nil then
        return
    end

    if DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID] ~= nil then
        self.linkedDrone = DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID]
        DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID] = nil
        if self.unDockingAction ~= nil then
            self.unDockingAction:setDrone(self.linkedDrone)
        end
        if self.dockingAction ~= nil then
            self.dockingAction:setDrone(self.linkedDrone)
        end

        SpecializationUtil.raiseEvent(self.linkedDrone,"onHubLoaded",self.hubOwner,self,self.slotIndex)
        return
    end

    -- shouldn't happen, save file issue
    self.linkedDroneID = ""
    self.name = ""
    self.slotConfig:clearConfig()
    self:changeState(self.ESlotState.NOLINK)
end

function DroneHubDroneSlot:noticeDroneReturnal()
    self.linkedDrone:addOnDroneArrivedListener(self.droneArriveCallback)
end


function DroneHubDroneSlot:onDroneArrived(drone)
    if drone == nil or self.slotConfig == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.droneArriveCallback)
    drone:changeState(drone.spec_drone.EDroneStates.DOCKING)
end

function DroneHubDroneSlot:tryLinkDrone()
    if self.currentState ~= self.ESlotState.NOLINK then
        return false
    end

    overlapBox(self.slot.position.x,self.slot.position.y,self.slot.position.z,0,0,0,1,1,1,"droneOverlapCheckCallback",self,CollisionMask.VEHICLE,true,true,true,false)
    if self.linkedDrone == nil then
        return false
    end

    self:changeState(self.ESlotState.LINKCHANGING)

    local newID = self:generateUniqueID()

    LinkDroneEvent.sendEvent(self.hubOwner,self.linkedDrone,newID,self.slotIndex)

    return true
end


function DroneHubDroneSlot:tryUnLinkDrone()
    if self.currentState ~= self.ESlotState.LINKED or self.linkedDrone == nil then
        return false
    end

    if not self.linkedDrone:isDroneAtHub() then
        return false
    end

    self:changeState(self.ESlotState.LINKCHANGING)

    UnLinkDroneEvent.sendEvent(self.hubOwner,self.slotIndex)

    return true
end

function DroneHubDroneSlot:tryChangeName(name)
    if self.currentState == self.ESlotState.NOLINK then
        return false
    end

    RenameDroneRouteEvent.sendEvent(self.hubOwner,self.slotIndex,name)

    return true
end

function DroneHubDroneSlot:getDroneCharge()
    local charge = 0

    if self.linkedDrone ~= nil then
        charge = self.linkedDrone:getCharge()
    end

    return charge
end

function DroneHubDroneSlot:getDronePositionAndRotation()
    local position = nil
    local rotation = nil

    if self.linkedDrone ~= nil then
        position = {}
        rotation = {}

        position.x, position.y, position.z = getWorldTranslation(self.linkedDrone.rootNode)
        rotation.x, rotation.y, rotation.z = getWorldRotation(self.linkedDrone.rootNode)
    end

    return position, rotation
end

function DroneHubDroneSlot:getDrone()
    return self.linkedDrone
end

function DroneHubDroneSlot:isDroneAtSlot()
    if self.linkedDrone == nil then
        return true
    end

    return self.linkedDrone:isDroneAtHub()
end

function DroneHubDroneSlot:getConfig()
    return self.slotConfig
end

function DroneHubDroneSlot:isLinked()
    return self.linkedDrone ~= nil
end

function DroneHubDroneSlot:requestClear()

    self:changeState(self.ESlotState.APPLYINGSETTINGS)

    ClearConfigEvent.sendEvent(self.hubOwner,self.slotIndex)
end

function DroneHubDroneSlot:getCurrentStateName()
    local stateName = ""

    if self.currentState == self.ESlotState.NOLINK then
        stateName = g_i18n:getText("droneHub_droneNotLinked")
    elseif self.currentState == self.ESlotState.LINKED then
        stateName = g_i18n:getText("droneHub_droneLinked")
    elseif self.currentState == self.ESlotState.LINKCHANGING then
        stateName = g_i18n:getText("droneHub_droneLinking")
    elseif self.currentState == self.ESlotState.BOOTING then
        stateName = g_i18n:getText("droneHub_Booting")
    elseif self.currentState == self.ESlotState.INCOMPATIBLEPLACEMENT then
        stateName = g_i18n:getText("droneHub_IncompatiblePlacement")
    elseif self.currentState == self.ESlotState.NOFLYPATHFINDING then
        stateName = g_i18n:getText("droneHub_NoFlyPathfinding")
    elseif self.currentState == self.ESlotState.APPLYINGSETTINGS then
        stateName = g_i18n:getText("droneHub_ApplyingSettings")
    end

    return stateName
end

--- droneOverlapCheckCallback callback from the overlapbox which runs to check when linking up a drone if there is actually an available drone.
--@param objectId is object ids of overlapped object.
--@return true to continue looking for more hits, false if found drone to stop looking for additional overlaps.
function DroneHubDroneSlot:droneOverlapCheckCallback(objectId)

    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]

    if object ~= nil and object:isa(Vehicle) and object.spec_drone ~= nil and object.spec_drone.linkID == "" then
        self.linkedDrone = object
        return false
    end

    return true
end

--- Used to generated a new id for drone and the hub slot.
-- unique enough for connecting drones to hub when loading game.
--@return string which represents the new id.
function DroneHubDroneSlot:generateUniqueID()

    local id = ""
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    for i = 1, 6 do
        local index = math.random(1, #chars)
        id = id .. string.sub(chars, index, index)
    end

    id = id .. "-"

    for i = 1,6 do
        local index = math.random(1, #chars)
        id = id .. string.sub(chars, index, index)
    end

    return id
end

--- emergencyUnlink used in a case where a drone is linked but pathfinding is not available suddenly in loaded save, or hub has been obstructed by some static buildings.
function DroneHubDroneSlot:emergencyUnlink()
    if not self:isLinked() or self.slotConfig == nil then
        return
    end

    self.linkedDroneID = ""
    self.name = ""
    self.slotConfig:clearConfig()
    self.hubOwner:setChargeCoverAnimation(self.slotIndex,false)
    SpecializationUtil.raiseEvent(self.linkedDrone,"onHubUnlink",true)
    self.linkedDrone = nil
end

function DroneHubDroneSlot:finalizeLinking(drone,id)
    if drone == nil then
        return
    end

    self.linkedDrone = drone
    self.linkedDroneID = id

    if self.isServer then
        self.hubOwner:setChargeCoverAnimation(self.slotIndex,true)
        if self.unDockingAction ~= nil then
            self.unDockingAction:setDrone(self.linkedDrone)
        end
        if self.dockingAction ~= nil then
            self.dockingAction:setDrone(self.linkedDrone)
        end
    end
    SpecializationUtil.raiseEvent(self.linkedDrone,"onHubLink",id,self.slot.position,self.slot.rotation,self.hubOwner,self,self.slotIndex)
    self.name = drone:getName()
    self:changeState(self.ESlotState.LINKED)
end

function DroneHubDroneSlot:finalizeUnlinking()
    if not self.linkedDrone:isDroneAtHub() then
        self:changeState(self.ESlotState.LINKED)
        return
    end

    if self.slotConfig ~= nil then
        self.slotConfig:clearConfig()
    end
    if self.hubOwner ~= nil then
        self.hubOwner:setChargeCoverAnimation(self.slotIndex,false)
    end

    self.linkedDroneID = ""
    SpecializationUtil.raiseEvent(self.linkedDrone,"onHubUnlink",false)
    self.linkedDrone = nil
    self.name = ""

    self:changeState(self.ESlotState.NOLINK)
end

function DroneHubDroneSlot:finalizeRenaming(name)
    self.name = name
    self.hubOwner:onDataChange(self.slotIndex)
end

function DroneHubDroneSlot:finalizeSettingsClear()
    if self.linkedDrone == nil or not self.linkedDrone:isDroneAtHub() then
        self:changeState(self.ESlotState.LINKED)
        return
    end

    if self.slotConfig ~= nil then
        self.slotConfig:clearConfig()
    end

    if self.isServer then
        SpecializationUtil.raiseEvent(self.linkedDrone,"onPointLost")
    end

    self:changeState(self.ESlotState.LINKED)
end

function DroneHubDroneSlot:verifySettings(newPickupConfig,newDeliveryConfig)
    if newPickupConfig == nil or newDeliveryConfig == nil or self.slotConfig == nil or self.hubOwner == nil then
        return
    end


    self:changeState(self.ESlotState.APPLYINGSETTINGS)
    self.slotConfig:addVerifyingConfigs(newPickupConfig,newDeliveryConfig)

    if self.isServer and self.pathCreator ~= nil then
        -- set drone from pickup and delivery managers to hold while generating new paths
        self.slotConfig:setManagerToHoldDrone(false)
        self.slotConfig:setManagerToHoldDrone(true)
        if newPickupConfig.placeable ~= nil or newDeliveryConfig.placeable ~= nil then
            local callback = function(trianglePath) self:onValidatedPaths(trianglePath)  end
            self.pathCreator:generateNew(newPickupConfig.placeable,newDeliveryConfig.placeable,callback)
        else
            -- if both placeables nil means the placeables didn't change but something else, no need to make new paths
            -- but need to call it with a timer as other clients might not have entered this function yet and called addVerifyingConfigs
            if self.prepareSettingsTimer ~= nil then
                self.prepareSettingsTimer:delete()
            end
            self.prepareSettingsTimer = Timer.createOneshot(3000,function() self:prepareSettingApply() end) --3sec timer
        end
    end

end

-- server only.
function DroneHubDroneSlot:onValidatedPaths(trianglePath)

    -- a pickup or delivery placeable was changed but path couldn't be made there so invalidate
    if trianglePath == nil then
        self:newPathInvalidated()
        return
    end

    self.bufferTrianglePath = trianglePath
    self:prepareSettingApply()
end

function DroneHubDroneSlot:newPathInvalidated()
    -- only while loading a save can the drone not be in the hub and have a path be validated, so if path couldn't be made, need to tell drone come back
    if not self.linkedDrone:isDroneAtHub() and self.slotConfig:isLoadedConfig() then
        SpecializationUtil.raiseEvent(self.linkedDrone,"onPointLost")
    else
        -- tries to add back the drones to managers from being in hold if had previous path if not loaded config
        if not self.slotConfig:isLoadedConfig() then
            self.slotConfig:clearManagerHold(false)
            self.slotConfig:clearManagerHold(true)
        end
    end

    ConfigValidatedEvent.sendEvent(self.hubOwner,self.slotIndex,false,self.slotConfig:isLoadedConfig())
    return
end

--- prepareSettingApply used to check if possibly can add the new settings, drone has to be at hub.
-- server only.
function DroneHubDroneSlot:prepareSettingApply()

    -- check if lodaded placeables still exists
    if self.slotConfig:isLoadedConfig() then
        local pickupPlaceable = self.slotConfig.pickupConfig.placeable
        local deliveryPlaceable = self.slotConfig.deliveryConfig.placeable

        if pickupPlaceable == nil or pickupPlaceable.isDeleted or deliveryPlaceable == nil or deliveryPlaceable.isDeleted then
            ConfigValidatedEvent.sendEvent(self.hubOwner,self.slotIndex,false,self.slotConfig:isLoadedConfig())
            return
        end
    end

    if self.linkedDrone:isDroneAtHub() or self.slotConfig:isLoadedConfig() then
        ConfigValidatedEvent.sendEvent(self.hubOwner,self.slotIndex,true,self.slotConfig:isLoadedConfig())
        return
    end

    ConfigValidatedEvent.sendEvent(self.hubOwner,self.slotIndex,false,self.slotConfig:isLoadedConfig())
end

--@param bLoadedConfig indicates if the settings were loaded from xml file.
function DroneHubDroneSlot:onValidatedSettings(bValid,bLoadedConfig)
    self:changeState(self.ESlotState.LINKED)

    print("on validated settings loadedconfig: " .. tostring(bLoadedConfig))
    print("on validated settings bValid: " .. tostring(bValid))
    if not bValid then
        self.slotConfig:clearVerifyingConfigs()

        -- if loaded then clears also the config in the default variables and not just verifyingConfigs as when loaded it loads config into the default variables.
        if bLoadedConfig then
            self.slotConfig:clearConfig()
        end

        return
    end

    self.linkedDrone:setManagers(self.slotConfig:adjustNewManagers())
    self.slotConfig:applySettings()

    if self.bufferTrianglePath ~= nil then
        self.trianglePath = self.bufferTrianglePath
        self.bufferTrianglePath = nil
        SpecializationUtil.raiseEvent(self.linkedDrone,"onPathReceived",self.trianglePath)
    end

end

