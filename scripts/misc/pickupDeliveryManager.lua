

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
    self.pickupHandler:register(true)
    self.deliveryHandler = DroneActionManager.new(self,isServer,isClient,true)
    self.deliveryHandler:register(true)
    self.isDeleted = false
    self.pickupCheckTime = 10 -- in seconds how often to check for pallets
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

    self.pickupDroneArrivedCallback = function(drone) self:onPickupDroneArrive(drone) end
    self.deliveryDroneArrivedCallback = function(drone) self:onDeliveryDroneArrive(drone) end

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


function PickupDeliveryManager:addPickupDrone(drone,hubSlot,config)
    if drone == nil then
        return
    end

    if self.pickupDrones[drone] == nil then
        local droneInfo = {}
        self.pickupDrones[drone] = droneInfo
        droneInfo.hubSlot = hubSlot
        droneInfo.drone = drone
        drone:addOnDroneReturnedListener(self.droneReturnedCallback)

        -- if adding a drone which is in picking up state means that it is loaded drone state
        if drone:isPickingUp() then
            self.loadedDrones[drone] = true
        elseif drone:isDroneAtHub() then
            self.readyPickupDrones[drone] = true
        end
    end

    self:updatePickupDrone(drone,config)

    self:raiseActive()
end

function PickupDeliveryManager:updatePickupDrone(drone,config)
    if self.pickupDrones == nil or self.pickupDrones[drone] == nil then
        return
    end

    local droneInfo = self.pickupDrones[drone]
    droneInfo.fillTypes = config.fillTypes
    droneInfo.fillTypeNode = config.fillTypes[config.fillTypeIndex]
    droneInfo.bPriceLimit = config.bPriceLimit
    droneInfo.priceLimit = config.priceLimit
    droneInfo.fillLimit = (config.fillLimitIndex * 10) / 100 -- get in decimal 0.1-1 range so can compare required filllevels
end

--- removeDrone called to remove a drone from the manager.
--@param drone is the drone object table to be removed.
--@return true if no more drones are connected to this manager.
function PickupDeliveryManager:removeDrone(drone)
    if drone == nil then
        return false
    end

    drone:removeOnDroneArrivedListener(self.pickupDroneArrivedCallback)
    drone:removeOnDroneReturnedListener(self.droneReturnedCallback)
    self.pickupDrones[drone] = nil
    self.readyPickupDrones[drone] = nil
    self.deliveryDrones[drone] = nil
    self.loadedDrones[drone] = nil
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

--@return true if no more drones are connected to this manager.
function PickupDeliveryManager:removeDeliveryDrone(drone)
    self.deliveryDrones[drone] = nil
    if next(self.pickupDrones) == nil and next(self.deliveryDrones) == nil then
        self:delete()
        return true
    end

    return false
end

function PickupDeliveryManager:update(dt)

    DebugUtil.drawOverlapBox(self.pickupInfo.position.x, self.pickupInfo.position.y, self.pickupInfo.position.z, self.pickupInfo.rotation.x, self.pickupInfo.rotation.y, self.pickupInfo.rotation.z, self.pickupInfo.scale.x, self.pickupInfo.scale.y, self.pickupInfo.scale.z, 0, 0, 1)

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

function PickupDeliveryManager:markPalletsUnchecked()

    for pallet,target in pairs(self.palletsScheduled) do
        target.checked = false
    end

    for pallet, target in pairs(self.palletsWaiting) do
        target.checked = false
    end

end


function PickupDeliveryManager:checkPickup()
    self.currentTime = 0

    self:markPalletsUnchecked()
    overlapBox(self.pickupInfo.position.x,self.pickupInfo.position.y,self.pickupInfo.position.z,self.pickupInfo.rotation.x,self.pickupInfo.rotation.y,self.pickupInfo.rotation.z,
        self.pickupInfo.scale.x,self.pickupInfo.scale.y,self.pickupInfo.scale.z,"pickupOverlapCallback",self,self.collisionMask,true,false,true,false)

    local palletsGone = {}
    for pallet,target in pairs(self.palletsScheduled) do
        if not target.checked then
            table.insert(palletsGone,target)
        end
    end

    for _,target in ipairs(palletsGone) do
        self:droneLostTarget(target.drone)
    end

    palletsGone = {}
    for pallet, target in pairs(self.palletsWaiting) do
        if not target.checked then
            table.insert(palletsGone,pallet)
        end
    end

    for _,pallet in ipairs(palletsGone) do
        self.palletsWaiting[pallet] = nil
    end

    -- first time, combine loaded drones to pallets
    if self.bIsFirstTime then
        self.bIsFirstTime = false
        self:reConnectLoadedDrones()
    end

    self:requestDrones(self.readyPickupDrones)

end

function PickupDeliveryManager:reConnectLoadedDrones()
    if self.loadedDrones == nil or next(self.loadedDrones) == nil then
        return
    end

    self:requestDrones(self.loadedDrones)

    for drone,_ in pairs(self.loadedDrones) do
        self:droneLostTarget(drone)
    end

end


function PickupDeliveryManager:pickupOverlapCallback(objectId)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    local bValid = self:checkObjectValidity(object,objectId)


    if bValid then
        if self.palletsWaiting[object] == nil and self.palletsScheduled[object] == nil and not object.bDroneCarried then
            -- new pallet need to get connection offset height
            self.palletsNeedInfo[object] = object
            local x,y,z = getWorldTranslation(objectId)
            raycastAll(x,y + 3,z,0,-1,0,"pickupHeightCheckCallback",6,self,self.collisionMask)
        elseif self.palletsScheduled[object] ~= nil then
            self.palletsScheduled[object].checked = true
        elseif self.palletsWaiting[object] ~= nil then
            self.palletsWaiting[object].checked = true
        end
    end

    return true
end


function PickupDeliveryManager:verifyPalletLocation(pallet)

    self.checkingPallet = pallet
    self.bCheckingPalletValid = false
    overlapBox(self.pickupInfo.position.x,self.pickupInfo.position.y,self.pickupInfo.position.z,self.pickupInfo.rotation.x,self.pickupInfo.rotation.y,self.pickupInfo.rotation.z,
        self.pickupInfo.scale.x,self.pickupInfo.scale.y,self.pickupInfo.scale.z,"verifyPalletLocationCallback",self,self.collisionMask,true,false,true,false)

    return self.bCheckingPalletValid
end

function PickupDeliveryManager:verifyPalletLocationCallback(objectId)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    local bValid = self:checkObjectValidity(object,objectId)

    if bValid and object == self.checkingPallet then
        self.bCheckingPalletValid = true
        return false
    end

    return true
end

function PickupDeliveryManager:checkObjectValidity(object,objectId)
    if object == nil then
        return false
    end

    local bValid = false

    local rigidBodyType = getRigidBodyType(objectId)

    if  rigidBodyType == RigidBodyType.DYNAMIC and (object:isa(Vehicle) and PickupDeliveryHelper.isSupportedObject(object) and object.spec_fillUnit ~= nil) or object:isa(Bale) then
        bValid = true
    end

    return bValid
end

function PickupDeliveryManager:pickupHeightCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
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


    local target = {}
    target.pallet = object
    target.objectId = objectId

    local _,posY,_ = getWorldTranslation(objectId)

    target.checked = true
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

    y = y + PickupDeliveryHelper.getAttachOffset(object,target.fillType)
    target.heightOffset = y - posY


    self.palletsWaiting[object] = target
end

function PickupDeliveryManager:requestDrones(drones)
    if drones == nil or next(drones) == nil then
        return false
    end

    local scheduledPallets = {}
    local scheduledDrones = {}

    for drone,_ in pairs(drones) do
        local droneInfo = self.pickupDrones[drone]
        for pallet,target in pairs(self.palletsWaiting) do

            if scheduledPallets[pallet] == nil then

                local bValid = self:checkDronePickupValidity(droneInfo,target)

                if bValid then
                    scheduledPallets[pallet] = true
                    scheduledDrones[drone] = true
                    self.palletsScheduled[pallet] = target
                    target.drone = drone
                    SpecializationUtil.raiseEvent(drone,"onTargetReceived",target)
                    break
                end
            end
        end
    end

    if next(scheduledDrones) == nil then
        return false
    end

    for pallet,_ in pairs(scheduledPallets) do
        self.palletsWaiting[pallet] = nil
    end

    for drone,_ in pairs(scheduledDrones) do
        self.readyPickupDrones[drone] = nil

        if drones ~= self.readyPickupDrones then
            drones[drone] = nil
        end
    end

    return true
end

function PickupDeliveryManager:requestPickup(drone)
    if drone == nil or self.pickupDrones[drone] == nil then
        Logging.warning("PickupDeliveryManager:requestPickup: Trying to request a drone which hasn't been added to manager!")
        return false
    end

    local drones = {}
    drones[drone] = true
    return self:requestDrones(drones)
end

function PickupDeliveryManager:checkDronePickupValidity(droneInfo,target)
    if droneInfo == nil or target == nil then
        Logging.warning("PickupDeliveryManager:checkDronePickupValidity: no valid droneInfo or target given!")
        return false
    end

    local deliveryPlaceable = droneInfo.drone.spec_drone.deliveryManager.owner

    if not droneInfo.drone:isAvailableForPickup() and self.loadedDrones[droneInfo.drone] == nil then -- check if drone can go pick up one
        return false
    end

    if droneInfo.fillTypeNode ~= target.fillType then -- check if drone has correct filltype to pickup, UNKNOWN == ANY FILLTYPE

        local bHadFillType = false
        if droneInfo.fillTypeNode == FillType.UNKNOWN then
            print("fill type is any checking available fill types")
            for _,fillType in ipairs(droneInfo.fillTypes) do
                if fillType == target.fillType then
                    print("had fill type : " .. tostring(fillType))
                    bHadFillType = true
                    break
                end
            end
        end

        if not bHadFillType then
            print("fill type did not match")
            local requiredFillType = g_fillTypeManager.indexToFillType[droneInfo.fillTypeNode]
            local availableFillType = g_fillTypeManager.indexToFillType[target.fillType]
            print("name of required filltype : " .. tostring(requiredFillType.name))
            print("name of available filltype : " .. tostring(availableFillType.name))

            return false
        end
    end

    if droneInfo.bPriceLimit and droneInfo.priceLimit > PickupDeliveryHelper.getSellPrice(deliveryPlaceable,target.fillType) then -- finally check if has any price limit
        print("price limit was not reached")
        return false
    end

    local fillLevel = 99999
    if target.pallet.spec_fillUnit ~= nil and target.pallet.spec_fillUnit.fillUnits[1] ~= nil then

        local requiredCapacity = target.pallet.spec_fillUnit.fillUnits[1].capacity * droneInfo.fillLimit
        if target.pallet.spec_fillUnit.fillUnits[1].fillLevel < (requiredCapacity - 1) then -- -1 for anomalities.
            print("fill limit was not reached")
            return false
        else
            fillLevel = target.pallet.spec_fillUnit.fillUnits[1].fillLevel
        end
    -- bale does not have capacity so as long as is a Bale then fine
    elseif not target.pallet:isa(Bale) then
        return false
    else
        fillLevel = target.pallet.fillLevel
    end

    if not PickupDeliveryHelper.hasStorageAvailability(deliveryPlaceable,target.fillType,fillLevel) then
        print("placeable was full of filltype can't deliver")
        return false
    end


    return true
end

function PickupDeliveryManager:droneLostTarget(drone)
    if drone == nil or self.pickupHandler == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.pickupDroneArrivedCallback)
    self.pickupHandler:interrupt(drone)
    if drone:getTarget() ~= nil then -- might be nil if loaded into pickup state
        self.palletsScheduled[drone:getTarget().pallet] = nil
    end
    SpecializationUtil.raiseEvent(drone,"onTargetLost")
end

function PickupDeliveryManager:onPickupDroneArrive(drone)
    if drone == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.pickupDroneArrivedCallback)
    self:createPickupAction(drone)
end

function PickupDeliveryManager:onDeliveryDroneArrive(drone)
    if drone == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.deliveryDroneArrivedCallback)

    self:createDeliveryAction(drone)
end


function PickupDeliveryManager:createPickupAction(drone)
    if drone == nil or self.pickupHandler == nil then
        return
    end

    local target = drone:getTarget()
    if target == nil then
        drone:changeState(drone.spec_drone.EDroneStates.PICKUPCANCELLED)
        return
    end

    local droneX, droneY, droneZ = getWorldTranslation(drone.rootNode)
    local targetX, targetY, targetZ = getWorldTranslation(target.objectId)

    local targetVector = {x=targetX - droneX,y = 0, z = targetZ - droneZ}
    local targetDirection = {x=0,y=0,z=0}
    targetDirection.x, targetDirection.y, targetDirection.z = MathUtil.vector3Normalize(targetVector.x,targetVector.y,targetVector.z)

    local distance = MathUtil.vector3Length(targetVector.x,targetVector.y,targetVector.z)
    local abovePalletPosition = {x = droneX + (targetDirection.x * distance),y = droneY + (targetDirection.y * distance), z = droneZ + (targetDirection.z * distance)}

    local finalTargetDirection = {x=0,y=0,z=0}
    finalTargetDirection.x, finalTargetDirection.y, finalTargetDirection.z = localDirectionToWorld(target.objectId,0,0,1)

    local endingCallback = function(drone)

            if drone:getTarget() ~= nil and self:verifyPalletLocation(drone:getTarget().pallet) then

                if drone:pickUp() then
                    self.palletsScheduled[drone:getTarget().pallet] = nil
                    if self.owner.spec_customDeliveryPickupPoint ~= nil then
                        self.owner:setAvailablePosition({x=targetX,y=targetY,z = targetZ})
                    end
                    drone:changeState(drone.spec_drone.EDroneStates.DELIVERING)
                else
                    self:droneLostTarget(drone)
                end

            else
                self:droneLostTarget(drone)
            end

        end


    local startingCallback = function(drone)
            if drone:getTarget().bHook then
                drone:useAnimation("hookAnimation",1,0,nil,nil)
            else
                drone:useAnimation("palletHolderAnimation",1,0,nil,nil)
            end
        end


    local downToPallet = DroneActionPhase.new(drone,{x=targetX,y=targetY + target.heightOffset,z = targetZ} ,nil,0.8,nil,nil,endingCallback,nil,nil)
    local rotateAgainstPallet = DroneActionPhase.new(drone,nil ,finalTargetDirection,nil,10,nil,nil,nil,downToPallet)
    local toAbovePallet = DroneActionPhase.new(drone,abovePalletPosition,nil,0.8,nil,nil,nil,nil,rotateAgainstPallet)
    local pickAction = DroneActionPhase.new(drone,nil,targetDirection,nil,10,startingCallback,nil,nil,toAbovePallet)

    self.pickupHandler:addDrone(pickAction)
end


function PickupDeliveryManager:createDeliveryAction(drone)
    if self.owner == nil or drone == nil or self.deliveryHandler == nil then
        return
    end

    local target = drone:getTarget()
    if target == nil then
        drone:changeState(drone.spec_drone.EDroneStates.RETURNING)
        return
    end

    local droneX, droneY,droneZ = getWorldTranslation(drone.rootNode)
    self.distanceToBottom = 0

    -- need to check entity if valid as pallet might have been consumed by now
    if entityExists(target.objectId) then
        drone:adjustCarriedPallet(false,target.pallet)
        local palletX, palletY,palletZ = getWorldTranslation(target.objectId)
        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,palletX,palletY,palletZ)
        self.currentDeliverDrone = drone
        raycastAll(palletX,terrainHeight,palletZ,0,1,0,"pickupGroundCheckCallback",5,self,self.collisionMask + CollisionFlag.PLAYER)
    end

    local endFunction = function(drone)
            if drone ~= nil then
                drone:drop()

                local pickupManager = drone.spec_drone.pickupManager

                local bMore = false

                if pickupManager ~= nil and drone:hasEnoughCharge() then
                    -- need to override drone is available as it returns only true if it is at the hub, but is now available temprorarily
                    local originalFunction = drone.isAvailableForPickup
                    drone.isAvailableForPickup = function() return true end
                    bMore = pickupManager:requestPickup(drone)
                    drone.isAvailableForPickup = originalFunction
                end

                if not bMore then
                    drone:changeState(drone.spec_drone.EDroneStates.RETURNING)
                end
            end
        end


    local startAction = nil
    -- special case for custom deliverypickup point spec
    if self.owner.spec_customDeliveryPickupPoint ~= nil then

        local deliverPosition, bFull = self.owner:getAvailablePosition()
        if deliverPosition ~= nil then
            -- if full drone does not go downwards and push things into the ground.
            if bFull then
                self.distanceToBottom = 0
            end

            local deliverDirection = {x=0,y=0,z=0}
            deliverDirection.x, deliverDirection.y, deliverDirection.z = MathUtil.vector3Normalize(deliverPosition.x - droneX, deliverPosition.y - droneY, deliverPosition.z - droneZ)

            local toDrop = DroneActionPhase.new(drone,{x=deliverPosition.x,y=droneY - self.distanceToBottom + 0.1,z=deliverPosition.z},nil,0.8,nil,nil,endFunction,nil,nil)

            local toDropPosition = DroneActionPhase.new(drone,{x=deliverPosition.x,y=droneY,z=deliverPosition.z},nil,1,nil,nil,nil,nil,toDrop)

            startAction = DroneActionPhase.new(drone,nil,deliverDirection,nil,10,nil,nil,nil,toDropPosition)
        end
    end

    if startAction == nil then
        startAction = DroneActionPhase.new(drone,{x=droneX,y=droneY - self.distanceToBottom + 0.1,z=droneZ},nil,0.8,nil,nil,endFunction,nil,nil)
    end

    self.deliveryHandler:addDrone(startAction)
end


function PickupDeliveryManager:pickupGroundCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    if self.currentDeliverDrone:getTarget() ~= nil and self.currentDeliverDrone:getTarget().pallet == object then
        self.distanceToBottom = distance
        print("distance to pallet bottom was : " .. tostring(distance))
        return false
    end



    return true
end

