

--- ClearConfigEvent is used for sending command to clear the setting for a drone.
ClearConfigEvent = {}
ClearConfigEvent_mt = Class(ClearConfigEvent,Event)
InitEventClass(ClearConfigEvent, "ClearConfigEvent")

--- emptyNew creates new empty event.
function ClearConfigEvent.emptyNew()
    local self = Event.new(ClearConfigEvent_mt)
    return self
end

--- new creates a new event and saves object received as param.
--@param hub is the drone hub which owns the drone that settings will be cleared.
--@param slotIndex is the index of slot which drone is on.
function ClearConfigEvent.new(hub,slotIndex)
    local self = ClearConfigEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    return self
end
--- readStream syncs the object to clients.
function ClearConfigEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function ClearConfigEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)
end

--- run calls on hub to forward clear settings command.
function ClearConfigEvent:run(connection)

    if self.hub ~= nil then
        self.hub:clearConfigSettings(self.slotIndex)
    end

    if not connection:getIsServer() then
        g_server:broadcastEvent(ClearConfigEvent.new(self.hub,self.slotIndex), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param hub is the drone hub which owns the drone that settings will be cleared.
--@param slotIndex is the index of slot which drone is on.
function ClearConfigEvent.sendEvent(hub,slotIndex)
    if hub == nil or slotIndex == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(ClearConfigEvent.new(hub,slotIndex), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:clearConfigSettings(slotIndex)
    else
        g_client:getServerConnection():sendEvent(ClearConfigEvent.new(hub,slotIndex))
    end

end