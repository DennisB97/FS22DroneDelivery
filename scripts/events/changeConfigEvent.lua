

--- ChangeConfigEvent is used for sending changed DroneWorkPoint data.
ChangeConfigEvent = {}
ChangeConfigEvent_mt = Class(ChangeConfigEvent,Event)
InitEventClass(ChangeConfigEvent, "ChangeConfigEvent")

--- emptyNew creates new empty event.
function ChangeConfigEvent.emptyNew()
    local self = Event.new(ChangeConfigEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param hub is the drone hub which slot's route will be renamed.
--@param slotIndex is the index of slot which to be renamed.
--@param pickUpPointCopy is the copy of DroneWorkPoint settings for pickup from the GUI.
--@param deliveryPointCopy is the copy of DroneWorkPoint settings for delivery from the GUI.
function ChangeConfigEvent.new(hub,slotIndex,pickUpPointCopy,deliveryPointCopy)
    local self = ChangeConfigEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    self.pickUpPointCopy = pickUpPointCopy
    self.deliveryPointCopy = deliveryPointCopy
    return self
end
--- readStream syncs the object to clients.
function ChangeConfigEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)

    self.pickUpPointCopy = DroneWorkPoint.new(true)
    self.pickUpPointCopy:nilEverything()
    self.deliveryPointCopy = DroneWorkPoint.new(false)
    self.deliveryPointCopy:nilEverything()

    -- if pickup placeable was dirty
    if streamReadBool(streamId) then
        local pickupPlaceable = NetworkUtil.readNodeObject(streamId)

        local allFillTypes = {}
        local fillTypes = {}

        local fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                table.insert(fillTypes, index)
            end
        end

        fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                allFillTypes[index] = true
            end
        end

        self.pickUpPointCopy:setPlaceable(pickupPlaceable,allFillTypes)
        self.pickUpPointCopy:restrictFilltypes(fillTypes)
    end

    -- if delivery placeable was dirty
    if streamReadBool(streamId) then

        local deliveryPlaceable = NetworkUtil.readNodeObject(streamId)

        local allFillTypes = {}
        local fillTypes = {}

        local fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                allFillTypes[index] = true
            end
        end

        fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                table.insert(fillTypes, index)
            end
        end


        self.deliveryPointCopy:setPlaceable(deliveryPlaceable,allFillTypes)
        self.pickUpPointCopy:restrictFilltypes(fillTypes)
    end

    -- always receives bool price limit
    self.pickUpPointCopy:setHasPriceLimit(streamReadBool(streamId))

    -- if price limit was dirty
    if streamReadBool(streamId) then
        self.pickUpPointCopy:setPriceLimit(streamReadInt32(streamId))
    end

    -- always receives fill type index
    self.pickUpPointCopy:setFillTypeIndex(streamReadInt8(streamId))

    self:run(connection)
end
--- writeStream writes to object to clients.
function ChangeConfigEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)

    -- write bool if pickup placeable should be sent or not
    if streamWriteBool(streamId,self.pickUpPointCopy:getPlaceable() ~= nil) then
        NetworkUtil.writeNodeObject(streamId, self.pickUpPointCopy:getPlaceable())


        local fillTypesString = ""
        for _,id in ipairs(self.pickUpPointCopy:getFillTypes()) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)

        fillTypesString = ""
        for id,_ in pairs(self.pickUpPointCopy:getAllFillTypes()) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    end

    -- write bool if delivery placeable should be sent or not
    if streamWriteBool(streamId,self.deliveryPointCopy:getPlaceable() ~= nil) then

        NetworkUtil.writeNodeObject(streamId, self.deliveryPointCopy:getPlaceable())

        fillTypesString = ""
        for id,_ in pairs(self.deliveryPointCopy:getAllFillTypes()) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)

        fillTypesString = ""
        for _,id in ipairs(self.pickUpPointCopy:getFillTypes()) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    end

    -- always sends price limit bool
    streamWriteBool(streamId,self.pickUpPointCopy:hasPriceLimit())

    if streamWriteBool(streamId,self.pickUpPointCopy:getPriceLimit() ~= nil) then
        streamWriteInt32(streamId,self.pickUpPointCopy:getPriceLimit())
    end

    -- always sends fill type index
    streamWriteInt8(streamId,self.pickUpPointCopy:getFillTypeIndex())

end

--- run calls on hub to apply the received config values.
function ChangeConfigEvent:run(connection)

    if self.hub ~= nil then
        self.hub:receiveConfigSettings(self.slotIndex,self.pickUpPointCopy,self.deliveryPointCopy)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ChangeConfigEvent.new(self.hub,self.slotIndex,self.pickUpPointCopy,self.deliveryPointCopy), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param hub is the drone hub which slot's route will be renamed.
--@param slotIndex is the index of slot which to be renamed.
--@param pickUpPointCopy is the copy of DroneWorkPoint settings for pickup from the GUI.
--@param deliveryPointCopy is the copy of DroneWorkPoint settings for delivery from the GUI.
function ChangeConfigEvent.sendEvent(hub,slotIndex,pickUpPointCopy,deliveryPointCopy)
    if hub == nil or slotIndex == nil or pickUpPointCopy == nil or deliveryPointCopy == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(ChangeConfigEvent.new(hub,slotIndex,pickUpPointCopy,deliveryPointCopy), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:receiveConfigSettings(slotIndex,pickUpPointCopy,deliveryPointCopy)
    else
        g_client:getServerConnection():sendEvent(ChangeConfigEvent.new(hub,slotIndex,pickUpPointCopy,deliveryPointCopy))
    end

end

