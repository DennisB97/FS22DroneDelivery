

---@class PalletAddition used for adding additional save data to all vehicles,
-- for making sure pallets,bales can be left in the air for drone to grab back when loading into game.
PalletAddition = {}



function PalletAddition.initialize()

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.BOOL, "vehicles.vehicle(?).FS22_DroneDelivery#isCarried", "Is being carried by drone")

    schemaSavegame = ItemSystem.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.BOOL, "items.item(?).FS22_DroneDelivery#isCarried", "Is being carried by drone")

    Vehicle.tryFinishLoading = Utils.prependedFunction(Vehicle.tryFinishLoading,PalletAddition.onVehicleFinishLoad)
    Vehicle.saveToXMLFile = Utils.appendedFunction(Vehicle.saveToXMLFile,PalletAddition.onVehicleSave)

    Bale.saveToXMLFile = Utils.appendedFunction(Bale.saveToXMLFile,PalletAddition.onBaleSave)
    Bale.createNode = Utils.overwrittenFunction(Bale.createNode,PalletAddition.onBaleNodeLoad)

    Bale.loadFromXMLFile = Utils.overwrittenFunction(Bale.loadFromXMLFile,PalletAddition.loadBale)

end


function PalletAddition:onVehicleSave(xmlFile,key,usedModNames)

    if PickupDeliveryHelper.isSupportedObject(self) then
        if self.bDroneCarried then
            xmlFile:setValue(key .. ".FS22_DroneDelivery#isCarried",self.bDroneCarried)
        end
    end

end

function PalletAddition:loadBale(superFunc,xmlFile, key, resetVehicles)

    local bCarried = Utils.getNoNil(xmlFile:getValue(key..".FS22_DroneDelivery#isCarried"),false)
    self.bDroneCarried = bCarried
    return superFunc(self,xmlFile, key, resetVehicles)
end

function PalletAddition:onBaleSave(xmlFile,key)

    if self.bDroneCarried then
        xmlFile:setValue(key .. ".FS22_DroneDelivery#isCarried",self.bDroneCarried)
    end

end

function PalletAddition:onBaleNodeLoad(superFunc,i3dFilename)
    superFunc(self,i3dFilename)
    PalletAddition.loadCarried(self,self.bDroneCarried)
end

function PalletAddition:onVehicleFinishLoad()

    if PickupDeliveryHelper.isSupportedObject(self) then
        if self.savegame ~= nil then

            local bCarried = Utils.getNoNil(self.savegame.xmlFile:getValue(self.savegame.key..".FS22_DroneDelivery#isCarried"),false)
            PalletAddition.loadCarried(self,bCarried)
            return
        end

    end
end

function PalletAddition.loadCarried(object,bCarried)


    if bCarried then
        local id = PickupDeliveryHelper.getObjectId(object)
        if id == nil then
            return
        end

        -- big bag doesn't fall down on load if hooked like pallets no need to set anything
        if object.spec_bigBag ~= nil then
            return
        end

        if object.isServer then
            setRigidBodyType(id, RigidBodyType.KINEMATIC)
            removeFromPhysics(id)
            addToPhysics(id)
        end
    end

end