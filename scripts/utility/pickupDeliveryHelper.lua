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

---@class PickupDeliveryHelper table containing various helper functions related to filltypes and pallets and position and rotations.
PickupDeliveryHelper = {}

-- some that should be able to be picked up by drones, don't have the pallet designation in filltype table.
PickupDeliveryHelper.specialPalletNames = {
    PIGFOOD = true,
    ROADSALT = true,
    TREESAPLINGS = true,
    POPLAR = true
}

PickupDeliveryHelper.allBaleNames = {
--     SQUAREBALE = true,
--     SQUAREBALE_COTTON = true,
--     SQUAREBALE_WOOD = true,
--     ROUNDBALE = true,
--     ROUNDBALE_GRASS = true,
--     ROUNDBALE_COTTON = true,
--     ROUNDBALE_WOOD = true,
    DRYGRASS_WINDROW = true,
    STRAW = true,
    SILAGE = true
}

-- special husbandries to avoid, cow uses mixed food so only the husbandry with robot could have hay delivered, but if wanted can use NovaLift for that case.
PickupDeliveryHelper.specialHusbandryAvoid = {
    COW = true
}

--- isSpecialHusbandryAvoid checks given animalType if it is a husbandry type to avoid or not.
--@param animalType is animalType to check for.
--@return true if is suppose to avoid given type.
function PickupDeliveryHelper.isSpecialHusbandryAvoid(animalType)
    if animalType == nil then
        return false
    end

    return PickupDeliveryHelper.specialHusbandryAvoid[animalType.name] == true
end

--- isSpecialPalletFillType checks if given filltypename is a special kind.-
--@param fillTypeName of the filltype to check if it is special type.
--@return true if was of special type.
function PickupDeliveryHelper.isSpecialPalletFillType(fillTypeName)
    return PickupDeliveryHelper.specialPalletNames[fillTypeName] == true
end

--- isBaleFillType called to check if given baleTypeName is of any bale name.
--@param baleTypeName given name of bale to check if can be accepted or not.
--@return true if was valid bale.
function PickupDeliveryHelper.isBaleFillType(baleTypeName)
    return PickupDeliveryHelper.allBaleNames[baleTypeName] == true
end

--- getObjectId is a helper function to get the objectId of given object/pallet/bale/bigbag.
-- as Bale's have differently stored the id.
--@param object to check id of.
--@return found id of object, could be nil.
function PickupDeliveryHelper.getObjectId(object)
    local id = object.rootNode
    if object:isa(Bale) then
        id = object.nodeId
    end

    return id
end

--- isSupportedObject checks object type if has required specializations that can be delivered by drone.
--@param object is the object to check if it is valid to be delivered.
--@return true if is valid.
function PickupDeliveryHelper.isSupportedObject(object)

    if object.spec_bigBag ~= nil or object.spec_pallet ~= nil or object.spec_treeSaplingPallet   then

        return true
    end
    return false
end

--- getFillTypeIds gets all the available filltypes that can be delivered and picked up by drone.
--@param placeable is the placeable to check all valid filltypes from.
--@param bPickup varies which filltypes the placeable will have if it is input or output filltypes.
--@return an hashtable of all available filltypeIds.
function PickupDeliveryHelper.getFilltypeIds(placeable,bPickup)
    local fillTypes = {}

    if placeable == nil then
        Logging.warning("placeable was nil for PickupDeliveryHelper.getFilltypeIds: ")
        return fillTypes
    end

    if bPickup then

        -- if pickup place then farmID has to match because can't pickup from any other
        if g_currentMission.connectedToDedicatedServer and g_server == nil or not g_currentMission.connectedToDedicatedServer then
            if placeable.ownerFarmId ~= g_currentMission.player.farmId then
                return fillTypes
            end
        end

        -- honey spec can only mean it can be pickup from a honey location
        if placeable.spec_beehivePalletSpawner ~= nil then
            fillTypes[FillType.HONEY] = true
        end

        -- husbandry pallet spec can only mean it can be picked up from husbandry that outputs pallets
        if placeable.spec_husbandryPallets ~= nil then
            local fillTypeName = placeable.xmlFile:getValue("placeable.husbandry.pallets#fillType")
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
            fillTypes[fillTypeIndex] = true
        end

        -- both pickup and delivery can have productionpoint spec, but the difference will be input and output filltypes
        if placeable.spec_productionPoint ~= nil then

            local production = placeable.spec_productionPoint.productionPoint

            if production ~= nil and production.outputFillTypeIds ~= nil then
                for fillId,_  in pairs(production.outputFillTypeIds) do

                    -- production can have some non pallet production such as electricity, so need to check for palletFilename exist or if special case.
                    local fillType = g_fillTypeManager.indexToFillType[fillId]
                    if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name) or PickupDeliveryHelper.isBaleFillType(fillType.name)) then
                        fillTypes[fillId] = true
                    end

                end
            end

        end

        if placeable.spec_customDeliveryPickupPoint ~= nil then
            PickupDeliveryHelper.addCustomPointSupportedTypes(fillTypes)
        end

    else
        -- can't deliver anything to a greenhouse so making sure greenhouse spec is nil
        if placeable.spec_productionPoint ~= nil and placeable.spec_greenhouse == nil then
            local production = placeable.spec_productionPoint.productionPoint
            if production ~= nil and production.inputFillTypeIds ~= nil then
                for fillId,_  in pairs(production.inputFillTypeIds) do

                    local fillType = g_fillTypeManager.indexToFillType[fillId]
                    if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name) or PickupDeliveryHelper.isBaleFillType(fillType.name)) then
                        fillTypes[fillId] = true
                    end
                end
            end

        end

        if placeable.spec_husbandryFood ~= nil and placeable.spec_husbandryAnimals ~= nil then

            -- checking specialhusbandryavoid mainly as cows can't have anything delivered to as they eat mixed food. Edge case perhaps robot feeder which mixes, but can just use custom delivery point in that case.
            if placeable.spec_husbandryFood.supportedFillTypes ~= nil and not PickupDeliveryHelper.isSpecialHusbandryAvoid(placeable.spec_husbandryAnimals.animalType) then
                for fillId,_  in pairs(placeable.spec_husbandryFood.supportedFillTypes) do
                    local fillType = g_fillTypeManager.indexToFillType[fillId]
                    if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name) or PickupDeliveryHelper.isBaleFillType(fillType.name)) then
                        fillTypes[fillId] = true
                    end
                end
            end

        end

        if placeable.spec_sellingStation ~= nil then

            local sellingStation = placeable.spec_sellingStation.sellingStation

            if sellingStation ~= nil and sellingStation.acceptedFillTypes ~= nil then

                for fillId,_ in pairs(sellingStation.acceptedFillTypes) do
                    local fillType = g_fillTypeManager.indexToFillType[fillId]
                    if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name) or PickupDeliveryHelper.isBaleFillType(fillType.name)) then
                        fillTypes[fillId] = true
                    end
                end
            end

        end

        if placeable.spec_objectStorage ~= nil then

            -- supports bales then adds all bales as possible
            if placeable.spec_objectStorage.supportsBales then
                for name,_ in pairs(PickupDeliveryHelper.allBaleNames) do
                    local fillType = g_fillTypeManager.nameToFillType[name]
                    fillTypes[fillType.index] = true
                end
            end

            -- supports pallets then adds all possible pallets
            if placeable.spec_objectStorage.supportsPallets then
                for name,_ in pairs(FillType) do
                    local fillType = g_fillTypeManager.nameToFillType[name]
                    if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name)) then
                        fillTypes[fillType.index] = true
                    end
                end
            end

            for fillId,_ in pairs(placeable.spec_objectStorage.supportedFillTypes) do
                local fillType = g_fillTypeManager.indexToFillType[fillId]
                if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name) or PickupDeliveryHelper.isBaleFillType(fillType.name)) then
                    fillTypes[fillId] = true
                end
            end

        end

        -- custom delivery pickup point placeable
        if placeable.spec_customDeliveryPickupPoint ~= nil then
            PickupDeliveryHelper.addCustomPointSupportedTypes(fillTypes)
        end

    end

    return fillTypes
end

--- validateInputOutput called to compare given pickup and delivery place filltypes and match any same ones as possible fill ids.
--@param pickupFillTypeIds all available filltypes of the pickup placeable.
--@param deliveryFillTypeIds all available filltypes of the delivery placeable.
--@return all possible common filltypes between both pickup and delivery place.
function PickupDeliveryHelper.validateInputOutput(pickupFillTypeIds,deliveryFillTypeIds)
    local possibleFillIds = {}

    if pickupFillTypeIds == nil or deliveryFillTypeIds == nil then
        return possibleFillIds
    end

    for fillId,_ in pairs(deliveryFillTypeIds) do

        if pickupFillTypeIds[fillId] then
            table.insert(possibleFillIds,fillId)
        end

    end

    if #possibleFillIds > 1 then
        table.insert(possibleFillIds,1,FillType.UNKNOWN)
    end

    return possibleFillIds
end

--- addCustomPointSupportedTypes called to add all available types that can be delivered to given table.
--@param fillTypes hash table will be filled with all drone carried filltypes.
function PickupDeliveryHelper.addCustomPointSupportedTypes(fillTypes)

    -- adds all bales and pallets as supported in the custom delivery pickup point
    for name,_ in pairs(PickupDeliveryHelper.allBaleNames) do
        local fillType = g_fillTypeManager.nameToFillType[name]
        fillTypes[fillType.index] = true
    end

    for name,_ in pairs(FillType) do
        local fillType = g_fillTypeManager.nameToFillType[name]
        if fillType ~= nil and (fillType.palletFilename ~= nil or PickupDeliveryHelper.isSpecialPalletFillType(fillType.name)) then
            fillTypes[fillType.index] = true
        end
    end

end

--- getPointPosition provides way to get correct location drone pickup/delivery position.
--@param bPickup bool indicating if requesting pickup or delivery position.
--@param placeable is from which placeable the position is requested.
function PickupDeliveryHelper.getPointPosition(bPickup,placeable)

    local position = {}
    -- few m above the ground position offset
    local heightOffset = 3.5

    if bPickup then


        if placeable.spec_beehivePalletSpawner ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightOffset
            return position

        elseif placeable.spec_husbandryPallets ~= nil then

            if placeable.spec_husbandryPallets.palletTriggers[1] ~= nil then
                position.x,position.y,position.z = getWorldTranslation(placeable.spec_husbandryPallets.palletTriggers[1].node)
                position.y = position.y + heightOffset
                return position
            end

        elseif placeable.spec_productionPoint ~= nil then

            local production = placeable.spec_productionPoint.productionPoint

            if production ~= nil and production.outputFillTypeIds ~= nil and production.palletSpawner ~= nil then

                if production.palletSpawner.spawnPlaces ~= nil and production.palletSpawner.spawnPlaces[1] ~= nil then
                    position.x,position.y,position.z = production.palletSpawner.spawnPlaces[1].startX , production.palletSpawner.spawnPlaces[1].startY, production.palletSpawner.spawnPlaces[1].startZ

                    local directionX, directionZ = production.palletSpawner.spawnPlaces[1].dirX, production.palletSpawner.spawnPlaces[1].dirZ

                    -- get middle output position
                    position.x = position.x + (directionX * (production.palletSpawner.spawnPlaces[1].width / 2))
                    position.y = position.y + heightOffset
                    position.z = position.z + (directionZ * (production.palletSpawner.spawnPlaces[1].width / 2))

                    return position
                end
            end

        elseif placeable.spec_customDeliveryPickupPoint ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightOffset
            return position
        end

    else

        if placeable.spec_productionPoint ~= nil and placeable.spec_greenhouse == nil then

            local production = placeable.spec_productionPoint.productionPoint

            if production ~= nil and production.inputFillTypeIds ~= nil and production.unloadingStation ~= nil then

                if production.unloadingStation.unloadTriggers ~= nil and production.unloadingStation.unloadTriggers[1] ~= nil then

                    position.x,position.y,position.z = getWorldTranslation(production.unloadingStation.unloadTriggers[1].exactFillRootNode)
                    position.y = position.y + heightOffset
                    return position
                end

            end



        elseif placeable.spec_husbandryFood ~= nil and placeable.spec_husbandryAnimals ~= nil then

            if placeable.spec_husbandryFood.supportedFillTypes ~= nil and not PickupDeliveryHelper.isSpecialHusbandryAvoid(placeable.spec_husbandryAnimals.animalType) then

                if placeable.spec_husbandryFood.feedingTrough ~= nil and placeable.spec_husbandryFood.feedingTrough.exactFillRootNode ~= nil then
                    position.x,position.y,position.z = getWorldTranslation(placeable.spec_husbandryFood.feedingTrough.exactFillRootNode)
                    position.y = position.y + heightOffset - 1.5 -- a bit lower for husbandries as tend to have low roof in the way
                    return position
                end
            end



        elseif placeable.spec_sellingStation ~= nil then

            local sellingStation = placeable.spec_sellingStation.sellingStation

            if sellingStation ~= nil and sellingStation.acceptedFillTypes ~= nil and sellingStation.unloadTriggers ~= nil then

                if sellingStation.unloadTriggers[1] ~= nil then
                    position.x,position.y,position.z = getWorldTranslation(sellingStation.unloadTriggers[1].exactFillRootNode)
                    position.y = position.y + heightOffset
                    return position
                end
            end

        elseif placeable.spec_objectStorage ~= nil then


            position.x,position.y,position.z = getWorldTranslation(placeable.spec_objectStorage.objectTriggerNode)
            position.y = position.y + heightOffset
            return position


        elseif placeable.spec_customDeliveryPickupPoint ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightOffset
            return position
        end

    end

    -- shouldn't go here, just set point 15m above center of placeable.
    position.x, position.y, position.z = getWorldTranslation(placeable.rootNode)
    position.y = position.y + 15
    return position
end

function PickupDeliveryHelper.getCorrectUnloadingPosition(placeable,fillType)
    local position = nil
    if placeable == nil or fillType == nil then
        return position
    end

    local unloadTriggers = nil
    if placeable.spec_productionPoint ~= nil then
        local production = placeable.spec_productionPoint.productionPoint
            if production ~= nil and production.inputFillTypeIds ~= nil and production.unloadingStation ~= nil then
                unloadTriggers = production.unloadingStation.unloadTriggers
            end
    elseif placeable.spec_sellingStation ~= nil then
        local sellingStation = placeable.spec_sellingStation.sellingStation

        if sellingStation ~= nil and sellingStation.acceptedFillTypes ~= nil and sellingStation.unloadTriggers ~= nil then
            unloadTriggers = sellingStation.unloadTriggers
        end
    end

    if unloadTriggers == nil then
        return position
    end

    for _, trigger in ipairs(unloadTriggers) do
        if trigger.fillTypes[fillType] ~= nil then
            position = {x=0,y=0,z=0}
            position.x,position.y,position.z = getWorldTranslation(trigger.exactFillRootNode)
            position.y = position.y + 3.5 -- suitable offset above the exact node
            return position
        end
    end

    return position
end

--- getPickupArea called to get the information of pickup area.
--@param placeable is the pickup placeable to check area from.
--@return pickup info table of {position=,rotation=,scale=}.
function PickupDeliveryHelper.getPickupArea(placeable)

    local pickupInfo = {}

    pickupInfo.position = {}
    pickupInfo.position.x = 0
    pickupInfo.position.y = 0
    pickupInfo.position.z = 0

    pickupInfo.rotation = {}
    pickupInfo.rotation.x = 0
    pickupInfo.rotation.y = 0
    pickupInfo.rotation.z = 0

    pickupInfo.scale = {}
    pickupInfo.scale.x = 0
    pickupInfo.scale.y = 0
    pickupInfo.scale.z = 0


    if placeable.spec_beehivePalletSpawner ~= nil then
        local foundPickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(placeable.spec_beehivePalletSpawner.palletSpawner)
        if foundPickupInfo ~= nil then
            pickupInfo = foundPickupInfo
        end
    elseif placeable.spec_husbandryPallets ~= nil then
        local foundPickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(placeable.spec_husbandryPallets.palletSpawner)
        if foundPickupInfo ~= nil then
            pickupInfo = foundPickupInfo
        end
    elseif placeable.spec_productionPoint ~= nil then
        local production = placeable.spec_productionPoint.productionPoint
        local foundPickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(production.palletSpawner)
        if foundPickupInfo ~= nil then
            pickupInfo = foundPickupInfo
        end
    elseif placeable.spec_customDeliveryPickupPoint ~= nil then

        local x,y,z = getWorldTranslation(placeable.rootNode)

        pickupInfo.position = {}
        pickupInfo.position.x = x
        pickupInfo.position.y = y + 1
        pickupInfo.position.z = z

        local dx, _, dz = localDirectionToWorld(placeable.rootNode, 0, 0, 1)

        dx,dz = MathUtil.vector2Normalize(dx,dz);

        pickupInfo.rotation.y = MathUtil.getYRotationFromDirection(dx,dz)

        local scale = placeable:getScale()
        pickupInfo.scale = {} -- half extent
        pickupInfo.scale.x = (placeable:getDefaultSize() * scale) / 2
        pickupInfo.scale.z = (placeable:getDefaultSize() * scale) / 2
        pickupInfo.scale.y = 1

    end

    return pickupInfo
end

--- getPalletSpawnerInfo called to get the pickup info of a placeable which uses a palletSpawner.
--@param palletSpawner is a placeable spawner to check the area from.
--@return pickup info table of {position=,rotation=,scale=}.
function PickupDeliveryHelper.getPalletSpawnerInfo(palletSpawner)
    if palletSpawner == nil then
        return nil
    end
    local firstSpawnPlace = palletSpawner.spawnPlaces[1]
    local spawnPlaceCount = #palletSpawner.spawnPlaces

    local pickupInfo = {}
    pickupInfo.rotation = {}
    pickupInfo.rotation.x = 0
    pickupInfo.rotation.z = 0

    local rotY = MathUtil.getYRotationFromDirection(firstSpawnPlace.dirPerpX,firstSpawnPlace.dirPerpZ)
    pickupInfo.rotation.y = rotY

    pickupInfo.position = {}
    pickupInfo.position.x = firstSpawnPlace.startX
    pickupInfo.position.y = firstSpawnPlace.startY + 1
    pickupInfo.position.z = firstSpawnPlace.startZ

    if spawnPlaceCount > 1 then
        pickupInfo.position.x = (firstSpawnPlace.startX + palletSpawner.spawnPlaces[spawnPlaceCount].startX) / 2
        pickupInfo.position.z = (firstSpawnPlace.startZ + palletSpawner.spawnPlaces[spawnPlaceCount].startZ) / 2
    end

    pickupInfo.position.x = pickupInfo.position.x + (firstSpawnPlace.dirX * (firstSpawnPlace.width/2))
    pickupInfo.position.z = pickupInfo.position.z + (firstSpawnPlace.dirZ * (firstSpawnPlace.width/2))

    pickupInfo.scale = {}
    pickupInfo.scale.x = firstSpawnPlace.width / 2
    pickupInfo.scale.y = 1
    pickupInfo.scale.z = 1

    if spawnPlaceCount > 1 then
        pickupInfo.scale.z = (1 * spawnPlaceCount)
    end

    return pickupInfo
end

--- getSellPrice called to check the current sell price of a filltype from placeable.
--@param placeable is the placeable which sells something.
--@param fillType is the filltype to price check.
--@return sellPrice of the given filltype in €/1000 liters.
function PickupDeliveryHelper.getSellPrice(placeable,fillType)
    local sellPrice = 999999999

    if placeable == nil or placeable.spec_sellingStation == nil then
        return sellPrice
    end

    local sellingStation = placeable.spec_sellingStation.sellingStation
    if sellingStation ~= nil then
        sellPrice = math.floor(sellingStation:getEffectiveFillTypePrice(fillType) * 1000) -- scale to 1000 liters
    end

    return sellPrice
end

--- hasStorageAvailability is used to check if given placeable has space for the filltype and filllevel so that drone can bring one pallet there and it gets taken.
--@param placeable which is set as delivery destination.
--@param fillType what filltype id wants to be delivered.
--@param fillLevel how much wants to be delivered.
function PickupDeliveryHelper.hasStorageAvailability(placeable,fillType,fillLevel)
    if placeable == nil or fillType == nil then
        return false
    end

    -- empty buffer offset that allows drone to transport pallets even if would go beyond capacity slightly by this value
    local emptyBufferLevel = 100

    if placeable.spec_productionPoint ~= nil and placeable.spec_greenhouse == nil then

        local production = placeable.spec_productionPoint.productionPoint

        if production ~= nil and production.storage ~= nil and production.inputFillTypeIds ~= nil and production.unloadingStation ~= nil then

            if production.storage.capacities[fillType] < production.storage.fillLevels[fillType] + fillLevel - emptyBufferLevel then
                return false
            end

        end

    elseif placeable.spec_husbandryFood ~= nil and placeable.spec_husbandryAnimals ~= nil then

        if placeable.spec_husbandryFood.supportedFillTypes ~= nil and not PickupDeliveryHelper.isSpecialHusbandryAvoid(placeable.spec_husbandryAnimals.animalType) then
            if placeable.spec_husbandryFood.feedingTrough ~= nil then
                local adjustedFillLevel = fillLevel
                local currentFillLevel = placeable.spec_husbandryFood.fillLevels[fillType] or 0
                local capacity = placeable.spec_husbandryFood.capacity or 0
                if capacity < fillLevel then -- bales might be larger than whole capacity on tiny husbandry
                    adjustedFillLevel = capacity
                end

                if capacity < currentFillLevel + adjustedFillLevel - emptyBufferLevel then
                    return false
                end

            end
        end

    elseif placeable.spec_objectStorage ~= nil then

        if placeable.spec_objectStorage.numStoredObjects + 1 > placeable.spec_objectStorage.capacity then
            return false
        end
    end

    return true
end

--- createTargetQuaternion used to create a quaternion out of a targetDirection.
--@param objectId object's id that will be the target rotation calculated from.
--@return quaternion of target rotation.
function PickupDeliveryHelper.createTargetQuaternion(objectId,targetDirection)

    local quatX, quatY, quatZ, quatW = getWorldQuaternion(objectId)

    local startDirectionX, _, startDirectionZ = localDirectionToWorld(objectId,0,0,1)

    local angle = MathUtil.dotProduct(startDirectionX,0,startDirectionZ,targetDirection.x,0,targetDirection.z)
    angle = math.acos(angle)

    local _, crossY, _ = MathUtil.crossProduct(startDirectionX,0,startDirectionZ,targetDirection.x,0,targetDirection.z)

    if crossY < 0 then
        angle = angle * -1
    end

    local rotationQuat = {}
    rotationQuat.w = math.cos(angle/2)
    rotationQuat.x = 0
    rotationQuat.y = math.sin(angle/2)
    rotationQuat.z = 0

    local targetQuat = {}
    targetQuat.x, targetQuat.y, targetQuat.z, targetQuat.w = MathUtil.quaternionMult(quatX,quatY,quatZ,quatW,rotationQuat.x,rotationQuat.y,rotationQuat.z,rotationQuat.w)

    return targetQuat
end

--- getAttachOffset receives correct y offset when drone picking up.
--@param object is object that is being picked up.
--@param fillType is the object's filltype.
--@return float offset value in the y axis.
function PickupDeliveryHelper.getAttachOffset(object,fillType)

    local attachSafeOffset = 0.1

    if fillType == FillType.TREESAPLINGS then
        attachSafeOffset = 1.5
    end

    return attachSafeOffset
end

