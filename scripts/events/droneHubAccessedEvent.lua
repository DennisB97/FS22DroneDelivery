--- DroneHubAccessedEvent is used to signal a drone hub has been accessed by another player, so that interaction can be limited to one player at a time.
DroneHubAccessedEvent = {}
DroneHubAccessedEvent_mt = Class(DroneHubAccessedEvent,Event)
InitEventClass(DroneHubAccessedEvent, "DroneHubAccessedEvent")

--- emptyNew creates new empty event.
function DroneHubAccessedEvent.emptyNew()
    local self = Event.new(DroneHubAccessedEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param hub is the drone hub object which should be set in use or not.
--@param isUsing bool which indicates if hub is used by someone or not.
function DroneHubAccessedEvent.new(hub,isUsing)
    local self = DroneHubAccessedEvent.emptyNew()
    self.hub = hub
    self.bUsing = isUsing
    return self
end

--- readStream syncs the object to clients.
function DroneHubAccessedEvent:readStream(streamId, connection)
    self.hub = NetworkUtil.readNodeObject(streamId)
    self.bUsing = streamReadBool(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function DroneHubAccessedEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.hub)
    streamWriteBool(streamId, self.bUsing)
end

--- run sets the drone hub in use or not in use.
function DroneHubAccessedEvent:run(connection)

    if self.hub ~= nil then
        self.hub:setInUse(self.bUsing)
    end
    if not connection:getIsServer() then
        g_server:broadcastEvent(DroneHubAccessedEvent.new(self.hub,self.bUsing), nil, connection, self.hub)
    end
end

--- sendEvent called when event wants to be sent.
--@param hub is the drone hub object which should be set in use or not.
--@param isUsing bool which indicates if hub is used by someone or not.
function DroneHubAccessedEvent.sendEvent(hub,isUsing)
    if hub == nil then
        return
    end
    isUsing = (isUsing ~= nil and {isUsing} or {true})[1]

    if g_server ~= nil then
        g_server:broadcastEvent(DroneHubAccessedEvent.new(hub,isUsing), nil, nil, hub)
    else
        g_client:getServerConnection():sendEvent(DroneHubAccessedEvent.new(hub,isUsing))
    end

end