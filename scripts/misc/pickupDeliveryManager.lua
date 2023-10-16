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
    self.isServer = isServer
    self.isClient = isClient
    self.pickupDrones = {}
    -- drones that have their path changed will be on hold until either a new path has been made and might get removed or if path was invalid will be put back to pickup or delivery drones table.
    self.onHoldDrones = {}
    self.loadedDrones = {}
    self.readyPickupDrones = {}
    self.deliveryDrones = {}
    self.pickupHandler = DroneActionManager.new(self,isServer,isClient,true)
    self.pickupHandler:register(true)
    self.deliveryHandler = DroneActionManager.new(self,isServer,isClient,true)
    self.deliveryHandler:register(true)
    self.isDeleted = false
    self.actionRotationSpeed = 15 -- default rotation speed in actions 15deg/s
    self.actionMoveSpeed = 1 -- default move speed with actions 1m/s
    self.minPickupCheckTime = 30 -- in seconds how often to check for pallets min
    self.maxPickupCheckTime = 60 -- in seconds how often to check for pallets max
    self.pickupCheckTime = math.random(self.minPickupCheckTime,self.maxPickupCheckTime)
    self.currentTime = 0
    self.palletNeedInfo = nil
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
    self.originalSellFunction = self.owner.canBeSold
    self.owner.canBeSold = Utils.overwrittenFunction(self.owner.canBeSold,callback)
    return self
end

--- canOwnerBeSold is overwritten canBeSold, that makes it so if manager exists on a placeable it can't be sold.
--@param owner is the placeable ref tried to be sold.
--@param superFunc the original function.
function PickupDeliveryManager:canOwnerBeSold(owner,superFunc)

    if self.isDeleted then
        local bSellable, message = superFunc(owner)
        return bSellable,message
    end

    return false, g_i18n:getText("droneManager_unlinkBeforeSell")
end

--- delete cleans up the handlers and replaces the sell function of owner back to original
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

    self.owner.canBeSold = self.originalSellFunction
    PickupDeliveryManager:superClass().delete(self)
end

--- isUnused called to check if manager is not being used by any drone.
--@return true if not in use.
function PickupDeliveryManager:isUnused()
    return next(self.pickupDrones) == nil and next(self.deliveryDrones) == nil and next(self.onHoldDrones) == nil and next(self.loadedDrones) == nil
end

--- holdDrone called to put a drone from available to on hold, while a new config is being generated.
--@param drone is the drone to put on hold.
function PickupDeliveryManager:holdDrone(drone)
    self.readyPickupDrones[drone] = nil
    self.onHoldDrones[drone] = true
end

--- clearHold will remove a drone from being in hold and back to ready.
--@param drone is the drone to make ready again.
function PickupDeliveryManager:clearHold(drone)
    self.readyPickupDrones[drone] = true
    self.onHoldDrones[drone] = nil
end

--- addPickupDrone called to add a drone to the manager, or if already exists will be updated with the given config.
--@param drone is the drone to add to manager.
--@param config is the new/updated config of the drone.
function PickupDeliveryManager:addPickupDrone(drone,config)
    if drone == nil then
        return
    end

    self:clearHold(drone)
    if self.pickupDrones[drone] == nil then
        local droneInfo = {}
        self.pickupDrones[drone] = droneInfo
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

    self:checkPickup()
    self:raiseActive()
end

--- updatePickupDrone updates the necessary drone info from config.
--@param drone is whose info to update.
--@param config is new/updated config of the drone to get new info from.
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
    self.onHoldDrones[drone] = nil
    self.pickupDrones[drone] = nil
    self.readyPickupDrones[drone] = nil
    self.deliveryDrones[drone] = nil
    self.loadedDrones[drone] = nil
    if self:isUnused() then
        self:delete()
        return true
    elseif next(self.pickupDrones) == nil then
        self.currentTime = 0
    end

    return false
end

--- addDeliveryDrone adds a drone to the delivery table.
--@param drone is a delivery drone to be added.
function PickupDeliveryManager:addDeliveryDrone(drone)
    self.onHoldDrones[drone] = nil
    self.deliveryDrones[drone] = true
end

--- update accumulates time on the update until ready to call and check for available pallets to pickup.
function PickupDeliveryManager:update(dt)

    if self.pickupDrones ~= nil and next(self.pickupDrones) ~= nil then
        self:raiseActive()
    else
        return
    end

    self.currentTime = self.currentTime + (dt / 1000)
    if self.currentTime > self.pickupCheckTime then
        self.pickupCheckTime = math.random(self.minPickupCheckTime,self.maxPickupCheckTime)
        self:checkPickup()
    end
end

--- markPalletsUnchecked will mark any current scheduled or waiting pallets as unchecked, so if pallet is not found on next overlap check it has gone,
-- and the scheduled pallet's drones need to have a notice that target is gone.
function PickupDeliveryManager:markPalletsUnchecked()

    for pallet,target in pairs(self.palletsScheduled) do
        target.checked = false
    end

    for pallet, target in pairs(self.palletsWaiting) do
        target.checked = false
    end

end

--- checkPickup handles overlapping the pickup area, checking and marking pallets, and proceeds to request drones.
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

    -- prioritize any loaded drones
    self:reConnectLoadedDrones()

    self:requestDrones(self.readyPickupDrones)
end

--- reConnectLoadedDrones any new drones that were added as loadedDrones, will have pallets requested before the others.
function PickupDeliveryManager:reConnectLoadedDrones()
    if self.loadedDrones == nil or next(self.loadedDrones) == nil then
        return
    end

    self:requestDrones(self.loadedDrones)

    for drone,_ in pairs(self.loadedDrones) do
        self:droneLostTarget(drone)
    end

    self.loadedDrones = {}
end

--- pickupOverlapCallback is callback from the overlapBox, if finds any valid pickup object proceeds to do raycast to find offset height.
--@param objectId is the id of object hit.
--@return true to continue search and false to call done.
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
            self.palletNeedInfo = object
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

--- verifyPalletLocation called to check if given pallet is still inside the pickup area.
--@param pallet is the pickup object to check if still in the pickup area.
--@return true if seeked pallet was still in the pickup area.
function PickupDeliveryManager:verifyPalletLocation(pallet)
    if pallet == nil then
        return false
    end

    self.checkingPallet = pallet
    self.bCheckingPalletValid = false
    overlapBox(self.pickupInfo.position.x,self.pickupInfo.position.y,self.pickupInfo.position.z,self.pickupInfo.rotation.x,self.pickupInfo.rotation.y,self.pickupInfo.rotation.z,
        self.pickupInfo.scale.x,self.pickupInfo.scale.y,self.pickupInfo.scale.z,"verifyPalletLocationCallback",self,self.collisionMask,true,false,true,false)

    return self.bCheckingPalletValid
end

--- verifyPalletLocationCallback callback from the overlapBox checking if specific pallet is in the pickup area or not.
--@param objectId id of object hit.
--@return true to continue search, false to stop overlap search.
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

--- checkObjectValidity called to check if an object is a valid pickup type.
--@param object to compare if valid.
--@param objectId id of the object to compare.
--@return true if was a valid object to pickup.
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

--- pickupHeightCheckCallback callback from the heigh offset check after a pickup object has been found in the overlap test.
--@param objectId is object's id that was hit.
--@param x coordinate position of hit.
--@param y coordinate position of hit.
--@param z coordinate position of hit.
--@param distance the used ray distance to hit object.
--@return true to continue ray, false to stop.
function PickupDeliveryManager:pickupHeightCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    if self.palletNeedInfo == object then
        self.palletNeedInfo = nil
        self:addNewPallet(object,objectId,y)
        return false
    end

    return true
end

--- setPickupPosition called to store the pickup position info from the owner placeable.
function PickupDeliveryManager:setPickupPosition()
    self.pickupInfo = PickupDeliveryHelper.getPickupArea(self.owner)
end

--- addNewPallet finalizes an object that can be picked up by drone and put on waiting table.
--@param object is object to put as waiting for pickup.
--@param objectId id of the object.
--@param y coordinate of the top of the pallet.
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

--- requestDrones will go through all given drones and try find a object to give as target.
--@param drones table of all drones that could be given a target to pickup.
--@return true if scheduled any drone.
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
        self.loadedDrones[drone] = nil

        if drones ~= self.readyPickupDrones then
            drones[drone] = nil
        end
    end

    return true
end

--- requestPickup called to request a pickup for a single drone.
--@param drone is the drone that requires a pickup.
--@return true if had a new pickup for drone.
function PickupDeliveryManager:requestPickup(drone)
    if drone == nil or self.pickupDrones[drone] == nil then
        Logging.warning("PickupDeliveryManager:requestPickup: Trying to request a drone which hasn't been added to manager!")
        return false
    end

    local drones = {}
    drones[drone] = true
    return self:requestDrones(drones)
end

--- checkDronePickupValidity checks all cases if drone can be matched with the target pallet.
--@param droneInfo contains the drone's info of required filltype and other limits.
--@param target contains the pallet object and it's information.
--@return true if pickup is possible between the drone and pallet.
function PickupDeliveryManager:checkDronePickupValidity(droneInfo,target)
    if droneInfo == nil or target == nil or droneInfo.drone.spec_drone.deliveryManager == nil then
        Logging.warning("PickupDeliveryManager:checkDronePickupValidity: no valid droneInfo or target given, or deliveryManager was nil!")
        return false
    end

    local deliveryPlaceable = droneInfo.drone.spec_drone.deliveryManager.owner
    if deliveryPlaceable == nil then
        return false
    end

    -- check if drone can go pick up one
    if not droneInfo.drone:isAvailableForPickup() and self.loadedDrones[droneInfo.drone] == nil then
        return false
    end

    -- check if drone has correct filltype to pickup, UNKNOWN == ANY FILLTYPE
    if droneInfo.fillTypeNode ~= target.fillType then

        local bHadFillType = false
        if droneInfo.fillTypeNode == FillType.UNKNOWN then
            for _,fillType in ipairs(droneInfo.fillTypes) do
                if fillType == target.fillType then
                    bHadFillType = true
                    break
                end
            end
        end

        if not bHadFillType then
            return false
        end
    end

    -- check if has any price limit
    if droneInfo.bPriceLimit and droneInfo.priceLimit > PickupDeliveryHelper.getSellPrice(deliveryPlaceable,target.fillType) then
        return false
    end

    local fillLevel = 99999
    if target.pallet.spec_fillUnit ~= nil and target.pallet.spec_fillUnit.fillUnits[1] ~= nil then

        local requiredCapacity = target.pallet.spec_fillUnit.fillUnits[1].capacity * droneInfo.fillLimit
        if target.pallet.spec_fillUnit.fillUnits[1].fillLevel < (requiredCapacity - 1) then -- -1 for anomalities.
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

    -- check if delivery placeable has enough storage for the filltype and filllevel
    if not PickupDeliveryHelper.hasStorageAvailability(deliveryPlaceable,target.fillType,fillLevel) then
        return false
    end

    return true
end

--- droneLostTarget called to inform given drone that target is gone.
--@param drone is the drone to inform about target is gone.
function PickupDeliveryManager:droneLostTarget(drone)
    if drone == nil or self.pickupHandler == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.pickupDroneArrivedCallback)
    self.pickupHandler:interrupt(drone)
    if drone:getTarget() ~= nil and drone:getTarget().pallet ~= nil then
        self.palletsScheduled[drone:getTarget().pallet] = nil
    end
    SpecializationUtil.raiseEvent(drone,"onTargetLost")
end

--- onPickupDroneArrive callback from when drone has arrived to pickup place.
--@param drone is the drone that arrived.
function PickupDeliveryManager:onPickupDroneArrive(drone)
    if drone == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.pickupDroneArrivedCallback)
    self:createPickupAction(drone)
end

--- onDeliveryDroneArrive callback from when drone has arrived to delivery place.
--@param drone is the drone that arrived.
function PickupDeliveryManager:onDeliveryDroneArrive(drone)
    if drone == nil then
        return
    end

    drone:removeOnDroneArrivedListener(self.deliveryDroneArrivedCallback)
    self:createDeliveryAction(drone)
end

--- createPickupAction creates the action and starts, that takes care of moving drone over the pickup object and goes down to pickup.
--@param drone is the drone to move.
function PickupDeliveryManager:createPickupAction(drone)
    if drone == nil or self.pickupHandler == nil then
        return
    end

    local target = drone:getTarget()
    if target == nil or not self:verifyPalletLocation(drone:getTarget().pallet) then
        self:droneLostTarget(drone)
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
                drone:playDroneAnimation("hookAnimation",true)
            else
                drone:playDroneAnimation("palletHolderAnimation",true)
            end
        end


    local downToPallet = DroneActionPhase.new(drone,{x=targetX,y=targetY + target.heightOffset,z = targetZ} ,nil,self.actionMoveSpeed,nil,nil,endingCallback,nil,nil)
    local rotateAgainstPallet = DroneActionPhase.new(drone,nil ,finalTargetDirection,nil,self.actionRotationSpeed,nil,nil,nil,downToPallet)
    local toAbovePallet = DroneActionPhase.new(drone,abovePalletPosition,nil,self.actionMoveSpeed,nil,nil,nil,nil,rotateAgainstPallet)
    local pickAction = DroneActionPhase.new(drone,nil,targetDirection,nil,self.actionRotationSpeed,startingCallback,nil,nil,toAbovePallet)

    self.pickupHandler:addAction(pickAction)
end

--- createDeliveryAction called to create the action and starts it, that takes care of moving drone on the delivery place in specific manner depending on placeable type.
--@param drone is the drone that is delivering something.
function PickupDeliveryManager:createDeliveryAction(drone)
    if self.owner == nil or drone == nil or self.deliveryHandler == nil then
        return
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


    local target = drone:getTarget()
    if target == nil then
        endFunction(drone)
        return
    end

    local droneX, droneY,droneZ = getWorldTranslation(drone.rootNode)
    self.distanceToBottom = 0

    -- need to check entity if valid as pallet might have been consumed by now, bigbag will be lowered only if to customDeliveryPickupPoint
    if entityExists(target.objectId) and ((target.pallet.spec_bigBag ~= nil and self.owner.spec_customDeliveryPickupPoint ~= nil) or target.pallet.spec_bigBag == nil) then
        local palletX, palletY,palletZ = getWorldTranslation(target.objectId)
        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,palletX,palletY,palletZ) + 0.1
        self.deliveryTarget = target.pallet
        raycastAll(palletX,terrainHeight,palletZ,0,1,0,"pickupGroundCheckCallback",5,self,self.collisionMask + CollisionFlag.PLAYER)
    end

    local additionalTaskFunction = nil
    local startAction = nil

    -- when it is not a custom delivery point and carried object is bigbag then will have a delay function to let the bigbag get emptied as it won't get emptied when sitting on ground.
    if self.owner.spec_customDeliveryPickupPoint == nil and target.pallet.spec_bigBag ~= nil then
        additionalTaskFunction = function(bFinalPosition,bFinalRotation,sDt,currentTime)
                if currentTime > 8.0 then -- 5sec time the action has to run before this returns true so the action phase can end
                    return true
                else
                    return false
                end
            end
    end

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

            local toDrop = DroneActionPhase.new(drone,{x=deliverPosition.x,y=droneY - self.distanceToBottom + 0.1,z=deliverPosition.z},nil,self.actionMoveSpeed,nil,nil,endFunction,nil,nil)

            local toDropPosition = DroneActionPhase.new(drone,{x=deliverPosition.x,y=droneY,z=deliverPosition.z},nil,self.actionMoveSpeed,nil,nil,nil,nil,toDrop)

            startAction = DroneActionPhase.new(drone,nil,deliverDirection,nil,self.actionRotationSpeed,nil,nil,nil,toDropPosition)
        end
    -- the production point or sellingstation might have different input places for different filltypes need to check correct location
    elseif self.owner.spec_productionPoint ~= nil or self.owner.spec_sellingStation ~= nil then
        if target.fillType == nil then
            if target.pallet:isa(Bale) then
                target.fillType = target.pallet.fillType
            elseif target.pallet.spec_fillUnit ~= nil and target.pallet.spec_fillUnit.fillUnits[1] ~= nil then
                target.fillType = target.pallet.spec_fillUnit.fillUnits[1].fillType
            end
        end
        local newPosition = PickupDeliveryHelper.getCorrectUnloadingPosition(self.owner,target.fillType)
        if newPosition ~= nil then
            droneX, droneY, droneZ = newPosition.x, newPosition.y, newPosition.z
        end
    end

    if startAction == nil then
        startAction = DroneActionPhase.new(drone,{x=droneX,y=droneY - self.distanceToBottom + 0.1,z=droneZ},nil,self.actionMoveSpeed,nil,nil,endFunction,additionalTaskFunction,nil)
    end

    self.deliveryHandler:addAction(startAction)
end

--- pickupGroundCheckCallback is callback from raycast to check distance between carried object and ground, so the object can be lowered almost to the ground before release.
--@param objectId id of hit object.
--@param x coordinate of hit.
--@param y coordinate of hit.
--@param z coordinate of hit.
--@param distance ray distance to the hit point.
--@return true to continue ray and false that stops the ray.
function PickupDeliveryManager:pickupGroundCheckCallback(objectId, x, y, z, distance)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    if self.deliveryTarget == object then
        self.distanceToBottom = distance
        return false
    end

    return true
end

