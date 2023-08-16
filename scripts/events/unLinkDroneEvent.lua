

--- UnLinkDroneEvent is used for linking a hub and a drone together.
UnLinkDroneEvent = {}
UnLinkDroneEvent_mt = Class(UnLinkDroneEvent,Event)
InitEventClass(UnLinkDroneEvent, "UnLinkDroneEvent")

--- emptyNew creates new empty event.
function UnLinkDroneEvent.emptyNew()
    local self = Event.new(UnLinkDroneEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param hub is the drone hub which drone will be unlinked from.
--@param slotIndex is the index of slot which unlinking from.
function UnLinkDroneEvent.new(hub,slotIndex)
    local self = UnLinkDroneEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    return self
end
--- readStream syncs the object to clients.
function UnLinkDroneEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function UnLinkDroneEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)
end

--- run calls on hub to unlink drone from given slotIndex
function UnLinkDroneEvent:run(connection)

    if self.hub ~= nil then
        self.hub:unLinkDrone(self.slotIndex)
    end
    if not connection:getIsServer() then
        g_server:broadcastEvent(UnLinkDroneEvent.new(self.hub,self.slotIndex), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param hub is the drone hub which drone will be unlinked from.
--@param slotIndex is the index of slot which unlinking from.
function UnLinkDroneEvent.sendEvent(hub,slotIndex)
    if hub == nil or slotIndex == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(UnLinkDroneEvent.new(hub,slotIndex), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:unLinkDrone(slotIndex)
    else
        g_client:getServerConnection():sendEvent(UnLinkDroneEvent.new(hub,slotIndex))
    end

end