

---@class DronePathCreator.
-- Handles creating path between hub -> pickup -> delivery -> hub.
DronePathCreator = {}
DronePathCreator_mt = Class(DronePathCreator)
InitObjectClass(DronePathCreator, "DronePathCreator")

--- new creates a new PickupDeliveryManager object.
--@param entrancePosition is table of hub's entrance position where drones will leave and enter, given as {x=,y=,z=}.
function DronePathCreator.new(entrancePosition)
    local self = setmetatable({}, DronePathCreator_mt)

    self.trianglePath = {}
    self.entrancePosition = entrancePosition
    self.pickUpPlaceable = nil
    self.deliveryPlaceable = nil
    self.pathGenerator = AStar.new(true,false)
    self.pathGenerator:register(true)
    self.splineGenerator = CatmullRomSplineCreator.new(true,false)
    self.splineGenerator:register(true)
    -- a distance value in m, when closer than this to directly pathfind between points. Else will go higher up in the sky between points.
    self.nearbyDistanceLimit = 100
    -- if longer distance than above limit then, this indicates how high up the path should be made between points.
    self.skyFlyHeight = 80

    self.callback = nil
    -- these bools indicate which paths need to be made
    self.bRequiresToPickup = false
    self.bRequiresToDelivery = false
    self.bRequiresToHub = false
    self.EConnections = {TOPICKUP = 1, TODELIVERY = 2, TOHUB = 3}
    self.currentConnection = nil
    return self
end


function DronePathCreator:delete()

    if self.splineGenerator ~= nil then
        self.splineGenerator:delete()
        self.splineGenerator = nil
    end

    if self.pathGenerator ~= nil then
        self.pathGenerator:delete()
        self.pathGenerator = nil
    end

    self.callback = nil

end

function DronePathCreator:generateNew(pickUpPlaceable,deliveryPlaceable,callback)
    if pickUpPlaceable == nil and deliveryPlaceable == nil then
        return
    end

    self.callback = callback
    self.bRequiresToPickup = false
    self.bRequiresToDelivery = false
    self.bRequiresToHub = false

    if self.pickUpPlaceable ~= pickUpPlaceable then
        self.bRequiresToPickup = true
        self.bRequiresToDelivery = true
        self.pickUpPlaceable = pickUpPlaceable
    end

    if self.deliveryPlaceable ~= deliveryPlaceable then
        self.bRequiresToDelivery = true
        self.bRequiresToHub = true
        self.deliveryPlaceable = deliveryPlaceable
    end



    self:newConnection()

end

function DronePathCreator:newConnection()
    self.currentSpline = nil
    self.currentStep = 0
    self.bIsDirect = false

    local startPosition = {}
    startPosition.x, startPosition.y, startPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
    local endPosition = nil

    if self.bRequiresToPickup then
        self.bRequiresToPickup = false
        self.currentConnection = self.EConnections.TOPICKUP
        endPosition = {}
        endPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
        if self:isDirectConnection(startPosition,endPosition) then
            self.bIsDirect = true
        end
    elseif self.bRequiresToDelivery then
        self.bRequiresToDelivery = false
        self.currentConnection = self.EConnections.TODELIVERY
        startPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
        endPosition = {}
        endPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
        if self:isDirectConnection(startPosition,endPosition) then
            self.bIsDirect = true
        end
    elseif self.bRequiresToHub then
        self.bRequiresToHub = false
        self.currentConnection = self.EConnections.TOHUB
        startPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
        endPosition = {}
        endPosition.x,endPosition.y,endPosition.z = self.entrancePosition.x, self.entrancePosition.y, self.entrancePosition.z
        if self:isDirectConnection(startPosition,endPosition) then
            self.bIsDirect = true
        end
    end

    if endPosition ~= nil then
        if self.bIsDirect then
            self:createNewPath(startPosition,endPosition)
        else
            self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
        end

    else -- if no end position means the whole "triangle" path is ready
        self.callback(self.trianglePath)
    end

end

function DronePathCreator:isDirectConnection(startPosition,endPosition)
    local distance = MathUtil.vector3Length(startPosition.x - endPosition.x, startPosition.y - endPosition.y, startPosition.z - endPosition.z)
    return distance <= self.nearbyDistanceLimit
end


function DronePathCreator:createNewPath(startPosition,endPosition)

    local callback = function(aStarResult) self:onPathCreated(aStarResult) end
    if not self.pathGenerator:find(startPosition,endPosition,false,true,true,callback,true,5,10000) then
        self.callback(nil)
    end

end

function DronePathCreator:onPathCreated(aStarResult)

    if not aStarResult[2] then
        self.callback(nil)
    end

    local customP0 = nil
    local lastDirection = nil
    print("on path created")

    if self.currentSpline ~= nil then
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        customP0 = {}
        customP0.x,customP0.y,customP0.z = lastSegment.p1.x, lastSegment.p1.y, lastSegment.p1.z
        lastDirection = {}
        lastDirection.x, lastDirection.y, lastDirection.z = MathUtil.vector3Normalize(lastSegment.p2.x - lastSegment.p1.x,lastSegment.p2.y - lastSegment.p1.y, lastSegment.p2.z - lastSegment.p1.z)
    end

    local callback = function(spline) self:onSplineCreated(spline) end
    self.splineGenerator:createSpline(aStarResult[1],callback,customP0,nil,lastDirection)
end


function DronePathCreator:onSplineCreated(spline)

    if self.bIsDirect then
        self:finalizeSpline(spline)
        return
    end

    if self.currentSpline == nil then
        self.currentSpline = spline
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    else

        local callback = function(newSpline) self:onSplineCombined(newSpline) end
        self.splineGenerator:combineSplinesAtDistance(self.currentSpline,spline,self.currentSpline:getSplineLength(),callback)

    end


end

function DronePathCreator:onSplineCombined(spline)

    if self.currentStep > 2 then
        self:finalizeSpline(spline)
    else
        lastSegment = self.currentSpline.segments[#self.currentSpline.segments]
        local startPosition = {x = lastSegment.p2.x,y = lastSegment.p2.y,z = lastSegment.p2.z}
        self:createNewPath(startPosition,self:getNextEndPosition({x=startPosition.x,y=startPosition.y,z=startPosition.z}))
    end

end

--- getNextEndPosition gets the next path's end position when connection is not direct but it goes through the sky high up.
-- simply uses a currentStep index from 0-2 to know which part of path end is being requested, 0 = vertical up, 1= horizontal , 2 = last step down back from the sky to the final position.
function DronePathCreator:getNextEndPosition(startPosition)

    if self.currentStep == 0 then
        startPosition.y = startPosition.y + self.skyFlyHeight
        self.currentStep = self.currentStep + 1
        return startPosition
    end

    local finalPosition = nil

    if self.currentConnection == self.EConnections.TOPICKUP then
        finalPosition = PickupDeliveryHelper.getPointPosition(true,self.pickUpPlaceable)
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        finalPosition = PickupDeliveryHelper.getPointPosition(false,self.deliveryPlaceable)
    elseif self.currentConnection == self.EConnections.TOHUB then
        finalPosition = {x=self.entrancePosition.x,y=self.entrancePosition.y,z=self.entrancePosition.z}
    end

    if self.currentStep == 1 then
        finalPosition.y = finalPosition.y + self.skyFlyHeight
    end

    self.currentStep = self.currentStep + 1
    return finalPosition
end

function DronePathCreator:finalizeSpline(spline)

    if self.currentConnection == self.EConnections.TOPICKUP then
        self.trianglePath.toPickup = spline
    elseif self.currentConnection == self.EConnections.TODELIVERY then
        self.trianglePath.toDelivery = spline
    elseif self.currentConnection == self.EConnections.TOHUB then
        self.trianglePath.toHub = spline
    end

    self:newConnection()
end

