
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


function PickupDeliveryHelper.getFilltypeIds(placeable,bPickup)
    local fillTypes = {}

    if placeable == nil then
        return fillTypes
    end


    if bPickup then

        -- honey spec can only mean it can be pickup from a honey location
        if placeable.spec_beehive ~= nil then
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

        --@TODO: add custom drone point spec



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

        --@TODO: add custom drone point spec

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

function PickupDeliveryHelper.validatePickupAndDelivery(pickUp,delivery)








end




