--[[
This file is part of Drone delivery mod (https://github.com/DennisB97/FS22DroneDelivery)

Copyright (c) 2023 Dennis B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this mod and associated files, to copy, modify ,subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This mod is for personal use only and is not affiliated with GIANTS Software.
Sharing or distributing FS22_DroneDelivery mod in any form is prohibited except for the official ModHub (https://www.farming-simulator.com/mods).
Selling or distributing FS22_DroneDelivery mod for a fee or any other form of consideration is prohibited by the game developer's terms of use and policies,
Please refer to the game developer's website for more information.
]]

--- Drone states only exists on the server---
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

--- init gives the drone to the state.
--@param inOwner the drone owner.
--@param isServer if is server.
--@param isClient if is client.
function DroneStateBase:init(inOwner,isServer,isClient)
    self.owner = inOwner
    self.isServer = isServer
    self.isClient = isClient
end

--- enter called when entering state.
function DroneStateBase:enter()
end

--- leave called when leaving state, basestate interrupts the steering when left.
function DroneStateBase:leave()
    self.bIsOnSpline = false
    if self.steering ~= nil then
        self.steering:interrupt()
    end
end

--- update forwarded from owner when active.
-- basestate handles forwarding to drone steering.
--@param dt is deltatime in ms.
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

--- hubLoaded called from owner when hub was loaded, that is when first update runs ion the dronehub.
function DroneStateBase:hubLoaded()
    self.bLoaded = false
end

--- pathReceived called from owner when a path has been generated.
--@param trianglePath is the paths that were generated.
function DroneStateBase:pathReceived(trianglePath)
end

--- setIsSaveLoaded will be called from owner on load to mark the current state as loaded state.
function DroneStateBase:setIsSaveLoaded()
    self.bLoaded = true
end

--- goForSpline will request the drone steering to go to the nearest point on given spline path.
--@param targetSpline to which spline to go to.
--@param direction which direction along the spline.
function DroneStateBase:goForSpline(targetSpline,direction)
    if self.owner ~= nil and self.owner:getSteering() ~= nil and targetSpline ~= nil then
        self.steering = self.owner:getSteering()
        self.steering:setTargetSpline(targetSpline)
        self.steering:setPathDirection(direction)
        self.steering:getToStartPoint(self.onArrivedToSplineCallback)
    end
end

--- onAtSpline is callback when drone has arrived onto the spline.
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

--- enter when entered the charging checks if actually requires charging or not.
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

--- leave no special clean up on this state.
function DroneChargeState:leave()
    DroneChargeState:superClass().leave(self)
end

--- update will mark drone as active and proceed to increase drone charge each update if not full.
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

--- enter the picking up state if loaded state will return, but if has a target and path will start the pickup process.
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

--- leave no special clean up on this state.
function DronePickingUpState:leave()
    DronePickingUpState:superClass().leave(self)
end

--- hubLoaded no special on this state, forward to base function.
function DronePickingUpState:hubLoaded()
    DronePickingUpState:superClass().hubLoaded(self)
end

--- pathReceived when path received for pickup state will start the process of going to pickup.
function DronePickingUpState:pathReceived(trianglePath)
    DronePickingUpState:superClass().pathReceived(self,trianglePath)
    self:startPickingUp()
end

--- startPickingUp called to prepare to pickup, compares the distance to toPickup and toDelivery splines,
-- as picking up can happen on either along the toPickup or toDelivery, based on if drone is regoing to pickup from the delivery placeable after delivering.
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

--- update no special stuff on this state, calls base function.
function DronePickingUpState:update(dt)
    DronePickingUpState:superClass().update(self,dt)
end

--- onAtSpline when arrived to spline calls to add manager's listener to the drone so manager knows when drone has arrived to pickup location.
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

--- enter delivering state if loaded will return but else will start delivering process.
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

--- pathReceived starts delivering when path is received.
function DroneDeliveringState:pathReceived(trianglePath)
    DroneDeliveringState:superClass().pathReceived(self,trianglePath)
    self:startDelivering()
end

--- hubLoaded nothing special in this state.
function DroneDeliveringState:hubLoaded()
    DroneDeliveringState:superClass().hubLoaded(self)
end

--- startDelivering adds the deliverymanager's callback to the drone arrived listener, so manager knows when drone arrives to delivery location.
-- and starts to go to the toDelivery spline beginning.
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

--- enter the returning state will return if loaded otherwise will start the returning process.
function DroneReturningState:enter()
    DroneReturningState:superClass().enter(self)

    if self.owner == nil or self.bLoaded then
        -- if loaded state into cancelled, can't do anything until grid is ready and path received.
        return
    end

    self:startReturning()
end

--- leave no special clean up on this state.
function DroneReturningState:leave()
    DroneReturningState:superClass().leave(self)
end

--- pathReceived starts the returning process.
function DroneReturningState:pathReceived(trianglePath)
    DroneReturningState:superClass().pathReceived(self,trianglePath)
    self:startReturning()
end

--- hubLoaded nothing special in this state, calls the base class function.
function DroneReturningState:hubLoaded()
    DroneReturningState:superClass().hubLoaded(self)
end

--- startReturning will add the hub's callback to the drone arrive listener so that hub knows when docking should start.
-- proceeds to go to the toHub spline.
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

--- enter the cancelled state if loaded will just return otherwise will start the cancelling process.
function DronePickupCancelledState:enter()
    DronePickupCancelledState:superClass().enter(self)

    if self.owner == nil or self.bLoaded then
        -- if loaded state into cancelled, can't do anything until grid is ready and path received.
        return
    end

    self:startCancelling()
end

--- --- leave no special clean up on this state.
function DronePickupCancelledState:leave()
    DronePickupCancelledState:superClass().leave(self)
end

--- pathReceived will start the cancelling process.
function DronePickupCancelledState:pathReceived(trianglePath)
    DronePickupCancelledState:superClass().pathReceived(self,trianglePath)
    self:startCancelling()
end

--- hubLoaded no special in this state, calls the base class function.
function DronePickupCancelledState:hubLoaded()
    DronePickupCancelledState:superClass().hubLoaded(self)
end

--- startCancelling will give notice to hub about drone returning, if doesn't have the path or isn't near the toPickup spline will create a new spline from current position to hub.
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

--- onPathCreated callback from the path has been found to hub from current drone position.
function DronePickupCancelledState:onPathCreated(pathResult)

    -- if wasn't able to create a path for some reason will teleport the drone back
    if not pathResult[2] then
        self.owner:getHubSlot():requestDirectReturn()
        return
    end

    local callback = function(spline) self:onSplineCreated(spline) end
    self.owner.spec_drone.specialSplineCreator:createSpline(pathResult[1],callback,nil,nil,nil)

end

--- onSplineCreated callback from when the path has been created into a spline, if valid proceeds to go towards spline.
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

--- enter undocking state if loaded will return, else will request undocking from the hub.
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

--- leave no special clean up on this state.
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

--- enter the docking state if loaded will just return else will request docking from the hub.
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

--- if docking state was a loaded state then will proceed to teleport drone back to the hub.
function DroneDockingState:hubLoaded()
    DroneDockingState:superClass().hubLoaded(self)

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestDirectReturn()
    end

end




