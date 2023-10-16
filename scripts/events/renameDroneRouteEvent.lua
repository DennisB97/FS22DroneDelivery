--- RenameDroneRouteEvent is used for renaming a drone route.
RenameDroneRouteEvent = {}
RenameDroneRouteEvent_mt = Class(RenameDroneRouteEvent,Event)
InitEventClass(RenameDroneRouteEvent, "RenameDroneRouteEvent")

--- emptyNew creates new empty event.
function RenameDroneRouteEvent.emptyNew()
    local self = Event.new(RenameDroneRouteEvent_mt)
    return self
end
--- new creates a new event.
--@param hub is the drone hub which slot's route will be renamed.
--@param slotIndex is the index of slot which to be renamed.
--@param name is the string of new name.
function RenameDroneRouteEvent.new(hub,slotIndex,name)
    local self = RenameDroneRouteEvent.emptyNew()
    self.hub = hub
    self.slotIndex = slotIndex
    self.name = name
    return self
end
--- readStream syncs the object to clients.
function RenameDroneRouteEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.slotIndex = streamReadInt8(streamId)
    self.name = streamReadString(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function RenameDroneRouteEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteInt8(streamId, self.slotIndex)
    streamWriteString(streamId, self.name)
end

--- run calls the renaming function on drone hub.
function RenameDroneRouteEvent:run(connection)

    if self.hub ~= nil then
        self.hub:renameDroneRoute(self.slotIndex,self.name)
    end
    if not connection:getIsServer() then
        g_server:broadcastEvent(RenameDroneRouteEvent.new(self.hub,self.slotIndex,self.name), nil, nil, self.hub)
    end
end

--- sendEvent called when event wants to be sent.
--@param hub is the drone hub which slot's route will be renamed.
--@param slotIndex is the index of slot which to be renamed.
--@param name is the string of new name.
function RenameDroneRouteEvent.sendEvent(hub,slotIndex,name)
    if hub == nil or slotIndex == nil or name == nil then
        return
    end

    if g_server ~= nil then
        g_server:broadcastEvent(RenameDroneRouteEvent.new(hub,slotIndex,name), nil, nil, hub)
        -- if server doing event then need to run function here because broadcast will only be to clients
        hub:renameDroneRoute(slotIndex,name)
    else
        g_client:getServerConnection():sendEvent(RenameDroneRouteEvent.new(hub,slotIndex,name))
    end
end