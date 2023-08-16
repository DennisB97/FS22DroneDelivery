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



--- CustomDeliveryPickupPoint specialization for placeables.
---@class CustomDeliveryPickupPoint.
CustomDeliveryPickupPoint = {}
-- hash table for clients to send to server scaled integer keyed with position coordinates in as string.
CustomDeliveryPickupPoint.scaledPoints = {}

--- prerequisitesPresent checks if all prerequisite specializations are loaded, none needed in this case.
--@param table specializations specializations.
--@return boolean hasPrerequisite true if all prerequisite specializations are loaded.
function CustomDeliveryPickupPoint.prerequisitesPresent(specializations)
    return true;
end


--- registerEventListeners registers all needed FS events.
function CustomDeliveryPickupPoint.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", CustomDeliveryPickupPoint)

end


--- registerFunctions registers new functions.
function CustomDeliveryPickupPoint.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onScalePoint", CustomDeliveryPickupPoint.onScalePoint)
    SpecializationUtil.registerFunction(placeableType, "scaleAll", CustomDeliveryPickupPoint.scaleAll)
    SpecializationUtil.registerFunction(placeableType, "onButtonPrimary", CustomDeliveryPickupPoint.onButtonPrimary)
    SpecializationUtil.registerFunction(placeableType, "verifyPlacement", CustomDeliveryPickupPoint.verifyPlacement)
    SpecializationUtil.registerFunction(placeableType, "encodeCoordinates", CustomDeliveryPickupPoint.encodeCoordinates)
    SpecializationUtil.registerFunction(placeableType, "decodeCoordinates", CustomDeliveryPickupPoint.decodeCoordinates)
    SpecializationUtil.registerFunction(placeableType, "serverReceiveScaled", CustomDeliveryPickupPoint.serverReceiveScaled)
    SpecializationUtil.registerFunction(placeableType, "constructBinding", CustomDeliveryPickupPoint.constructBinding)
    SpecializationUtil.registerFunction(placeableType, "onCheckScaledOverlap", CustomDeliveryPickupPoint.onCheckScaledOverlap)
end

--- registerEvents registers new events.
function CustomDeliveryPickupPoint.registerEvents(placeableType)
--     SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederFillLevelChanged")

end

--- registerOverwrittenFunctions register overwritten functions.
function CustomDeliveryPickupPoint.registerOverwrittenFunctions(placeableType)
--     SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", DroneHub.collectPickObjectsOW)


end

--- onLoad loading creates the
--@param savegame loaded savegame.
function CustomDeliveryPickupPoint:onLoad(savegame)
	--- Register the spec
	self.spec_customDeliveryPickupPoint = self["spec_FS22_DroneDelivery.customDeliveryPickupPoint"]
    local xmlFile = self.xmlFile
    local spec = self.spec_customDeliveryPickupPoint

    spec.clearAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#clearAreas",nil,self.components,self.i3dMappings)
    spec.testAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#testAreas",nil,self.components,self.i3dMappings)
    spec.tipOcclusionUpdateAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#tipOcclusionUpdateAreas",nil,self.components,self.i3dMappings)
    spec.levelAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#levelAreas",nil,self.components,self.i3dMappings)
    spec.infoTrigger = xmlFile:getValue("placeable.customDeliveryPickupPoint#infoTrigger",nil,self.components,self.i3dMappings)
    spec.scaleTriggers = xmlFile:getValue("placeable.customDeliveryPickupPoint#scaleTriggers",nil,self.components,self.i3dMappings)
    spec.scale = 1

    local stripes = xmlFile:getValue("placeable.customDeliveryPickupPoint#stripes",nil,self.components,self.i3dMappings)
    spec.allStripes = {}
    spec.allStripes.leftTop = getChildAt(stripes,2)
    spec.allStripes.leftTopPosition = {}
    spec.allStripes.leftTopPosition.x, spec.allStripes.leftTopPosition.y, spec.allStripes.leftTopPosition.z = getTranslation(spec.allStripes.leftTop)
    spec.allStripes.rightTop = getChildAt(stripes,3)
    spec.allStripes.rightTopPosition = {}
    spec.allStripes.rightTopPosition.x, spec.allStripes.rightTopPosition.y, spec.allStripes.rightTopPosition.z = getTranslation(spec.allStripes.rightTop)
    spec.allStripes.rightBottom = getChildAt(stripes,0)
    spec.allStripes.rightBottomPosition = {}
    spec.allStripes.rightBottomPosition.x, spec.allStripes.rightBottomPosition.y, spec.allStripes.rightBottomPosition.z = getTranslation(spec.allStripes.rightBottom)
    spec.allStripes.leftBottom = getChildAt(stripes,1)
    spec.allStripes.leftBottomPosition = {}
    spec.allStripes.leftBottomPosition.x, spec.allStripes.leftBottomPosition.y, spec.allStripes.leftBottomPosition.z = getTranslation(spec.allStripes.leftBottom)
    spec.allStripes.diagonalTopLeftDirection = {}
    spec.allStripes.diagonalTopRightDirection = {}
    spec.allStripes.diagonalTopLeftDirection.x, spec.allStripes.diagonalTopLeftDirection.y,spec.allStripes.diagonalTopLeftDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.leftTopPosition.x - spec.allStripes.rightBottomPosition.x,spec.allStripes.leftTopPosition.y - spec.allStripes.rightBottomPosition.y,spec.allStripes.leftTopPosition.z - spec.allStripes.rightBottomPosition.z)
    spec.allStripes.diagonalTopRightDirection.x, spec.allStripes.diagonalTopRightDirection.y, spec.allStripes.diagonalTopRightDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.rightTopPosition.x - spec.allStripes.leftBottomPosition.x,spec.allStripes.rightTopPosition.y - spec.allStripes.leftBottomPosition.y,spec.allStripes.rightTopPosition.z - spec.allStripes.leftBottomPosition.z)

    spec.allStripes.topDirection = {}
    spec.allStripes.rightDirection = {}
    spec.allStripes.topDirection.x, spec.allStripes.topDirection.y,spec.allStripes.topDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.leftBottomPosition.x - spec.allStripes.leftTopPosition.x,spec.allStripes.leftBottomPosition.y - spec.allStripes.leftTopPosition.y,spec.allStripes.leftBottomPosition.z - spec.allStripes.leftTopPosition.z)
    spec.allStripes.rightDirection.x, spec.allStripes.rightDirection.y, spec.allStripes.rightDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.leftTopPosition.x - spec.allStripes.rightTopPosition.x,spec.allStripes.leftTopPosition.y - spec.allStripes.rightTopPosition.y,spec.allStripes.leftTopPosition.z - spec.allStripes.rightTopPosition.z)

    spec.allStripes.size = 2


    if self.isServer and savegame == nil then

        local x,y,z = getWorldTranslation(self.rootNode)
        local encodedPosition = self.encodeCoordinates(x,y,z)
        if CustomDeliveryPickupPoint.scaledPoints[encodedPosition] ~= nil then
            spec.scale = CustomDeliveryPickupPoint.scaledPoints[encodedPosition]
            CustomDeliveryPickupPoint.scaledPoints[encodedPosition] = nil
            self:scaleAll()
        else
            self:constructBinding()
        end

    else
        self:constructBinding()
    end


end

function CustomDeliveryPickupPoint:constructBinding()
    local spec = self.spec_customDeliveryPickupPoint

    -- if in construction screen and still not bound the scaling action then binds so the placeable can be scaled.
    if g_gui ~= nil and g_gui.currentGuiName == "ConstructionScreen" then

        -- filter out even more to where construction screen is using placeablebrush and has this placeable selected
        if g_gui.guis.ConstructionScreen ~= nil and g_gui.guis.ConstructionScreen.parent.brush ~= nil and  g_gui.guis.ConstructionScreen.parent.brush:class() == ConstructionBrushPlaceable and
            g_gui.guis.ConstructionScreen.parent.brush.storeItem.xmlFilename == self.configFileName then

            spec.bConstructionValidPlacement = false

            -- register M&N keys action buttons for scaling the placeable before placing.
            _, spec.constructionScalingEventId = g_inputBinding:registerActionEvent(InputAction.AXIS_CONSTRUCTION_ACTION_PRIMARY, self, self.onScalePoint,true,false,false,true,nil,false)


            g_inputBinding:setActionEventTextVisibility(spec.constructionScalingEventId, true)
            g_inputBinding:setActionEventText(spec.constructionScalingEventId, g_i18n:getText("customAction_scale"))
            g_inputBinding:setActionEventTextPriority(spec.constructionScalingEventId, GS_PRIO_HIGH)


            g_gui.guis.ConstructionScreen.parent.brush.onButtonPrimary = Utils.overwrittenFunction(g_gui.guis.ConstructionScreen.parent.brush.onButtonPrimary,function(...)
                self:onButtonPrimary(unpack({...}))
                end)

            g_gui.guis.ConstructionScreen.parent.brush.verifyPlacement = Utils.overwrittenFunction(g_gui.guis.ConstructionScreen.parent.brush.verifyPlacement,function(...)
                return self:verifyPlacement(unpack({...}))
                end)

        end

    end


end

function CustomDeliveryPickupPoint.serverReceiveScaled(positionString,scale)
    CustomDeliveryPickupPoint.scaledPoints[positionString] = scale
end

function CustomDeliveryPickupPoint.encodeCoordinates(x,y,z)
    return  x .. " " .. y .. " " .. z
end

function CustomDeliveryPickupPoint.decodeCoordinates(coordinateString)

    local coords = {}
    for coord in string.gmatch(coordinateString, "[^%s]+") do
        table.insert(coords,coord)
    end

    local coordinates = {}
    coordinates.x, coordinates.y, coordinates.z = coords[1], coords[2], coords[3]
    return coordinates
end

function CustomDeliveryPickupPoint:onButtonPrimary(class,superFunc)

    if self.spec_customDeliveryPickupPoint.bConstructionValidPlacement then
        local x,y,z = getWorldTranslation(self.rootNode)
        local positionString = self.encodeCoordinates(x,y,z)

        if self.isServer then
            self.serverReceiveScaled(positionString,self.spec_customDeliveryPickupPoint.scale)
        else
            ChangeCustomPointScaleEvent.sendEvent(positionString,self.spec_customDeliveryPickupPoint.scale)
        end
    end

    superFunc(class)
end

function CustomDeliveryPickupPoint:verifyPlacement(class,superFunc,x,y,z,farmId)
    local spec = self.spec_customDeliveryPickupPoint

    local returnVal = superFunc(class,x,y,z,farmId)

    spec.bLargenedValid = true
    -- if has a larger scale need to custom check placement collision
    if spec.scale > 1 and returnVal == nil then

        local dx, _, dz = localDirectionToWorld(self.rootNode, spec.allStripes.topDirection.x, 0, spec.allStripes.topDirection.z)

        dx,dz = MathUtil.vector2Normalize(dx,dz);

        local yRot = MathUtil.getYRotationFromDirection(dx,dz)

        local halfExtent = spec.allStripes.size / 2
        overlapBox(x,y,z,0,yRot,0,halfExtent,halfExtent,halfExtent,"onCheckScaledOverlap",self,CollisionFlag.STATIC_WORLD + CollisionFlag.GROUND_TIP_BLOCKING,false,true,true,false)
    end

    if returnVal == nil and spec.bLargenedValid then
        self.spec_customDeliveryPickupPoint.bConstructionValidPlacement = true
    else
        self.spec_customDeliveryPickupPoint.bConstructionValidPlacement = false

        -- sets the error message to 205 which equals blocked message
        if returnVal == nil then
            returnVal = 205
        end
    end

    return returnVal
end

function CustomDeliveryPickupPoint:onCheckScaledOverlap(objectId)
    if objectId < 0 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    self.spec_customDeliveryPickupPoint.bLargenedValid = false
    return false
end


function CustomDeliveryPickupPoint:onScalePoint(_,_,_,_,_,_,actionTable)

    local axis = 1
    if actionTable.axisComponent ~= nil and actionTable.axisComponent == "-" then
        axis = -1
    end

    local maxScaling = 8
    local minScaling = 1

    self.spec_customDeliveryPickupPoint.scale = MathUtil.clamp(self.spec_customDeliveryPickupPoint.scale + axis,minScaling,maxScaling)

    self:scaleAll()
end

function CustomDeliveryPickupPoint:scaleAll()
    local spec = self.spec_customDeliveryPickupPoint

    if spec.clearAreasNode ~= nil then
        setScale(spec.clearAreasNode,spec.scale,1,spec.scale)
    end

    if spec.testAreasNode ~= nil then
        setScale(spec.testAreasNode,spec.scale,1,spec.scale)
    end

    if spec.tipOcclusionUpdateAreasNode ~= nil then
        setScale(spec.tipOcclusionUpdateAreasNode,spec.scale,1,spec.scale)
    end

    if spec.levelAreasNode ~= nil then
        setScale(spec.levelAreasNode,spec.scale,1,spec.scale)
    end

    if spec.scaleTriggers ~= nil then
        setScale(spec.scaleTriggers,spec.scale,1,spec.scale)
    end

    local scale = spec.scale
    -- -1 on scale when scale == 1 should be the default position, so nothing should be added
    if scale == 1 then
        scale = 0
    end

    if spec.allStripes.leftTop ~= nil then

        local newLocalPositionX = spec.allStripes.leftTopPosition.x + (spec.allStripes.diagonalTopLeftDirection.x * (scale))
        local newLocalPositionZ = spec.allStripes.leftTopPosition.z + (spec.allStripes.diagonalTopLeftDirection.z * (scale))

        setTranslation(spec.allStripes.leftTop,newLocalPositionX,spec.allStripes.leftTopPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.rightTop ~= nil then
        local newLocalPositionX = spec.allStripes.rightTopPosition.x + (spec.allStripes.diagonalTopRightDirection.x * (scale))
        local newLocalPositionZ = spec.allStripes.rightTopPosition.z + (spec.allStripes.diagonalTopRightDirection.z * (scale))

        setTranslation(spec.allStripes.rightTop,newLocalPositionX,spec.allStripes.rightTopPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.rightBottom ~= nil then
        local newLocalPositionX = spec.allStripes.rightBottomPosition.x + ((spec.allStripes.diagonalTopLeftDirection.x * - 1) * (scale))
        local newLocalPositionZ = spec.allStripes.rightBottomPosition.z + ((spec.allStripes.diagonalTopLeftDirection.z * - 1) * (scale))

        setTranslation(spec.allStripes.rightBottom,newLocalPositionX,spec.allStripes.rightBottomPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.leftBottom ~= nil then
        local newLocalPositionX = spec.allStripes.leftBottomPosition.x + ((spec.allStripes.diagonalTopRightDirection.x * - 1) * (scale))
        local newLocalPositionZ = spec.allStripes.leftBottomPosition.z + ((spec.allStripes.diagonalTopRightDirection.z * - 1) * (scale))

        setTranslation(spec.allStripes.leftBottom,newLocalPositionX,spec.allStripes.leftBottomPosition.y,newLocalPositionZ)
    end

    -- save the size for later use when default is 2m
    spec.allStripes.size = 2 * spec.scale


end

--- onDelete when drone hub deleted, clean up the unloading station and storage and birds and others.
function CustomDeliveryPickupPoint:onDelete()
    local spec = self.spec_customDeliveryPickupPoint

    if spec.constructionScalingEventId ~= nil then
        g_inputBinding:removeActionEvent(spec.constructionScalingEventId)
        spec.constructionScalingEventId = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
function CustomDeliveryPickupPoint:onUpdate(dt)
    local spec = self.spec_customDeliveryPickupPoint



end



--- Event on finalizing the placement of this bird feeder.
-- used to create the birds and feeder states and other variables initialized.
function CustomDeliveryPickupPoint:onFinalizePlacement()
    local spec = self.spec_customDeliveryPickupPoint
    local xmlFile = self.xmlFile

    if self.isServer and FlyPathfinding.bPathfindingEnabled then

        -- add this point to be ignored by the navigation grid as non solid.
        g_currentMission.gridMap3D:addObjectIgnoreID(self.rootNode)

    end





end



--- Registering
function CustomDeliveryPickupPoint.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("CustomDeliveryPickupPoint")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#tipOcclusionUpdateAreas", "root node containing the tip occlusion update areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#clearAreas", "root node containing the clear areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#testAreas", "root node containing the test areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#levelAreas", "root node containing the level areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#stripes", "root node containing the visual stripes")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#infoTrigger", "node for info trigger")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#scaleTriggers", "node that contains collision and trigger to scale both at once")

    schema:setXMLSpecializationType()
end

--- Registering
function CustomDeliveryPickupPoint.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("CustomDeliveryPickupPoint")
    schema:register(XMLValueType.INT,        basePath .. "#scale", "Scaling of this point")

    schema:setXMLSpecializationType()
end

--- On saving,
function CustomDeliveryPickupPoint:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_customDeliveryPickupPoint
    xmlFile:setValue(key.."#scale", spec.scale)

end

--- On loading,
function CustomDeliveryPickupPoint:loadFromXMLFile(xmlFile, key)
    local spec = self.spec_customDeliveryPickupPoint

    spec.scale = Utils.getNoNil(xmlFile:getValue(key.."#scale"),1)
    self:scaleAll()

    return true
end

--- onReadStream initial receive at start from server these variables.
function CustomDeliveryPickupPoint:onReadStream(streamId, connection)

    if connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint

        spec.scale = streamReadInt8(streamId)
        self:scaleAll()

    end
end

--- onWriteStream initial sync at start from server to client these variables.
function CustomDeliveryPickupPoint:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint

        streamWriteInt8(streamId,spec.scale)


    end
end

--- onReadUpdateStream receives from server these variables when dirty raised on server.
function CustomDeliveryPickupPoint:onReadUpdateStream(streamId, timestamp, connection)

    if connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint


    end

end

--- onWriteUpdateStream syncs from server to client these variabels when dirty raised.
function CustomDeliveryPickupPoint:onWriteUpdateStream(streamId, connection, dirtyMask)

    if not connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint


    end
end


-- --- collectPickObjectsOW overriden function for collecting pickable objects, avoiding error for trigger node getting added twice.
-- --@param superFunc original function.
-- --@param trigger node
-- function DroneHub:collectPickObjectsOW(superFunc,node)
--     local spec = self.spec_droneHub
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








