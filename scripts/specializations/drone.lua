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

--- Drone specialization for vehicle.
---@class Drone.
Drone = {}



--- prerequisitesPresent checks if all prerequisite specializations are loaded, none needed in this case.
--@param table specializations specializations.
--@return boolean hasPrerequisite true if all prerequisite specializations are loaded.
function Drone.prerequisitesPresent(specializations)
    return true;
end

function Drone.initSpecialization()
    Vehicle.xmlSchema:setXMLSpecializationType("Drone")
    Drone.registerXMLPaths(Vehicle.xmlSchema, "vehicle")
    Drone.registerDroneSaveXMLPaths(Vehicle.xmlSchemaSavegame, "vehicles.vehicle(?).FS22_DroneDelivery.drone")
    Vehicle.xmlSchema:setXMLSpecializationType()
end


--- registerEventListeners registers all needed FS events.
function Drone.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onHubLink", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onHubUnlink", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onHubLoaded", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onTargetReceived", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onTargetLost", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onPathReceived", Drone)
end

--- registerFunctions registers new functions.
function Drone.registerFunctions(vehicleType)
--     SpecializationUtil.registerFunction(vehicleType, "onGridMapGenerated", Drone.onGridMapGenerated)
    SpecializationUtil.registerFunction(vehicleType, "setLinkID", Drone.setLinkID)
    SpecializationUtil.registerFunction(vehicleType, "isMatchingID", Drone.isMatchingID)
    SpecializationUtil.registerFunction(vehicleType, "registerDroneSaveXMLPaths", Drone.registerDroneSaveXMLPaths)
    SpecializationUtil.registerFunction(vehicleType, "getCharge", Drone.getCharge)
    SpecializationUtil.registerFunction(vehicleType, "randomizeCharge", Drone.randomizeCharge)
    SpecializationUtil.registerFunction(vehicleType, "isLinked", Drone.isLinked)
    SpecializationUtil.registerFunction(vehicleType, "changeState", Drone.changeState)
    SpecializationUtil.registerFunction(vehicleType, "isDroneAtHub", Drone.isDroneAtHub)
    SpecializationUtil.registerFunction(vehicleType, "initialize", Drone.initialize)
    SpecializationUtil.registerFunction(vehicleType, "getCurrentStateName", Drone.getCurrentStateName)
    SpecializationUtil.registerFunction(vehicleType, "getID", Drone.getID)
    SpecializationUtil.registerFunction(vehicleType, "isAvailableForPickup", Drone.isAvailableForPickup)
    SpecializationUtil.registerFunction(vehicleType, "getHubSlot", Drone.getHubSlot)
    SpecializationUtil.registerFunction(vehicleType, "setHubAndSlot", Drone.setHubAndSlot)
    SpecializationUtil.registerFunction(vehicleType, "setDroneIdleState", Drone.setDroneIdleState)
    SpecializationUtil.registerFunction(vehicleType, "useAnimation", Drone.useAnimation)
    SpecializationUtil.registerFunction(vehicleType, "setAnimationBool", Drone.setAnimationBool)
    SpecializationUtil.registerFunction(vehicleType, "addOnDroneArrivedListener", Drone.addOnDroneArrivedListener)
    SpecializationUtil.registerFunction(vehicleType, "removeOnDroneArrivedListener", Drone.removeOnDroneArrivedListener)
    SpecializationUtil.registerFunction(vehicleType, "onDroneArrived", Drone.onDroneArrived)
    SpecializationUtil.registerFunction(vehicleType, "addOnDroneReturnedListener", Drone.addOnDroneReturnedListener)
    SpecializationUtil.registerFunction(vehicleType, "removeOnDroneReturnedListener", Drone.removeOnDroneReturnedListener)
    SpecializationUtil.registerFunction(vehicleType, "onDroneReturned", Drone.onDroneReturned)
    SpecializationUtil.registerFunction(vehicleType, "isPickingUp", Drone.isPickingUp)
    SpecializationUtil.registerFunction(vehicleType, "setDirectPosition", Drone.setDirectPosition)
    SpecializationUtil.registerFunction(vehicleType, "setAnimationsToDefault", Drone.setAnimationsToDefault)


end

--- registerEvents registers new events.
function Drone.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onHubLink")
    SpecializationUtil.registerEvent(vehicleType, "onHubUnlink")
    SpecializationUtil.registerEvent(vehicleType, "onHubLoaded")
    SpecializationUtil.registerEvent(vehicleType, "onTargetReceived")
    SpecializationUtil.registerEvent(vehicleType, "onTargetLost")
    SpecializationUtil.registerEvent(vehicleType, "onPathReceived")

end

--- registerOverwrittenFunctions register overwritten functions.
function Drone.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsInUse", Drone.getIsInUse)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsMapHotspotVisible", Drone.getIsMapHotspotVisible)
end

function Drone:getIsMapHotspotVisible(_,_)
    return true
end

--- getIsInUse overridden to return is in use if linked together with a hub, to stop selling.
function Drone:getIsInUse(_,_)
    return self:isLinked()
end


-- local info = {}
--         info.attacherVehicle = testDrone
--         info.attacherVehicleJointDescIndex = 1
--         info.attachable = testBag
--         info.attachableJointDescIndex = 1
--         info.attacherVehicle:attachImplementFromInfo(info)
--         testDrone:detachImplement(1)



--- onLoad
--@param savegame loaded savegame.
function Drone:onLoad(savegame)
	--- Register the spec
	self.spec_drone = self["spec_FS22_DroneDelivery.drone"]
    local xmlFile = self.xmlFile
    local spec = self.spec_drone
    spec.EDroneStates = {NOROUTE = 0,WAITING = 1, CHARGING = 2, PICKING_UP = 3, DELIVERING = 4, RETURNING = 5, EMERGENCYUNLINK = 6, UNLINKED = 7, PICKUPCANCELLED = 8, UNDOCKING = 9, DOCKING = 10 }
    -- states classes will be only valid for server
    spec.droneStates = {}
    spec.currentState = spec.EDroneStates.NOROUTE
    local loadID = ""
    spec.charge = self:randomizeCharge()
    spec.droneDirtyFlag = self:getNextDirtyFlag()
    spec.dronePositionDirtyFlag = self:getNextDirtyFlag()
    spec.defaultCollisionMask = 203002
    spec.linkedCollisionMask = 16384
    spec.bUpdateInitialized = false
    spec.estimatedChargeUse = 5
    spec.leftLegCol = xmlFile:getValue("vehicle.drone#leftLegCollision",nil,self.components,self.i3dMappings)
    spec.rightLegCol = xmlFile:getValue("vehicle.drone#rightLegCollision",nil,self.components,self.i3dMappings)

    -- animation related bools
    spec.bLegsUp = false
    spec.bHookDown = false
    spec.bPalletHooksDown = false
    spec.bRotorsSpinning = false


    spec.lastAbsolutePosition = {}
    spec.lastAbsolutePosition.x, spec.lastAbsolutePosition.y, spec.lastAbsolutePosition.z = getWorldTranslation(self.rootNode)
    spec.lastAbsoluteRotation = {}
    spec.lastAbsoluteRotation.x, spec.lastAbsoluteRotation.y, spec.lastAbsoluteRotation.z = getWorldRotation(self.rootNode)

    if self.isClient then
        spec.samples = {}
        spec.samples.rotor = g_soundManager:loadSampleFromXML(xmlFile, "vehicle.drone.sounds", "rotor", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
    end


    if self.isServer then

        spec.arrivedListeners = {}
        spec.steering = DroneSteering.new()
        -- not all states need a class, some are mainly for showing the state name in hub.
        spec.droneStates[spec.EDroneStates.CHARGING] = DroneChargeState.new()
        spec.droneStates[spec.EDroneStates.CHARGING]:init(self,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.PICKING_UP] = DronePickingUpState.new()
        spec.droneStates[spec.EDroneStates.PICKING_UP]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.DELIVERING] = DroneDeliveringState.new()
        spec.droneStates[spec.EDroneStates.DELIVERING]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.RETURNING] = DroneReturningState.new()
        spec.droneStates[spec.EDroneStates.RETURNING]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.EMERGENCYUNLINK] = DroneEmergencyUnlinkState.new()
        spec.droneStates[spec.EDroneStates.EMERGENCYUNLINK]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.PICKUPCANCELLED] = DronePickupCancelledState.new()
        spec.droneStates[spec.EDroneStates.PICKUPCANCELLED]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.UNDOCKING] = DroneUnDockingState.new()
        spec.droneStates[spec.EDroneStates.UNDOCKING]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.DOCKING] = DroneDockingState.new()
        spec.droneStates[spec.EDroneStates.DOCKING]:init(self,self.owner,self.isServer,self.isClient)

    end


    if savegame ~= nil then
        loadID = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#linkID"),"")
        -- on loading drones from save which is linked adds it to hash table so hubs can easily go through it and link this table reference.
        if loadID ~= "" then
            DroneDeliveryMod.loadedLinkedDrones[loadID] = self

            local loadedState = savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#state")
            if spec.droneStates[loadedState] ~= nil then
                spec.droneStates[loadedState]:setIsSaveLoaded()
            end
            if loadedState ~= nil then
                self:changeState(loadedState)
            end

        end

        spec.charge = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#charge"),self:randomizeCharge())

        spec.bLegsUp = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bLegsUp"),false)
        spec.bHookDown = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bHookDown"),false)
        spec.bPalletHooksDown = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bPalletHooksDown"),false)
        spec.bRotorsSpinning = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bRotorsSpinning"),false)

    end

    self:setLinkID(loadID)

end

--- onDelete when drone deleted,
function Drone:onDelete()

    local spec = self.spec_drone

    if self.samples ~= nil and self.samples.rotor ~= nil then
        g_soundManager:deleteSample(self.samples.rotor)
        self.samples = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
function Drone:onUpdate(dt)
    local spec = self.spec_drone

    if not spec.bUpdateInitialized then
        spec.bUpdateInitialized = true

        -- the animations are valid now in first update tick, sets the initial state as loaded.
        if spec.bLegsUp then
            self:setAnimationTime("legAnimation",1.0) -- at 1.0 time legs are up
        end

        if spec.bHookDown then
            self:setAnimationTime("hookAnimation",1.0) -- at 1.0 time hooks are down
        end

        if spec.bPalletHooksDown then
            self:setAnimationTime("palletHolderAnimation",1.0) -- at 1.0 time hooks are down
        end

        if spec.bRotorsSpinning then
            self:playAnimation("rotorAnimation", nil, nil, true, true)

            if spec.samples ~= nil and spec.samples.rotor ~= nil then
                g_soundManager:playSample(spec.samples.rotor)
            end
        end

    end



    self:raiseActive()

    if not self:isLinked() then

    end

--     self:setAbsolutePosition(x, y, z, rotX, rotY, rotZ)


--     if test > 100 then
--
--         self:playAnimation("rotorAnimation", nil, nil, false, true)
--         self:playAnimation("palletHolderAnimation", 1, 0, false, true)
--         self:playAnimation("hookAnimation", 1, 0, false, true)
--         self:playAnimation("legAnimation", 1, 0, false, true)
--
--     end
--     if self.isServer then
--
--     else
--         if self.networkTimeInterpolator:isInterpolating() then
--             self.networkTimeInterpolator:update(dt)
--             local interpolationAlpha = self.networkTimeInterpolator:getAlpha()
--             local posX, posY, posZ = self.positionInterpolator:getInterpolatedValues(interpolationAlpha)
--             local quatX, quatY, quatZ, quatW = self.quaternionInterpolator:getInterpolatedValues(interpolationAlpha)
--             setTranslation(self.rootNode, posX, posY, posZ)
--             setQuaternion(self.rootNode, quatX, quatY, quatZ, quatW)
--         end
--     end
--

end

--- updateTick called every network tick if raiseactive
--@param is deltatime in ms.
function Drone:updateTick(dt)

    Drone:superClass().updateTick(self, dt)
end


--- debugRender if debug is on for mod then debug renders some .
--@param dt is deltatime received from update function.
function Drone:debugRender(dt)
    if not self.isServer then
        return
    end

    local spec = self.spec_drone
    self:raiseActive()

end

--- Registering drone's xml paths and its objects.
function Drone.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Drone")
--     schema:register(XMLValueType.INT,        basePath .. ".placeableFeeder.birds#maxNumberBirds", "Maximum number of birds")
--     schema:register(XMLValueType.FLOAT,        basePath .. ".placeableFeeder.birds#flyRadius", "Radius of the birds can fly around the feeder")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".drone#leftLegCollision", "left leg collision node")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".drone#rightLegCollision", "right leg collision node")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition3", "third node of eat area")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#fillPlaneNode", "seed fillplane node")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#scareTriggerNode", "scare trigger node")
--     schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#xmlFilePath", "xml file path for bird object")
--     schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#i3dFilePath", "i3d file path for bird object")
--     schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToSpawn",   "Hour value until the birds start to arrive if food in feeder", 5)
--     schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToLeave",   "Hour value until the birds leave if no food in feeder", 5)
--     Storage.registerXMLPaths(schema,            basePath .. ".placeableFeeder.storage")
--     UnloadingStation.registerXMLPaths(schema, basePath .. ".placeableFeeder.unloadingStation")
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".drone.sounds", "rotor")
end


--- Registering drone's savegame xml paths.
function Drone.registerDroneSaveXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Drone")
    schema:register(XMLValueType.STRING, basePath .. "#linkID", "link id between hub and drone")
    schema:register(XMLValueType.INT, basePath .. "#state", "state drone was in")
    schema:register(XMLValueType.INT, basePath .. "#charge", "charge % drone was in")


    schema:register(XMLValueType.BOOL, basePath .. "#bLegsUp", "charge % drone was in")
    schema:register(XMLValueType.BOOL, basePath .. "#bHookDown", "charge % drone was in")
    schema:register(XMLValueType.BOOL, basePath .. "#bPalletHooksDown", "charge % drone was in")
    schema:register(XMLValueType.BOOL, basePath .. "#bRotorsSpinning", "charge % drone was in")


    schema:setXMLSpecializationType()
end

--- On saving
function Drone:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_drone

    xmlFile:setValue(key.."#linkID", spec.linkID)
    xmlFile:setValue(key.."#state",spec.currentState)
    xmlFile:setValue(key.."#charge",spec.charge)

    xmlFile:setValue(key.."#bLegsUp",spec.bLegsUp)
    xmlFile:setValue(key.."#bHookDown",spec.bHookDown)
    xmlFile:setValue(key.."#bPalletHooksDown",spec.bPalletHooksDown)
    xmlFile:setValue(key.."#bRotorsSpinning",spec.bRotorsSpinning)

end

--- onReadStream initial receive at start from server these variables.
function Drone:onReadStream(streamId, connection)

    if connection:getIsServer() then
        local spec = self.spec_drone
        local linkID = streamReadString(streamId)
        self:setLinkID(linkID)
        local state = streamReadInt8(streamId)
        self:changeState(state)
        spec.charge = streamReadInt8(streamId)
        spec.lastAbsolutePosition.x = streamReadFloat32(streamId)
        spec.lastAbsolutePosition.y = streamReadFloat32(streamId)
        spec.lastAbsolutePosition.z = streamReadFloat32(streamId)
        spec.lastAbsoluteRotation.x = NetworkUtil.readCompressedAngle(streamId)
        spec.lastAbsoluteRotation.y = NetworkUtil.readCompressedAngle(streamId)
        spec.lastAbsoluteRotation.z = NetworkUtil.readCompressedAngle(streamId)

        self:setAbsolutePosition(spec.lastAbsolutePosition.x, spec.lastAbsolutePosition.y, spec.lastAbsolutePosition.z, spec.lastAbsoluteRotation.x, spec.lastAbsoluteRotation.y, spec.lastAbsoluteRotation.z)

        spec.bLegsUp = streamReadBool(streamId)
        spec.bHookDown = streamReadBool(streamId)
        spec.bPalletHooksDown = streamReadBool(streamId)
        spec.bRotorsSpinning = streamReadBool(streamId)

        if streamReadBool(streamId) then
            spec.hubSlotIndex = streamReadInt8(streamId)
            spec.hub = NetworkUtil.readNodeObject(streamId)
            spec.hubSlot = spec.hub.spec_droneHub.droneSlots[spec.hubSlotIndex]
        end
        self:raiseActive()
    end
end

--- onWriteStream initial sync at start from server to client these variables.
function Drone:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
        local spec = self.spec_drone
        streamWriteString(streamId,spec.linkID)
        streamWriteInt8(streamId,spec.currentState)
        streamWriteInt8(streamId,spec.charge)
        local x,y,z = getWorldTranslation(self.rootNode)
        local xRot,yRot,zRot = getWorldRotation(self.rootNode)
        streamWriteFloat32(streamId, x)
        streamWriteFloat32(streamId, y)
        streamWriteFloat32(streamId, z)
        NetworkUtil.writeCompressedAngle(streamId, xRot)
        NetworkUtil.writeCompressedAngle(streamId, yRot)
        NetworkUtil.writeCompressedAngle(streamId, zRot)

        streamWriteBool(streamId,spec.bLegsUp)
        streamWriteBool(streamId,spec.bHookDown)
        streamWriteBool(streamId,spec.bPalletHooksDown)
        streamWriteBool(streamId,spec.bRotorsSpinning)

        if streamWriteBool(streamId,self.hub ~= nil) then
            streamWriteInt8(streamId,spec.hubSlotIndex)
            NetworkUtil.writeNodeObject(streamId,self.hub)
        end


    end

end

--- onReadUpdateStream receives from server these variables when dirty raised on server.
function Drone:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_drone

        local state = streamReadInt8(streamId)
        self:changeState(state)

        -- the rotor animation play state is synced automatically by events but the rotor sound will be received by the stream
        local rotorSpin = streamReadBool(streamId)
        if rotorSpin ~= spec.bRotorsSpinning and spec.samples ~= nil and spec.samples.rotor ~= nil then
            spec.bRotorsSpinning = rotorSpin
            if spec.bRotorsSpinning then
                g_soundManager:playSample(spec.samples.rotor)
            else
                g_soundManager:stopSample(spec.samples.rotor)
            end
        end

        if streamReadBool(streamId) then
            spec.lastAbsolutePosition.x = streamReadFloat32(streamId)
            spec.lastAbsolutePosition.y = streamReadFloat32(streamId)
            spec.lastAbsolutePosition.z = streamReadFloat32(streamId)
            spec.lastAbsoluteRotation.x = NetworkUtil.readCompressedAngle(streamId)
            spec.lastAbsoluteRotation.y = NetworkUtil.readCompressedAngle(streamId)
            spec.lastAbsoluteRotation.z = NetworkUtil.readCompressedAngle(streamId)

            self:setAbsolutePosition(spec.lastAbsolutePosition.x, spec.lastAbsolutePosition.y, spec.lastAbsolutePosition.z, spec.lastAbsoluteRotation.x, spec.lastAbsoluteRotation.y, spec.lastAbsoluteRotation.z)
        end


    end

end

--- onWriteUpdateStream syncs from server to client these variabels when dirty raised.
function Drone:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_drone

        streamWriteInt8(streamId,spec.currentState)

        streamWriteBool(streamId,spec.bRotorsSpinning)

        if streamWriteBool(streamId,bitAND(dirtyMask,spec.dronePositionDirtyFlag) ~= 0) then

            local x,y,z = getWorldTranslation(self.rootNode)
            local xRot,yRot,zRot = getWorldRotation(self.rootNode)
            streamWriteFloat32(streamId, x)
            streamWriteFloat32(streamId, y)
            streamWriteFloat32(streamId, z)
            NetworkUtil.writeCompressedAngle(streamId, xRot)
            NetworkUtil.writeCompressedAngle(streamId, yRot)
            NetworkUtil.writeCompressedAngle(streamId, zRot)

        end



    end

end

function Drone:setDirectPosition(position,rotation,bSetDirty)

    self:setAbsolutePosition(position.x, position.y, position.z, rotation.x, rotation.y, rotation.z)

    if self.isServer and bSetDirty then
        self:raiseDirtyFlags(self.spec_drone.dronePositionDirtyFlag)
    end

end

function Drone:setDroneIdleState()
    local spec = self.spec_drone

    if spec.charge >= 100 then
        if spec.trianglePath == nil then
            self:changeState(spec.EDroneStates.NOROUTE)
        else
            self:changeState(spec.EDroneStates.WAITING)
        end
    else
        self:changeState(spec.EDroneStates.CHARGING)
    end

end

function Drone:onHubLink(linkID,position,rotation,hub,hubSlot,hubSlotIndex)
    local spec = self.spec_drone

    self:setLinkID(linkID)
    self:setAbsolutePosition(position.x, position.y, position.z, rotation.x, rotation.y, rotation.z)
    self:setHubAndSlot(hub,hubSlot,hubSlotIndex)

    if self.isServer then
        self:setDroneIdleState()
    end
end

function Drone:setHubAndSlot(hub,hubSlot,hubSlotIndex)
    self.spec_drone.hub = hub
    self.spec_drone.hubSlot = hubSlot
    self.spec_drone.hubSlotIndex = hubSlotIndex
end

function Drone:onHubUnlink()
    self:setLinkID("")

    self:changeState(self.spec_drone.EDroneStates.NOROUTE)
end

-- server only.
function Drone:onHubLoaded(hub,hubSlot,hubSlotIndex)
    local spec = self.spec_drone
    spec.hub = hub
    spec.hubSlot = hubSlot
    spec.hubSlotIndex = hubSlotIndex

    if spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:hubLoaded()
    end
    print("on hub loaded for drone")
end

function Drone:setLinkID(id)
    local spec = self.spec_drone
    spec.linkID = id
    if spec.linkID == nil then
        spec.linkID = ""
    end

    if self.isServer then
        if id ~= "" then
            setCollisionMask(self.rootNode,spec.linkedCollisionMask)
            setCollisionMask(spec.leftLegCol,spec.linkedCollisionMask)
            setCollisionMask(spec.rightLegCol,spec.linkedCollisionMask)

            setRigidBodyType(self.rootNode, RigidBodyType.KINEMATIC)
            self.components[1].isKinematic = true
            self.components[1].isDynamic = false
        else
            setCollisionMask(self.rootNode,spec.defaultCollisionMask)
            setRigidBodyType(self.rootNode, RigidBodyType.DYNAMIC)
            self.components[1].isKinematic = false
            self.components[1].isDynamic = true
        end

        self:removeFromPhysics()
        self:addToPhysics()
    end

end

function Drone:isLinked()
    return self.spec_drone.linkID ~= ""
end

function Drone:isMatchingID(id)
    if id == nil or id == "" then
        return false
    end

    return id == self.spec_drone.linkID
end

function Drone:getID()
    return self.spec_drone.linkID
end

--- getCharge returns the drone charge percentage.
--@return drone charge percentage integer between 0-100.
function Drone:getCharge()
    return self.spec_drone.charge
end

function Drone:getHubSlot()
    return self.spec_drone.hubSlot
end

--- randomizeCharge is used to set an initial random charge on a bought drone.
--@return int value of new charge percentage.
function Drone:randomizeCharge()

    local minCharge = 30
    local maxCharge = 60

    return math.random(minCharge,maxCharge)
end

function Drone:initialize()



end

function Drone:changeState(newState)
    local spec = self.spec_drone

    if newState == nil or newState == spec.currentState then
        return
    end

    local previousState = spec.currentState
    if spec.droneStates ~= nil and spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:leave()
    end

    spec.currentState = newState

    if spec.droneStates ~= nil and spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:enter()
    end

    if self:isDroneAtHub() and previousState == spec.EDroneStates.RETURNING or previousState == spec.EDroneStates.PICKUPCANCELLED then
        self:onDroneReturned()
    end

    if self.isServer then
        self:raiseDirtyFlags(spec.droneDirtyFlag)
    end

    if spec.hubSlot ~= nil then
        spec.hubSlot:onDroneDataChanged()
    end

end

--- getCurrentStateName is used to return localized string of current state name.
--@return string of describing the current state of drone with a name.
function Drone:getCurrentStateName()
    local spec = self.spec_drone
    local stateName = ""

    if spec.currentState == spec.EDroneStates.NOROUTE then
        stateName = g_i18n:getText("drone_NoRoute")
    elseif spec.currentState == spec.EDroneStates.CHARGING then
        stateName = g_i18n:getText("drone_Charging")
    elseif spec.currentState == spec.EDroneStates.PICKING_UP then
        stateName = g_i18n:getText("drone_PickingUp")
    elseif spec.currentState == spec.EDroneStates.DELIVERING then
        stateName = g_i18n:getText("drone_Delivering")
    elseif spec.currentState == spec.EDroneStates.RETURNING then
        stateName = g_i18n:getText("drone_Returning")
    elseif spec.currentState == spec.EDroneStates.WAITING then
        stateName = g_i18n:getText("drone_Waiting")
    elseif spec.currentState == spec.EDroneStates.EMERGENCYUNLINK then
        stateName = g_i18n:getText("drone_EmergencyUnlink")
    elseif spec.currentState == spec.EDroneStates.UNLINKED then
        stateName = g_i18n:getText("drone_Unlinked")
    elseif spec.currentState == spec.EDroneStates.PICKUPCANCELLED then
        stateName = g_i18n:getText("drone_PickupCancelled")
    elseif spec.currentState == spec.EDroneStates.UNDOCKING then
        stateName = g_i18n:getText("drone_Undocking")
    elseif spec.currentState == spec.EDroneStates.DOCKING then
        stateName = g_i18n:getText("drone_Docking")
    end

    return stateName
end

function Drone:isDroneAtHub()
    local spec = self.spec_drone

    if not self:isLinked() then
        return false
    end

    return spec.currentState == spec.EDroneStates.NOROUTE or spec.currentState == spec.EDroneStates.CHARGING or
        spec.currentState == spec.EDroneStates.WAITING
end

function Drone:isPickingUp()
    local spec = self.spec_drone

    if not self:isLinked() then
        return false
    end

    return spec.currentState == spec.EDroneStates.PICKING_UP
end

function Drone:isAvailableForPickup()
    local spec = self.spec_drone

    if not self:isDroneAtHub() or (spec.charge < (spec.charge - spec.estimatedChargeUse)) then
        return false
    end

    return true
end

-- server only.
function Drone:useAnimation(animationName,speed,animTime,bSetDirectTime,bStopAnimation)

    if bSetDirectTime then
        self:setAnimationTime(animationName,animTime)
        self:setAnimationBool(animationName,false,animTime ~= 0)
    elseif bStopAnimation then
        self:stopAnimation(animationName,false)
        self:setAnimationBool(animationName,false,false)
    else
        self:playAnimation(animationName,speed,animTime,false,true)
        self:setAnimationBool(animationName,true)
    end

end

function Drone:setAnimationBool(animationName,bFlip,bActive)
    local spec = self.spec_drone

    if animationName == "legAnimation" then
        if bFlip then
            spec.bLegsUp = not spec.bLegsUp
        else
            spec.bLegsUp = bActive
        end
    elseif animationName == "hookAnimation" then
        if bFlip then
            spec.bHookDown = not spec.bHookDown
        else
            spec.bHookDown = bActive
        end
    elseif animationName == "palletHolderAnimation" then
        if bFlip then
            spec.bPalletHooksDown = not spec.bPalletHooksDown
        else
            spec.bPalletHooksDown = bActive
        end
    elseif animationName == "rotorAnimation" then
        if bFlip then
            spec.bRotorsSpinning = not spec.bRotorsSpinning
        else
            spec.bRotorsSpinning = bActive
        end

        if spec.samples ~= nil and spec.samples.rotor ~= nil then
            if spec.bRotorsSpinning then
                g_soundManager:playSample(spec.samples.rotor)
            else
                g_soundManager:stopSample(spec.samples.rotor)
            end
            self:raiseDirtyFlags(spec.droneDirtyFlag)
        end
    end

end


function Drone:addOnDroneArrivedListener(callback)
    table.addElement(self.spec_drone.arrivedListeners,callback)
end


function Drone:removeOnDroneArrivedListener(callback)
    table.removeElement(self.spec_drone.arrivedListeners, callback)
end

function Drone:onDroneArrived()
    for _, callback in ipairs(self.spec_drone.arrivedListeners) do
        callback()
    end
end

function Drone:addOnDroneReturnedListener(callback)
    table.addElement(self.spec_drone.returnedListeners,callback)
end


function Drone:removeOnDroneReturnedListener(callback)
    table.removeElement(self.spec_drone.returnedListeners, callback)
end

function Drone:onDroneReturned()
    for _, callback in ipairs(self.spec_drone.returnedListeners) do
        callback(self)
    end
end



function Drone:onTargetReceived(target)
    local spec = self.spec_drone

    spec.target = target
    print("on target received")
    if spec.currentState ~= spec.EDroneStates.PICKING_UP then
        self:changeState(spec.EDroneStates.UNDOCKING)
    else
        self:raiseActive()
    end

end

function Drone:onTargetLost()
    local spec = self.spec_drone
    spec.target = nil

    if spec.EDroneStates.PICKUPCANCELLED == spec.currentState then
        --@TODO: create new temp path to hub

    else
        self:changeState(spec.EDroneStates.PICKUPCANCELLED)
    end

    if spec.hubSlot ~= nil then
        spec.hubSlot:noticeDroneReturnal()
    end
end

function Drone:onPathReceived(trianglePath)
    local spec = self.spec_drone

    spec.trianglePath = trianglePath

    if spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:pathReceived(trianglePath)
    end

end

function Drone:setAnimationsToDefault()
    local spec = self.spec_drone

    if spec.bLegsUp then
        self.linkedDrone:useAnimation("legAnimation",-1,self.linkedDrone:getAnimationTime("legAnimation"),nil,nil)
    end

    if spec.bHookDown then
        self.linkedDrone:useAnimation("hookAnimation",-1,self.linkedDrone:getAnimationTime("hookAnimation"),nil,nil)
    end

    if spec.bPalletHooksDown then
        self.linkedDrone:useAnimation("palletHolderAnimation",-1,self.linkedDrone:getAnimationTime("palletHolderAnimation"),nil,nil)
    end

    self:useAnimation("rotorAnimation",nil,nil,false,true)

    if self.isServer then
        self:raiseDirtyFlags(spec.droneDirtyFlag)
    end

end

-- --- collectPickObjectsOW overriden function for collecting pickable objects, avoiding error for trigger node getting added twice.
-- --@param superFunc original function.
-- --@param trigger node
-- function Drone:collectPickObjectsOW(superFunc,node)
--     local spec = self.spec_drone
--     local bExists = false
--
--     if spec == nil then
--         superFunc(self,node)
--         return
--     end
--
--     if getRigidBodyType(node) ~= RigidBodyType.NONE then
--        for _, loadTrigger in ipairs(spec.unloadingStation.unloadTriggers) do
--             if node == loadTrigger.exactFillRootNode then
--                 bExists = true
--                 break
--             end
--         end
--     end
--
--     if not bExists then
--         superFunc(self,node)
--     end
-- end



-- --- onGridMapGenerated bound function to the broadcast when gridmap has been generated.
-- -- server only.
-- function PlaceableFeeder:onGridMapGenerated()
--     self:initializeFeeder()
-- end

















