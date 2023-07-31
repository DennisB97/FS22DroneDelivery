
--- linkDroneEvent is used for linking a hub and a drone together.
LinkDroneEvent = {}
LinkDroneEvent_mt = Class(LinkDroneEvent,Event)
InitEventClass(LinkDroneEvent, "LinkDroneEvent")

--- emptyNew creates new empty event.
function LinkDroneEvent.emptyNew()
    local self = Event.new(LinkDroneEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param object is the drone hub object.
function LinkDroneEvent.new(hub,drone,id,slotIndex)
    local self = LinkDroneEvent.emptyNew()
    self.hub = hub
    self.drone = drone
    self.id = id
    self.slotIndex = slotIndex
    return self
end
--- readStream syncs the object to clients.
function LinkDroneEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.drone = NetworkUtil.readNodeObject(streamId)
    self.id = streamReadString(streamId)
    self.slotIndex = streamReadInt8(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function LinkDroneEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    NetworkUtil.writeNodeObject(streamId, self.drone)
    streamWriteString(streamId, self.id)
    streamWriteInt8(streamId, self.slotIndex)
end

--- run
function LinkDroneEvent:run(connection)

    if self.hub ~= nil then
        self.hub:linkDrone(self.drone,self.id,self.slotIndex)
    end
    if not connection:getIsServer() then
        g_server:broadcastEvent(LinkDroneEvent.new(self.hub,self.drone,self.id,self.slotIndex), nil, nil, self.hub)
    end
end
--- sendEvent called when event wants to be sent.
--@param.
function LinkDroneEvent.sendEvent(hub,drone,id,slotIndex)
    if hub == nil or drone == nil or id == nil or slotIndex == nil then
        return
    end

    if drone.spec_drone ~= nil and drone.spec_drone.linkID == "" then
        if g_server ~= nil then
            g_server:broadcastEvent(LinkDroneEvent.new(hub,drone,id,slotIndex), nil, nil, hub)
            -- if server doing event then need to run function here because broadcast will only be to clients
            hub:linkDrone(drone,id,slotIndex)
        else
            g_client:getServerConnection():sendEvent(LinkDroneEvent.new(hub,drone,id,slotIndex))
        end

    end
end