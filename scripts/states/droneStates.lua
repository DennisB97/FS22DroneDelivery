
--- BASE SYSTEM STATE CLASS ---
DroneStateBase = {}
DroneStateBase_mt = Class(DroneStateBase)
InitObjectClass(DroneStateBase, "DroneStateBase")

function DroneStateBase.new(customMt)
    local self = setmetatable({}, customMt or DroneStateBase_mt)
    self.owner = nil
    self.isServer = nil
    self.isClient = nil
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

--- PREPARE ARRIVE SYSTEM STATE CLASS ---
--- BirdSystemPrepareArriveState is state where the feeder waits of random hours until it tries then to send the birds to fly towards feeder.
BirdSystemPrepareArriveState = {}
BirdSystemPrepareArriveState_mt = Class(BirdSystemPrepareArriveState,DroneStateBase)
InitObjectClass(BirdSystemPrepareArriveState, "BirdSystemPrepareArriveState")

--- new creates a new prepare arrive state.
--@param customMt optional custom metatable.
function BirdSystemPrepareArriveState.new(customMt)
    local self = BirdSystemPrepareArriveState:superClass().new(customMt or BirdSystemPrepareArriveState_mt)
    self.targetHours = -1
    self.currentHours = 0
    return self
end







