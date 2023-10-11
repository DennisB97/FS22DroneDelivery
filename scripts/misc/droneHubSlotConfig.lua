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

---@class DroneBaseConfig functions as basis for config point drone route, base used for delivery point.
-- as delivery does not require anything else than the placeable and placeable position information and name.
DroneBaseConfig = {}
DroneBaseConfig_mt = Class(DroneBaseConfig)
InitObjectClass(DroneBaseConfig, "DroneBaseConfig")

--- new creates a new DroneBaseConfig, initializes the three variables used.
--@return self reference of created DroneBaseConfig.
function DroneBaseConfig.new()
    local self = setmetatable({}, DroneBaseConfig_mt)
    self.placeable = nil
    self.position = nil
    self.name = ""
    return self
end

--- hasPoint is a call to check if the config has a placeable or not.
--@return true if has placeable else false.
function DroneBaseConfig:hasPoint()
    return self.placeable ~= nil
end

--- hasManager is a call to check if the config's placeable has a drone manager or not.
--@return true if has a manager in the placeable table.
function DroneBaseConfig:hasManager()
    return self.placeable ~= nil and self.placeable.droneManager ~= nil
end

--- reset called to reset all the variables back to default.
function DroneBaseConfig:reset()
    self.placeable = nil
    self.position = nil
    self.name = ""
end

--- nilEverything is called to nil everything, unlike like reset which puts to default.
function DroneBaseConfig:nilEverything()
    self.placeable = nil
    self.position = nil
    self.name = nil
end

--- findPlaceable is called to try get the placeable reference with loaded x,y,z position coordinates.
--@return true if found a placeable reference else false.
function DroneBaseConfig:findPlaceable()
    if self.position == nil then
        return false
    end

    -- loops through all placeables in the map to find the correct placeable
    if g_currentMission ~= nil and g_currentMission.placeableSystem ~= nil and g_currentMission.placeableSystem.placeables ~= nil then
        for _, placeable in ipairs(g_currentMission.placeableSystem.placeables) do
            if placeable ~= nil then
                local foundPosition = {x=0,y=0,z=0}
                foundPosition.x,foundPosition.y,foundPosition.z = getWorldTranslation(placeable.rootNode)
                -- assuming there will be no possible placeable within 2cm
                if CatmullRomSpline.isNearlySamePosition(foundPosition,self.position,0.02) then
                    self.placeable = placeable
                    self.name = placeable:getName()
                    break
                end
            end
        end
    end

    if self.placeable ~= nil then
        return true
    else
        return false
    end
end

--- copy makes a DroneBaseConfig copy of current table.
--@return a new copy of base config without any reference attachment to the original.
function DroneBaseConfig:copy()

    local newCopy = DroneBaseConfig.new()

    if self.position ~= nil then
        newCopy.position = {x=self.position.x, y=self.position.y, z=self.position.z}
    end

    newCopy.name = self.name
    newCopy.placeable = self.placeable

    return newCopy
end

--- setPlaceable called to set the placeable variable, which also takes the position and name out of the placeable into the config.
--@param placeable is the route's one placeable.
function DroneBaseConfig:setPlaceable(placeable)
    if placeable == nil or placeable.rootNode == nil then
        return
    end

    self.placeable = placeable

    -- position on the root nodes, will be used when loading game to get back the reference of the placeable to self.placeable
    self.position = {x=0,y=0,z=0}
    self.position.x, self.position.y, self.position.z = getWorldTranslation(placeable.rootNode)

    self.name = placeable:getName()
end

--- On saving saves the coordinates of the placeable if config had one.
function DroneBaseConfig:saveToXMLFile(xmlFile, key, usedModNames)

    local x,y,z = nil,nil,nil
    if self.position ~= nil then
        x,y,z = self.position.x, self.position.y, self.position.z
    end

    xmlFile:setValue(key.."#position", x, y, z)
end

--- On loading config loads coordinates of placeable if it had one saved.
function DroneBaseConfig:loadFromXMLFile(xmlFile, key)

    local posX,posY,posZ = xmlFile:getValue(key.."#position")
    if posX == nil then
        return
    end

    self.position = {x = posX, y = posY, z = posZ}
    return
end

--- Registering savegame xml paths for base config.
function DroneBaseConfig.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.VECTOR_TRANS,        basePath .. ".config(?)#position", "Position of placeable")
end

--- readStream placeable,name and position synced to clients on client join.
function DroneBaseConfig:readStream(streamId,connection)

    if streamReadBool(streamId) then
        self.placeable = NetworkUtil.readNodeObject(streamId)
        self.name = self.placeable:getName()
        self.position = {x=0,y=0,z=0}
        self.position.x = streamReadFloat32(streamId)
        self.position.y = streamReadFloat32(streamId)
        self.position.z = streamReadFloat32(streamId)
    end

end

--- writeStream server writes to joining client, placeable and position, as position of placeable might not be yet loaded on the client.
function DroneBaseConfig:writeStream(streamId,connection)

    if streamWriteBool(streamId,self.placeable ~= nil) then
        NetworkUtil.writeNodeObject(streamId, self.placeable)
        streamWriteFloat32(streamId,self.position.x)
        streamWriteFloat32(streamId,self.position.y)
        streamWriteFloat32(streamId,self.position.z)
    end

end

---@class DronePickupConfig is used to have additional config settings for the pickup point.
DronePickupConfig = {}
DronePickupConfig_mt = Class(DronePickupConfig,DroneBaseConfig)
InitObjectClass(DronePickupConfig, "DronePickupConfig")

--- new creates a new DronePickupConfig with default variables initialized.
function DronePickupConfig.new()
    local self = setmetatable({}, DronePickupConfig_mt)
    self.fillTypes = {}
    self.allFillTypes = {}
    self.fillLimitIndex = 5
    self.fillTypeIndex = 1
    self.bPriceLimit = false
    self.priceLimit = 0
    return self
end

--- reset called to reset all the variables back to default.
function DronePickupConfig:reset()
    DronePickupConfig:superClass().reset(self)
    self.fillTypes = {}
    self.allFillTypes = {}
    self.fillTypeIndex = 1
    self.fillLimitIndex = 5 -- reset 5 which ends up as 50%
    self.bPriceLimit = false
    self.priceLimit = 0
end

--- nilEverything is called to nil everything, unlike like reset which puts to default.
function DronePickupConfig:nilEverything()
    DronePickupConfig:superClass().nilEverything(self)
    self.fillTypes = nil
    self.allFillTypes = nil
    self.fillTypeIndex = nil
    self.bPickup = nil
    self.bPriceLimit = nil
    self.priceLimit = nil
    self.fillLimitIndex = nil
end

--- copy makes a DronePickupConfig copy of current table.
--@return a new copy of pickup config without any reference attachment to the original.
function DronePickupConfig:copy()

    local newCopy = DronePickupConfig.new()

    if self.position ~= nil then
        newCopy.position = {x=self.position.x, y=self.position.y, z=self.position.z}
    end

    newCopy.name = self.name
    newCopy.placeable = self.placeable
    newCopy.fillTypeIndex = self.fillTypeIndex
    newCopy.bPriceLimit = self.bPriceLimit
    newCopy.priceLimit = self.priceLimit
    newCopy.fillLimitIndex = self.fillLimitIndex

    for _,fillId in ipairs(self.fillTypes) do
        table.insert(newCopy.fillTypes,fillId)
    end

    for fillId,_ in pairs(self.allFillTypes) do
        newCopy.allFillTypes[fillId] = true
    end

    return newCopy
end

function DronePickupConfig:restrictFillTypes(fillTypes)
    self.fillTypes = fillTypes
    self.fillTypeIndex = 1
end


--- On saving additionally to the base config, this saves the configurated values such as array of filltypes, price limit and chosen filltype.
function DronePickupConfig:saveToXMLFile(xmlFile, key, usedModNames)
    DronePickupConfig:superClass().saveToXMLFile(self,xmlFile,key,usedModNames)

    xmlFile:setValue(key.."#fillTypeIndex", self.fillTypeIndex)
    xmlFile:setValue(key.."#hasPriceLimit", self.bPriceLimit)
    xmlFile:setValue(key.."#fillLimitIndex",self.fillLimitIndex)
    xmlFile:setValue(key.."#priceLimit", self.priceLimit)

    local fillTypeString = ""

    for _,fillTypeId in ipairs(self.fillTypes) do
        local fillTypeDesc = g_fillTypeManager.indexToFillType[fillTypeId]
        fillTypeString = fillTypeString .. fillTypeDesc.name .. " "
    end

    xmlFile:setValue(key.."#fillTypes", fillTypeString)

    fillTypeString = ""
    for fillTypeId,_ in pairs(self.allFillTypes) do
        local fillTypeDesc = g_fillTypeManager.indexToFillType[fillTypeId]
        fillTypeString = fillTypeString .. fillTypeDesc.name .. " "
    end

    xmlFile:setValue(key.."#allFillTypes",fillTypeString)
end

--- On loading additioanlly to loading the base config, this loads the configurated values such as array of filltypes, price limit and chosen filltype.
function DronePickupConfig:loadFromXMLFile(xmlFile, key)
    DronePickupConfig:superClass().loadFromXMLFile(self,xmlFile,key)

    self.fillTypeIndex = Utils.getNoNil(xmlFile:getValue(key.."#fillTypeIndex"),1)
    self.bPriceLimit = Utils.getNoNil(xmlFile:getValue(key.."#hasPriceLimit"),false)
    self.priceLimit = Utils.getNoNil(xmlFile:getValue(key.."#priceLimit"),0)
    self.fillLimitIndex = Utils.getNoNil(xmlFile:getValue(key.."#fillLimitIndex"),5)

    local fillTypeString = xmlFile:getValue(key.."#fillTypes")
    if fillTypeString ~= nil then
        local currentIndex = 1
        for fillName in fillTypeString:gmatch("%S+") do
            local index = g_fillTypeManager:getFillTypeIndexByName(fillName)

            if index == nil and self.fillTypeIndex >= currentIndex then
                self.fillTypeIndex = MathUtil.clamp(self.fillTypeIndex - 1,1,9999)
            end

            if index ~= nil then
                table.insert(self.fillTypes, index)
            end
            currentIndex = currentIndex + 1
        end
    end

    fillTypeString = xmlFile:getValue(key.."#allFillTypes")
    if fillTypeString ~= nil then
        for fillName in fillTypeString:gmatch("%S+") do
            local index = g_fillTypeManager:getFillTypeIndexByName(fillName)
            if index ~= nil then
                self.allFillTypes[index] = true
            end
        end
    end
end

--- Registering PickupConfig's variables to be saved.
function DronePickupConfig.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.INT,        basePath .. ".config(?)#fillTypeIndex", "Fill type index within the fillTypes array")
    schema:register(XMLValueType.INT,        basePath .. ".config(?)#fillLimitIndex", "Fill limit index which is base to multiply by 10 to get percentage of fill limit of pallet for pickup")
    schema:register(XMLValueType.BOOL,        basePath .. ".config(?)#hasPriceLimit", "If has a price limit")
    schema:register(XMLValueType.FLOAT,        basePath .. ".config(?)#priceLimit", "price limit value")
    schema:register(XMLValueType.STRING,        basePath .. ".config(?)#fillTypes", "limited fillTypes")
    schema:register(XMLValueType.STRING,        basePath .. ".config(?)#allFillTypes", "all fillTypes")
end

--- readStream placeable,name and position and additional pickup related variables synced to clients on client join.
function DronePickupConfig:readStream(streamId,connection)

    if streamReadBool(streamId) then
        self.placeable = NetworkUtil.readNodeObject(streamId)
        self.name = self.placeable:getName()
        self.position = {x=0,y=0,z=0}
        self.position.x = streamReadFloat32(streamId)
        self.position.y = streamReadFloat32(streamId)
        self.position.z = streamReadFloat32(streamId)

        self.fillTypeIndex = streamReadInt32(streamId)
        self.bPriceLimit = streamReadBool(streamId)
        self.priceLimit = streamReadInt32(streamId)
        self.fillLimitIndex = streamReadInt8(streamId)

        local fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                table.insert(self.fillTypes, index)
            end
        end

        fillTypesString = streamReadString(streamId)

        for fillIdString in fillTypesString:gmatch("%S+") do
            local index = tonumber(fillIdString)
            if index ~= nil then
                self.allFillTypes[index] = true
            end
        end

    end
end


--- writeStream server writes to joining client, placeable and position, and the rest pickupconfig related variables.
function DronePickupConfig:writeStream(streamId,connection)

    if streamWriteBool(streamId,self.placeable ~= nil) then

        NetworkUtil.writeNodeObject(streamId, self.placeable)
        streamWriteFloat32(streamId,self.position.x)
        streamWriteFloat32(streamId,self.position.y)
        streamWriteFloat32(streamId,self.position.z)

        streamWriteInt32(streamId,self.fillTypeIndex)
        streamWriteBool(streamId,self.bPriceLimit)
        streamWriteInt32(streamId,self.priceLimit)
        streamWriteInt8(streamId,self.fillLimitIndex)

        local fillTypesString = ""
        for _,id in ipairs(self.fillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)

        fillTypesString = ""
        for id,_ in pairs(self.allFillTypes) do
            fillTypesString = fillTypesString .. id .. " "
        end

        streamWriteString(streamId,fillTypesString)
    end
end

---@class DroneHubSlotConfig keeps the pickup and delivery config, and handles clearing and applying settings.
DroneHubSlotConfig = {}
DroneHubSlotConfig_mt = Class(DroneHubSlotConfig)
InitObjectClass(DroneHubSlotConfig, "DroneHubSlotConfig")

DroneHubSlotConfig.EDirtyFields = {PICKUPPLACEABLE = 0x01, DELIVERYPLACEABLE = 0x02, PRICELIMIT = 0x04, PRICELIMITUSED = 0x08, FILLTYPEID = 0x10, FILLLIMITID = 0x20}

--- new creates a new DroneHubSlotConfig, creates the pickup and delivery config and rest variables.
--@param slot is the hub's slot which owns this config.
--@param hub is the drone hub which owns this config.
--@param isServer if is server.
--@param isClient if is client.
function DroneHubSlotConfig.new(slot,hub,isServer,isClient)
    local self = setmetatable({}, DroneHubSlotConfig_mt)
    self.hubOwner = hub
    -- pickupConfig and deliveryConfig will be synced between clients and server purely with events.
    self.pickupConfig = DronePickupConfig.new()
    self.deliveryConfig = DroneBaseConfig.new()
    -- loaded config bool is used as exception for applying settings for a drone which is not at a hub, if not loaded config and not at hub then can't apply settings.
    self.bLoadedConfig = false
    self.dirty = 0
    self.slot = slot
    self.isServer = isServer
    self.isClient = isClient
    return self
end

--- On saving forwards to save the pickup and delivery configs.
function DroneHubSlotConfig:saveToXMLFile(xmlFile, key, usedModNames)
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return
    end

    self.pickupConfig:saveToXMLFile(xmlFile,key..".config(1)",usedModNames)
    self.deliveryConfig:saveToXMLFile(xmlFile,key..".config(2)",usedModNames)
end

--- On loading forwards to load the pickup and delivery config.
function DroneHubSlotConfig:loadFromXMLFile(xmlFile, key)
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return
    end
    self.bLoadedConfig = true

    self.pickupConfig:loadFromXMLFile(xmlFile,key..".config(1)")
    self.deliveryConfig:loadFromXMLFile(xmlFile,key..".config(2)")
end

--- isLoadedConfig called to check if is still a loaded config.
--@return true if is loaded config.
function DroneHubSlotConfig:isLoadedConfig()
    return self.bLoadedConfig
end

--- On registering savegame paths forwards to register the baseconfig and pickupconfig paths.
function DroneHubSlotConfig.registerSavegameXMLPaths(schema, basePath)
    DroneBaseConfig.registerSavegameXMLPaths(schema,basePath)
    DronePickupConfig.registerSavegameXMLPaths(schema,basePath)
end

--- on read syncing from server to client on join, forwards syncing the pickup and delivery config.
function DroneHubSlotConfig:readStream(streamId,connection)
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return
    end

    self.pickupConfig:readStream(streamId,connection)
    self.deliveryConfig:readStream(streamId,connection)
end

--- on write server to client join, forwards syncing the pickup and delivery config.
function DroneHubSlotConfig:writeStream(streamId,connection)
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return
    end

    self.pickupConfig:writeStream(streamId,connection)
    self.deliveryConfig:writeStream(streamId,connection)
end

--- clearConfig called to completely erase the configurated values and removes the drones from managers, if manager is empty then removes the manager.
function DroneHubSlotConfig:clearConfig()
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return
    end

    self:removeDroneFromManager(false)
    self:removeDroneFromManager(true)

    self.pickupConfig:reset()
    self.deliveryConfig:reset()
    self:clearAllDirty()
    self.bLoadedConfig = false
end

--- on deleting the slot config will clear the configs.
function DroneHubSlotConfig:delete()
    self:clearConfig()
end

--- searchPlaceables is early function done after grid has been generated, will try to reconnect from loaded x,y,z coordinates for pickup and delivery placeable.
--@return true if was able to load both pickup and delivery placeable.
function DroneHubSlotConfig:searchPlaceables()
    if self.pickupConfig == nil or self.deliveryConfig == nil then
        return false
    end

    local bValid = true

    if not self.pickupConfig:findPlaceable() then
        bValid = false
    end

    if not self.deliveryConfig:findPlaceable() then
        bValid = false
    end

    if not bValid then
        self.pickupConfig:reset()
        self.deliveryConfig:reset()
        self.bLoadedConfig = false
        return false
    end

    -- sets all dirty as everything needs to be sent over when loaded.
    self:setAllDirty()
    return true
end

--- initializeConfig will be called after grid has been generated, will try to reconnect the placeables for pickup and delivery config and then proceed to event to apply the loaded config.
--@return true if could find both pickup and delivery placeables and is applying the settings.
function DroneHubSlotConfig:initializeConfig()
    if self.slot == nil or not self.bLoadedConfig or self.pickupConfig == nil or self.deliveryConfig == nil then
        return false
    end

    -- look for loaded placeables in config
    self:searchPlaceables()

    if not self.pickupConfig:hasPoint() or self.pickupConfig.placeable.isDeleted or not self.deliveryConfig:hasPoint() or self.deliveryConfig.placeable.isDeleted then
        return false
    end

    ChangeConfigEvent.sendEvent(self.hubOwner,self.slot.slotIndex,self.pickupConfig,self.deliveryConfig)
    return true
end

--- clearDirty called to clear one bit on the dirty.
function DroneHubSlotConfig:clearDirty(dirtyValue,shiftValue)

    if bitAND(self.dirty,dirtyValue) ~= 0 then

        -- create mask where only the dirtyValue bit is 0 rest is all 1
        local mask = (1 * (2^shiftValue)) - 1
        mask = bitOR(mask,-1 * (2^(shiftValue + 1)))
        self.dirty = bitAND(self.dirty,mask)
    end
end

--- clearAllDirty completely clears the dirty bits.
function DroneHubSlotConfig:clearAllDirty()
    self.dirty = 0
end

--- setDirty will set a value as dirty in the bits only if it is actually dirty compared to current config.
function DroneHubSlotConfig:setDirty(newPickupConfig,newDeliveryConfig,dirtyValue)

    if dirtyValue == DroneHubSlotConfig.EDirtyFields.PICKUPPLACEABLE then
        if self.pickupConfig.placeable == newPickupConfig.placeable then
            self:clearDirty(dirtyValue,0)
            return
        end
    elseif dirtyValue == DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE then
        if self.deliveryConfig.placeable == newDeliveryConfig.placeable then
            self:clearDirty(dirtyValue,1)
            return
        end
    elseif dirtyValue == DroneHubSlotConfig.EDirtyFields.PRICELIMIT then
        if self.pickupConfig.priceLimit == newPickupConfig.priceLimit then
            self:clearDirty(dirtyValue,2)
            return
        end
    elseif dirtyValue == DroneHubSlotConfig.EDirtyFields.PRICELIMITUSED then
        if self.pickupConfig.bPriceLimit == newPickupConfig.bPriceLimit then
            self:clearDirty(dirtyValue,3)
            return
        end
    elseif dirtyValue == DroneHubSlotConfig.EDirtyFields.FILLTYPEID then
        if self.pickupConfig.fillTypeIndex == newPickupConfig.fillTypeIndex then
            self:clearDirty(dirtyValue,4)
            return
        end
    elseif dirtyValue == DroneHubSlotConfig.EDirtyFields.FILLLIMITID then
        if self.pickupConfig.fillLimitIndex == newPickupConfig.fillLimitIndex then
            self:clearDirty(dirtyValue,5)
            return
        end
    end

    self.dirty = bitOR(self.dirty,dirtyValue)
end

--- setAlldirty sets all the bits used to 1.
function DroneHubSlotConfig:setAllDirty()
    self.dirty = 0

    for _,dirtyValue in pairs(DroneHubSlotConfig.EDirtyFields) do
        self.dirty = self.dirty + dirtyValue
    end
end

--- isDirty checks if has any dirty.
--@return true if is dirty.
function DroneHubSlotConfig:isDirty()
    return self.dirty ~= 0
end

--- createDroneManager used to create manager to given placeable.
function DroneHubSlotConfig:createDroneManager(placeable)
    if placeable == nil or placeable.droneManager ~= nil then
        return
    end

    placeable.droneManager = PickupDeliveryManager.new(placeable,self.isServer,self.isClient)
    placeable.droneManager:register(true)
end

--- addDroneToManager called to add either a pickup or delivery drone to placeble's drone manager.
--@param bDelivery indicating if is a pickup or delivery drone
function DroneHubSlotConfig:addDroneToManager(bDelivery)
    if self.pickupConfig == nil or self.deliveryConfig == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.deliveryConfig:hasPoint() then
            self:createDroneManager(self.deliveryConfig.placeable)
            self.deliveryConfig.placeable.droneManager:addDeliveryDrone(self.slot.linkedDrone)
        end
    else
        if self.pickupConfig:hasPoint() then
            self:createDroneManager(self.pickupConfig.placeable)
            self.pickupConfig.placeable.droneManager:addPickupDrone(self.slot.linkedDrone,self.pickupConfig)
        end
    end

end

--- removeDroneFromManager called to either remove a pickup or delivery drone from placeable's drone manager.
--@param bDelivery indicating if is a pickup or delivery drone.
function DroneHubSlotConfig:removeDroneFromManager(bDelivery)
    if self.pickupConfig == nil or self.deliveryConfig == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.deliveryConfig:hasPoint() and self.deliveryConfig:hasManager() then
            if self.deliveryConfig.placeable.droneManager:removeDrone(self.slot.linkedDrone) then
                self.deliveryConfig.placeable.droneManager = nil
            end
        end
    else
        if self.pickupConfig:hasPoint() and self.pickupConfig:hasManager() then
            if self.pickupConfig.placeable.droneManager:removeDrone(self.slot.linkedDrone) then
                self.pickupConfig.placeable.droneManager = nil
            end
        end
    end
end

function DroneHubSlotConfig:setManagerToHoldDrone(bDelivery)
    if self.pickupConfig == nil or self.deliveryConfig == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.deliveryConfig:hasPoint() and self.deliveryConfig:hasManager() then
            self.deliveryConfig.placeable.droneManager:holdDrone(self.slot.linkedDrone)
        end
    else
        if self.pickupConfig:hasPoint() and self.pickupConfig:hasManager() then
            self.pickupConfig.placeable.droneManager:holdDrone(self.slot.linkedDrone)
        end
    end

end

function DroneHubSlotConfig:clearManagerHold(bDelivery)
    if self.pickupConfig == nil or self.deliveryConfig == nil or not self.isServer then
        return
    end

    if bDelivery then
        if self.deliveryConfig:hasPoint() and self.deliveryConfig:hasManager() then
            self.deliveryConfig.placeable.droneManager:clearHold(self.slot.linkedDrone)
        end
    else
        if self.pickupConfig:hasPoint() and self.pickupConfig:hasManager() then
            self.pickupConfig.placeable.droneManager:clearHold(self.slot.linkedDrone)
        end
    end
end


--- addVerifyingConfigs stores a pickup and delivery config which will be verified to be valid and then sent later over to replace the current settings.
--@param pickupConfigCopy, is a copy with new settings for the pickupConfig.
--@param deliveryConfigCopy is a copy with new settings for the deliveryConfig.
function DroneHubSlotConfig:addVerifyingConfigs(pickupConfigCopy,deliveryConfigCopy)
    self.verifyPickupConfig = pickupConfigCopy
    self.verifyDeliveryConfig = deliveryConfigCopy
    print("Added verifying config")
end

--- clearVerifyingConfigs is called to clear the stored configs waiting to be verified.
function DroneHubSlotConfig:clearVerifyingConfigs()
    self.verifyPickupConfig = nil
    self.verifyDeliveryConfig = nil
end

--- getPlaceableManagers called to receive the pickup and delivery placeable's drone managers.
--@return pickup and delivery managers if found otherwise nil.
function DroneHubSlotConfig:getPlaceableManagers()
    if self.pickupConfig == nil or not self.pickupConfig:hasPoint() or self.deliveryConfig == nil or not self.deliveryConfig:hasPoint() then
        return nil
    end

    local pickupManager = self.pickupConfig.placeable.droneManager
    local deliveryManager = self.deliveryConfig.placeable.droneManager
    return pickupManager, deliveryManager
end

--- verifyWorkConfigs used to compare the dirty values and add them into a new nilled config to send over to all clients and server.
--@param pickupConfigCopy, is a copy with new settings for the pickupConfig.
--@param deliveryConfigCopy is a copy with new settings for the deliveryConfig.
function DroneHubSlotConfig:verifyWorkConfigs(pickupConfigCopy,deliveryConfigCopy)

    local sendPickupConfig = DronePickupConfig.new()
    sendPickupConfig:nilEverything()
    local sendDeliveryConfig = DroneBaseConfig.new()
    sendDeliveryConfig:nilEverything()

    print("self.dirty is : " .. tostring(self.dirty))

    if bitAND(self.dirty,DroneHubSlotConfig.EDirtyFields.PICKUPPLACEABLE) ~= 0 then
        sendPickupConfig:setPlaceable(pickupConfigCopy.placeable)
        sendPickupConfig.fillTypes = pickupConfigCopy.fillTypes
        sendPickupConfig.allFillTypes = pickupConfigCopy.allFillTypes
    end

    if bitAND(self.dirty,DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE) ~= 0 then
        sendDeliveryConfig:setPlaceable(deliveryConfigCopy.placeable)
        -- if delivery placeable is changed making sure that pickup config's fillTypes will be refreshed as might be new
        sendPickupConfig.fillTypes = pickupConfigCopy.fillTypes
    end

    -- price limit could be large so uses int32 so won't be sent if not dirty
    if bitAND(self.dirty,DroneHubSlotConfig.EDirtyFields.PRICELIMIT) ~= 0 then
        sendPickupConfig.priceLimit = pickupConfigCopy.priceLimit
    end

    -- these values will always be sent as they are sent using int8 type so does not save any by using additional bool to check if they should be sent or not
    sendPickupConfig.bPriceLimit = pickupConfigCopy.bPriceLimit
    sendPickupConfig.fillTypeIndex = pickupConfigCopy.fillTypeIndex
    sendPickupConfig.fillLimitIndex = pickupConfigCopy.fillLimitIndex

    self.slot:changeState(self.slot.ESlotState.APPLYINGSETTINGS)
    ChangeConfigEvent.sendEvent(self.hubOwner,self.slot.slotIndex,sendPickupConfig,sendDeliveryConfig)
end

--- adjustNewManagers is used to create and prepare to send for drone pair of managers that might have changed after new settings.
-- server only.
--@return pickup and delivery manager
function DroneHubSlotConfig:adjustNewManagers()
    if not self.isServer then
        return nil
    end

    local pickupManager = nil
    local deliveryManager = nil

    if self.verifyPickupConfig ~= nil and self.verifyPickupConfig:hasPoint() then
        self:createDroneManager(self.verifyPickupConfig.placeable)
        pickupManager = self.verifyPickupConfig.placeable.droneManager
    elseif self.pickupConfig ~= nil and self.pickupConfig:hasPoint() then
        self:createDroneManager(self.pickupConfig.placeable)
        pickupManager = self.pickupConfig.placeable.droneManager
    end

    if self.verifyDeliveryConfig ~= nil and self.verifyDeliveryConfig:hasPoint() then
        self:createDroneManager(self.verifyDeliveryConfig.placeable)
        deliveryManager = self.verifyDeliveryConfig.placeable.droneManager
    elseif self.deliveryConfig ~= nil and self.deliveryConfig:hasPoint() then
        self:createDroneManager(self.deliveryConfig.placeable)
        deliveryManager = self.deliveryConfig.placeable.droneManager
    end

    return pickupManager, deliveryManager
end

--- applySettings is final step for applying the new settings, will change the pickup and delivery config values with the new values waiting in verify variables.
function DroneHubSlotConfig:applySettings()
    if self.verifyPickupConfig == nil or self.verifyDeliveryConfig == nil then
        return
    end

    self.pickupConfig.fillTypeIndex = self.verifyPickupConfig.fillTypeIndex
    self.pickupConfig.fillLimitIndex = self.verifyPickupConfig.fillLimitIndex
    self.pickupConfig.bPriceLimit = self.verifyPickupConfig.bPriceLimit


    if self.verifyPickupConfig.priceLimit ~= nil then
        self.pickupConfig.priceLimit = self.verifyPickupConfig.priceLimit
    end

    if self.verifyDeliveryConfig:hasPoint() then
        if not self.bLoadedConfig then
            self:removeDroneFromManager(true)
        end
        self.deliveryConfig.placeable = self.verifyDeliveryConfig.placeable
        self.deliveryConfig.name = self.verifyDeliveryConfig.name
        self.deliveryConfig.position = self.verifyDeliveryConfig.position
    end

    if self.verifyPickupConfig:hasPoint() then
        if not self.bLoadedConfig then
            self:removeDroneFromManager(false)
        end
        self.pickupConfig.placeable = self.verifyPickupConfig.placeable
        self.pickupConfig.name = self.verifyPickupConfig.name
        self.pickupConfig.position = self.verifyPickupConfig.position
        self.pickupConfig.allFillTypes = self.verifyPickupConfig.allFillTypes
        self.pickupConfig.fillTypes = self.verifyPickupConfig.fillTypes
    elseif self.verifyDeliveryConfig:hasPoint() then
        -- case where only delivery config has been changed then need to update the fillTypes
        self.pickupConfig.fillTypes = self.verifyPickupConfig.fillTypes
    end

    -- add drone both pickup and delivery managers
    self:addDroneToManager(false)
    self:addDroneToManager(true)

    -- making sure if this was the first time loaded config to mark that it is no more loaded config
    self.bLoadedConfig = false
    self:clearVerifyingConfigs()
    self:clearAllDirty()
end



