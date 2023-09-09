
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
end

function DroneStateBase:update(dt)
end

function DroneStateBase:hubLoaded()
end

function DroneStateBase:pathReceived(trianglePath)
end

function DroneStateBase:setIsSaveLoaded()
    self.bLoaded = true
end

--- CHARGING STATE CLASS ---
--- DroneChargeState is state where drone will be charged while it docked in hub.
DroneChargeState = {}
DroneChargeState_mt = Class(DroneChargeState,DroneStateBase)
InitObjectClass(DroneChargeState, "DroneChargeState")

--- new creates a new charge state.
--@param customMt optional custom metatable.
function DroneChargeState.new(customMt)
    local self = DroneChargeState:superClass().new(customMt or DroneChargeState_mt)


    return self
end


--- PICKING_UP CLASS ---
--- DronePickingUpState is state handles steering along path to pickup place.
DronePickingUpState = {}
DronePickingUpState_mt = Class(DronePickingUpState,DroneStateBase)
InitObjectClass(DronePickingUpState, "DronePickingUpState")

--- new creates a pickingup state.
--@param customMt optional custom metatable.
function DronePickingUpState.new(customMt)
    local self = DronePickingUpState:superClass().new(customMt or DronePickingUpState_mt)


    return self
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


--- EMERGENCY UNLINK CLASS ---
--- DroneEmergencyUnlinkState state used when pathfinding issues to,from hub. Will handles moving drone back to store.
DroneEmergencyUnlinkState = {}
DroneEmergencyUnlinkState_mt = Class(DroneEmergencyUnlinkState,DroneStateBase)
InitObjectClass(DroneEmergencyUnlinkState, "DroneEmergencyUnlinkState")

--- new creates a emergency unlink state.
--@param customMt optional custom metatable.
function DroneEmergencyUnlinkState.new(customMt)
    local self = DroneEmergencyUnlinkState:superClass().new(customMt or DroneEmergencyUnlinkState_mt)


    return self
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



--- UNDOCKING CLASS ---
--- DroneUnDockingState used when drone leaves hub, if happens to game load into this state (hubLoaded called), will return drone back to hub from start.
DroneUnDockingState = {}
DroneUnDockingState_mt = Class(DroneUnDockingState,DroneStateBase)
InitObjectClass(DroneUnDockingState, "DroneUnDockingState")

--- new creates a undocking state.
--@param customMt optional custom metatable.
function DroneUnDockingState.new(customMt)
    local self = DroneUnDockingState:superClass().new(customMt or DroneUnDockingState_mt)


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
    self.bLoaded = false

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
--@param customMt optional custom metatable.
function DroneDockingState.new(customMt)
    local self = DroneDockingState:superClass().new(customMt or DroneDockingState_mt)




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
    self.bLoaded = false

    local hubSlot = self.owner:getHubSlot()
    if hubSlot ~= nil then
        hubSlot:requestDirectReturn()
    end

end




