

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
--@param object is the drone hub object.
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


    self.pickUpPointCopy:setHasPriceLimit(streamReadBool(streamId))

    -- if price limit was dirty
    if streamReadBool(streamId) then
        self.pickUpPointCopy:setPriceLimit(streamReadInt32(streamId))
    end

    self.pickUpPointCopy:setFillTypeIndex(streamReadInt8(streamId))

    self:run(connection)
end
--- writeStream writes to object to clients.
function ChangeConfigEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)

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

    streamWriteBool(streamId,self.pickUpPointCopy:hasPriceLimit())

    if streamWriteBool(streamId,self.pickUpPointCopy:getPriceLimit() ~= nil) then
        streamWriteInt32(streamId,self.pickUpPointCopy:getPriceLimit())
    end

    streamWriteInt8(streamId,self.pickUpPointCopy:getFillTypeIndex())

end

--- run
function ChangeConfigEvent:run(connection)

    print("run running")
    DebugUtil.printTableRecursively(self.pickUpPointCopy,"run pickup: ",0,0)
    DebugUtil.printTableRecursively(self.deliveryPointCopy,"run delivery: ",0,0)

    if self.hub ~= nil then
        self.hub:applyConfigSettings(self.slotIndex,self.pickUpPointCopy,self.deliveryPointCopy)
    end

    if not connection:getIsServer() then
        print("run event connection is not getIsServer")
        g_server:broadcastEvent(ChangeConfigEvent.new(self.hub,self.slotIndex,self.pickUpPointCopy,self.deliveryPointCopy), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param.
function ChangeConfigEvent.sendEvent(hub,slotIndex,pickUpPointCopy,deliveryPointCopy)
    if hub == nil or slotIndex == nil or pickUpPointCopy == nil or deliveryPointCopy == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(ChangeConfigEvent.new(hub,slotIndex,pickUpPointCopy,deliveryPointCopy), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:applyConfigSettings(slotIndex,pickUpPointCopy,deliveryPointCopy)
    else
        print("client sending the event")
        DebugUtil.printTableRecursively(pickUpPointCopy,"pickup: ",0,0)
        DebugUtil.printTableRecursively(deliveryPointCopy,"delivery: ",0,0)
        g_client:getServerConnection():sendEvent(ChangeConfigEvent.new(hub,slotIndex,pickUpPointCopy,deliveryPointCopy))
    end

end

