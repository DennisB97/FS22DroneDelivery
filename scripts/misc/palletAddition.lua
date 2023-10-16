---@class PalletAddition used for adding additional save data to all vehicles,
-- for making sure pallets,bales can be left in the air for drone to grab back when loading into game.
PalletAddition = {}
-- when loading the vehicles store the ones that were carried by drone in this table, so that drone can relink from the tensionbelt function.
PalletAddition.loadedCarriedPallets = {}

--- intialize called from root script of this mod once to prepend and append to the necessary loading and saving functions.
-- and also registers some additional save params to the savegame xml.
function PalletAddition.initialize()

    local schemaSavegame = Vehicle.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.BOOL, "vehicles.vehicle(?).FS22_DroneDelivery#isCarried", "Is being carried by drone")
    schemaSavegame:register(XMLValueType.STRING, "vehicles.vehicle(?).FS22_DroneDelivery#droneLinkID", "link id of drone carrying")

    schemaSavegame = ItemSystem.xmlSchemaSavegame
    schemaSavegame:register(XMLValueType.BOOL, "items.item(?).FS22_DroneDelivery#isCarried", "Is being carried by drone")
    schemaSavegame:register(XMLValueType.STRING, "items.item(?).FS22_DroneDelivery#droneLinkID", "link id of drone carrying")

    Vehicle.tryFinishLoading = Utils.prependedFunction(Vehicle.tryFinishLoading,PalletAddition.onVehicleFinishLoad)
    Vehicle.saveToXMLFile = Utils.prependedFunction(Vehicle.saveToXMLFile,PalletAddition.reAdjustCarriedPallet)
    Vehicle.saveToXMLFile = Utils.appendedFunction(Vehicle.saveToXMLFile,PalletAddition.onVehicleSave)

    Bale.saveToXMLFile = Utils.appendedFunction(Bale.saveToXMLFile,PalletAddition.onBaleSave)
    Bale.loadFromXMLFile = Utils.overwrittenFunction(Bale.loadFromXMLFile,PalletAddition.loadBale)
    Bale.saveToXMLFile = Utils.prependedFunction(Bale.saveToXMLFile,PalletAddition.reAdjustCarriedPallet)
end

--- reAdjustCarriedPallet will adjust any object which is carried by drone just before save, so that it will be certainly under the drone.
-- as speed is high and the object might be dragging behing the drone otherwise if saving without adjusting.
function PalletAddition:reAdjustCarriedPallet()
    if not self.bDroneCarried or self.carryDrone == nil then
        return
    end

    local id = PickupDeliveryHelper.getObjectId(self)

    if id ~= nil and entityExists(self.carryDrone.rootNode) and entityExists(id) then
        local droneX,_,droneZ = getWorldTranslation(self.carryDrone.rootNode)
        local _,palletY,_ = getWorldTranslation(id)
        setTranslation(id,droneX,palletY,droneZ)
    end
end

--- onVehicleSave saves additional bDroneCarried and drone's linkID if was carried by drone.
function PalletAddition:onVehicleSave(xmlFile,key,usedModNames)

    if PickupDeliveryHelper.isSupportedObject(self) then
        if self.bDroneCarried and self.carryDrone ~= nil then
            xmlFile:setValue(key .. ".FS22_DroneDelivery#isCarried",self.bDroneCarried)
            xmlFile:setValue(key .. ".FS22_DroneDelivery#droneLinkID",self.carryDrone:getID())
        end
    end
end

--- loadBale when a bale gets loaded, loads the new additional save variables and if was carried then sets itself into the global table.
function PalletAddition:loadBale(superFunc,xmlFile, key, resetVehicles)
    self.bDroneCarried = Utils.getNoNil(xmlFile:getValue(key..".FS22_DroneDelivery#isCarried"),false)
    local linkId = Utils.getNoNil(xmlFile:getValue(key..".FS22_DroneDelivery#droneLinkID"),"")
    if self.bDroneCarried and linkId ~= "" then
        PalletAddition.loadedCarriedPallets[linkId] = self
    end

    return superFunc(self,xmlFile, key, resetVehicles)
end

--- onBaleSave when bale gets saved, saves if was carried and the drone id of the carrying drone.
function PalletAddition:onBaleSave(xmlFile,key)

    local bDroneCarry = self.bDroneCarried
    local droneLinkID = ""
    if self.carryDrone ~= nil then
        droneLinkID = self.carryDrone:getID()
    end

    if self.bDroneCarried then
        xmlFile:setValue(key .. ".FS22_DroneDelivery#isCarried",bDroneCarry)
        xmlFile:setValue(key .. ".FS22_DroneDelivery#droneLinkID",droneLinkID)
    end

end

--- onVehicleFinishLoad is where the vehicle still has the valid savegame variable, so that the additional drone related variables can be loaded.
-- and self added into the global table if the object was actually carried by a drone, with the drone link id as the hash table key.
function PalletAddition:onVehicleFinishLoad()

    if PickupDeliveryHelper.isSupportedObject(self) then
        if self.savegame ~= nil then
            local bCarried = Utils.getNoNil(self.savegame.xmlFile:getValue(self.savegame.key..".FS22_DroneDelivery#isCarried"),false)
            self.bDroneCarried = bCarried
            local linkId = Utils.getNoNil(self.savegame.xmlFile:getValue(self.savegame.key..".FS22_DroneDelivery#droneLinkID"),"")
            if self.bDroneCarried and linkId ~= "" and self.spec_bigBag == nil then
                PalletAddition.loadedCarriedPallets[linkId] = self
            end

        end
    end
end


