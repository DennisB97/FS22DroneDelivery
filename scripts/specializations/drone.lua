--[[
This file is part of Bird feeder mod (https://github.com/DennisB97/FS22DroneDelivery)

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
    Drone.registerDroneSaveXMLPaths(Vehicle.xmlSchemaSavegame, "vehicles.vehicle(?).FS22_DroneDelivery.drone")
end


--- registerEventListeners registers all needed FS events.
function Drone.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onFinalizePlacement", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", Drone)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", Drone)

end

--- registerFunctions registers new functions.
function Drone.registerFunctions(vehicleType)
--     SpecializationUtil.registerFunction(vehicleType, "onGridMapGenerated", Drone.onGridMapGenerated)
    SpecializationUtil.registerFunction(vehicleType, "setLinkID", Drone.setLinkID)
    SpecializationUtil.registerFunction(vehicleType, "isMatchingID", Drone.isMatchingID)
    SpecializationUtil.registerFunction(vehicleType, "setPositionAndRotation", Drone.setPositionAndRotation)
    SpecializationUtil.registerFunction(vehicleType, "registerDroneSaveXMLPaths", Drone.registerDroneSaveXMLPaths)
    SpecializationUtil.registerFunction(vehicleType, "getCharge", Drone.getCharge)
    SpecializationUtil.registerFunction(vehicleType, "isLinked", Drone.isLinked)
--
end

--- registerEvents registers new events.
function Drone.registerEvents(vehicleType)
--     SpecializationUtil.registerEvent(vehicleType, "onPlaceableFeederFillLevelChanged")

end

--- registerOverwrittenFunctions register overwritten functions.
function Drone.registerOverwrittenFunctions(vehicleType)
--     SpecializationUtil.registerOverwrittenFunction(vehicleType, "isa", Drone.isa)

end

--- onLoad
--@param savegame loaded savegame.
function Drone:onLoad(savegame)
	--- Register the spec
	self.spec_drone = self["spec_FS22_DroneDelivery.drone"]
    local xmlFile = self.xmlFile
    local spec = self.spec_drone

    local loadID = ""

    if savegame ~= nil then
        loadID = Utils.getNoNil(savegame.xmlFile:getValue(savegame.key..".FS22_DroneDelivery.drone#linkID"),"")
        -- on loading drones from save which is linked adds it to hash table so hubs can easily go through it and link this table reference.
        if loadID ~= "" then
            DroneDeliveryMod.loadedLinkedDrones[loadID] = self
        end
    end
    self:setLinkID(loadID)

    spec.charge = 100

--     spec.networkTimeInterpolator = InterpolationTime.new(1.2)

--     local x, y, z = getTranslation(self.rootNode)
--     local xRot, yRot, zRot = getRotation(self.rootNode)
--     self.sendPosX, self.sendPosY, self.sendPosZ = x, y, z
--     self.sendRotX, self.sendRotY, self.sendRotZ = xRot, yRot, zRot

--     if self.isClient then
--
--         local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(xRot, yRot, zRot)
--         self.positionInterpolator = InterpolatorPosition.new(x, y, z)
--         self.quaternionInterpolator = InterpolatorQuaternion.new(quatX, quatY, quatZ, quatW)
--     end

end

--- onDelete when drone deleted,
function Drone:onDelete()

    local spec = self.spec_drone



end

--- onUpdate update function, called when raiseActive called and initially.
function Drone:onUpdate(dt)
    local spec = self.spec_drone

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

--     if self.isServer then
--         self:updateMove()
--     end

    Drone:superClass().updateTick(self, dt)
end

--- updateMove sets the interpolation loc and rot to send for client if moved enough since last send, to avoid very tiny jitter movement.
-- server only.
function Drone:updateMove()
    local x, y, z = getWorldTranslation(self.rootNode)
    local xRot, yRot, zRot = getWorldRotation(self.rootNode)
    local hasMoved = math.abs(self.sendPosX-x)>0.005 or math.abs(self.sendPosY-y)>0.005 or math.abs(self.sendPosZ-z)>0.005 or
                     math.abs(self.sendRotX-xRot)>0.02 or math.abs(self.sendRotY-yRot)>0.02 or math.abs(self.sendRotZ-zRot)>0.02
    if hasMoved then
        self:raiseDirtyFlags()
        self.bInterpolate = true
        self.sendPosX, self.sendPosY, self.sendPosZ = x, y ,z
        self.sendRotX, self.sendRotY, self.sendRotZ = xRot, yRot, zRot
    end
    return hasMoved
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
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition1", "first node of eat area")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition2", "second node of eat area")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition3", "third node of eat area")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#fillPlaneNode", "seed fillplane node")
--     schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#scareTriggerNode", "scare trigger node")
--     schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#xmlFilePath", "xml file path for bird object")
--     schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#i3dFilePath", "i3d file path for bird object")
--     schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToSpawn",   "Hour value until the birds start to arrive if food in feeder", 5)
--     schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToLeave",   "Hour value until the birds leave if no food in feeder", 5)
--     Storage.registerXMLPaths(schema,            basePath .. ".placeableFeeder.storage")
--     UnloadingStation.registerXMLPaths(schema, basePath .. ".placeableFeeder.unloadingStation")
end


--- Registering drone's savegame xml paths.
function Drone.registerDroneSaveXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("Drone")
    schema:register(XMLValueType.STRING, basePath .. "#linkID", "link id between hub and drone")
    schema:setXMLSpecializationType()
end

--- On saving
function Drone:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_drone

    xmlFile:setValue(key.."#linkID", spec.linkID)

end

-- --- On loading, .
-- function Drone:loadFromXMLFile(xmlFile, key)
--     local spec = self.spec_drone
--
--     self:setLinkID(xmlFile:getValue(key.."#linkID"))
--
--     return true
-- end

--- onReadStream initial receive at start from server these variables.
function Drone:onReadStream(streamId, connection)

    if connection:getIsServer() then
        local spec = self.spec_drone
        spec.linkID = streamReadString(streamId)
        local x = streamReadFloat32(streamId)
        local y = streamReadFloat32(streamId)
        local z = streamReadFloat32(streamId)
        local xRot = NetworkUtil.readCompressedAngle(streamId)
        local yRot = NetworkUtil.readCompressedAngle(streamId)
        local zRot = NetworkUtil.readCompressedAngle(streamId)
        self:setPositionAndRotation({x=x,y=y,z=z},{x=xRot,y=yRot,z=zRot},false)

    end
end

--- onWriteStream initial sync at start from server to client these variables.
function Drone:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
        local spec = self.spec_drone
        streamWriteString(streamId,spec.linkID)
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

--- setPositionAndRotation handles changing the rotation and position of drone, also on clients and can be chosen to interpolate or to directly set on clients.
--@param position is the position to be changed to given as {x=,y=,z=}.
--@param rotation is the euler angles to change to given as {x=,y=,z=}.
--@param shouldInterpolate is bool indicating if the client should have the new position or rotation interpolated or not.
function Drone:setPositionAndRotation(position,rotation,shouldInterpolate)

    if self.isClient and shouldInterpolate and self.positionInterpolator ~= nil and self.quaternionInterpolator ~= nil and self.networkTimeInterpolator ~= nil then
        if position ~= nil then
            self.positionInterpolator:setTargetPosition(position.x, position.y, position.z)
        end
        if rotation ~= nil then
            local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rotation.x,rotation.y,rotation.z)
            self.quaternionInterpolator:setTargetQuaternion(quatX, quatY, quatZ, quatW)
        end

        self.networkTimeInterpolator:startNewPhaseNetwork()
    else
        if position ~= nil then
            setTranslation(self.rootNode, position.x, position.y, position.z)
        end
        if rotation ~= nil then
            setRotation(self.rootNode,rotation.x,rotation.y,rotation.z)
        end

        if self.isClient and self.positionInterpolator ~= nil and self.quaternionInterpolator ~= nil and self.networkTimeInterpolator ~= nil then
            if rotation ~= nil then
                local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rotation.x,rotation.y,rotation.z)
                self.quaternionInterpolator:setQuaternion(quatX, quatY, quatZ, quatW)
            end
            if position ~= nil then
                self.positionInterpolator:setPosition(position.x,position.y,position.z)
            end

            self.networkTimeInterpolator:reset()
        end

    end

end

function Drone:setLinkID(id)
    self.spec_drone.linkID = id
    if self.spec_drone.linkID == nil then
        self.spec_drone.linkID = ""
    end

    if id ~= "" then
        setRigidBodyType(self.rootNode, RigidBodyType.NONE)
        self.components[1].isKinematic = false
        self.components[1].isDynamic = false
    else
        setRigidBodyType(self.rootNode, RigidBodyType.DYNAMIC)
        self.components[1].isKinematic = false
        self.components[1].isDynamic = true
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

function Drone:getCharge()
    return self.spec_drone.charge
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

















