--- ChangeCustomPointScaleEvent is used to change scale of custom delivery pickup point when changing scale of it when constructing.
ChangeCustomPointScaleEvent = {}
ChangeCustomPointScaleEvent_mt = Class(ChangeCustomPointScaleEvent,Event)
InitEventClass(ChangeCustomPointScaleEvent, "ChangeCustomPointScaleEvent")

--- emptyNew creates new empty event.
function ChangeCustomPointScaleEvent.emptyNew()
    local self = Event.new(ChangeCustomPointScaleEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param positionString is coordinates inserted into string.
--@param scale integer of the new scale.
function ChangeCustomPointScaleEvent.new(positionString,scale)
    local self = ChangeCustomPointScaleEvent.emptyNew()
    self.positionString = positionString
    self.scale = scale
    return self
end

--- readStream syncs the object to clients.
function ChangeCustomPointScaleEvent:readStream(streamId, connection)
    self.positionString = streamReadString(streamId)
    self.scale = streamReadInt8(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function ChangeCustomPointScaleEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.positionString)
    streamWriteInt8(streamId, self.scale)
end

--- run gives the position string and scale to server's CustomDeliveryPickupPoint.
function ChangeCustomPointScaleEvent:run(connection)

    if self.positionString ~= nil then
        CustomDeliveryPickupPoint.serverReceiveScaled(self.positionString,self.scale)
    end
end


--- sendEvent called when event wants to be sent.
--@param positionString is coordinates inserted into string.
--@param scale integer of the new scale.
function ChangeCustomPointScaleEvent.sendEvent(positionString,scale)
    if positionString == nil or scale == nil then
        return
    end

    if g_server ~= nil then
        -- do nothing if server, as placeable with scaling is synced to clients automatically.
    else
        g_client:getServerConnection():sendEvent(ChangeCustomPointScaleEvent.new(positionString,scale))
    end
end