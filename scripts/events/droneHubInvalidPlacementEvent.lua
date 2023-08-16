


--- DroneHubInvalidPlacementEvent is used for signaling farm members of their drone hub being badly placed.
DroneHubInvalidPlacementEvent = {}
DroneHubInvalidPlacementEvent_mt = Class(DroneHubInvalidPlacementEvent,Event)
InitEventClass(DroneHubInvalidPlacementEvent, "DroneHubInvalidPlacementEvent")

--- emptyNew creates new empty event.
function DroneHubInvalidPlacementEvent.emptyNew()
    local self = Event.new(DroneHubInvalidPlacementEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param object is the bird feeder object.
function DroneHubInvalidPlacementEvent.new(object)
    local self = DroneHubInvalidPlacementEvent.emptyNew()
    self.object = object
    return self
end
--- readStream syncs the object to clients.
function DroneHubInvalidPlacementEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function DroneHubInvalidPlacementEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end
--- run calls the invalidPlacement of dronehub object.
function DroneHubInvalidPlacementEvent:run(connection)
    if self.object ~= nil then
        self.object:invalidPlacement()
    end
end
--- sendEvent called when event wants to be sent.
-- server only.
--@param droneHub is the hub that wants to have event called.
function DroneHubInvalidPlacementEvent.sendEvent(droneHub)
    if droneHub ~= nil and g_server ~= nil then
        g_server:broadcastEvent(DroneHubInvalidPlacementEvent.new(droneHub), nil, nil, droneHub)
    end
end