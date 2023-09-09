

---@class PickupDeliveryManager.
--Custom object class for adding to a pickup or delivery point.
-- Handles looking out for delivery work to send for drones to come and pickup.
PickupDeliveryManager = {}
PickupDeliveryManager_mt = Class(PickupDeliveryManager,Object)
InitObjectClass(PickupDeliveryManager, "PickupDeliveryManager")

--- new creates a new PickupDeliveryManager object.
--@param owner is the placeable which this manager belongs in.
--@param isServer if owner is server.
--@param isClient if owner is client.
function PickupDeliveryManager.new(owner,isServer,isClient)
    local self = Object.new(isServer,isClient, PickupDeliveryManager_mt)
    self.owner = owner
    self.pickupDrones = {}
    self.loadedDrones = {}
    self.readyPickupDrones = {}
    self.deliveryDrones = {}
    self.pickupHandler = DroneActionManager.new(self,isServer,isClient,true)
    self.deliveryHandler = DroneActionManager.new(self,isServer,isClient,true)
    self.isDeleted = false
    self.pickupCheckTime = 10 -- in seconds how often to check for pallets
    self.requiredFillPercentage = 0.5 -- how much filllevel does pallets require to be picked up
    self.attachSafeOffset = 0.1
    self.currentTime = 0
    self.bIsFirstTime = true -- used to checkup any loaded pallets to get connected back to the drones they were suppose to be picked up by.
    self.palletsNeedInfo = {}
    self.palletsWaiting = {}
    self.palletsScheduled = {}
    self.collisionMask = CollisionFlag.STATIC_WORLD + CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TRIGGER_VEHICLE + CollisionFlag.FILLABLE
    self:setPickupPosition()
    self.droneReturnedCallback = function(drone)
            self.readyPickupDrones[drone] = true
        end

    local callback = function(owner,superFunc) self:canOwnerBeSold(owner,superFunc) end
    self.owner.canBeSold = Utils.overwrittenFunction(self.owner.canBeSold,callback)
    return self
end

function PickupDeliveryManager:canOwnerBeSold(owner,superFunc)

    if self.isDeleted then
        local bSellable, message = superFunc(owner)
        return bSellable,message
    end

    return false, g_i18n:getText("droneManager_unlinkBeforeSell")
end

function PickupDeliveryManager:delete()

    if self.isDeleted then
        return
    end

    self.isDeleted = true

    self.pickupDrones = nil
    self.deliveryDrones = nil

    if self.pickupHandler ~= nil then
        self.pickupHandler:delete()
        self.pickupHandler = nil
    end

    if self.deliveryHandler ~= nil then
        self.deliveryHandler:delete()
        self.deliveryHandler = nil
    end


    PickupDeliveryManager:superClass().delete(self)
end


function PickupDeliveryManager:addPickupDrone(drone,hubSlot,fillTypeNode,bPriceLimit,priceLimit,deliveryPlaceable)
    if drone == nil then
        return
    end

    local droneInfo = {}
    droneInfo.hubSlot = hubSlot
    droneInfo.fillTypeNode = fillTypeNode
    droneInfo.bPriceLimit = bPriceLimit
    droneInfo.priceLimit = priceLimit
    droneInfo.deliveryPlaceable = deliveryPlaceable
    droneInfo.drone = drone
    self.pickupDrones[drone] = droneInfo
    drone:addOnDroneReturnedListener(self.droneReturnedCallback)

    -- if adding a drone which is in picking up state means that it is loaded drone state
    if drone:isPickingUp() then
        self.loadedDrones[drone] = true
    else
        self.readyPickupDrones[drone] = true
    end

    self:raiseActive()
end

function PickupDeliveryManager:updatePickupDrone(drone,fillTypeNode,bPriceLimit,priceLimit,deliveryPlaceable)
    if self.pickupDrones == nil or self.pickupDrones[drone] == nil then
        return
    end

    local droneInfo = self.pickupDrones[drone]
    droneInfo.fillTypeNode = fillTypeNode
    droneInfo.bPriceLimit = bPriceLimit
    droneInfo.priceLimit = priceLimit
    droneInfo.deliveryPlaceable = deliveryPlaceable

end

--- removeDrone called to remove a drone from the manager.
--@param drone is the drone object table to be removed.
--@return true if no more drones are connected to this manager.
function PickupDeliveryManager:removeDrone(drone)
    if drone == nil then
        return false
    end

    drone:removeOnDroneReturnedListener(self.droneReturnedCallback)
    self.pickupDrones[drone] = nil
    self.readyPickupDrones[drone] = nil
    self.deliveryDrones[drone] = nil
    if next(self.pickupDrones) == nil and next(self.deliveryDrones) == nil then
        self:delete()
        return true
    elseif next(self.pickupDrones) == nil then
        self.currentTime = 0
    end

    return false
end

function PickupDeliveryManager:addDeliveryDrone(drone,hubSlot)
    self.deliveryDrones[drone] = hubSlot
end

function PickupDeliveryManager:removeDeliveryDrone(drone)
    self.deliveryDrones[drone] = nil
    if next(self.pickupDrones) == nil and next(self.deliveryDrones) == nil then
        self:delete()
    end

end

function PickupDeliveryManager:update(dt)

    if self.pickupDrones ~= nil and next(self.pickupDrones) ~= nil then
        self:raiseActive()
    else
        return
    end

    self.currentTime = self.currentTime + (dt / 1000)
    if self.currentTime > self.pickupCheckTime then
        self:checkPickup()
    end
end

function PickupDeliveryManager:markScheduledUnchecked()

    for pallet,target in pairs(self.palletsScheduled) do
        target.checked = false
    end

end


function PickupDeliveryManager:checkPickup()
    self.currentTime = 0

    self:markScheduledUnchecked()
    overlapBox(self.pickupInfo.position.x,self.pickupInfo.position.y,self.pickupInfo.position.z,self.pickupInfo.rotation.x,self.pickupInfo.rotation.y,self.pickupInfo.rotation.z,
        self.pickupInfo.scale.x,self.pickupInfo.scale.y,self.pickupInfo.scale.z,"pickupOverlapCallback",self,self.collisionMask,true,false,true,false)

    local palletsGone = {}
    for pallet,target in pairs(self.palletsScheduled) do
        if not target.checked then
            SpecializationUtil.raiseEvent(target.drone,"onTargetLost")
            table.insert(palletsGone,pallet)
        end
    end

    for _,pallet in ipairs(palletsGone) do
        self.palletsScheduled[pallet] = nil
    end

    -- first time, combine loaded drones to nearest pallets
    if self.bIsFirstTime then
        self.bIsFirstTime = false
        self:reConnectLoadedDrones()
    end


    local scheduledPallets, scheduledDrones = self:requestDrones(self.readyPickupDrones)

    for _,pallet in ipairs(scheduledPallets) do
        self.palletsWaiting[pallet] = nil
    end

    for _,drone in ipairs(scheduledDrones) do
        self.readyPickupDrones[drone] = nil
    end



end

function PickupDeliveryManager:reConnectLoadedDrones()
    if self.loadedDrones == nil or next(self.loadedDrones) == nil then
        return
    end

    local scheduledPallets,scheduledDrones = self:requestDrones(self.loadedDrones)

    for _,pallet in ipairs(scheduledPallets) do
        self.palletsWaiting[pallet] = nil
    end

    for _,drone in ipairs(scheduledDrones) do
        self.loadedDrones[drone] = nil
    end

    for drone,_ in pairs(self.loadedDrones) do
        SpecializationUtil.raiseEvent(drone,"onTargetLost")
    end

end


function PickupDeliveryManager:pickupOverlapCallback(objectId)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return
    end

    local bValid = self:checkObjectValidity(object,objectId)


    if bValid then
            if self.palletsWaiting[object] == nil and self.palletsScheduled[object] == nil then
                -- new pallet need to get connection height
                print("new pallet found")
                self.palletsNeedInfo[object] = object
                local x,y,z = getWorldTranslation(objectId)
                raycastAll(x,y + 3,z,0,-1,0,"pickupHeightCheckCallback",6,self,self.collisionMask)
            elseif self.palletsScheduled[object] ~= nil then
                self.palletsScheduled[object].checked = true
            end
        end

    return true
end

function PickupDeliveryManager:checkObjectValidity(object,objectId)
    local bValid = false
    if object == nil then
        return bValid
    end

    local rigidBodyType = getRigidBodyType(objectId)

    if  rigidBodyType == RigidBodyType.DYNAMIC and (object:isa(Vehicle) and PickupDeliveryHelper.isSupportedObject(object) and object.spec_fillUnit ~= nil) or object:isa(Bale) then


        if object.spec_fillUnit ~= nil and object.spec_fillUnit.fillUnits[1] ~= nil then

            local requiredCapacity = object.spec_fillUnit.fillUnits[1].capacity * self.requiredFillPercentage
            if object.spec_fillUnit.fillUnits[1].fillLevel >= requiredCapacity then
                bValid = true
            end

        elseif object:isa(Bale) then
            bValid = true
        end
    end

    return bValid
end

function PickupDeliveryManager:pickupHeightCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return
    end

    if self.palletsNeedInfo[object] ~= nil then
        self.palletsNeedInfo[object] = nil
        self:addNewPallet(object,objectId,y)
        return false
    end

    return true
end

function PickupDeliveryManager:setPickupPosition()
    self.pickupInfo = PickupDeliveryHelper.getPickupArea(self.owner)
end

function PickupDeliveryManager:addNewPallet(object,objectId,y)
    if object == nil or y == nil then
        return
    end

    y = y + self.attachSafeOffset

    local target = {}
    target.pallet = object

    local _,posY,_ = getWorldTranslation(objectId)

    target.heightOffset = y - posY
    target.checked = false
    target.bHook = false

    -- special case for bigbag, drone uses hook to grab.
    if object.spec_bigBag then
        target.bHook = true
    end

    if object:isa(Bale) then
        target.fillType = object.fillType
    elseif object.spec_fillUnit ~= nil and object.spec_fillUnit.fillUnits[1] ~= nil then
        target.fillType = object.spec_fillUnit.fillUnits[1].fillType
    end

    self.palletsWaiting[object] = target

end

function PickupDeliveryManager:requestDrones(drones)
    local scheduledPallets = {}
    local scheduledDrones = {}

    if drones == nil or next(drones) == nil then
        return scheduledPallets, scheduledDrones
    end

    for drone,_ in pairs(drones) do
        local droneInfo = self.pickupDrones[drone]
        for pallet,target in pairs(self.palletsWaiting) do

            local bValid = self:checkDronePickupValidity(droneInfo,target)

            if bValid then
                table.insert(scheduledPallets,pallet)
                table.insert(scheduledDrones,drone)
                self.palletsScheduled[pallet] = target
                target.drone = drone
                SpecializationUtil.raiseEvent(drone,"onTargetReceived",target)
                print("was valid")
                break
            end
        end
    end

    return scheduledPallets, scheduledDrones
end

function PickupDeliveryManager:requestPickup(drone)



end

function PickupDeliveryManager:checkDronePickupValidity(droneInfo,target)
    local bValid = true

    if not droneInfo.drone:isAvailableForPickup() and self.loadedDrones[droneInfo.drone] == nil then -- check if drone can go pick up one
        bValid = false
    end

    if droneInfo.fillTypeNode ~= target.fillType and droneInfo.fillTypeNode ~= FillType.UNKNOWN then -- check if drone has correct filltype to pickup, UNKNOWN == ANY FILLTYPE
        print("fill type did not match")
        local requiredFillType = g_fillTypeManager.indexToFillType[droneInfo.fillTypeNode]
        local availableFillType = g_fillTypeManager.indexToFillType[target.fillType]
        print("name of required filltype : " .. tostring(requiredFillType.name))
        print("name of available filltype : " .. tostring(availableFillType.name))

        bValid = false
    end

    if droneInfo.bPriceLimit and droneInfo.priceLimit > PickupDeliveryHelper.getSellPrice(droneInfo.deliveryPlaceable,target.fillType) then -- finally check if has any price limit
        print("price limit was not reached")
        bValid = false
    end

    return bValid
end

