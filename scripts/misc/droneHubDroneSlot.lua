DroneHubDroneSlot = {}
DroneHubDroneSlot_mt = Class(DroneHubDroneSlot)
InitObjectClass(DroneHubDroneSlot, "DroneHubDroneSlot")

function DroneHubDroneSlot.new(hubOwner,inSlotIndex,inPosition,inRotation)
    if hubOwner == nil then
        Logging.warning("No hub owner given to a new DroneHubDroneSlot!")
        return
    end

    local self = setmetatable({}, DroneHubDroneSlot_mt)
    self.linkedDrone = nil
    self.linkedDroneID = ""
    self.hubOwner = hubOwner
    self.name = ""
    self.slotIndex = inSlotIndex
    self.EDroneWorkStatus = {NOLINK = 0, IDLE = 1, CHARGING = 2, PICKING_UP = 3, DELIVERING = 4, LINKCHANGING = 5, BOOTING = 6, INCOMPATIBLE = 7}
    self.currentState = self.EDroneWorkStatus.NOLINK
    self.loadedState = nil
    self.slot = {}
    self.slot.position = inPosition
    self.slot.rotation = inRotation
    self.stateDirtyFlag = self.hubOwner:getNextDirtyFlag()
    self.slotConfig = DroneHubSlotConfig.new(self.hubOwner,inSlotIndex)

    return self
end

--- On saving
function DroneHubDroneSlot:saveToXMLFile(xmlFile, key, usedModNames)

    xmlFile:setValue(key.."#droneID", self.linkedDroneID)
    xmlFile:setValue(key.."#name", self.name)
    xmlFile:setValue(key.."#state", self.currentState)

    if self.slotConfig ~= nil then
        self.slotConfig:saveToXMLFile(xmlFile,key,usedModNames)
    end

end

--- On loading
function DroneHubDroneSlot:loadFromXMLFile(xmlFile, key)

    self.linkedDroneID = Utils.getNoNil(xmlFile:getValue(key.."#droneID"),"")
    self.name = Utils.getNoNil(xmlFile:getValue(key.."#name"),"")
    self.loadedState = Utils.getNoNil(xmlFile:getValue(key.."#state"),self.EDroneWorkStatus.NOLINK)

    if self.slotConfig ~= nil then
        self.slotConfig:loadFromXMLFile(xmlFile,key)
    end

    return true
end


--- Registering
function DroneHubDroneSlot.registerXMLPaths(schema, basePath)
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".drone(?)#attachNode", "drone attach node on hub")
    DroneHubSlotConfig.registerXMLPaths(schema,basePath)
end

--- Registering
function DroneHubDroneSlot.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING,        basePath .. "#droneID", "Drone and slot unique ID")
    schema:register(XMLValueType.STRING,        basePath .. "#name", "Drone route name")
    schema:register(XMLValueType.INT,        basePath .. "#state", "Drone state")
    DroneHubSlotConfig.registerSavegameXMLPaths(schema,basePath)
end

function DroneHubDroneSlot:readStream(streamId,connection)

    self.linkedDroneID = streamReadString(streamId)
    self.name = streamReadString(streamId)
    self.linkedDrone = NetworkUtil.readNodeObject(streamId)
    local loadedState = streamReadInt8(streamId)
    self:changeState(loadedState)

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

        print("read update stream for slot: " .. tostring(self.slotIndex))

        if streamReadBool(streamId) then
            local state = streamReadInt8(streamId)
            self:changeState(state)
        end


    end
end

--- writeUpdateStream syncs from server to client these variabels when dirty raised.
function DroneHubDroneSlot:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then

        print("write update stream for slot: " .. tostring(self.slotIndex))

        if streamWriteBool(streamId,bitAND(dirtyMask,self.stateDirtyFlag) ~= 0) then
            streamWriteInt8(streamId,self.currentState)
        end

    end
end

function DroneHubDroneSlot:initialize()

    self:changeState(self.loadedState)
    self.loadedState = nil

    return self.stateDirtyFlag
end

function DroneHubDroneSlot:changeState(newState)

    if self.currentState == newState or newState == nil or newState < 0 then
        return
    end

    self.currentState = newState

    self.hubOwner:onSlotStateChange(self.slotIndex)
end

function DroneHubDroneSlot:searchDrone()

    if self.linkedDroneID == "" or self.slotConfig == nil then
        return
    end

    if DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID] ~= nil then
        self.linkedDrone = DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID]
        DroneDeliveryMod.loadedLinkedDrones[self.linkedDroneID] = nil
        self.slotConfig:searchPlaceables()
        return
    end

    -- shouldn't happen, save file edited?
    self.linkedDroneID = ""
    self.name = ""
    self.loadedState = self.EDroneWorkStatus.NOLINK
    self.slotConfig:clearConfig()
    self:changeState(self.EDroneWorkStatus.NOLINK)
end

function DroneHubDroneSlot:tryLinkDrone()
    if self.currentState ~= self.EDroneWorkStatus.NOLINK then
        return false
    end

    overlapBox(self.slot.position.x,self.slot.position.y,self.slot.position.z,0,0,0,1,1,1,"droneOverlapCheckCallback",self,CollisionMask.VEHICLE,true,true,true,false)
    if self.linkedDrone == nil then
        return false
    end


    self:changeState(self.EDroneWorkStatus.LINKCHANGING)

    local newID = self:generateUniqueID()

    LinkDroneEvent.sendEvent(self.hubOwner,self.linkedDrone,newID,self.slotIndex)

    return true
end


function DroneHubDroneSlot:tryUnLinkDrone()
    if (self.currentState ~= self.EDroneWorkStatus.CHARGING and self.currentState ~= self.EDroneWorkStatus.IDLE) or self.linkedDrone == nil then
        return false
    end

    self:changeState(self.EDroneWorkStatus.LINKCHANGING)

    UnLinkDroneEvent.sendEvent(self.hubOwner,self.slotIndex)

    return true
end

function DroneHubDroneSlot:tryChangeName(name)
    if self.currentState == self.EDroneWorkStatus.NOLINK then
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

function DroneHubDroneSlot:getConfig()
    return self.slotConfig
end

function DroneHubDroneSlot:getCurrentStateName()
    local stateName = ""

    if self.currentState == self.EDroneWorkStatus.NOLINK then
        stateName = g_i18n:getText("listingGUI_droneNotLinked")
    elseif self.currentState == self.EDroneWorkStatus.IDLE then
        stateName = g_i18n:getText("listingGUI_droneIdle")
    elseif self.currentState == self.EDroneWorkStatus.CHARGING then
        stateName = g_i18n:getText("listingGUI_droneCharging")
    elseif self.currentState == self.EDroneWorkStatus.PICKING_UP then
        stateName = g_i18n:getText("listingGUI_dronePicking")
    elseif self.currentState == self.EDroneWorkStatus.DELIVERING then
        stateName = g_i18n:getText("listingGUI_droneDelivering")
    elseif self.currentState == self.EDroneWorkStatus.LINKCHANGING then
        stateName = ""
    elseif self.currentState == self.EDroneWorkStatus.BOOTING then
        stateName = g_i18n:getText("listingGUI_droneBooting")
    elseif self.currentState == self.EDroneWorkStatus.INCOMPATIBLE then
        stateName = g_i18n:getText("listingGUI_droneIncompatible")
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

function DroneHubDroneSlot:finalizeLinking(drone,id)
    if drone == nil then
        return
    end

    self.linkedDrone = drone
    self.linkedDroneID = id
    self.linkedDrone:setLinkID(id)
    self.linkedDrone:setPositionAndRotation(self.slot.position,self.slot.rotation,false)
    self.name = drone:getName()
    self:changeState(self.EDroneWorkStatus.IDLE)
end

function DroneHubDroneSlot:finalizeUnlinking()

    self.linkedDrone:setLinkID("")
    self.linkedDroneID = ""
    self.linkedDrone = nil
    self.name = ""

    if self.slotConfig ~= nil then
        self.slotConfig:clearConfig()
    end

    self:changeState(self.EDroneWorkStatus.NOLINK)
end

function DroneHubDroneSlot:finalizeRenaming(name)
    self.name = name
    self.hubOwner:onSlotStateChange(self.slotIndex)
end

function DroneHubDroneSlot:finalizeSettingsApply(pickUpPointCopy,deliveryPointCopy)
    if pickUpPointCopy == nil or deliveryPointCopy == nil or self.slotConfig == nil then
        return
    end

    self.slotConfig:applySettings(pickUpPointCopy,deliveryPointCopy)
    if g_droneHubScreen ~= nil then
        g_droneHubScreen:onAppliedSettings()
    end
end

