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

--- initSpecialization once init that goes and registers the xml paths and for savefile xml.
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
    SpecializationUtil.registerEventListener(vehicleType, "onPointLost", Drone)
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
    SpecializationUtil.registerFunction(vehicleType, "getCurrentStateName", Drone.getCurrentStateName)
    SpecializationUtil.registerFunction(vehicleType, "getID", Drone.getID)
    SpecializationUtil.registerFunction(vehicleType, "isAvailableForPickup", Drone.isAvailableForPickup)
    SpecializationUtil.registerFunction(vehicleType, "getHubSlot", Drone.getHubSlot)
    SpecializationUtil.registerFunction(vehicleType, "setHubAndSlot", Drone.setHubAndSlot)
    SpecializationUtil.registerFunction(vehicleType, "setDroneIdleState", Drone.setDroneIdleState)
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
    SpecializationUtil.registerFunction(vehicleType, "increaseCharge", Drone.increaseCharge)
    SpecializationUtil.registerFunction(vehicleType, "getTrianglePath", Drone.getTrianglePath)
    SpecializationUtil.registerFunction(vehicleType, "getSteering", Drone.getSteering)
    SpecializationUtil.registerFunction(vehicleType, "getTarget", Drone.getTarget)
    SpecializationUtil.registerFunction(vehicleType, "pickUp", Drone.pickUp)
    SpecializationUtil.registerFunction(vehicleType, "onGetPalletToMount", Drone.onGetPalletToMount)
    SpecializationUtil.registerFunction(vehicleType, "adjustCarriedPallet", Drone.adjustCarriedPallet)
    SpecializationUtil.registerFunction(vehicleType, "drop", Drone.drop)
    SpecializationUtil.registerFunction(vehicleType, "setLoadedTarget", Drone.setLoadedTarget)
    SpecializationUtil.registerFunction(vehicleType, "hasEnoughCharge", Drone.hasEnoughCharge)
    SpecializationUtil.registerFunction(vehicleType, "consumeBattery", Drone.consumeBattery)
    SpecializationUtil.registerFunction(vehicleType, "debugRender", Drone.debugRender)
    SpecializationUtil.registerFunction(vehicleType, "findPalletCollisionsNode", Drone.findPalletCollisionsNode)
    SpecializationUtil.registerFunction(vehicleType, "emergencyDrop", Drone.emergencyDrop)
    SpecializationUtil.registerFunction(vehicleType, "placeToStore", Drone.placeToStore)
    SpecializationUtil.registerFunction(vehicleType, "storeParkingOverlapCallback", Drone.storeParkingOverlapCallback)
    SpecializationUtil.registerFunction(vehicleType, "estimatePathChargeConsumption", Drone.estimatePathChargeConsumption)
    SpecializationUtil.registerFunction(vehicleType, "setDroneAnimationDirectly", Drone.setDroneAnimationDirectly)
    SpecializationUtil.registerFunction(vehicleType, "stopDroneAnimation", Drone.stopDroneAnimation)
    SpecializationUtil.registerFunction(vehicleType, "playDroneAnimation", Drone.playDroneAnimation)
    SpecializationUtil.registerFunction(vehicleType, "setManagers", Drone.setManagers)

end

--- registerEvents registers new events.
function Drone.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onHubLink")
    SpecializationUtil.registerEvent(vehicleType, "onHubUnlink")
    SpecializationUtil.registerEvent(vehicleType, "onHubLoaded")
    SpecializationUtil.registerEvent(vehicleType, "onTargetReceived")
    SpecializationUtil.registerEvent(vehicleType, "onTargetLost")
    SpecializationUtil.registerEvent(vehicleType, "onPathReceived")
    SpecializationUtil.registerEvent(vehicleType, "onPointLost")
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

--- onLoad
--@param savegame loaded savegame.
function Drone:onLoad(savegame)
	--- Register the spec
	self.spec_drone = self["spec_FS22_DroneDelivery.drone"]
    local xmlFile = self.xmlFile
    local spec = self.spec_drone
    spec.EDroneStates = {NOROUTE = 0,WAITING = 1, CHARGING = 2, PICKING_UP = 3, DELIVERING = 4, RETURNING = 5, UNLINKED = 7, PICKUPCANCELLED = 8, UNDOCKING = 9, DOCKING = 10}
    spec.currentState = spec.EDroneStates.NOROUTE
    local loadID = ""
    spec.charge = self:randomizeCharge()
    spec.bUpdateInitialized = false
    -- animation related bools
    spec.bLegsUp = false
    spec.bHookDown = false
    spec.bPalletHooksDown = false
    spec.bRotorsSpinning = false

    if self.isClient then
        spec.samples = {}
        spec.samples.rotor = g_soundManager:loadSampleFromXML(xmlFile, "vehicle.drone.sounds", "rotor", self.baseDirectory, self.components, 1, AudioGroup.VEHICLE, self.i3dMappings, self)
    end

    if self.isServer then
        if FlyPathfinding.bPathfindingEnabled then
            -- this path and spline creator will be used in cases where the usual trianglePath can't be used.
            spec.specialPathCreator = AStar.new(self.isServer,self.isClient)
            spec.specialPathCreator:register(true)
            spec.specialSplineCreator = CatmullRomSplineCreator.new(self.isServer,self.isClient)
            spec.specialSplineCreator:register(true)
        end

        spec.droneDirtyFlag = self:getNextDirtyFlag()
        spec.droneOwnerDirtyFlag = self:getNextDirtyFlag()
        spec.leftLegCol = xmlFile:getValue("vehicle.drone#leftLegCollision",nil,self.components,self.i3dMappings)
        spec.rightLegCol = xmlFile:getValue("vehicle.drone#rightLegCollision",nil,self.components,self.i3dMappings)
        spec.defaultCollisionMask = 203002
        spec.linkedCollisionMask = 0
        spec.dronePositionDirtyFlag = self:getNextDirtyFlag()
        spec.estimatedChargeUse = 5
        self.getObjectToMount = Utils.overwrittenFunction(self.getObjectToMount,self.onGetPalletToMount)
        spec.chargeSpeed = Utils.getNoNil(xmlFile:getValue("vehicle.drone#chargeSpeed"),5)
        spec.chargeSpeed = spec.chargeSpeed / 60 -- from minutes to seconds
        spec.chargeConsumption = Utils.getNoNil(xmlFile:getValue("vehicle.drone#chargeConsumption"),2)
        spec.chargeConsumption = spec.chargeConsumption / 60 -- from minute to seconds
        spec.horizontalSpeed = Utils.getNoNil(xmlFile:getValue("vehicle.drone#horizontalSpeed"),50)
        spec.horizontalSpeed = spec.horizontalSpeed / 3.6 -- to m/s
        spec.verticalSpeed = Utils.getNoNil(xmlFile:getValue("vehicle.drone#verticalSpeed"),1)
        spec.verticalSpeed = spec.verticalSpeed / 3.6 -- to m/s
        spec.carrySpeed = Utils.getNoNil(xmlFile:getValue("vehicle.drone#carrySpeed"),35)
        spec.carrySpeed = spec.carrySpeed / 3.6 -- to m/s
        spec.groundOffset = Utils.getNoNil(xmlFile:getValue("vehicle.drone#minGroundOffset"),2)
        spec.arrivedListeners = {}
        spec.returnedListeners = {}
        spec.steering = DroneSteering.new(self,spec.groundOffset,spec.carrySpeed,spec.horizontalSpeed,spec.verticalSpeed)
        -- states classes will be only valid for server
        spec.droneStates = {}
        -- not all states need a class, some are mainly for showing the state name in hub.
        spec.droneStates[spec.EDroneStates.CHARGING] = DroneChargeState.new()
        spec.droneStates[spec.EDroneStates.CHARGING]:init(self,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.PICKING_UP] = DronePickingUpState.new()
        spec.droneStates[spec.EDroneStates.PICKING_UP]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.DELIVERING] = DroneDeliveringState.new()
        spec.droneStates[spec.EDroneStates.DELIVERING]:init(self,self.owner,self.isServer,self.isClient)
        spec.droneStates[spec.EDroneStates.RETURNING] = DroneReturningState.new()
        spec.droneStates[spec.EDroneStates.RETURNING]:init(self,self.owner,self.isServer,self.isClient)
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

            -- load state and mark that state as loaded state
            local loadedState = savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#state")
            if spec.droneStates[loadedState] ~= nil then
                spec.droneStates[loadedState]:setIsSaveLoaded()
            end
            if loadedState ~= nil then
                self:changeState(loadedState)
            end

            -- load carried pallets rel y position to drone
            self.palletRelPosY = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#carriedPalletRelY"),0)
        end

        spec.charge = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#charge"),self:randomizeCharge())
        spec.bLegsUp = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bLegsUp"),false)
        spec.bHookDown = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bHookDown"),false)
        spec.bPalletHooksDown = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bPalletHooksDown"),false)
        spec.bRotorsSpinning = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#bRotorsSpinning"),false)
    end

    self:setLinkID(loadID)
end

--- onDelete when drone deleted, cleans up audio, steering, path and spline creators.
function Drone:onDelete()

    local spec = self.spec_drone

    if spec.samples ~= nil and spec.samples.rotor ~= nil then
        g_soundManager:deleteSample(spec.samples.rotor)
        spec.samples = nil
    end

    if spec.steering ~= nil then
        spec.steering:delete()
        spec.steering = nil
    end

    if spec.specialPathCreator ~= nil then
        spec.specialPathCreator:delete()
        spec.specialPathCreator = nil
    end

    if spec.specialSplineCreator ~= nil then
        spec.specialSplineCreator:delete()
        spec.specialSplineCreator = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
--@param dt is deltatime in ms.
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

            if self.isServer then
                -- restore carried big bag as target if hooked
                if self.spec_attacherJoints.attachedImplements[1] ~= nil and self.spec_attacherJoints.attachedImplements[1].object ~= nil then
                    self:setLoadedTarget(self.spec_attacherJoints.attachedImplements[1].object,true)
                    self:adjustCarriedPallet(true,self.spec_attacherJoints.attachedImplements[1].object)
                end
            end
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

    if self.isServer then
        if spec.droneStates[spec.currentState] ~= nil then
            spec.droneStates[spec.currentState]:update(dt)
        end

        if not self:isDroneAtHub() and self:isLinked() and g_currentMission.gridMap3D ~= nil and g_currentMission.gridMap3D:isAvailable() then
            self:consumeBattery(dt)
        end
    end

    --self:debugRender(dt)
end

--- debugRender if debug is on for mod then debug renders some .
--@param dt is deltatime received from update function.
function Drone:debugRender(dt)
    if g_currentMission.connectedToDedicatedServer and self.isServer then
        return
    end

    local positionX, positionY, positionZ = getWorldTranslation(self.rootNode)

    renderText3D(positionX - 1, positionY + 1.0, positionZ,0,0,0,0.25,"Current state:")
    renderText3D(positionX + 1.5, positionY + 1.0, positionZ,0,0,0,0.25,self:getCurrentStateName())

    renderText3D(positionX - 1, positionY + 1.5, positionZ,0,0,0,0.25,"Charge:")
    renderText3D(positionX + 1.5, positionY + 1.5, positionZ,0,0,0,0.25,string.format("%.1f",self:getCharge()))
end

--- Registering drone's xml paths and its objects.
function Drone.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Drone")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".drone#leftLegCollision", "left leg collision node")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".drone#rightLegCollision", "right leg collision node")
    schema:register(XMLValueType.INT,        basePath .. ".drone#chargeSpeed", "How much per minute to charge")
    schema:register(XMLValueType.INT,        basePath .. ".drone#chargeConsumption", "How much per minute to consume charge")
    schema:register(XMLValueType.INT,        basePath .. ".drone#horizontalSpeed", "How fast km/h can go at max horizontal level")
    schema:register(XMLValueType.INT,        basePath .. ".drone#verticalSpeed", "How fast km/h can go at max vertically level")
    schema:register(XMLValueType.INT,        basePath .. ".drone#carrySpeed", "How fast km/h can go at max when carrying pallets")
    schema:register(XMLValueType.FLOAT,        basePath .. ".drone#minGroundOffset", "How much m from ground at least when flying")
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
    schema:register(XMLValueType.FLOAT, basePath .. "#carriedPalletRelY", "relative position to drone of the carried pallet")
    schema:setXMLSpecializationType()
end

--- On saving saves all values related to drone and gets carried pallet's relative y position to drone if is carrying something.
function Drone:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_drone
    xmlFile:setValue(key.."#linkID", spec.linkID)
    xmlFile:setValue(key.."#state",spec.currentState)
    xmlFile:setValue(key.."#charge",spec.charge)
    xmlFile:setValue(key.."#bLegsUp",spec.bLegsUp)
    xmlFile:setValue(key.."#bHookDown",spec.bHookDown)
    xmlFile:setValue(key.."#bPalletHooksDown",spec.bPalletHooksDown)
    xmlFile:setValue(key.."#bRotorsSpinning",spec.bRotorsSpinning)

    if self.spec_tensionBelts ~= nil and next(self.spec_tensionBelts.objectsToJoint) ~= nil then
        local palletId,_ = next(self.spec_tensionBelts.objectsToJoint)
        local _,y,_ = worldToLocal(self.rootNode,getTranslation(palletId))
        xmlFile:setValue(key.."#carriedPalletRelY",y)
    end

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
        local x = streamReadFloat32(streamId)
        local y = streamReadFloat32(streamId)
        local z = streamReadFloat32(streamId)
        local rotX = NetworkUtil.readCompressedAngle(streamId)
        local rotY = NetworkUtil.readCompressedAngle(streamId)
        local rotZ = NetworkUtil.readCompressedAngle(streamId)

        self:setAbsolutePosition(x, y, z, rotX, rotY, rotZ)

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

        if streamWriteBool(streamId,spec.hub ~= nil) then
            streamWriteInt8(streamId,spec.hubSlotIndex)
            NetworkUtil.writeNodeObject(streamId,spec.hub)
        end

    end

end

--- onReadUpdateStream receives from server these variables when dirty raised on server.
function Drone:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = self.spec_drone

        if streamReadBool(streamId) then
            spec.bLegsUp = streamReadBool(streamId)
            spec.bHookDown = streamReadBool(streamId)
            spec.bPalletHooksDown = streamReadBool(streamId)
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
            spec.charge = streamReadInt8(streamId)
        end

        if streamReadBool(streamId) then
            spec.hubSlotIndex = streamReadInt8(streamId)
            spec.hub = NetworkUtil.readNodeObject(streamId)
            spec.hubSlot = spec.hub.spec_droneHub.droneSlots[spec.hubSlotIndex]
        end

        if streamReadBool(streamId) then
            local x = streamReadFloat32(streamId)
            local y = streamReadFloat32(streamId)
            local z = streamReadFloat32(streamId)
            local rotX = NetworkUtil.readCompressedAngle(streamId)
            local rotY = NetworkUtil.readCompressedAngle(streamId)
            local rotZ = NetworkUtil.readCompressedAngle(streamId)

            self:setAbsolutePosition(x, y, z, rotX, rotY, rotZ)
        end


    end

end

--- onWriteUpdateStream syncs from server to client these variabels when dirty raised.
function Drone:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = self.spec_drone

        if streamWriteBool(streamId,bitAND(dirtyMask,spec.droneDirtyFlag) ~= 0) then
            streamWriteBool(streamId,spec.bLegsUp)
            streamWriteBool(streamId,spec.bHookDown)
            streamWriteBool(streamId,spec.bPalletHooksDown)
            streamWriteInt8(streamId,spec.currentState)
            streamWriteBool(streamId,spec.bRotorsSpinning)
            streamWriteInt8(streamId,spec.charge)
        end

        if streamWriteBool(streamId,bitAND(dirtyMask,spec.droneOwnerDirtyFlag) ~= 0) then
            streamWriteInt8(streamId,spec.hubSlotIndex)
            NetworkUtil.writeNodeObject(streamId,spec.hub)
        end

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

--- setDirectPosition called to set accurately instantly the drone position and rotation, optionally syncing through updateStream.
--@param position new position of drone given as {x=,y=,z=}.
--@param new rotation of drone given as {x=,y=,z=}.
--@param bSetDirty, if should set the drone as dirty to stream new position and rotation to clients too.
function Drone:setDirectPosition(position,rotation,bSetDirty)

    self:setAbsolutePosition(position.x, position.y, position.z, rotation.x, rotation.y, rotation.z)

    if self.isServer and bSetDirty then
        self:raiseDirtyFlags(self.spec_drone.dronePositionDirtyFlag)
    end

end

--- setDroneIdleState called to choose correct state if idle.
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

--- onHubLink raiseable event when drone gets linked up with a hub, receives params from the hub slot link.
--@param linkID the new string id between slot and drone connecting the two.
--@param position new position for the drone directly in the slot, given as {x=,y=,z=}.
--@param rotation new rotation for hte drone directly in the slot, given as {x=,y=,z=}.
--@param hub is the dronehub that drone is now linked to.
--@param hubSlot is the slot in the hub which drone is now linked to.
--@param hubSlotIndex is the index of the slot.
function Drone:onHubLink(linkID,position,rotation,hub,hubSlot,hubSlotIndex)
    self:setLinkID(linkID)
    self:setAbsolutePosition(position.x, position.y, position.z, rotation.x, rotation.y, rotation.z)
    self:setHubAndSlot(hub,hubSlot,hubSlotIndex)

    if self.isServer then
        self:setDroneIdleState()
    end
end

--- setHubAndSlot gives the hub related variables to drone spec.
--@param hub is the dronehub that drone is now linked to.
--@param hubSlot is the slot in the hub which drone is now linked to.
--@param hubSlotIndex is the index of the slot.
function Drone:setHubAndSlot(hub,hubSlot,hubSlotIndex)
    self.spec_drone.hub = hub
    self.spec_drone.hubSlot = hubSlot
    self.spec_drone.hubSlotIndex = hubSlotIndex
end

--- onHubUnlink raiseable event when hub unlinks from the drone.
--@param bEmergencyUnlink indicates if was an emergeny unlink and drone could possibly be on a delivery or something.
function Drone:onHubUnlink(bEmergencyUnlink)
    local spec = self.spec_drone

    self:setLinkID("")
    self:setHubAndSlot(nil,nil,nil)

    if self.isServer then
        self:changeState(spec.EDroneStates.NOROUTE)
        self:setAnimationsToDefault()
    end

    -- if emergency unlink will emergency drop any carried object and then place both pallet and drone to the store area.
    if bEmergencyUnlink and self.isServer then

        local droppedPallet = self:emergencyDrop()
        if droppedPallet ~= nil then
            self:placeToStore(droppedPallet)
        end

        self:placeToStore(self)
    end
end

--- onHubLoaded raiseable event when hub loads and reconnects with the drone.
--@param hub is the dronehub that drone is now linked to.
--@param hubSlot is the slot in the hub which drone is now linked to.
--@param hubSlotIndex is the index of the slot.
-- server only.
function Drone:onHubLoaded(hub,hubSlot,hubSlotIndex)
    local spec = self.spec_drone
    spec.hub = hub
    spec.hubSlot = hubSlot
    spec.hubSlotIndex = hubSlotIndex

    if spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:hubLoaded()
    end

    self:raiseDirtyFlags(spec.droneOwnerDirtyFlag)
end

--- setLinkID called to set the link id, on server also changes the drone to kinematic or dynamic depending if has id or not, and the collisionmask.
function Drone:setLinkID(id)
    local spec = self.spec_drone
    spec.linkID = id
    if spec.linkID == nil then
        spec.linkID = ""
    end

    if self.isServer then
        if id ~= "" then
            setCollisionMask(self.rootNode,0)
            setCollisionMask(spec.leftLegCol,0)
            setCollisionMask(spec.rightLegCol,0)
            setRigidBodyType(self.rootNode, RigidBodyType.KINEMATIC)
            self.components[1].isKinematic = true
            self.components[1].isDynamic = false
        else
            setCollisionMask(self.rootNode,spec.defaultCollisionMask)
            setCollisionMask(spec.leftLegCol,spec.defaultCollisionMask)
            setCollisionMask(spec.rightLegCol,spec.defaultCollisionMask)
            setRigidBodyType(self.rootNode, RigidBodyType.DYNAMIC)
            self.components[1].isKinematic = false
            self.components[1].isDynamic = true
        end

        self:removeFromPhysics()
        self:addToPhysics()
    end

end

--- isLinked called to ask if drone is linked or not.
--@return true if is linked, which means has a linkID.
function Drone:isLinked()
    return self.spec_drone.linkID ~= ""
end

--- isMatchingID called to check if link id's match.
--@param id is an id to compare the link id with.
--@return true if the given id matched with drone's linkID.
function Drone:isMatchingID(id)
    if id == nil or id == "" then
        return false
    end

    return id == self.spec_drone.linkID
end

--- getID called to receive the linkID.
--@return linkID which is a string id.
function Drone:getID()
    return self.spec_drone.linkID
end

--- getCharge returns the drone charge percentage.
--@return drone charge percentage integer between 0-100.
function Drone:getCharge()
    return self.spec_drone.charge
end

--- getSteering returns the DroneSteering of drone.
function Drone:getSteering()
    return self.spec_drone.steering
end

--- increaseCharge is used to incrementally increase the charge percentage of drone.
--@return true if charge is full after increment.
function Drone:increaseCharge(dt)
    local spec = self.spec_drone
    spec.charge = MathUtil.clamp(spec.charge + (spec.chargeSpeed * (dt/1000)),0,100)

    if spec.charge == 100 then
        return true
    else
        return false
    end
end

--- consumeBattery eats a little bit from the charge variable every call.
--@param dt is deltatime given in ms.
function Drone:consumeBattery(dt)
    local spec = self.spec_drone
    spec.charge = MathUtil.clamp(spec.charge - spec.chargeConsumption * (dt / 1000),0,100)
end

--- getHubSlot called to return the hubSlot this drone is linked to.
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

--- changeState called to change of drone, only server will have the states, but client will have it's state also changed by dirty flags.
function Drone:changeState(newState)
    local spec = self.spec_drone

    if newState == nil or newState == spec.currentState then
        return
    end

    if self.isServer then
        if spec.specialPathCreator ~= nil and spec.specialSplineCreator ~= nil then
            spec.specialPathCreator:interrupt()
            spec.specialSplineCreator:interrupt()
        end
    end


    local previousState = spec.currentState
    if spec.droneStates ~= nil and spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:leave()
    end

    spec.currentState = newState

    if spec.droneStates ~= nil and spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:enter()
    end

    if self.isServer then

        if self:isDroneAtHub() and previousState == spec.EDroneStates.DOCKING then
            self:onDroneReturned()
        end

        self:raiseDirtyFlags(spec.droneDirtyFlag)
    end


    if spec.hub ~= nil and spec.hubSlotIndex ~= nil then
        spec.hub:onDataChange(spec.hubSlotIndex)
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

--- isDroneAtHub called to check if drone is in a state where it is at the drone hub.
--@return true if drone is at hub or if drone is unlinked.
function Drone:isDroneAtHub()
    local spec = self.spec_drone

    if not self:isLinked() then
        return false
    end

    return spec.currentState == spec.EDroneStates.NOROUTE or spec.currentState == spec.EDroneStates.CHARGING or
        spec.currentState == spec.EDroneStates.WAITING
end

--- isPickingUp called to check if drone is in the picking up state.
--@return true if was in picking up state.
function Drone:isPickingUp()
    local spec = self.spec_drone

    if not self:isLinked() then
        return false
    end

    return spec.currentState == spec.EDroneStates.PICKING_UP
end

--- isAvailableForPickup called to check if drone could go and pickup objects.
--@return true if drone can go pickup.
function Drone:isAvailableForPickup()

    if not self:isDroneAtHub() or not self:hasEnoughCharge() then
        return false
    end

    return true
end

--- hasEnoughCharge called to check if drone has enough charge to go on a pickup delivery.
--@return true if has enough charge.
function Drone:hasEnoughCharge()
    local spec = self.spec_drone
    -- charge to be at least left higher than 5 to go pickup
    return (spec.charge - spec.estimatedChargeUse) > 5
end

--- setDroneAnimationDirectly called to set an animation to a specific state.
--@param animationName name of the animation to set.
--@param bState if animation should be set to an off or on state.
function Drone:setDroneAnimationDirectly(animationName,bState)

    local animTime = 0

    if bState == true then
        animTime = 1
    end

    self:setAnimationTime(animationName,animTime)
    self:setAnimationBool(animationName,bState)
end

--- stopDroneAnimation used to stop looping animations, so rotor animation.
--@param animationName animation to stop.
function Drone:stopDroneAnimation(animationName)

    if animationName == "rotorAnimation" then
        self:stopAnimation(animationName,false)
        self:setAnimationBool(animationName,false)
    end

end

--- playDroneAnimation called to start playing an animation from current animation time, direction depending on given bState value.
--@param animationName which animation to start playing.
--@param bState changes direction that the animation plays, true -> positive 1 speed.
function Drone:playDroneAnimation(animationName,bState)
    local speed = -1
    if bState == true then
        speed = 1
    end

    self:playAnimation(animationName,speed,self:getAnimationTime(animationName),false,true)
    self:setAnimationBool(animationName,bState)
end

--- setAnimationBool keeps the drone's animation bools updated, so when drone gets saved and loaded it will have correct animation states.
--@param animationName with animation name finds correspondent bool to change.
--@param bState is true or false state of the animation.
function Drone:setAnimationBool(animationName,bState)
    local spec = self.spec_drone

    if animationName == "legAnimation" then
        spec.bLegsUp = bState
    elseif animationName == "hookAnimation" then
        spec.bHookDown = bState
    elseif animationName == "palletHolderAnimation" then
        spec.bPalletHooksDown = bState
    elseif animationName == "rotorAnimation" then
        spec.bRotorsSpinning = bState
        if spec.samples ~= nil and spec.samples.rotor ~= nil then
            if spec.bRotorsSpinning then
                g_soundManager:playSample(spec.samples.rotor)
            else
                g_soundManager:stopSample(spec.samples.rotor)
            end
        end
    end
    self:raiseDirtyFlags(spec.droneDirtyFlag)
end

--- addOnDroneArrivedListener adds a callback to the drone arrived listener.
--@param callback that will be called when drone arrives somwhere.
function Drone:addOnDroneArrivedListener(callback)
    table.addElement(self.spec_drone.arrivedListeners,callback)
end

--- removeOnDroneArrivedListener removes a callback from the drone arrived listener.
--@param callback that will was suppose to be called when drone arrives somwhere.
function Drone:removeOnDroneArrivedListener(callback)
    table.removeElement(self.spec_drone.arrivedListeners, callback)
end

--- onDroneArrived goes through all the listeners and notices them about drone arriving.
function Drone:onDroneArrived()
    for i, callback in ipairs(self.spec_drone.arrivedListeners) do
        callback(self)
    end
end

--- addOnDroneReturnedListener adds a callback to the drone returned listener
--@param callback that will be called when drone returned to hub.
function Drone:addOnDroneReturnedListener(callback)
    table.addElement(self.spec_drone.returnedListeners,callback)
end

--- removeOnDroneReturnedListener removes a callback from the drone returned listener
--@param callback that was suppose to be called when drone returned to hub.
function Drone:removeOnDroneReturnedListener(callback)
    table.removeElement(self.spec_drone.returnedListeners, callback)
end

--- onDroneReturned informs all the returnedListeners that drone has returned back to hub.
function Drone:onDroneReturned()
    for _, callback in ipairs(self.spec_drone.returnedListeners) do
        callback(self)
    end
end

--- onTargetReceived raiseable event to notice drone has received a target to pickup.
--@param target contains the information required for drone to pickup correct object.
function Drone:onTargetReceived(target)
    local spec = self.spec_drone

    spec.target = target

    -- if delivering state means just after delivering drone was requested again by the manager to go deliver, no need to undock
    if spec.currentState == spec.EDroneStates.DELIVERING then
        self:changeState(spec.EDroneStates.PICKING_UP)
    elseif self:isDroneAtHub() then
        self:changeState(spec.EDroneStates.UNDOCKING)
    else
        self:raiseActive()
    end

end

--- onTargetLost raiseable event to notice drone that the target it had is lost and should return.
function Drone:onTargetLost()
    local spec = self.spec_drone
    spec.target = nil

    -- only if picking up state then changes to cancelled, else will go from undocking -> pickup -> cancelled
    if spec.currentState ~= spec.EDroneStates.PICKING_UP then
        return
    end

    self:changeState(spec.EDroneStates.PICKUPCANCELLED)
    self:playDroneAnimation("hookAnimation",false)
    self:playDroneAnimation("palletHolderAnimation",false)
end

--- getTarget called to get the target drone has.
function Drone:getTarget()
    return self.spec_drone.target
end

--- onPointLost raiseable event will be called when point has been cleared or lost, for example removing a mod that had a placeable factory as pickup or delivery point.
function Drone:onPointLost()
    local spec = self.spec_drone
    spec.trianglePath = nil

    if spec.pickupManager ~= nil then
        self:removeOnDroneArrivedListener(spec.pickupManager.pickupDroneArrivedCallback)
        spec.pickupManager = nil
    end

    if spec.deliveryManager ~= nil then
        self:removeOnDroneArrivedListener(spec.deliveryManager.deliveryDroneArrivedCallback)
        spec.deliveryManager = nil
    end

    if not self:isDroneAtHub() then
        local droppedPallet = self:emergencyDrop()
        if droppedPallet ~= nil then
            self:placeToStore(droppedPallet)
        end
        self:changeState(spec.EDroneStates.PICKUPCANCELLED)
    else
        self:setDroneIdleState()
    end

end

--- setManagers sets the pickup and delivery manager to drone.
--@param pickupManager which has this drone as a pickup drone.
--@param deliveryManager which has this drone as a delivery drone.
function Drone:setManagers(pickupManager,deliveryManager)
    local spec = self.spec_drone
    spec.pickupManager = pickupManager
    spec.deliveryManager = deliveryManager
end

--- onPathReceived raiseable event for drone when paths has been generated.
--@param trianglePath is the three paths that drone uses to go from hub->pickup->delivery->hub, given as {toPickup=,toDelivery=,toHub=}
function Drone:onPathReceived(trianglePath)
    local spec = self.spec_drone

    spec.trianglePath = trianglePath

    self:estimatePathChargeConsumption()

    if self:isDroneAtHub() then
        self:setDroneIdleState()
    end

    if spec.droneStates[spec.currentState] ~= nil then
        spec.droneStates[spec.currentState]:pathReceived(trianglePath)
    end

end

--- getTrianglePath called to receive the three paths.
--@return trianglePath is the three paths that drone uses to go from hub->pickup->delivery->hub, given as {toPickup=,toDelivery=,toHub=}
function Drone:getTrianglePath()
    return self.spec_drone.trianglePath
end

--- setAnimationsToDefault called to set all the animations to default state and bools too.
function Drone:setAnimationsToDefault()
    local spec = self.spec_drone

    if spec.bLegsUp then
        self:setDroneAnimationDirectly("legAnimation",false)
    end

    if spec.bHookDown then
        self:setDroneAnimationDirectly("hookAnimation",false)
    end

    if spec.bPalletHooksDown then
        self:setDroneAnimationDirectly("palletHolderAnimation",false)
    end

    self:stopDroneAnimation("rotorAnimation")

    if self.isServer then
        self:raiseDirtyFlags(spec.droneDirtyFlag)
    end

end

--- pickUp called for drone to pickup the target which should be just below the drone now.
function Drone:pickUp()
    local spec = self.spec_drone
    if spec.target == nil then
        return false
    end

    if spec.target.bHook then
        local info = {}
        info.attacherVehicle = self
        info.attacherVehicleJointDescIndex = 1
        info.attachable = spec.target.pallet
        info.attachableJointDescIndex = 1
        self:attachImplementFromInfo(info)
    else
        self:setAllTensionBeltsActive(true,false)
    end

    spec.target.pallet.bDroneCarried = true
    self:adjustCarriedPallet(true,spec.target.pallet)

    if spec.target.pallet ~= nil then
       spec.target.pallet.carryDrone = self
    end

    return true
end

--- drop called for drone to drop the carried object at current position.
function Drone:drop()
    local spec = self.spec_drone
    if spec.target == nil then
        self:playDroneAnimation("palletHolderAnimation",false)
        self:playDroneAnimation("hookAnimation",false)
        self:setAllTensionBeltsActive(false,false)
        return false
    end

    if spec.target.bHook then
        -- check if big bag still exists then can detach
        if self.spec_attacherJoints.attachedImplements[1] ~= nil and self.spec_attacherJoints.attachedImplements[1].object ~= nil and entityExists(PickupDeliveryHelper.getObjectId(self.spec_attacherJoints.attachedImplements[1].object)) then
            self:detachImplement(1)
        end
        self:playDroneAnimation("hookAnimation",false)
    else
        self:setAllTensionBeltsActive(false,false)
        self:playDroneAnimation("palletHolderAnimation",false)
    end
    spec.target.pallet.carryDrone = nil
    spec.target.pallet.bDroneCarried = false
    self:adjustCarriedPallet(false,spec.target.pallet)
    return true
end

--- onGetPalletToMount overwritten tensionBelt function that receives the possible objects to attach with tensionbelt,
-- in this case for drone it will only be the object in the target table.
--@param superFunc original function which won't be called on the drone.
--@param belt that is looking for objects.
function Drone:onGetPalletToMount(superFunc,belt)
    local spec = self.spec_drone


    if spec.currentState == spec.EDroneStates.DELIVERING and not spec.bUpdateInitialized then
        -- if on loading the game in delivering state and not update initialized yet, will check and match pallet from the global PalletAddition.loadedCarriedPallets table
        if PalletAddition.loadedCarriedPallets[spec.linkID] ~= nil then
            local pallet = PalletAddition.loadedCarriedPallets[spec.linkID]
            local palletId = PickupDeliveryHelper.getObjectId(pallet)
            local x,y,z = localToWorld(self.rootNode,0,self.palletRelPosY,0)

            if pallet ~= nil and not pallet.isDeleted and entityExists(palletId) then
                setTranslation(palletId,x,y,z)
                local dirX,_,dirZ = localDirectionToWorld(self.rootNode,0,0,1)
                local yRot = MathUtil.getYRotationFromDirection(dirX,dirZ)
                setRotation(palletId,0,yRot,0)
                self:adjustCarriedPallet(true,pallet)
                self:setLoadedTarget(pallet,false)
            end

            PalletAddition.loadedCarriedPallets[spec.linkID] = nil
            spec.loadedPalletRelPos = nil
        end

    end

    local objectsInTensionBeltRange = {}
    local numObjectsIntensionBeltRange = 0

    if spec.target == nil or spec.target.pallet == nil or spec.target.pallet.isDeleted or not entityExists(spec.target.objectId) then
        return objectsInTensionBeltRange, numObjectsIntensionBeltRange
    end
    -- as long as has a valid target can set that one as the one to be bound with tensionbelts
    local nodeId = spec.target.pallet:getTensionBeltNodeId()
    local nodes = spec.target.pallet:getMeshNodes()

    objectsInTensionBeltRange[nodeId] = {physics=nodeId, visuals=nodes, object=spec.target.pallet}
    numObjectsIntensionBeltRange = 1

    return objectsInTensionBeltRange, numObjectsIntensionBeltRange
end

--- adjustCarriedPallet will adjust the collisionmask of carried pallet.
--@param bCarrying bool indicating if carrying the pallet.
--@param pallet is the pallet to change collisionMask on.
function Drone:adjustCarriedPallet(bCarrying,pallet)
    if not self.isServer or pallet == nil then
        return
    end

    local spec = self.spec_drone
    local id = PickupDeliveryHelper.getObjectId(pallet)

    if id == nil or id < 0 then
        Logging.warning("custom pallet/bale/ object used for pickup ?, did not have self.rootNode or self.nodeId valid!")
        return
    end

    if pallet.isDeleted or not entityExists(id) then
        return
    end

    if bCarrying then
        spec.originalPalletCollisionMasks = {}
        spec.originalPalletCollisionMasks.child = {}
        spec.originalPalletCollisionMasks.main = getCollisionMask(id)
        setCollisionMask(id,CollisionFlag.PLAYER)

        local collisionsNode = self:findPalletCollisionsNode(id)
        if entityExists(collisionsNode) then
            for i = 0, getNumOfChildren(collisionsNode)-1 do
                local childNode = getChildAt(collisionsNode,i)
                if getIsCompoundChild(childNode) then
                    spec.originalPalletCollisionMasks.child[childNode] = getCollisionMask(childNode)
                    setCollisionMask(childNode,CollisionFlag.PLAYER)
                end
            end
        end

        -- requires this for the loaded pallet to stay under drone
        if pallet.spec_bigBag == nil then
            if getRigidBodyType(id) ~= RigidBodyType.DYNAMIC then
                setRigidBodyType(id, RigidBodyType.DYNAMIC)
                removeFromPhysics(id)
                addToPhysics(id)
            end
        end
    else
        if entityExists(id) then
            setCollisionMask(id,spec.originalPalletCollisionMasks.main)

            for childNode,originalMask in pairs(spec.originalPalletCollisionMasks.child) do
                if entityExists(childNode) then
                    setCollisionMask(childNode,originalMask)
                end
            end
        end
    end

end

--- findPalletCollisionsNode ugly hack to find the default game's assets collisions transform node, which usually exists as child of root or child child.
--@param palletId the root id of the pallet.
function Drone:findPalletCollisionsNode(palletId)
    if palletId == nil or palletId <= 0 then
        return -1
    end

    local maxSearchDepth = 3
    local currentDepth = 1
    local currentChildNode = palletId
    while true do

        if entityExists(getChild(currentChildNode,"collisions")) then
            return getChild(currentChildNode,"collisions")
        end

        local childCount = getNumOfChildren(currentChildNode)
        if childCount < 1 then
            return -1
        end

        currentChildNode = getChildAt(currentChildNode,0)

        if currentDepth > maxSearchDepth then
            return -1
        end

        currentDepth = currentDepth + 1
    end

end

--- setLoadedTarget called to give the drone the target loaded route.
--@param pallet which is the target to pickup.
--@param bHook bool indicating if uses the hook to carry.
function Drone:setLoadedTarget(pallet,bHook)
    if pallet == nil then
        return
    end
    local spec = self.spec_drone

    spec.target = {}
    spec.target.pallet = pallet
    spec.target.bHook = bHook
    spec.target.objectId = PickupDeliveryHelper.getObjectId(pallet)
    spec.target.drone = self
    pallet.carryDrone = self
end

--- emergencyDrop called to drop any carried object.
--@return dropped object if was carrying otherwise nil.
function Drone:emergencyDrop()
    local droppedObject = nil

    -- drop a bigbag if is carried
    if self.spec_attacherJoints.attachedImplements[1] ~= nil and self.spec_attacherJoints.attachedImplements[1].object ~= nil then
        self:adjustCarriedPallet(false,self.spec_attacherJoints.attachedImplements[1].object)
        droppedObject = self.spec_attacherJoints.attachedImplements[1].object
        self:detachImplement(1)
    end

    for objectId, data in pairs(self.spec_tensionBelts.objectsToJoint) do
        self:adjustCarriedPallet(false,g_currentMission.nodeToObject[objectId])
        droppedObject = g_currentMission.nodeToObject[objectId]
    end

    self:setAllTensionBeltsActive(false,false)

    self:playDroneAnimation("hookAnimation",false)
    self:playDroneAnimation("palletHolderAnimation",false)

    return droppedObject
end

--- placeToStore called to place the object into the store area.
--@param object that should be placed in the store area.
function Drone:placeToStore(object)
    local spec = self.spec_drone

    local storeSpawnPlace = g_currentMission.storeSpawnPlaces[1]
    if storeSpawnPlace == nil or object == nil or object.isDeleted then
        return
    end

    local tries = 0
    local maxTries = 1000
    local objectId = PickupDeliveryHelper.getObjectId(object)

    while tries <= maxTries do

        local randomPosition = {x=storeSpawnPlace.startX,y=storeSpawnPlace.startY + 1,z=storeSpawnPlace.startZ}

        local randomDistance = math.random(0,storeSpawnPlace.width)
        randomPosition.x = randomPosition.x + (storeSpawnPlace.dirX * randomDistance)
        randomPosition.z = randomPosition.z + (storeSpawnPlace.dirZ * randomDistance)

        spec.bStoreOverlapCheckSolid = false
        overlapBox(randomPosition.x,randomPosition.y,randomPosition.z,0,0,0,1,1,1,"storeParkingOverlapCallback",self,CollisionFlag.VEHICLE + CollisionFlag.FILLABLE + CollisionFlag.DYNAMIC_OBJECT,true,false,true,false)

        if not spec.bStoreOverlapCheckSolid then
            if object == self then -- case when is drone and not carried pallet
                local rotX, rotY, rotZ = getWorldRotation(self.rootNode)
                self:setDirectPosition(randomPosition,{x=rotX,y=rotY,z=rotZ},true)
            else

                if object.spec_bigBag ~= nil then
                    local tempRootNode = createTransformGroup("tempRootNode")
                    setTranslation(tempRootNode,randomPosition.x,randomPosition.y,randomPosition.z)
                    for i, component in pairs(object.components) do
                        local x,y,z = localToWorld(tempRootNode, unpack(component.originalTranslation))
                        setTranslation(component.node,x,y,z)
                    end
                    delete(tempRootNode)
                else
                    setTranslation(objectId,randomPosition.x,randomPosition.y,randomPosition.z)
                end
            end
            break
        end

        tries = tries + 1
    end

end

--- storeParkingOverlapCallback callback to the overlapBox test trying to find a free position to store object in the store area.
--@param objectId is hit object id.
--@return true to continue overlap testing, false stops it.
function Drone:storeParkingOverlapCallback(objectId)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil then
        return true
    end

    self.spec_drone.bStoreOverlapCheckSolid = true
    return false
end

--- estimatePathChargeConsumption estimates in a simple way an estimate how much charge will be used in one trip.
-- is not accurate as drone is never gonna stop working if charge reaches <1%, mainly to require at least some amount of charge for the drone if it is gonna go pickup a delivery.
function Drone:estimatePathChargeConsumption()
    local spec = self.spec_drone

    if spec.trianglePath == nil then
        return
    end

    local totalDistance = 0
    totalDistance = totalDistance + spec.trianglePath.toPickup:getSplineLength()
    totalDistance = totalDistance + spec.trianglePath.toDelivery:getSplineLength()
    totalDistance = totalDistance + spec.trianglePath.toHub:getSplineLength()

    -- simply calculates 90% as fullspeed and rest vertical
    local fullSpeedDistance = totalDistance * 0.85
    local slowSpeedDistance = totalDistance - fullSpeedDistance

    local secondsTaken = fullSpeedDistance / spec.horizontalSpeed
    secondsTaken = secondsTaken + (slowSpeedDistance / spec.verticalSpeed)

    spec.estimatedChargeUse = secondsTaken * spec.chargeConsumption
end











