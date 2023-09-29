

DroneWorkPoint = {}
DroneWorkPoint_mt = Class(DroneWorkPoint)
InitObjectClass(DroneWorkPoint, "DroneWorkPoint")

function DroneWorkPoint.new(bPickup)
    local self = setmetatable({}, DroneWorkPoint_mt)
    self.placeable = nil
    self.position = nil
    self.name = ""
    self.fillTypes = {}
    self.allFillTypes = {}
    self.fillLimitIndex = 5
    self.fillTypeIndex = 1
    self.bPickup = bPickup
    self.bPriceLimit = false
    self.priceLimit = 0

    return self
end

function DroneWorkPoint:getPosition()
    return self.position
end

function DroneWorkPoint:getName()
    return self.name
end

function DroneWorkPoint:hasPoint()
    return self.placeable ~= nil
end

function DroneWorkPoint:isPickup()
    return self.bPickup
end

function DroneWorkPoint:getFillTypes()
    return self.fillTypes
end

function DroneWorkPoint:getAllFillTypes()
    return self.allFillTypes
end

function DroneWorkPoint:getPlaceable()
    return self.placeable
end

function DroneWorkPoint:hasPriceLimit()
    return self.bPriceLimit
end

function DroneWorkPoint:getPriceLimit()
    return self.priceLimit
end

function DroneWorkPoint:setFillTypeIndex(fillIndex)
    self.fillTypeIndex = fillIndex
end

function DroneWorkPoint:getFillTypeIndex()
    return self.fillTypeIndex
end

function DroneWorkPoint:setFillLimitIndex(fillLimitIndex)
    self.fillLimitIndex = fillLimitIndex
end

function DroneWorkPoint:getFillLimitIndex()
    return self.fillLimitIndex
end

function DroneWorkPoint:getDeliveryId()
    return self.fillTypes[self.fillTypeId]
end

function DroneWorkPoint:setHasPriceLimit(hasLimit)
    self.bPriceLimit = hasLimit
end

function DroneWorkPoint:setPriceLimit(limit)
    self.priceLimit = limit
end

function DroneWorkPoint:reset()

    self.placeable = nil
    self.position = nil
    self.name = ""
    self.fillTypes = {}
    self.allFillTypes = {}
    self.fillTypeIndex = 1
    self.fillLimitIndex = 5 -- reset 5 which ends up as 50%
    self.bPriceLimit = false
    self.priceLimit = 0
end

function DroneWorkPoint:nilEverything()
    self.placeable = nil
    self.position = nil
    self.name = nil
    self.fillTypes = nil
    self.allFillTypes = nil
    self.fillTypeIndex = nil
    self.bPickup = nil
    self.bPriceLimit = nil
    self.priceLimit = nil
    self.fillLimitIndex = nil
end

function DroneWorkPoint:findPlaceable()
    if self.position == nil then
        return false
    end

    overlapBox(self.position.x,self.position.y,self.position.z,0,0,0,5,5,5,"placeableSearchCallback",self,CollisionFlag.STATIC_WORLD + CollisionFlag.GROUND_TIP_BLOCKING,false,true,true,false)

    if self.placeable ~= nil then
        return true
    else
        return false
    end
end

function DroneWorkPoint:placeableSearchCallback(objectId)

    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]

    if object ~= nil and object:isa(Placeable) then
        local foundPosition = {}
        foundPosition.x,foundPosition.y,foundPosition.z = getWorldTranslation(object.rootNode)

        -- assuming there will be no possible placeable within 2cm
        if CatmullRomSpline.isNearlySamePosition(foundPosition,self.position,0.02) then
            self.placeable = object
            self.name = object:getName()
            return false
        end
    end

    return true
end

function DroneWorkPoint:copy()

    local newCopy = DroneWorkPoint.new()
    newCopy.bPickup = self.bPickup

    if self.position ~= nil then
        newCopy.position = {x=self.position.x, y=self.position.y, z=self.position.z}
    end

    newCopy.name = self.name
    newCopy.placeable = self.placeable
    newCopy.fillTypeIndex = self.fillTypeIndex
    newCopy.bPriceLimit = self.bPriceLimit
    newCopy.priceLimit = self.priceLimit
    newCopy.fillLimitIndex = self.fillLimitIndex

    for _,fillId in ipairs(self.fillTypes) do
        table.insert(newCopy.fillTypes,fillId)
    end

    for fillId,_ in pairs(self.allFillTypes) do
        newCopy.allFillTypes[fillId] = true
    end

    return newCopy
end

function DroneWorkPoint:setPlaceable(placeable,fillTypes)
    if placeable == nil or placeable.rootNode == nil then
        return
    end

    self.placeable = placeable

    -- position on the root nodes, will be used when loading game to get back the reference of the placeable to self.placeable
    self.position = {}
    self.position.x, self.position.y, self.position.z = getWorldTranslation(placeable.rootNode)

    self.name = placeable:getName()

    self.allFillTypes = fillTypes

end

function DroneWorkPoint:restrictFilltypes(fillTypes)
    self.fillTypes = fillTypes
    self.fillTypeIndex = 1
end


--- On saving
function DroneWorkPoint:saveToXMLFile(xmlFile, key, usedModNames)

    local x,y,z = nil,nil,nil
    if self.position ~= nil then
        x,y,z = self.position.x, self.position.y, self.position.z
    end

    xmlFile:setValue(key.."#position", x, y, z)
    xmlFile:setValue(key.."#fillTypeIndex", self.fillTypeIndex)
    xmlFile:setValue(key.."#hasPriceLimit", self.bPriceLimit)
    xmlFile:setValue(key.."#fillLimitIndex",self.fillLimitIndex)
    xmlFile:setValue(key.."#priceLimit", self.priceLimit)

    local fillTypeString = ""

    for _,fillTypeId in ipairs(self.fillTypes) do
        local fillTypeDesc = g_fillTypeManager.indexToFillType[fillTypeId]
        fillTypeString = fillTypeString .. fillTypeDesc.name .. " "
    end

    xmlFile:setValue(key.."#fillTypes", fillTypeString)

    fillTypeString = ""
    for fillTypeId,_ in pairs(self.allFillTypes) do
        local fillTypeDesc = g_fillTypeManager.indexToFillType[fillTypeId]
        fillTypeString = fillTypeString .. fillTypeDesc.name .. " "
    end

    xmlFile:setValue(key.."#allFillTypes",fillTypeString)

end

--- On loading
function DroneWorkPoint:loadFromXMLFile(xmlFile, key)

    local posX,posY,posZ = xmlFile:getValue(key.."#position")
    if posX == nil then
        return true
    end

    self.position = {x = posX, y = posY, z = posZ}
    self.fillTypeIndex = Utils.getNoNil(xmlFile:getValue(key.."#fillTypeIndex"),1)
    self.bPriceLimit = Utils.getNoNil(xmlFile:getValue(key.."#hasPriceLimit"),false)
    self.priceLimit = Utils.getNoNil(xmlFile:getValue(key.."#priceLimit"),0)
    self.fillLimitIndex = Utils.getNoNil(xmlFile:getValue(key.."#fillLimitIndex"),5)

    local fillTypeString = xmlFile:getValue(key.."#fillTypes")
    for fillName in fillTypeString:gmatch("%S+") do
        local index = g_fillTypeManager:getFillTypeIndexByName(fillName)
        table.insert(self.fillTypes, index)
    end

    fillTypeString = xmlFile:getValue(key.."#allFillTypes")

    for fillName in fillTypeString:gmatch("%S+") do
        local index = g_fillTypeManager:getFillTypeIndexByName(fillName)
        self.allFillTypes[index] = true
    end

    return true
end


--- Registering
function DroneWorkPoint.registerXMLPaths(schema, basePath)


end

--- Registering
function DroneWorkPoint.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.VECTOR_TRANS,        basePath .. ".config(?)#position", "Position of placeable")
    schema:register(XMLValueType.INT,        basePath .. ".config(?)#fillTypeIndex", "Fill type index within the fillTypes array")
    schema:register(XMLValueType.INT,        basePath .. ".config(?)#fillLimitIndex", "Fill limit index which is base to multiply by 10 to get percentage of fill limit of pallet for pickup")
    schema:register(XMLValueType.BOOL,        basePath .. ".config(?)#hasPriceLimit", "If has a price limit")
    schema:register(XMLValueType.FLOAT,        basePath .. ".config(?)#priceLimit", "price limit value")
    schema:register(XMLValueType.STRING,        basePath .. ".config(?)#fillTypes", "limited fillTypes")
    schema:register(XMLValueType.STRING,        basePath .. ".config(?)#allFillTypes", "all fillTypes")
end

function DroneWorkPoint:readStream(streamId,connection)

    if streamReadBool(streamId) then
        self.placeable = NetworkUtil.readNodeObject(streamId)
        self.name = self.placeable:getName()
        self.position = {}
        self.position.x = streamReadFloat32(streamId)
        self.position.y = streamReadFloat32(streamId)
        self.position.z = streamReadFloat32(streamId)

        self.fillTypeIndex = streamReadInt32(streamId)
        self.bPriceLimit = streamReadBool(streamId)
        self.priceLimit = streamReadInt32(streamId)
        self.fillLimitIndex = streamReadInt8(streamId)

        local fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                table.insert(self.fillTypes, index)
            end
        end

        fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                self.allFillTypes[index] = true
            end
        end

    end


end

function DroneWorkPoint:writeStream(streamId,connection)

    if streamWriteBool(streamId,self.placeable ~= nil) then

        NetworkUtil.writeNodeObject(streamId, self.placeable)
        streamWriteFloat32(streamId,self.position.x)
        streamWriteFloat32(streamId,self.position.y)
        streamWriteFloat32(streamId,self.position.z)

        streamWriteInt32(streamId,self.fillTypeIndex)
        streamWriteBool(streamId,self.bPriceLimit)
        streamWriteInt32(streamId,self.priceLimit)
        streamWriteInt8(streamId,self.fillLimitIndex)

        local fillTypesString = ""
        for _,id in ipairs(self.fillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)

        fillTypesString = ""
        for id,_ in pairs(self.allFillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    end

end

--- readUpdateStream receives from server these variables when dirty raised on server.
function DroneWorkPoint:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then



    end
end

--- writeUpdateStream syncs from server to client these variabels when dirty raised.
function DroneWorkPoint:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then



    end
end




DroneHubSlotConfig = {}
DroneHubSlotConfig_mt = Class(DroneHubSlotConfig)
InitObjectClass(DroneHubSlotConfig, "DroneHubSlotConfig")

DroneHubSlotConfig.EDirtyFields = {PICKUPPLACEABLE = 1, DELIVERYPLACEABLE = 2, PRICELIMIT = 3, PRICELIMITUSED = 4, FILLTYPEID = 5, FILLLIMITID = 6 }


function DroneHubSlotConfig.new(slot,hub,isServer,isClient)
    local self = setmetatable({}, DroneHubSlotConfig_mt)
    self.hubOwner = hub
    self.pickUpPoint = DroneWorkPoint.new(true)
    self.deliveryPoint = DroneWorkPoint.new(false)
    self.bLoadedConfig = true
    self.dirtyTable = {}
    self.slot = slot
    self.isServer = isServer
    self.isClient = isClient
    return self
end

function DroneHubSlotConfig:clearConfig()
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    if self.pickUpPoint.placeable ~= nil and self.pickUpPoint.placeable.droneManager ~= nil then
        if self.pickUpPoint.placeable.droneManager:removeDrone(self.slot.linkedDrone) then
            self.pickUpPoint.placeable.droneManager = nil
        end
    end

    if self.deliveryPoint.placeable ~= nil and self.deliveryPoint.placeable.droneManager ~= nil then
        if self.deliveryPoint.placeable.droneManager:removeDrone(self.slot.linkedDrone) then
            self.deliveryPoint.placeable.droneManager = nil
        end
    end

    self.pickUpPoint:reset()
    self.deliveryPoint:reset()
    self.dirtyTable = {}

end

function DroneHubSlotConfig:searchPlaceables()
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return false
    end

    local bValid = true

    if not self.pickUpPoint:findPlaceable() then
        bValid = false
    end

    if not self.deliveryPoint:findPlaceable() then
        bValid = false
    end

    if not bValid then
        self.pickUpPoint:reset()
        self.deliveryPoint:reset()
        self.bLoadedConfig = false
        return false
    end


    self.pickUpPoint.placeable.droneManager = PickupDeliveryManager.new(self.pickUpPoint.placeable,self.isServer,self.isClient)
    self.pickUpPoint.placeable.droneManager:register(true)

    self.deliveryPoint.placeable.droneManager = PickupDeliveryManager.new(self.deliveryPoint.placeable,self.isServer,self.isClient)
    self.deliveryPoint.placeable.droneManager:register(true)


    return true
end

function DroneHubSlotConfig:hasPickupPoint()

    if self.pickUpPoint ~= nil then
        return self.pickUpPoint:hasPoint()
    end

    return false
end

function DroneHubSlotConfig:hasDeliveryPoint()

    if self.deliveryPoint ~= nil then
        return self.deliveryPoint:hasPoint()
    end

    return false
end

function DroneHubSlotConfig:getPickupPoint()
    return self.pickUpPoint
end

function DroneHubSlotConfig:getDeliveryPoint()
    return self.deliveryPoint
end

function DroneHubSlotConfig:clearDirtyTable()
    self.dirtyTable = {}
end

function DroneHubSlotConfig:setDirty(dirtyValue)
    self.dirtyTable[dirtyValue] = true
end

function DroneHubSlotConfig:setAllDirty()
    for dirty,_ in pairs(DroneHubSlotConfig.EDirtyFields) do
        self.dirtyTable[dirty] = true
    end
end

function DroneHubSlotConfig:isDirty()
    return next(self.dirtyTable) ~= nil
end

function DroneHubSlotConfig:addDroneToManager(bDelivery,bUpdate)
    if self.pickUpPoint == nil or self.deliveryPoint == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.deliveryPoint.placeable ~= nil and self.deliveryPoint.placeable.droneManager == nil then
            self.deliveryPoint.placeable.droneManager = PickupDeliveryManager.new(self.deliveryPoint.placeable,self.isServer,self.isClient)
            self.deliveryPoint.placeable.droneManager:register(true)
        end
        if self.deliveryPoint.placeable ~= nil then
            self.deliveryPoint.placeable.droneManager:addDeliveryDrone(self.slot.linkedDrone,self.slot)
        end
    else
        if self.pickUpPoint.placeable ~= nil and self.pickUpPoint.placeable.droneManager == nil then
            self.pickUpPoint.placeable.droneManager = PickupDeliveryManager.new(self.pickUpPoint.placeable,self.isServer,self.isClient)
            self.pickUpPoint.placeable.droneManager:register(true)
        end

        if self.pickUpPoint.placeable ~= nil then
            self.pickUpPoint.placeable.droneManager:addPickupDrone(self.slot.linkedDrone,self.slot,self.pickUpPoint)
        end
    end

end

function DroneHubSlotConfig:removeDroneFromManager(bDelivery)
    if self.pickUpPoint == nil or self.deliveryPoint == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.pickUpPoint.placeable ~= nil and self.pickUpPoint.placeable.droneManager ~= nil then
            if self.deliveryPoint.placeable.droneManager:removeDeliveryDrone(self.slot.linkedDrone) then
                self.deliveryPoint.placeable.droneManager = nil
            end
        end
    else
        if self.pickUpPoint.placeable ~= nil and self.pickUpPoint.placeable.droneManager ~= nil then
            if self.pickUpPoint.placeable.droneManager:removeDrone(self.slot.linkedDrone) then
                self.pickUpPoint.placeable.droneManager = nil
            end
        end
    end
end

function DroneHubSlotConfig:addVerifyingPoints(pickUpPointCopy,deliveryPointCopy)
    self.verifyPickUpPoint = pickUpPointCopy
    self.verifydeliveryPoint = deliveryPointCopy
end

function DroneHubSlotConfig:clearVerifyingPoints()
    self.verifyPickUpPoint = nil
    self.verifydeliveryPoint = nil
end

function DroneHubSlotConfig:getPlaceableManagers()
    if self.pickUpPoint == nil or self.pickUpPoint:getPlaceable() == nil or self.deliveryPoint == nil or self.deliveryPoint:getPlaceable() == nil then
        return
    end

    local pickupManager = self.pickUpPoint:getPlaceable().droneManager
    local deliveryManager = self.deliveryPoint:getPlaceable().droneManager
    return pickupManager, deliveryManager
end

function DroneHubSlotConfig:verifyWorkPoints(pickUpPointCopy,deliveryPointCopy)

    local sendPickUpPointCopy = DroneWorkPoint.new(true)
    sendPickUpPointCopy:nilEverything()
    local sendDeliveryPointCopy = DroneWorkPoint.new(false)
    sendDeliveryPointCopy:nilEverything()

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.PICKUPPLACEABLE] then
        sendPickUpPointCopy:setPlaceable(pickUpPointCopy:getPlaceable(),pickUpPointCopy:getAllFillTypes())
        sendPickUpPointCopy:restrictFilltypes(pickUpPointCopy:getFillTypes())
    end

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE] then
        sendPickUpPointCopy:restrictFilltypes(deliveryPointCopy:getFillTypes())
        sendDeliveryPointCopy:setPlaceable(deliveryPointCopy:getPlaceable(),deliveryPointCopy:getAllFillTypes())
    end

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.PRICELIMIT] then
        sendPickUpPointCopy:setPriceLimit(pickUpPointCopy:getPriceLimit())
    end

    sendPickUpPointCopy:setHasPriceLimit(deliveryPointCopy:hasPriceLimit())
    sendPickUpPointCopy:setFillTypeIndex(deliveryPointCopy:getFillTypeIndex())
    sendPickUpPointCopy:setFillLimitIndex(deliveryPointCopy:getFillLimitIndex())

    self.slot:changeState(self.slot.ESlotState.APPLYINGSETTINGS)
    ChangeConfigEvent.sendEvent(self.hubOwner,self.slot.slotIndex,sendPickUpPointCopy,sendDeliveryPointCopy)
end


function DroneHubSlotConfig:applySettings()
    if self.verifyPickUpPoint == nil or self.verifydeliveryPoint == nil then
        return
    end

    if self.verifyPickUpPoint:getFillTypeIndex() ~= nil then
        self.pickUpPoint.fillTypeIndex = self.verifyPickUpPoint:getFillTypeIndex()
    end

    if self.verifyPickUpPoint:getFillLimitIndex() ~= nil then
        self.pickUpPoint.fillLimitIndex = self.verifyPickUpPoint:getFillLimitIndex()
    end

    if self.verifyPickUpPoint:hasPriceLimit() ~= nil then
        self.pickUpPoint.bPriceLimit = self.verifyPickUpPoint:hasPriceLimit()
    end

    if self.verifyPickUpPoint:getPriceLimit() ~= nil then
        self.pickUpPoint.priceLimit = self.verifyPickUpPoint:getPriceLimit()
    end

    if self.verifydeliveryPoint:getPlaceable() ~= nil then
        self.deliveryPoint.placeable = self.verifydeliveryPoint.placeable
        self.deliveryPoint.name = self.verifydeliveryPoint.name
        self.deliveryPoint.position = self.verifydeliveryPoint.position
        self.deliveryPoint.allFillTypes = self.verifydeliveryPoint.allFillTypes
    end

    if self.verifyPickUpPoint:getPlaceable() ~= nil then
        self.pickUpPoint.placeable = self.verifyPickUpPoint.placeable
        self.pickUpPoint.name = self.verifyPickUpPoint.name
        self.pickUpPoint.position = self.verifyPickUpPoint.position
        self.pickUpPoint.allFillTypes = self.verifyPickUpPoint.allFillTypes
        self.pickUpPoint.fillTypes = self.verifyPickUpPoint.fillTypes
    else
        -- case where only  point has been changed then need to update the fillTypes
        if self.verifydeliveryPoint:getPlaceable() ~= nil then
            self.pickUpPoint.fillTypes = self.verifyPickUpPoint.fillTypes
        end
    end

    self:addDroneToManager(false)
    self:addDroneToManager(true)

    self.bLoadedConfig = false
    self:clearDirtyTable()
end

--- On saving
function DroneHubSlotConfig:saveToXMLFile(xmlFile, key, usedModNames)
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    self.pickUpPoint:saveToXMLFile(xmlFile,key..".config(1)",usedModNames)
    self.deliveryPoint:saveToXMLFile(xmlFile,key..".config(2)",usedModNames)
end

--- On loading
function DroneHubSlotConfig:loadFromXMLFile(xmlFile, key)
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return true
    end

    self.pickUpPoint:loadFromXMLFile(xmlFile,key..".config(1)")
    self.deliveryPoint:loadFromXMLFile(xmlFile,key..".config(2)")
    self:setAllDirty()

    return true
end

function DroneHubSlotConfig:onConfigInitialized()
    if self.slot == nil or not self.bLoadedConfig then
        return false
    end

    self.slot:changeState(self.slot.ESlotState.APPLYINGSETTINGS)
    ChangeConfigEvent.sendEvent(self.hubOwner,self.slot.slotIndex,self.pickUpPoint,self.deliveryPoint)
    return true
end

function DroneHubSlotConfig:isLoadedConfig()
    return self.bLoadedConfig == true
end

--- Registering
function DroneHubSlotConfig.registerXMLPaths(schema, basePath)



end

--- Registering
function DroneHubSlotConfig.registerSavegameXMLPaths(schema, basePath)
    DroneWorkPoint.registerSavegameXMLPaths(schema,basePath)
end

function DroneHubSlotConfig:readStream(streamId,connection)
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    self.pickUpPoint:readStream(streamId,connection)
    self.deliveryPoint:readStream(streamId,connection)
end

function DroneHubSlotConfig:writeStream(streamId,connection)
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    self.pickUpPoint:writeStream(streamId,connection)
    self.deliveryPoint:writeStream(streamId,connection)

end

--- readUpdateStream receives from server these variables when dirty raised on server.
function DroneHubSlotConfig:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then



    end
end

--- writeUpdateStream syncs from server to client these variabels when dirty raised.
function DroneHubSlotConfig:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then



    end
end
