--- ChangeConfigEvent is used for sending changed DroneBaseConfig/DronePickupConfig data.
ChangeConfigEvent = {}
ChangeConfigEvent_mt = Class(ChangeConfigEvent,Event)
InitEventClass(ChangeConfigEvent, "ChangeConfigEvent")

--- emptyNew creates new empty event.
function ChangeConfigEvent.emptyNew()
    local self = Event.new(ChangeConfigEvent_mt)
    return self
end

--- new creates a new event and saves object received as param.
--@param hub is the drone hub which slot's route will be changed.
--@param slotIndex is the index of slot which will have config changed.
--@param newPickupConfig is the copy of DronePickupConfig settings for pickup from the GUI.
--@param newDeliveryConfig is the copy of DroneBaseConfig settings for delivery from the GUI.
function ChangeConfigEvent.new(hub,slotIndex,newPickupConfig,newDeliveryConfig)
    local self = ChangeConfigEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    self.newPickupConfig = newPickupConfig
    self.newDeliveryConfig = newDeliveryConfig
    return self
end

--- readStream syncs the object to clients.
function ChangeConfigEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)

    self.newPickupConfig = DronePickupConfig.new()
    self.newPickupConfig:nilEverything()
    self.newDeliveryConfig = DroneBaseConfig.new()
    self.newDeliveryConfig:nilEverything()

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

        self.newPickupConfig:setPlaceable(pickupPlaceable)
        self.newPickupConfig.allFillTypes = allFillTypes
        self.newPickupConfig:restrictFillTypes(fillTypes)
    elseif streamReadBool(streamId) then
        -- if pickup placeable was not new however if delivery placeable is new then needs new common filltypes set
        local fillTypes = {}

        local fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                table.insert(fillTypes, index)
            end
        end
        self.newPickupConfig:restrictFillTypes(fillTypes)
    end

    -- if delivery placeable was dirty
    if streamReadBool(streamId) then
        local deliveryPlaceable = NetworkUtil.readNodeObject(streamId)
        self.newDeliveryConfig:setPlaceable(deliveryPlaceable)
    end

    -- always receives bool price limit
    self.newPickupConfig.bPriceLimit = streamReadBool(streamId)

    -- if price limit was dirty
    if streamReadBool(streamId) then
        self.newPickupConfig.priceLimit = streamReadInt32(streamId)
    end

    -- always receives fill type index
    self.newPickupConfig.fillTypeIndex = streamReadInt8(streamId)

    -- always receives fill limit index
    self.newPickupConfig.fillLimitIndex = streamReadInt8(streamId)

    self:run(connection)
end
--- writeStream writes to object to clients.
function ChangeConfigEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)

    -- write bool if pickup placeable should be sent or not
    if streamWriteBool(streamId,self.newPickupConfig:hasPoint()) then
        NetworkUtil.writeNodeObject(streamId, self.newPickupConfig.placeable)


        local fillTypesString = ""
        for _,id in ipairs(self.newPickupConfig.fillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)

        fillTypesString = ""
        for id,_ in pairs(self.newPickupConfig.allFillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    elseif streamWriteBool(streamId,self.newDeliveryConfig:hasPoint()) then

        local fillTypesString = ""
        for _,id in ipairs(self.newPickupConfig.fillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    end

    -- write bool if delivery placeable should be sent or not
    if streamWriteBool(streamId,self.newDeliveryConfig:hasPoint()) then
        NetworkUtil.writeNodeObject(streamId, self.newDeliveryConfig.placeable)
    end

    -- always sends price limit bool
    streamWriteBool(streamId,self.newPickupConfig.bPriceLimit)

    if streamWriteBool(streamId,self.newPickupConfig.priceLimit ~= nil) then
        streamWriteInt32(streamId,self.newPickupConfig.priceLimit)
    end

    -- always sends fill type index
    streamWriteInt8(streamId,self.newPickupConfig.fillTypeIndex)

    -- always send fill limit index
    streamWriteInt8(streamId,self.newPickupConfig.fillLimitIndex)
end

--- run calls on hub to apply the received config values.
function ChangeConfigEvent:run(connection)

    if self.hub ~= nil then
        self.hub:receiveConfigSettings(self.slotIndex,self.newPickupConfig,self.newDeliveryConfig)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ChangeConfigEvent.new(self.hub,self.slotIndex,self.newPickupConfig,self.newDeliveryConfig), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param hub is the drone hub which slot's route will be changed.
--@param slotIndex is the index of slot which will have config changed.
--@param newPickupConfig is the copy of DronePickupConfig settings for pickup from the GUI.
--@param newDeliveryConfig is the copy of DroneBaseConfig settings for delivery from the GUI.
function ChangeConfigEvent.sendEvent(hub,slotIndex,newPickupConfig,newDeliveryConfig)
    if hub == nil or slotIndex == nil or newPickupConfig == nil or newDeliveryConfig == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(ChangeConfigEvent.new(hub,slotIndex,newPickupConfig,newDeliveryConfig), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:receiveConfigSettings(slotIndex,newPickupConfig,newDeliveryConfig)
    else
        g_client:getServerConnection():sendEvent(ChangeConfigEvent.new(hub,slotIndex,newPickupConfig,newDeliveryConfig))
    end

end

