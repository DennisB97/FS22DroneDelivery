
--- BASE SYSTEM STATE CLASS ---
DroneStateBase = {}
DroneStateBase_mt = Class(DroneStateBase)
InitObjectClass(DroneStateBase, "DroneStateBase")

function DroneStateBase.new(customMt)
    local self = setmetatable({}, customMt or DroneStateBase_mt)
    self.owner = nil
    self.isServer = nil
    self.isClient = nil
    self.bLoaded = false
    self.steering = nil
    self.bIsOnSpline = false
    self.onArrivedToSplineCallback = function() self:onAtSpline() end
    return self
end

function DroneStateBase:init(inOwner,isServer,isClient)
    self.owner = inOwner
    self.isServer = isServer
    self.isClient = isClient
end

function DroneStateBase:enter()
end

function DroneStateBase:leave()
    self.bIsOnSpline = false
    if self.steering ~= nil then
        self.steering:interrupt()
    end
end

function DroneStateBase:update(dt)

    if self.bLoaded or self.owner == nil then
        return
    end

    if self.steering ~= nil and self.bIsOnSpline then
        if not self.steering:run(dt) then
            self.owner:raiseActive()
        end
    end


end

function DroneStateBase:hubLoaded()
    self.bLoaded = false
end

function DroneStateBase:pathReceived(trianglePath)
end

function DroneStateBase:setIsSaveLoaded()
    self.bLoaded = true
end

function DroneStateBase:goForSpline(targetSpline,direction)
    if self.owner ~= nil and self.owner:getSteering() ~= nil and targetSpline ~= nil then
        self.steering = self.owner:getSteering()
        self.steering:setTargetSpline(targetSpline)
        self.steering:setPathDirection(direction)
        self.steering:getToStartPoint(self.onArrivedToSplineCallback)
    end
end

function DroneStateBase:onAtSpline()
    if self.owner == nil then
        return
    end

    self.bIsOnSpline = true
    self.owner:raiseActive()
end

--- CHARGING STATE CLASS ---
--- DroneChargeState is state where drone will be charged while it docked in hub.
DroneChargeState = {}
DroneChargeState_mt = Class(DroneChargeState,DroneStateBase)
InitObjectClass(DroneChargeState, "DroneChargeState")

--- new creates a new charge state.
function DroneChargeState.new()
    local self = DroneChargeState:superClass().new(DroneChargeState_mt)
    return self
end

function DroneChargeState:enter()
    DroneChargeState:superClass().enter(self)
    if self.owner == nil then
        return
    end

    if self.owner:getCharge() >= 100 then
        self.owner:setDroneIdleState()
        return
    end

end

function DroneChargeState:leave()
    DroneChargeState:superClass().leave(self)
end

function DroneChargeState:update(dt)
    DroneChargeState:superClass().update(self,dt)

    self.owner:raiseActive()

    if self.owner:increaseCharge(dt) then
        self.owner:setDroneIdleState()
    end

end

--- PICKING_UP CLASS ---
--- DronePickingUpState is state handles steering along path to pickup place.
DronePickingUpState = {}
DronePickingUpState_mt = Class(DronePickingUpState,DroneStateBase)
InitObjectClass(DronePickingUpState, "DronePickingUpState")

--- new creates a pickingup state.
function DronePickingUpState.new()
    local self = DronePickingUpState:superClass().new(DronePickingUpState_mt)
    return self
end

function DronePickingUpState:enter()
    DronePickingUpState:superClass().enter(self)
    if self.owner == nil or self.bLoaded then
        return
    end

    if self.owner:getTarget() == nil or self.owner:getTrianglePath() == nil then
        SpecializationUtil.raiseEvent(self.owner,"onTargetLost")
        return
    end

    self:startPickingUp()
end

function DronePickingUpState:leave()
    DronePickingUpState:superClass().leave(self)

end

function DronePickingUpState:hubLoaded()
    DronePickingUpState:superClass().hubLoaded(self)


end

function DronePickingUpState:pathReceived(trianglePath)
    DronePickingUpState:superClass().pathReceived(self,trianglePath)
    self:startPickingUp()
end

function DronePickingUpState:startPickingUp()
    if self.owner == nil or self.owner:getSteering() == nil or self.owner:getTrianglePath() == nil then
        return
    end

    local position = {x=0,y=0,z=0}
    position.x,position.y,position.z = getWorldTranslation(self.owner.rootNode)

    local _,_,_,distanceToPickup,_ = self.owner:getTrianglePath().toPickup:getClosePositionOnSpline(position)
    local _,_,_,distanceToDelivery,_ = self.owner:getTrianglePath().toDelivery:getClosePositionOnSpline(position)

    if distanceToPickup <= distanceToDelivery then
        self:goForSpline(self.owner:getTrianglePath().toPickup,1)
    else
        self:goForSpline(self.owner:getTrianglePath().toDelivery,-1)
    end

end


function DronePickingUpState:update(dt)
    DronePickingUpState:superClass().update(self,dt)

end

function DronePickingUpState:onAtSpline()
    DronePickingUpState:superClass().onAtSpline(self)
    if self.owner == nil or self.owner.spec_drone.pickupManager == nil then
        return
    end

    self.owner:addOnDroneArrivedListener(self.owner.spec_drone.pickupManager.pickupDroneArrivedCallback)
end


--- DELIVERING CLASS ---
--- DronePickingUpState is state handles steering along path to pickup place.
DroneDeliveringState = {}
DroneDeliveringState_mt = Class(DroneDeliveringState,DroneStateBase)
InitObjectClass(DroneDeliveringState, "DroneDeliveringState")

--- new creates a delivering state.
--@param customMt optional custom metatable.
function DroneDeliveringState.new(customMt)
    local self = DroneDeliveringState:superClass().new(customMt or DroneDeliveringState_mt)


    return self
end

function DroneDeliveringState:enter()
    DroneDeliveringState:superClass().enter(self)
    if self.owner == nil or self.bLoaded then
        -- if loaded state into delivering, can't do anything until grid is ready and path received.
        return
    end

    self:startDelivering()
end

function DroneDeliveringState:leave()
    DroneDeliveringState:superClass().leave(self)

end

function DroneDeliveringState:pathReceived(trianglePath)
    DroneDeliveringState:superClass().pathReceived(self,trianglePath)

    self:startDelivering()
end

function DroneDeliveringState:hubLoaded()


    DroneDeliveringState:superClass().hubLoaded(self)
end

function DroneDeliveringState:startDelivering()

    if self.owner.spec_drone.deliveryManager ~= nil then
        self.owner:addOnDroneArrivedListener(self.owner.spec_drone.deliveryManager.deliveryDroneArrivedCallback)
    end

    self:goForSpline(self.owner:getTrianglePath().toDelivery,1)
end


--- RETURNING CLASS ---
--- DroneReturningState is state handles steering along path to hub from delivery place.
DroneReturningState = {}
DroneReturningState_mt = Class(DroneReturningState,DroneStateBase)
InitObjectClass(DroneReturningState, "DroneReturningState")

--- new creates a returning state.
--@param customMt optional custom metatable.
function DroneReturningState.new(customMt)
    local self = DroneReturningState:superClass().new(customMt or DroneReturningState_mt)


    return self
end

function DroneReturningState:enter()
    DroneReturningState:superClass().enter(self)

    if self.owner == nil or self.bLoaded then
        -- if loaded state into cancelled, can't do anything until grid is ready and path received.
        return
    end

    self:startReturning()
end

function DroneReturningState:leave()
    DroneReturningState:superClass().leave(self)

end

function DroneReturningState:pathReceived(trianglePath)
    DroneReturningState:superClass().pathReceived(self,trianglePath)
    self:startReturning()
end

function DroneReturningState:hubLoaded()
    DroneReturningState:superClass().hubLoaded(self)
end

function DroneReturningState:startReturning()

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:noticeDroneReturnal()
    end

    self:goForSpline(self.owner:getTrianglePath().toHub,1)
end

--- PICKUPCANCELLED CLASS ---
--- DronePickupCancelledState state used when pickup pallet not found while going there, will go backwards on the hub -> pickup path.
DronePickupCancelledState = {}
DronePickupCancelledState_mt = Class(DronePickupCancelledState,DroneStateBase)
InitObjectClass(DronePickupCancelledState, "DronePickupCancelledState")

--- new creates a pickup cancelled state.
--@param customMt optional custom metatable.
function DronePickupCancelledState.new(customMt)
    local self = DronePickupCancelledState:superClass().new(customMt or DronePickupCancelledState_mt)


    return self
end

function DronePickupCancelledState:enter()
    DronePickupCancelledState:superClass().enter(self)

    if self.owner == nil or self.bLoaded then
        -- if loaded state into cancelled, can't do anything until grid is ready and path received.
        return
    end

    self:startCancelling()
end

function DronePickupCancelledState:leave()
    DronePickupCancelledState:superClass().leave(self)

end

function DronePickupCancelledState:pathReceived(trianglePath)
    DronePickupCancelledState:superClass().pathReceived(self,trianglePath)
    self:startCancelling()
end

function DronePickupCancelledState:hubLoaded()
    DronePickupCancelledState:superClass().hubLoaded(self)
end

function DronePickupCancelledState:startCancelling()
    if self.owner == nil or self.owner:getSteering() == nil then
        return
    end

    local hubSlot = self.owner:getHubSlot()
    if hubSlot == nil then
        Logging.warning("DronePickupCancelledState:startCancelling: Could not notice hubslot about drone returnal!")
        return
    end

    hubSlot:noticeDroneReturnal()

    local position = {x=0,y=0,z=0}
    position.x,position.y,position.z = getWorldTranslation(self.owner.rootNode)
    local _, distanceToPickup, distanceToDelivery = nil,nil,nil

    if self.owner:getTrianglePath() ~= nil then
        _,_,_,distanceToPickup,_ = self.owner:getTrianglePath().toPickup:getClosePositionOnSpline(position)
        _,_,_,distanceToDelivery,_ = self.owner:getTrianglePath().toDelivery:getClosePositionOnSpline(position)
    end

    if distanceToPickup ~= nil and distanceToDelivery ~= nil and distanceToPickup <= distanceToDelivery and distanceToPickup < 3 then
        self:goForSpline(self.owner:getTrianglePath().toPickup,-1)
    else
        -- need custom temp path to hub as was cancelled while not near or on the toPickup path
        if self.owner.spec_drone.specialPathCreator == nil or self.owner.spec_drone.specialSplineCreator == nil then
            Logging.warning("Drone now stuck, as specialPathCreator or specialSplineCreator was nil in startCancelling!")
            return
        end

        local callback = function(result) self:onPathCreated(result) end
        if not self.owner.spec_drone.specialPathCreator:find(position,hubSlot.hubOwner:getEntrancePosition(),false,true,false,callback,true,5,60000) then
            hubSlot:requestDirectReturn()
        end
    end

end

function DronePickupCancelledState:onPathCreated(pathResult)

    if not pathResult[2] then
        self.owner:getHubSlot():requestDirectReturn()
        return
    end

    local callback = function(spline) self:onSplineCreated(spline) end
    self.owner.spec_drone.specialSplineCreator:createSpline(pathResult[1],callback,nil,nil,nil)

end

function DronePickupCancelledState:onSplineCreated(spline)
    if spline == nil then
        self.owner:getHubSlot():requestDirectReturn()
        return
    end

    self:goForSpline(spline,1)
end



--- UNDOCKING CLASS ---
--- DroneUnDockingState used when drone leaves hub, if happens to game load into this state (hubLoaded called), will return drone back to hub from start.
DroneUnDockingState = {}
DroneUnDockingState_mt = Class(DroneUnDockingState,DroneStateBase)
InitObjectClass(DroneUnDockingState, "DroneUnDockingState")

--- new creates a undocking state.
function DroneUnDockingState.new()
    local self = DroneUnDockingState:superClass().new(DroneUnDockingState_mt)
    return self
end

function DroneUnDockingState:enter()
    DroneUnDockingState:superClass().enter(self)
    if self.owner == nil or self.bLoaded then
        return
    end

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestUndocking()
    end

end

function DroneUnDockingState:leave()
    DroneUnDockingState:superClass().leave(self)
end

--- hubLoaded is called for a state if it happens to be the loaded state when hub reconnects drones after load.
-- the undocking state will just directly request to dock the drone back.
function DroneUnDockingState:hubLoaded()
    DroneUnDockingState:superClass().hubLoaded(self)

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestDirectReturn()
    end

end



--- DOCKING CLASS ---
--- DroneDockingState used when drone comes to hub, if happens to game load into this state (hubLoaded called), will skip "flying" it to hub and will just position is as done.
DroneDockingState = {}
DroneDockingState_mt = Class(DroneDockingState,DroneStateBase)
InitObjectClass(DroneDockingState, "DroneDockingState")

--- new creates a docking state.
function DroneDockingState.new()
    local self = DroneDockingState:superClass().new(DroneDockingState_mt)
    return self
end

function DroneDockingState:enter()
    DroneDockingState:superClass().enter(self)
    if self.owner == nil or self.bLoaded then
        return
    end

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestDocking()
    end

end


function DroneDockingState:hubLoaded()
    DroneDockingState:superClass().hubLoaded(self)


    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestDirectReturn()
    end

end




