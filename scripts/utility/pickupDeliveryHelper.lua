
PickupDeliveryHelper = {}

-- some that should be able to be picked up by drones, don't have the pallet designation in filltype table.
PickupDeliveryHelper.specialPalletNames = {
    PIGFOOD = true,
    ROADSALT = true,
    TREESAPLINGS = true,
    POPLAR = true
}

PickupDeliveryHelper.allBaleNames = {
    SQUAREBALE = true,
    SQUAREBALE_COTTON = true,
    SQUAREBALE_WOOD = true,
    ROUNDBALE = true,
    ROUNDBALE_GRASS = true,
    ROUNDBALE_COTTON = true,
    ROUNDBALE_WOOD = true
}


PickupDeliveryHelper.specialHusbandryAvoid = {
    COW = true
}


function PickupDeliveryHelper.isSpecialHusbandryAvoid(animalType)
    if animalType == nil then
        return false
    end

    return PickupDeliveryHelper.specialHusbandryAvoid[animalType.name] == true
end


function PickupDeliveryHelper.isSpecialPalletFillType(fillTypeName)
    return PickupDeliveryHelper.specialPalletNames[fillTypeName] == true
end

function PickupDeliveryHelper.isBaleFillType(baleTypeName)
    return PickupDeliveryHelper.allBaleNames[baleTypeName] == true
end

function PickupDeliveryHelper.isSupportedObject(object)

    if object.spec_bigBag ~= nil or object.spec_pallet ~= nil or object.spec_treeSaplingPallet   then

        return true
    end
    return false
end

function PickupDeliveryHelper.getFilltypeIds(placeable,bPickup)
    local fillTypes = {}

    if placeable == nil then
        return fillTypes
    end

    if bPickup then

        -- if pickup place then farmID has to match because can't pickup from any other
        if placeable.ownerFarmId ~= g_currentMission.player.farmId then
            return fillTypes
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
                for name,_ in ipairs(PickupDeliveryHelper.allBaleNames) do
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

function PickupDeliveryHelper.validateInputOutput(pickupFillTypeIds,deliveryFillTypeIds)
    if pickupFillTypeIds == nil or deliveryFillTypeIds == nil then
        return
    end


    local possibleFillIds = {}

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

function PickupDeliveryHelper.addCustomPointSupportedTypes(fillTypes)

    -- adds all bales and pallets as supported in the custom delivery pickup point
    for name,_ in ipairs(PickupDeliveryHelper.allBaleNames) do
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
    local heightPickupOffset = 3.5 -- few m above the ground position offset.

    if bPickup then


        if placeable.spec_beehivePalletSpawner ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightPickupOffset
            return position

        elseif placeable.spec_husbandryPallets ~= nil then

            if placeable.spec_husbandryPallets.palletTriggers[1] ~= nil then
                position.x,position.y,position.z = getWorldTranslation(placeable.spec_husbandryPallets.palletTriggers[1].node)
                position.y = position.y + heightPickupOffset
                return position
            end

        elseif placeable.spec_productionPoint ~= nil then

            local production = placeable.spec_productionPoint.productionPoint

            if production ~= nil and production.outputFillTypeIds ~= nil and production.palletSpawner ~= nil then

                if production.palletSpawner.spawnPlaces ~= nil and production.palletSpawner.spawnPlaces[1] ~= nil then
                    position.x,position.y,position.z = production.palletSpawner.spawnPlaces[1].startX , production.palletSpawner.spawnPlaces[1].startY, production.palletSpawner.spawnPlaces[1].startZ

                    local directionX, directionZ = production.palletSpawner.spawnPlaces[1].dirX, production.palletSpawner.spawnPlaces[1].dirZ

                    -- get middle output position
                    position.x = position.x + (directionX * (production.palletSpawner.spawnPlaces[1].width))
                    position.y = position.y + heightPickupOffset
                    position.z = position.z + (directionZ * (production.palletSpawner.spawnPlaces[1].width))

                    return position
                end
            end

        elseif placeable.spec_customDeliveryPickupPoint ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightPickupOffset
            return position
        end

    else

        if placeable.spec_productionPoint ~= nil and placeable.spec_greenhouse == nil then

            local production = placeable.spec_productionPoint.productionPoint

            if production ~= nil and production.inputFillTypeIds ~= nil and production.unloadingStation ~= nil then

                if production.unloadingStation.unloadTriggers ~= nil and production.unloadingStation.unloadTriggers[1] ~= nil then

                    position.x,position.y,position.z = getWorldTranslation(production.unloadingStation.unloadTriggers[1].exactFillRootNode)
                    position.y = position.y + heightPickupOffset
                    return position
                end

            end



        elseif placeable.spec_husbandryFood ~= nil and placeable.spec_husbandryAnimals ~= nil then

            if placeable.spec_husbandryFood.supportedFillTypes ~= nil and not PickupDeliveryHelper.isSpecialHusbandryAvoid(placeable.spec_husbandryAnimals.animalType) then

                if placeable.spec_husbandryFood.feedingTrough ~= nil and placeable.spec_husbandryFood.feedingTrough.exactFillRootNode ~= nil then
                    position.x,position.y,position.z = getWorldTranslation(placeable.spec_husbandryFood.feedingTrough.exactFillRootNode)
                    position.y = position.y + heightPickupOffset
                    return position
                end
            end



        elseif placeable.spec_sellingStation ~= nil then

            local sellingStation = placeable.spec_sellingStation.sellingStation

            if sellingStation ~= nil and sellingStation.acceptedFillTypes ~= nil and sellingStation.unloadTriggers ~= nil then

                if sellingStation.unloadTriggers[1] ~= nil then
                    position.x,position.y,position.z = getWorldTranslation(sellingStation.unloadTriggers[1].exactFillRootNode)
                    position.y = position.y + heightPickupOffset
                    return position
                end
            end

        elseif placeable.spec_objectStorage ~= nil then


            position.x,position.y,position.z = getWorldTranslation(placeable.spec_objectStorage.objectTriggerNode)
            position.y = position.y + heightPickupOffset
            return position


        elseif placeable.spec_customDeliveryPickupPoint ~= nil then
            position.x,position.y,position.z = getWorldTranslation(placeable.rootNode)
            position.y = position.y + heightPickupOffset
            return position
        end

    end


    position.x, position.y, position.z = getWorldTranslation(placeable.rootNode)
    position.y = position.y + 15
    return position
end

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
        pickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(placeable.spec_beehivePalletSpawner.palletSpawner)

    elseif placeable.spec_husbandryPallets ~= nil then
        pickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(placeable.spec_husbandryPallets.palletSpawner)

    elseif placeable.spec_productionPoint ~= nil then
        local production = placeable.spec_productionPoint.productionPoint
        pickupInfo = PickupDeliveryHelper.getPalletSpawnerInfo(production.palletSpawner)

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

function PickupDeliveryHelper.getPalletSpawnerInfo(palletSpawner)
    local firstSpawnPlace = palletSpawner.spawnPlaces[1]
    local spawnPlaceCount = #palletSpawner.spawnPlaces

    local pickupInfo = {}
    pickupInfo.rotation = {}
    pickupInfo.rotation.x = 0
    pickupInfo.rotation.z = 0

    pickupInfo.position = {}
    pickupInfo.position.x = palletSpawner.spawnPlaces[1].startX
    pickupInfo.position.y = palletSpawner.spawnPlaces[1].startY + 1
    pickupInfo.position.z = palletSpawner.spawnPlaces[1].startZ

    if spawnPlaceCount > 1 then
        pickupInfo.position.x = (firstSpawnPlace.startX + palletSpawner.spawnPlaces[spawnPlaceCount].startX) / 2
        pickupInfo.position.z = (firstSpawnPlace.startZ + palletSpawner.spawnPlaces[spawnPlaceCount].startZ) / 2
    end

    pickupInfo.position.x = pickupInfo.position.x * (firstSpawnPlace.dirX * (firstSpawnPlace.width/2))
    pickupInfo.position.z = pickupInfo.position.z * (firstSpawnPlace.dirZ * (firstSpawnPlace.width/2))

    pickupInfo.rotation.y = MathUtil.getYRotationFromDirection(firstSpawnPlace.dirX,firstSpawnPlace.dirZ)

    pickupInfo.scale = {}
    pickupInfo.scale.x = firstSpawnPlace.width / 2
    pickupInfo.scale.y = 1
    pickupInfo.scale.z = 1

    if spawnPlaceCount > 1 then
        pickupInfo.scale.z = (MathUtil.vector3Length(firstSpawnPlace.startX - palletSpawner.spawnPlaces[spawnPlaceCount].startX,firstSpawnPlace.startY - palletSpawner.spawnPlaces[spawnPlaceCount].startY,
            firstSpawnPlace.startZ - palletSpawner.spawnPlaces[spawnPlaceCount].startZ)) / 2
    end

    return pickupInfo
end

function PickupDeliveryHelper.getSellPrice(placeable,fillType)
    local sellPrice = 999999

    if placeable == nil or placeable.spec_sellingStation == nil then
        return sellPrice
    end

    local sellingStation = placeable.spec_sellingStation.sellingStation
    if sellingStation ~= nil then
        sellPrice = math.floor(sellingStation:getEffectiveFillTypePrice(fillType) * 1000) -- scale to 1000 liters
    end

    return sellPrice
end

function PickupDeliveryHelper.createTargetQuaternion(objectNode,targetDirection)

    local quatX, quatY, quatZ, quatW = getWorldQuaternion(objectNode)

    local startDirectionX, _, startDirectionZ = localDirectionToWorld(objectNode,0,0,1)

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


