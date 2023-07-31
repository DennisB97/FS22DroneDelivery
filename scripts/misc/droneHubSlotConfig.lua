

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
end

function DroneWorkPoint:findPlaceable()
    if self.position == nil then
        return false
    end

    overlapBox(self.position.x,self.position.y,self.position.z,0,0,0,5,5,5,"placeableSearchCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)

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

        if self.name == object:getName() and CatmullRomSpline.isNearlySamePosition(foundPosition,self.position,0.1) then
            self.placeable = object
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
end


--- On saving
function DroneWorkPoint:saveToXMLFile(xmlFile, key, usedModNames)

    local x,y,z = nil,nil,nil
    if self.position ~= nil then
        x,y,z = self.position.x, self.position.y, self.position.z
    end

    xmlFile:setValue(key.."#position", x, y, z)
    xmlFile:setValue(key.."#name",self.name)
    xmlFile:setValue(key.."#fillTypeIndex", self.fillTypeIndex)
    xmlFile:setValue(key.."#hasPriceLimit", self.bPriceLimit)
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
    self.name = Utils.getNoNil(xmlFile:getValue(key.."#name"),"")
    self.bPriceLimit = Utils.getNoNil(xmlFile:getValue(key.."#hasPriceLimit"),false)
    self.priceLimit = Utils.getNoNil(xmlFile:getValue(key.."#priceLimit"),0)

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
    schema:register(XMLValueType.STRING,        basePath .. ".config(?)#name", "name of placeable")
    schema:register(XMLValueType.INT,        basePath .. ".config(?)#fillTypeIndex", "Fill type index within the fillTypes array")
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

        print("sending placeable which is : " .. tostring(self.placeable))

        NetworkUtil.writeNodeObject(streamId, self.placeable)
        streamWriteFloat32(streamId,self.position.x)
        streamWriteFloat32(streamId,self.position.y)
        streamWriteFloat32(streamId,self.position.z)

        streamWriteInt32(streamId,self.fillTypeIndex)
        streamWriteBool(streamId,self.bPriceLimit)
        streamWriteInt32(streamId,self.priceLimit)

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

DroneHubSlotConfig.EDirtyFields = {PICKUPPLACEABLE = 1, DELIVERYPLACEABLE = 2, PRICELIMIT = 3, PRICELIMITUSED = 4, FILLTYPEID = 5 }


function DroneHubSlotConfig.new(hub,slotIndex)
    local self = setmetatable({}, DroneHubSlotConfig_mt)
    self.hubOwner = hub
    self.pickUpPoint = DroneWorkPoint.new(true)
    self.deliveryPoint = DroneWorkPoint.new(false)
    self.dirtyTable = {}
    self.slotIndex = slotIndex

    return self
end

function DroneHubSlotConfig:clearConfig()
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    self.pickUpPoint:reset()
    self.deliveryPoint:reset()
    self.dirtyTable = {}

end

function DroneHubSlotConfig:searchPlaceables()
    if self.pickUpPoint == nil or self.deliveryPoint == nil then
        return
    end

    if not self.pickUpPoint:findPlaceable() then
        self.pickUpPoint:reset()
    end

    if not self.deliveryPoint:findPlaceable() then
        self.deliveryPoint:reset()
    end


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

function DroneHubSlotConfig:updateWorkPoints(pickUpPointCopy,deliveryPointCopy)

    local sendPickUpPointCopy = DroneWorkPoint.new(true)
    sendPickUpPointCopy:nilEverything()
    local sendDeliveryPointCopy = DroneWorkPoint.new(false)
    sendDeliveryPointCopy:nilEverything()

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.PICKUPPLACEABLE] then
        sendPickUpPointCopy:setPlaceable(pickUpPointCopy:getPlaceable(),pickUpPointCopy:getAllFillTypes())
        sendPickUpPointCopy:restrictFilltypes(pickUpPointCopy:getFillTypes())
    end

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE] then
        sendPickUpPointCopy:restrictFilltypes(pickUpPointCopy:getFillTypes())
        sendDeliveryPointCopy:setPlaceable(deliveryPointCopy:getPlaceable(),deliveryPointCopy:getAllFillTypes())
    end

    if self.dirtyTable[DroneHubSlotConfig.EDirtyFields.PRICELIMIT] then
        sendPickUpPointCopy:setPriceLimit(pickUpPointCopy:getPriceLimit())
    end

    sendPickUpPointCopy:setHasPriceLimit(pickUpPointCopy:hasPriceLimit())
    sendPickUpPointCopy:setFillTypeIndex(pickUpPointCopy:getFillTypeIndex())

    ChangeConfigEvent.sendEvent(self.hubOwner,self.slotIndex,sendPickUpPointCopy,sendDeliveryPointCopy)
end

function DroneHubSlotConfig:applySettings(pickUpPointCopy,deliveryPointCopy)
    if pickUpPointCopy == nil or deliveryPointCopy == nil then
        return
    end

    if pickUpPointCopy:getPlaceable() ~= nil then
        self.pickUpPoint.placeable = pickUpPointCopy.placeable
        self.pickUpPoint.name = pickUpPointCopy.name
        self.pickUpPoint.position = pickUpPointCopy.position
        self.pickUpPoint.fillTypes = pickUpPointCopy.fillTypes
        self.pickUpPoint.allFillTypes = pickUpPointCopy.allFillTypes

        --@TODO: do some event call pickup location changed
    end

    if pickUpPointCopy:getFillTypeIndex() ~= nil then
        self.pickUpPoint.fillTypeIndex = pickUpPointCopy:getFillTypeIndex()
    end

    if pickUpPointCopy:hasPriceLimit() ~= nil then
        self.pickUpPoint.bPriceLimit = pickUpPointCopy:hasPriceLimit()
    end

    if pickUpPointCopy:getPriceLimit() ~= nil then
        self.pickUpPoint.priceLimit = pickUpPointCopy:getPriceLimit()
    end

    if deliveryPointCopy:getPlaceable() ~= nil then
        self.deliveryPoint.placeable = deliveryPointCopy.placeable
        self.deliveryPoint.name = deliveryPointCopy.name
        self.deliveryPoint.position = deliveryPointCopy.position
        self.deliveryPoint.fillTypes = {}
        self.deliveryPoint.allFillTypes = deliveryPointCopy.allFillTypes

        --@TODO: do some event call delivery location changed
    end

    if deliveryPointCopy:getFillTypeIndex() ~= nil then
        self.deliveryPoint.fillTypeIndex = deliveryPointCopy:getFillTypeIndex()
    end

    if deliveryPointCopy:hasPriceLimit() ~= nil then
        self.deliveryPoint.bPriceLimit = deliveryPointCopy:hasPriceLimit()
    end

    if deliveryPointCopy:getPriceLimit() ~= nil then
        self.deliveryPoint.priceLimit = deliveryPointCopy:getPriceLimit()
    end

    self:clearDirtyTable()
    --@TODO: do some event call general settings changed
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

    return true
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
