

---@class PlaceablesPointManager.
--Custom object class for adding to a pickup or delivery point table.
-- Handles tracking pallets to pickup, moving drone to accurate location when delivering or picking up.
PlaceablesPointManager = {}
PlaceablesPointManager_mt = Class(PlaceablesPointManager,Object)
InitObjectClass(PlaceablesPointManager, "PlaceablesPointManager")

--- new creates a new PlaceablesPointManager object.
function PlaceablesPointManager.new(isServer,isClient)
    local self = Object.new(isServer,isClient, PlaceablesPointManager_mt)

    return self
end


