--- ConfigValidatedEvent is used for when server has finished validating new pickup/delivery point for drone from a hub slot.
ConfigValidatedEvent = {}
ConfigValidatedEvent_mt = Class(ConfigValidatedEvent,Event)
InitEventClass(ConfigValidatedEvent, "ConfigValidatedEvent")

--- emptyNew creates new empty event.
function ConfigValidatedEvent.emptyNew()
    local self = Event.new(ConfigValidatedEvent_mt)
    return self
end
--- new creates a new event and savess received params.
--@param hub is drone hub which has had a slot settings changed.
--@param slotIndex is the index of slot of the hub that has settings changed.
--@param bValid indicates if the new settings received(path was able to be created) were valid.
--@param bLoadedConfig indicates if the settings were loaded from xml file.
function ConfigValidatedEvent.new(hub,slotIndex,bValid,bLoadedConfig)
    local self = ConfigValidatedEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    self.bValid = bValid
    self.bLoadedConfig = bLoadedConfig
    return self
end
--- readStream syncs the object to clients.
function ConfigValidatedEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)
    self.bValid = streamReadBool(streamId)
    self.bLoadedConfig = streamReadBool(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function ConfigValidatedEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)
    streamWriteBool(streamId, self.bValid)
    streamWriteBool(streamId,self.bLoadedConfig)
end
--- run calls the invalidPlacement of birdfeeder object.
function ConfigValidatedEvent:run(connection)
    if self.hub ~= nil then
        self.hub:validatedSlotSettings(self.slotIndex,self.bValid,self.bLoadedConfig)
    end
end

--- sendEvent called when event wants to be sent.
-- server only.
--@param hub is drone hub which has had a slot settings changed.
--@param slotIndex is the index of slot of the hub that has settings changed.
--@param bValid indicates if the new settings received(path was able to be created) were valid.
--@param bLoadedConfig indicates if the settings were loaded from xml file.
function ConfigValidatedEvent.sendEvent(hub,slotIndex,bValid,bLoadedConfig)
    if hub ~= nil and slotIndex ~= nil and g_server ~= nil then
        g_server:broadcastEvent(ConfigValidatedEvent.new(hub,slotIndex,bValid,bLoadedConfig), nil, nil, hub)
        hub:validatedSlotSettings(slotIndex,bValid,bLoadedConfig)
    end
end